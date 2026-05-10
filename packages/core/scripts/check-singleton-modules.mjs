#!/usr/bin/env node
/**
 * Boundary check for cross-bundle singleton dedup (ADR-0012).
 *
 * The full bundle (olonjs-core.js) and the runtime bundle
 * (olonjs-core-runtime.js) are produced by two independent Vite library
 * builds. Each build inlines whatever its import graph reaches, so a
 * source file that holds module-level identity (a `React.createContext()`
 * call, a stateful singleton object) would be compiled into BOTH bundles
 * unless `vite.config.ts` externalizes it.
 *
 * `vite.config.ts` carries a `SINGLETON_RUNTIME_MODULES` regex list of
 * paths that MUST be externalized in the full build and resolved at load
 * time from the sibling `./olonjs-core-runtime.js` artifact. If a
 * singleton-bearing file is added to source without also being added to
 * that list, the bug ADR-0012 fixed silently re-emerges: tenants that
 * mount Studio see `useX must be used within XProvider` errors at
 * runtime.
 *
 * This script asserts three invariants:
 *
 *   1. Every regex in SINGLETON_RUNTIME_MODULES (extracted from
 *      vite.config.ts) matches at least one real source file. Catches
 *      stale entries after file renames or deletes.
 *
 *   2. Every source file under src/runtime/ or src/studio/ that calls
 *      React's `createContext(` at module scope matches at least one
 *      regex in the externalize list, unless the file is on the
 *      documented ALLOWED_NON_SINGLETON allowlist below.
 *
 *   3. Files matching KNOWN_NON_CONTEXT_SINGLETONS (singletons that hold
 *      module-level state without using `createContext`, e.g.
 *      theme-manager) are in the externalize list.
 *
 * Run with:  node scripts/check-singleton-modules.mjs
 *            (also wired into the package's `test:boundary` script).
 *
 * Exits 0 on success, 1 on violation.
 */

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, dirname, resolve as pathResolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PKG = pathResolve(__dirname, '..');
const SRC = join(PKG, 'src');
const VITE_CONFIG = join(PKG, 'vite.config.ts');

/**
 * Files that hold module-level identity WITHOUT using React.createContext.
 * These cannot be detected by Invariant 2's `createContext` heuristic, so
 * they are listed explicitly here. Add to this list when introducing a
 * new singleton pattern (e.g. a stateful module-scope object, a class
 * instance held at module scope, an event-bus instance).
 */
const KNOWN_NON_CONTEXT_SINGLETONS = [
  'src/runtime/theme/theme-manager.ts',
];

/**
 * Files that call `createContext(` at module scope but are NOT a
 * singleton boundary — e.g. a re-export shim that wraps an underlying
 * context, or a test fixture. Each entry must include a one-line reason
 * so future maintainers can audit.
 */
const ALLOWED_NON_SINGLETON = new Map([
  // studio/admin/IconRegistryContext.tsx is a documented re-export shim
  // pointing to runtime/icons/IconRegistryContext.tsx (the real
  // singleton). The shim itself does not call createContext; it only
  // re-exports. Listed here defensively in case a future grep heuristic
  // misclassifies.
]);

/* ───────────────────────── helpers ───────────────────────── */

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    const st = statSync(full);
    if (st.isDirectory()) {
      yield* walk(full);
    } else if (/\.(ts|tsx)$/.test(name) && !/\.test\.(ts|tsx)$/.test(name)) {
      yield full;
    }
  }
}

/**
 * Returns true if the line is an actual code statement, not a comment.
 * Mirrors the heuristic in check-runtime-decoupling.mjs.
 */
function isCodeLine(line) {
  const trimmed = line.trim();
  if (trimmed.startsWith('//')) return false;
  if (trimmed.startsWith('*') || trimmed.startsWith('/*')) return false;
  return true;
}

/**
 * Parses vite.config.ts as text and extracts the regex array declared as
 * SINGLETON_RUNTIME_MODULES. Uses `new Function` to evaluate the array
 * literal — the array contains plain regex literals (no function calls,
 * no template strings), so this is safe and keeps the script free of a
 * TypeScript-AST dependency. Throws if the array can't be located.
 */
function extractSingletonRegexes() {
  const src = readFileSync(VITE_CONFIG, 'utf8');
  const startMarker = 'const SINGLETON_RUNTIME_MODULES = [';
  const start = src.indexOf(startMarker);
  if (start === -1) {
    throw new Error(
      `Could not find SINGLETON_RUNTIME_MODULES array in ${relative(PKG, VITE_CONFIG)}. ` +
        `If this constant was renamed, update this script's startMarker.`,
    );
  }
  const end = src.indexOf('];', start);
  if (end === -1) {
    throw new Error(
      `Malformed SINGLETON_RUNTIME_MODULES array in ${relative(PKG, VITE_CONFIG)} (no closing '];').`,
    );
  }
  const body = src.slice(start + startMarker.length, end);
  try {
    // eslint-disable-next-line no-new-func
    const result = new Function(`return [${body}];`)();
    if (!Array.isArray(result)) {
      throw new Error('SINGLETON_RUNTIME_MODULES did not evaluate to an array');
    }
    for (const re of result) {
      if (!(re instanceof RegExp)) {
        throw new Error(
          `SINGLETON_RUNTIME_MODULES contains a non-RegExp element: ${typeof re}`,
        );
      }
    }
    return result;
  } catch (err) {
    throw new Error(
      `Failed to evaluate SINGLETON_RUNTIME_MODULES from vite.config.ts: ${err.message}`,
    );
  }
}

/**
 * Returns true if `filePath` (absolute) matches any of the regex
 * patterns from vite.config.ts's externalize list.
 */
function isExternalized(filePath, externalizeRegexes) {
  return externalizeRegexes.some((re) => re.test(filePath));
}

/* ───────────────────────── main ───────────────────────── */

const externalizeRegexes = extractSingletonRegexes();

if (externalizeRegexes.length === 0) {
  console.error(
    `\n❌ SINGLETON_RUNTIME_MODULES in vite.config.ts is empty. The full bundle ` +
      `is no longer deduping any singleton — every shared module will be inlined ` +
      `into both bundles, re-introducing the ADR-0012 bug.\n`,
  );
  process.exit(1);
}

const violations = [];

/* Invariant 1: every regex matches at least one real source file. */
const matchedFiles = new Map(externalizeRegexes.map((re) => [re, []]));
for (const file of walk(SRC)) {
  for (const re of externalizeRegexes) {
    if (re.test(file)) matchedFiles.get(re).push(file);
  }
}
for (const [re, hits] of matchedFiles) {
  if (hits.length === 0) {
    violations.push({
      kind: 'stale-regex',
      detail: `vite.config.ts SINGLETON_RUNTIME_MODULES regex ${re} matches no source file. ` +
        `Likely a renamed or deleted file — remove the regex or update it.`,
    });
  }
}

/* Invariant 2: every shared file that calls createContext( at module
 * scope is externalized.
 *
 * "Shared" means reachable from BOTH the runtime entry and the full
 * entry. Per ADR-0009 boundary check (check-runtime-decoupling.mjs),
 * the studio admin/orchestration/ui subtrees are forbidden imports for
 * the runtime entry — i.e. they are full-bundle-only by construction.
 * Files inside those subtrees can safely declare their own contexts
 * without dedup concerns (they exist in exactly one bundle).
 *
 * Only files that ARE shared (everything under src/runtime/ plus the
 * top-level files in src/studio/ that ADR-0009 D3 keeps in the runtime
 * bundle, e.g. StudioContext.tsx and events.ts) need the externalize
 * boundary. */
const RUNTIME_DIR = join(SRC, 'runtime');
const STUDIO_DIR = join(SRC, 'studio');
const RUNTIME_ENTRY = join(SRC, 'runtime-entry.ts');

const FULL_ONLY_STUDIO_SUBDIRS = ['admin', 'orchestration', 'ui'];

function isFullBundleOnly(file) {
  const rel = relative(SRC, file).replaceAll('\\', '/');
  return FULL_ONLY_STUDIO_SUBDIRS.some((sub) =>
    rel.startsWith(`studio/${sub}/`),
  );
}

for (const dir of [RUNTIME_DIR, STUDIO_DIR]) {
  for (const file of walk(dir)) {
    // Skip full-bundle-only Studio subtrees (no duplication risk).
    if (isFullBundleOnly(file)) continue;

    // The runtime entry itself is the "boundary" — it's the file that
    // becomes the runtime artifact, so it doesn't need to be externalized
    // from the full bundle (the full bundle imports it AS the
    // externalize target).
    if (file === RUNTIME_ENTRY) continue;

    const relPath = relative(PKG, file).replaceAll('\\', '/');

    // Read and look for top-level createContext calls.
    const lines = readFileSync(file, 'utf8').split(/\r?\n/);
    let braceDepth = 0;
    for (const line of lines) {
      // Track brace depth to distinguish module scope from function body.
      // A naive count is enough: createContext inside a function body
      // would be after a `function …(` or `=> {` — both increase depth.
      // This isn't a real parser, but for the patterns we care about
      // (createContext at module top scope) it's reliable.
      const code = line;
      // Count opens minus closes BEFORE the createContext check, so a
      // createContext call on a line that also opens a brace still
      // counts as same-scope-as-current.
      const opens = (code.match(/\{/g) || []).length;
      const closes = (code.match(/\}/g) || []).length;

      // Match `createContext(` and `createContext<...>(` (generic call
      // sites). The lenient `[^;]*` between the identifier and `(`
      // tolerates type parameters and whitespace; restricting to one
      // statement (no `;`) avoids matching across statement boundaries.
      if (
        isCodeLine(code) &&
        braceDepth === 0 &&
        /\bcreateContext\b[^;]*\(/.test(code)
      ) {
        // Found a top-level createContext call.
        if (
          !isExternalized(file, externalizeRegexes) &&
          !ALLOWED_NON_SINGLETON.has(relPath)
        ) {
          violations.push({
            kind: 'unexternalized-context',
            detail: `${relPath} calls createContext() at module scope but is not in ` +
              `vite.config.ts → SINGLETON_RUNTIME_MODULES. Add a regex that matches ` +
              `this path, or document why it's safe to inline (then add to ` +
              `ALLOWED_NON_SINGLETON in this script with a one-line reason).`,
          });
          break; // one violation per file
        }
      }

      braceDepth += opens - closes;
      if (braceDepth < 0) braceDepth = 0; // defensive against weird files
    }
  }
}

/* Invariant 3: all KNOWN_NON_CONTEXT_SINGLETONS are externalized. */
for (const relPath of KNOWN_NON_CONTEXT_SINGLETONS) {
  const abs = join(PKG, relPath.replaceAll('/', '\\'));
  const absUnix = join(PKG, relPath);
  // try both separators for cross-platform compatibility
  const found = isExternalized(abs, externalizeRegexes) ||
                isExternalized(absUnix, externalizeRegexes);
  if (!found) {
    violations.push({
      kind: 'missing-non-context-singleton',
      detail: `${relPath} is listed in this script's KNOWN_NON_CONTEXT_SINGLETONS ` +
        `but no regex in vite.config.ts → SINGLETON_RUNTIME_MODULES matches it. ` +
        `Either add a regex to externalize the file, or remove the entry from ` +
        `this script if the file is no longer a singleton.`,
    });
  }
}

/* ───────────────────────── report ───────────────────────── */

if (violations.length === 0) {
  console.log(
    `✅ singleton modules properly externalized ` +
      `(${externalizeRegexes.length} regex patterns, ` +
      `${KNOWN_NON_CONTEXT_SINGLETONS.length} non-context singletons verified)`,
  );
  process.exit(0);
}

console.error('\n❌ singleton dedup boundary violations found (ADR-0012):\n');
for (const v of violations) {
  console.error(`  [${v.kind}] ${v.detail}`);
  console.error('');
}
console.error(
  `The two-bundle architecture (ADR-0009) requires that any module holding\n` +
  `runtime identity is loaded once and shared. See ADR-0012 for the\n` +
  `externalize mechanism and this script's invariants.\n`,
);
process.exit(1);
