#!/usr/bin/env node
/**
 * Enterprise release script for @olonjs/stack, @olonjs/core, @olonjs/react,
 * @olonjs/studio, @olonjs/mcp, @olonjs/cli (plus @jsonpages/* compat packages).
 * Run from monorepo root. Uses NPM_TOKEN for authentication (no interactive login).
 *
 * Publish order follows the ADR-0016 dependency graph: stack -> core ->
 * studio -> react (react pins core + the optional studio peer to the
 * versions just published) -> mcp -> tenant-alpha (pins all three @olonjs/*
 * packages, then rebuilds + regenerates the CLI DNA template) -> cli -> compat.
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
    { step: "4/6", desc: "tenant-alpha", cmd: "Update package.json @olonjs/core/@olonjs/react/@olonjs/studio -> ^<new-versions>", cwd: "apps/tenant-alpha", skip: false },
    { step: "4/6", desc: "tenant-alpha", cmd: "npm install -w tenant-alpha", cwd: "root", skip: false },
    { step: "4/6", desc: "tenant-alpha", cmd: "npm run build -w tenant-alpha", cwd: "root", skip: false },
    { step: "4/6", desc: "tenant-alpha", cmd: "npm run dist -w tenant-alpha", cwd: "root", skip: false },
    { step: "5/6", desc: "@olonjs/cli", cmd: "npm run build -w @olonjs/cli", cwd: "root", skip: false },
    { step: "5/6", desc: "@olonjs/cli", cmd: "npm version patch --no-git-tag-version -w @olonjs/cli", cwd: "root", skip: false },
    { step: "5/6", desc: "@olonjs/cli (publish)", cmd: "npm publish --access public -w @olonjs/cli", cwd: "root", skip: dryRun },
    { step: "6/6", desc: "@jsonpages/stack compat", cmd: "npm version patch --no-git-tag-version -w @jsonpages/stack", cwd: "root", skip: false },
    { step: "6/6", desc: "@jsonpages/stack compat (publish)", cmd: "npm publish --access public -w @jsonpages/stack", cwd: "root", skip: dryRun },
    { step: "6/6", desc: "@jsonpages/core compat", cmd: "npm version patch --no-git-tag-version -w @jsonpages/core", cwd: "root", skip: false },
    { step: "6/6", desc: "@jsonpages/core compat (publish)", cmd: "npm publish --access public -w @jsonpages/core", cwd: "root", skip: dryRun },
    { step: "6/6", desc: "@jsonpages/cli compat", cmd: "npm version patch --no-git-tag-version -w @jsonpages/cli", cwd: "root", skip: false },
    { step: "6/6", desc: "@jsonpages/cli compat (publish)", cmd: "npm publish --access public -w @jsonpages/cli", cwd: "root", skip: dryRun },
    
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
  run("npm version patch --no-git-tag-version -w @olonjs/stack");
  const newVersion = getVersion(path.join(ROOT, "packages", "stack"));
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
  run("npm version patch --no-git-tag-version -w @olonjs/core");
  const newVersion = getVersion(dir);
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
  run("npm version patch --no-git-tag-version -w @olonjs/studio");
  const newVersion = getVersion(dir);
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
  run("npm version patch --no-git-tag-version -w @olonjs/react");
  const newVersion = getVersion(dir);
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
  run("npm version patch --no-git-tag-version -w @olonjs/mcp");
  const newVersion = getVersion(dir);
  if (!dryRun) {
    run("npm publish --access public -w @olonjs/mcp");
  } else {
    log("[dry-run] Skipping npm publish for mcp");
  }
  return newVersion;
}

function stepTenant(tenantName, coreVersion, reactVersion, studioVersion) {
  log(`Step 4/6: ${tenantName} — pin @olonjs/core/@olonjs/react/@olonjs/studio, build & dist (from root -w)`);
  const dir = path.join(ROOT, "apps", tenantName);
  const pkg = readPackageJson(dir);
  const prevCore = pkg.dependencies["@olonjs/core"] ?? pkg.dependencies["@jsonpages/core"];
  const prevReact = pkg.dependencies["@olonjs/react"];
  const prevStudio = pkg.dependencies["@olonjs/studio"];
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
  writePackageJson(dir, pkg);
  log(
    `Updated ${tenantName}: @olonjs/core ${prevCore ?? "(unset)"} -> ^${coreVersion}, ` +
      `@olonjs/react ${prevReact ?? "(unset)"} -> ^${reactVersion}, ` +
      `@olonjs/studio ${prevStudio ?? "(unset)"} -> ^${studioVersion}`
  );
  run(`npm install -w ${tenantName}`);
  run(`npm run build -w ${tenantName}`);
  run(`npm run dist -w ${tenantName}`);
}

function stepCli() {
  log("Step 5/6: @olonjs/cli — build, version patch & publish (from root -w)");
  run("npm run build -w @olonjs/cli");
  run("npm version patch --no-git-tag-version -w @olonjs/cli");
  const newVersion = getVersion(path.join(ROOT, "packages", "cli"));
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
    const mcpVersion = stepMcp();
    stepTenant("tenant-alpha", coreVersion, reactVersion, studioVersion);
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
