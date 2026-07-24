#!/usr/bin/env node
/**
 * Enterprise release script for @olonjs/stack, @olonjs/core, @olonjs/react,
 * @olonjs/studio, @olonjs/mcp, @olonjs/next, @olonjs/cli (plus @jsonpages/* compat packages).
 * Run from monorepo root. Uses NPM_TOKEN for authentication (no interactive login).
 *
 * Publish order follows the ADR-0016 dependency graph: stack -> core ->
 * studio -> react (react pins core + the optional studio peer to the
 * versions just published) -> mcp -> next (pins @olonjs/core) ->
 * tenant-alpha (pins @olonjs/core/react/studio, rebuilds + regenerates alpha DNA) ->
 * tenant-next (apps/next; pins core/react/studio/next, rebuilds + regenerates next DNA) ->
 * cli -> compat.
 *
 * Usage:
 *   Put NPM_TOKEN in root .env (one line: NPM_TOKEN=npm_xxx), then: npm run release
 *   Or: NPM_TOKEN=<token> npm run release
 *
 * Options:
 *   --dry-run    Build and bump versions only; do not publish or commit version bumps
 *   --skip-git-check   Do not require a clean git working tree
 */

import { execSync, spawnSync } from "child_process";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { resolveTenantAppDir } from "./releaseTenantPaths.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

const NPM_REGISTRY = "https://registry.npmjs.org/";
const AUTH_LINE = "//registry.npmjs.org/:_authToken=${NPM_TOKEN}";

// --- Load .env (so you don't need export NPM_TOKEN every time) ---
function loadEnv() {
  const envPath = path.join(ROOT, ".env");
  if (!fs.existsSync(envPath)) return;
  const content = fs.readFileSync(envPath, "utf8");
  for (const line of content.split("\n")) {
    const m = line.match(/^\s*NPM_TOKEN\s*=\s*(.+?)\s*$/);
    if (m) {
      const val = m[1].replace(/^["']|["']$/g, "").trim();
      if (val && !process.env.NPM_TOKEN) process.env.NPM_TOKEN = val;
      break;
    }
  }
}
loadEnv();

// --- Parsing ---
const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const skipGitCheck = args.includes("--skip-git-check");

// --- Logging ---
function log(msg, level = "info") {
  const ts = new Date().toISOString();
  const prefix = level === "error" ? "ERROR" : level === "warn" ? "WARN" : "INFO";
  console.log(`${ts} [${prefix}] ${msg}`);
}

function run(cmd, cwd = ROOT, env = undefined) {
  const dir = cwd !== ROOT ? `(cd ${path.relative(ROOT, cwd) || "."} && ` : "";
  const close = cwd !== ROOT ? ")" : "";
  const display = dir ? `${dir}${cmd}${close}` : cmd;
  log(`$ ${display}`, "info");
  const opts = { cwd, stdio: "inherit", shell: true, env: env ?? process.env };
  const result = spawnSync(cmd, opts);
  if (result.status !== 0) {
    throw new Error(`Command failed (exit ${result.status}): ${cmd}`);
  }
}

function runSilent(cmd, cwd = ROOT) {
  return execSync(cmd, { cwd, encoding: "utf8" }).trim();
}

// --- Validation ---
function assertRoot() {
  const pkgPath = path.join(ROOT, "package.json");
  if (!fs.existsSync(pkgPath)) {
    throw new Error("Not in monorepo root: package.json not found");
  }
  const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
  if (!pkg.workspaces || !Array.isArray(pkg.workspaces)) {
    throw new Error("Root package.json must define workspaces");
  }
  log("Monorepo root validated");
}

function assertNpmToken() {
  const token = process.env.NPM_TOKEN;
  if (!token || token.length < 10) {
    throw new Error(
      "NPM_TOKEN is required. Add it to root .env (ignored by git):\n  echo 'NPM_TOKEN=npm_your_token' > .env\n  Or: export NPM_TOKEN=your_token"
    );
  }
  log("NPM_TOKEN is set");
}

function ensureNpmRc() {
  const npmrcPath = path.join(ROOT, ".npmrc");
  let content = "";
  if (fs.existsSync(npmrcPath)) {
    content = fs.readFileSync(npmrcPath, "utf8");
  }
  if (!content.includes("_authToken") && !content.includes("registry.npmjs.org")) {
    const line = AUTH_LINE + "\n";
    fs.appendFileSync(npmrcPath, line);
    log("Appended auth line to .npmrc (uses NPM_TOKEN from env)");
  }
}

function assertGitClean() {
  if (skipGitCheck) {
    log("Skipping git working tree check (--skip-git-check)");
    return;
  }
  try {
    const status = runSilent("git status --porcelain");
    if (status) {
      log("Working tree has uncommitted changes (release will proceed; commit the version bumps afterward)", "warn");
      return;
    }
    log("Git working tree is clean");
  } catch (e) {
    if (e.message.includes("Command failed")) {
      log("Could not run git status (is git available?). Proceeding.", "warn");
    } else {
      throw e;
    }
  }
}

// --- Package.json helpers ---
function readPackageJson(dir) {
  const p = path.join(dir, "package.json");
  if (!fs.existsSync(p)) throw new Error(`package.json not found: ${dir}`);
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

function writePackageJson(dir, pkg) {
  const p = path.join(dir, "package.json");
  fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + "\n", "utf8");
}

function getVersion(dir) {
  return readPackageJson(dir).version;
}

function packageVersionExists(packageName, version) {
  const escapedName = packageName.replace(/"/g, '\\"');
  const escapedVersion = version.replace(/"/g, '\\"');
  try {
    runSilent(`npm view "${escapedName}@${escapedVersion}" version`);
    return true;
  } catch {
    return false;
  }
}

function bumpPatch(version) {
  const m = version.match(/^(\d+)\.(\d+)\.(\d+)(?:-.+)?$/);
  if (!m) {
    throw new Error(`Cannot bump patch for invalid semver: ${version}`);
  }
  const major = Number(m[1]);
  const minor = Number(m[2]);
  const patch = Number(m[3]) + 1;
  return `${major}.${minor}.${patch}`;
}

function ensureUnpublishedVersion(dir, preferredVersion) {
  const pkg = readPackageJson(dir);
  let candidate = preferredVersion;
  while (packageVersionExists(pkg.name, candidate)) {
    candidate = bumpPatch(candidate);
  }
  pkg.version = candidate;
  writePackageJson(dir, pkg);
  if (candidate !== preferredVersion) {
    log(`Resolved unpublished version for ${pkg.name}: ${preferredVersion} -> ${candidate}`, "warn");
  } else {
    log(`Resolved unpublished version for ${pkg.name}: ${candidate}`);
  }
  return candidate;
}

/**
 * Same bump as always (`npm version patch`), then reuse ensureUnpublishedVersion
 * (already used by @jsonpages/* compat) so a local tree that lags npm never
 * tries to publish a version that already exists.
 */
function patchToUnpublished(workspaceName, dir) {
  run(`npm version patch --no-git-tag-version -w ${workspaceName}`);
  return ensureUnpublishedVersion(dir, getVersion(dir));
}

// --- Dry-run: full command plan (enterprise: show exactly what would run) ---
// All version/publish run from root with -w so .npmrc and NPM_TOKEN apply.
function getCommandPlan() {
  return [
    { step: "1/6", desc: "Build all workspaces", cmd: "npm run build:all", cwd: "root", skip: false },
    { step: "2/6", desc: "@olonjs/stack", cmd: "npm version patch --no-git-tag-version -w @olonjs/stack", cwd: "root", skip: false },
    { step: "2/6", desc: "@olonjs/stack (publish)", cmd: "npm publish --access public -w @olonjs/stack", cwd: "root", skip: dryRun },
    { step: "3/6", desc: "@olonjs/core", cmd: "npm run build -w @olonjs/core", cwd: "root", skip: false },
    { step: "3/6", desc: "@olonjs/core", cmd: "npm version patch --no-git-tag-version -w @olonjs/core", cwd: "root", skip: false },
    { step: "3/6", desc: "@olonjs/core (publish)", cmd: "npm publish --access public -w @olonjs/core", cwd: "root", skip: dryRun },
    { step: "3b/6", desc: "@olonjs/studio", cmd: "Update package.json @olonjs/core -> ^<new-version>", cwd: "packages/studio", skip: false },
    { step: "3b/6", desc: "@olonjs/studio", cmd: "npm run build -w @olonjs/studio", cwd: "root", skip: false },
    { step: "3b/6", desc: "@olonjs/studio", cmd: "npm version patch --no-git-tag-version -w @olonjs/studio", cwd: "root", skip: false },
    { step: "3b/6", desc: "@olonjs/studio (publish)", cmd: "npm publish --access public -w @olonjs/studio", cwd: "root", skip: dryRun },
    { step: "3c/6", desc: "@olonjs/react", cmd: "Update package.json @olonjs/core -> ^<new-version>, peerDependencies['@olonjs/studio'] -> ^<studio-version>", cwd: "packages/react", skip: false },
    { step: "3c/6", desc: "@olonjs/react", cmd: "npm run build -w @olonjs/react", cwd: "root", skip: false },
    { step: "3c/6", desc: "@olonjs/react", cmd: "npm version patch --no-git-tag-version -w @olonjs/react", cwd: "root", skip: false },
    { step: "3c/6", desc: "@olonjs/react (publish)", cmd: "npm publish --access public -w @olonjs/react", cwd: "root", skip: dryRun },
    { step: "3d/6", desc: "@olonjs/mcp", cmd: "npm run build -w @olonjs/mcp", cwd: "root", skip: false },
    { step: "3d/6", desc: "@olonjs/mcp", cmd: "npm version patch --no-git-tag-version -w @olonjs/mcp", cwd: "root", skip: false },
    { step: "3d/6", desc: "@olonjs/mcp (publish)", cmd: "npm publish --access public -w @olonjs/mcp", cwd: "root", skip: dryRun },
    { step: "3e/6", desc: "@olonjs/next", cmd: "Update package.json @olonjs/core -> ^<new-version>", cwd: "packages/next", skip: false },
    { step: "3e/6", desc: "@olonjs/next", cmd: "npm run build -w @olonjs/next", cwd: "root", skip: false },
    { step: "3e/6", desc: "@olonjs/next", cmd: "npm version patch --no-git-tag-version -w @olonjs/next", cwd: "root", skip: false },
    { step: "3e/6", desc: "@olonjs/next (publish)", cmd: "npm publish --access public -w @olonjs/next", cwd: "root", skip: dryRun },
    { step: "4/6", desc: "tenant-alpha", cmd: "Update package.json @olonjs/core/@olonjs/react/@olonjs/studio -> ^<new-versions>", cwd: "apps/tenant-alpha", skip: false },
    { step: "4/6", desc: "tenant-alpha", cmd: "npm install -w tenant-alpha", cwd: "root", skip: false },
    { step: "4/6", desc: "tenant-alpha", cmd: "npm run build -w tenant-alpha", cwd: "root", skip: false },
    { step: "4/6", desc: "tenant-alpha", cmd: "npm run dist -w tenant-alpha", cwd: "root", skip: false },
    { step: "4b/6", desc: "tenant-next", cmd: "Update package.json @olonjs/core/@olonjs/react/@olonjs/studio/@olonjs/next -> ^<new-versions>", cwd: "apps/next", skip: false },
    { step: "4b/6", desc: "tenant-next", cmd: "npm install -w tenant-next", cwd: "root", skip: false },
    { step: "4b/6", desc: "tenant-next", cmd: "npm run build -w tenant-next", cwd: "root", skip: false },
    { step: "4b/6", desc: "tenant-next", cmd: "npm run dist -w tenant-next", cwd: "root", skip: false },
    { step: "5/6", desc: "@olonjs/cli", cmd: "npm run build -w @olonjs/cli", cwd: "root", skip: false },
    { step: "5/6", desc: "@olonjs/cli", cmd: "npm version patch --no-git-tag-version -w @olonjs/cli", cwd: "root", skip: false },
    { step: "5/6", desc: "@olonjs/cli (publish)", cmd: "npm publish --access public -w @olonjs/cli", cwd: "root", skip: dryRun },
    { step: "6/6", desc: "@jsonpages/stack compat", cmd: "npm publish --access public -w @jsonpages/stack", cwd: "root", skip: dryRun },
    { step: "6/6", desc: "@jsonpages/core compat", cmd: "npm publish --access public -w @jsonpages/core", cwd: "root", skip: dryRun },
    { step: "6/6", desc: "@jsonpages/cli compat", cmd: "npm publish --access public -w @jsonpages/cli", cwd: "root", skip: dryRun },
  ];
}

function printCommandPlan() {
  const plan = getCommandPlan();
  console.log("");
  console.log("  DRY RUN — Commands that would be executed:");
  console.log("  " + "—".repeat(60));
  for (const { step, desc, cmd, cwd, skip } of plan) {
    const where = cwd === "root" ? "(root)" : `(${cwd})`;
    const label = skip ? "  [SKIP] " : `  [${step}] `;
    console.log(`${label}${where} ${cmd}`);
  }
  console.log("  " + "—".repeat(60));
  console.log("");
}

// --- Steps ---
function stepBuildAll() {
  log("Step 1/6: Build all workspaces");
  run("npm run build:all");
}

function stepStack() {
  log("Step 2/6: @olonjs/stack — version patch & publish (from root -w)");
  const dir = path.join(ROOT, "packages", "stack");
  const newVersion = patchToUnpublished("@olonjs/stack", dir);
  if (!dryRun) {
    run("npm publish --access public -w @olonjs/stack");
  } else {
    log("[dry-run] Skipping npm publish for stack");
  }
  return newVersion;
}

function stepCore() {
  log("Step 3/6: @olonjs/core — build, version patch & publish (from root -w)");
  const dir = path.join(ROOT, "packages", "core");
  run("npm run build -w @olonjs/core");
  const newVersion = patchToUnpublished("@olonjs/core", dir);
  if (!dryRun) {
    run("npm publish --access public -w @olonjs/core");
  } else {
    log("[dry-run] Skipping npm publish for core");
  }
  return newVersion;
}

function stepStudio(coreVersion) {
  log("Step 3b/6: @olonjs/studio — pin @olonjs/core, build, version patch & publish (from root -w)");
  const dir = path.join(ROOT, "packages", "studio");
  const pkg = readPackageJson(dir);
  pkg.dependencies["@olonjs/core"] = `^${coreVersion}`;
  writePackageJson(dir, pkg);
  run("npm run build -w @olonjs/studio");
  const newVersion = patchToUnpublished("@olonjs/studio", dir);
  if (!dryRun) {
    run("npm publish --access public -w @olonjs/studio");
  } else {
    log("[dry-run] Skipping npm publish for studio");
  }
  return newVersion;
}

function stepReact(coreVersion, studioVersion) {
  log("Step 3c/6: @olonjs/react — pin @olonjs/core + @olonjs/studio, build, version patch & publish (from root -w)");
  const dir = path.join(ROOT, "packages", "react");
  const pkg = readPackageJson(dir);
  pkg.dependencies["@olonjs/core"] = `^${coreVersion}`;
  if (pkg.peerDependencies && pkg.peerDependencies["@olonjs/studio"]) {
    pkg.peerDependencies["@olonjs/studio"] = `^${studioVersion}`;
  }
  writePackageJson(dir, pkg);
  run("npm run build -w @olonjs/react");
  const newVersion = patchToUnpublished("@olonjs/react", dir);
  if (!dryRun) {
    run("npm publish --access public -w @olonjs/react");
  } else {
    log("[dry-run] Skipping npm publish for react");
  }
  return newVersion;
}

function stepMcp() {
  log("Step 3d/6: @olonjs/mcp — build, version patch & publish (from root -w)");
  const dir = path.join(ROOT, "packages", "mcp");
  run("npm run build -w @olonjs/mcp");
  const newVersion = patchToUnpublished("@olonjs/mcp", dir);
  if (!dryRun) {
    run("npm publish --access public -w @olonjs/mcp");
  } else {
    log("[dry-run] Skipping npm publish for mcp");
  }
  return newVersion;
}

function stepNext(coreVersion) {
  log("Step 3e/6: @olonjs/next — pin @olonjs/core, build, version patch & publish (from root -w)");
  const dir = path.join(ROOT, "packages", "next");
  const pkg = readPackageJson(dir);
  pkg.dependencies["@olonjs/core"] = `^${coreVersion}`;
  writePackageJson(dir, pkg);
  run("npm run build -w @olonjs/next");
  const newVersion = patchToUnpublished("@olonjs/next", dir);
  if (!dryRun) {
    run("npm publish --access public -w @olonjs/next");
  } else {
    log("[dry-run] Skipping npm publish for @olonjs/next");
  }
  return newVersion;
}

function stepTenant(workspaceName, coreVersion, reactVersion, studioVersion, nextVersion) {
  const appDir = resolveTenantAppDir(workspaceName);
  const stepLabel = workspaceName === "tenant-next" ? "4b/6" : "4/6";
  log(
    `Step ${stepLabel}: ${workspaceName} (apps/${appDir}) — pin @olonjs/* deps, build & dist (from root -w)`
  );
  const dir = path.join(ROOT, "apps", appDir);
  const pkg = readPackageJson(dir);
  const prevCore = pkg.dependencies["@olonjs/core"] ?? pkg.dependencies["@jsonpages/core"];
  const prevReact = pkg.dependencies["@olonjs/react"];
  const prevStudio = pkg.dependencies["@olonjs/studio"];
  const prevNext = pkg.dependencies["@olonjs/next"];
  pkg.dependencies["@olonjs/core"] = `^${coreVersion}`;
  if (pkg.dependencies["@jsonpages/core"]) {
    delete pkg.dependencies["@jsonpages/core"];
  }
  if (pkg.dependencies["@olonjs/react"]) {
    pkg.dependencies["@olonjs/react"] = `^${reactVersion}`;
  }
  if (pkg.dependencies["@olonjs/studio"]) {
    pkg.dependencies["@olonjs/studio"] = `^${studioVersion}`;
  }
  if (nextVersion && pkg.dependencies["@olonjs/next"]) {
    pkg.dependencies["@olonjs/next"] = `^${nextVersion}`;
  }
  writePackageJson(dir, pkg);
  let updateMsg =
    `Updated ${workspaceName}: @olonjs/core ${prevCore ?? "(unset)"} -> ^${coreVersion}, ` +
    `@olonjs/react ${prevReact ?? "(unset)"} -> ^${reactVersion}, ` +
    `@olonjs/studio ${prevStudio ?? "(unset)"} -> ^${studioVersion}`;
  if (nextVersion && prevNext !== undefined) {
    updateMsg += `, @olonjs/next ${prevNext ?? "(unset)"} -> ^${nextVersion}`;
  }
  log(updateMsg);
  run(`npm install -w ${workspaceName}`);
  run(`npm run build -w ${workspaceName}`);
  run(`npm run dist -w ${workspaceName}`);
}

function stepCli() {
  log("Step 5/6: @olonjs/cli — build, version patch & publish (from root -w)");
  const dir = path.join(ROOT, "packages", "cli");
  run("npm run build -w @olonjs/cli");
  const newVersion = patchToUnpublished("@olonjs/cli", dir);
  if (!dryRun) {
    run("npm publish --access public -w @olonjs/cli");
  } else {
    log("[dry-run] Skipping npm publish for cli");
  }
  return newVersion;
}

function stepCompatPackages(stackVersion, coreVersion, cliVersion) {
  log("Step 6/6: compat packages (@jsonpages/*) — sync deps, version resolve & publish");

  const coreCompatDir = path.join(ROOT, "packages", "jsonpages-core-compat");
  const coreCompatPkg = readPackageJson(coreCompatDir);
  coreCompatPkg.dependencies["@olonjs/core"] = `^${coreVersion}`;
  writePackageJson(coreCompatDir, coreCompatPkg);

  const stackCompatDir = path.join(ROOT, "packages", "jsonpages-stack-compat");
  const stackCompatPkg = readPackageJson(stackCompatDir);
  stackCompatPkg.dependencies["@olonjs/stack"] = `^${stackVersion}`;
  writePackageJson(stackCompatDir, stackCompatPkg);

  const cliCompatDir = path.join(ROOT, "packages", "jsonpages-cli-compat");
  const cliCompatPkg = readPackageJson(cliCompatDir);
  cliCompatPkg.dependencies["@olonjs/cli"] = `^${cliVersion}`;
  writePackageJson(cliCompatDir, cliCompatPkg);

  ensureUnpublishedVersion(stackCompatDir, stackVersion);
  if (!dryRun) run("npm publish --access public -w @jsonpages/stack");
  else log("[dry-run] Skipping npm publish for @jsonpages/stack compat");

  ensureUnpublishedVersion(coreCompatDir, coreVersion);
  if (!dryRun) run("npm publish --access public -w @jsonpages/core");
  else log("[dry-run] Skipping npm publish for @jsonpages/core compat");

  ensureUnpublishedVersion(cliCompatDir, cliVersion);
  if (!dryRun) run("npm publish --access public -w @jsonpages/cli");
  else log("[dry-run] Skipping npm publish for @jsonpages/cli compat");
}

// --- Main ---
function main() {
  log("Release script started" + (dryRun ? " (dry-run)" : ""));
  if (dryRun) printCommandPlan();
  try {
    assertRoot();
    assertNpmToken();
    ensureNpmRc();
    assertGitClean();

    stepBuildAll();
    const stackVersion = stepStack();
    const coreVersion = stepCore();
    const studioVersion = stepStudio(coreVersion);
    const reactVersion = stepReact(coreVersion, studioVersion);
    stepMcp();
    const nextVersion = stepNext(coreVersion);
    stepTenant("tenant-alpha", coreVersion, reactVersion, studioVersion);
    stepTenant("tenant-next", coreVersion, reactVersion, studioVersion, nextVersion);
    const cliVersion = stepCli();
    stepCompatPackages(stackVersion, coreVersion, cliVersion);

    log("Release completed successfully.");
    if (dryRun) {
      log("Dry-run: version bumps were applied locally but nothing was published. Revert with git checkout -- .");
    }
  } catch (err) {
    log(err.message, "error");
    process.exit(1);
  }
}

main();
