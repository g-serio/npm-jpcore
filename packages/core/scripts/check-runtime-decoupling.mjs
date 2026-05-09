#!/usr/bin/env node
/**
 * Boundary check for the runtime/studio split (ADR-0009, Task 1.5).
 *
 * Fails CI if any file under packages/core/src/runtime/ imports from
 * packages/core/src/studio/admin/ or packages/core/src/studio/orchestration/.
 *
 * Allowed integration points (the full-engine wrappers that mount Studio
 * routes by design):
 *   - runtime/engine/JsonPagesEngine.tsx
 *   - runtime/engine/StudioRoute.tsx
 *   - runtime/engine/PreviewRoute.tsx
 *
 * These files are loaded only when a consumer imports the full
 * @olonjs/core entry. The runtime entry @olonjs/core/runtime is built
 * from OlonJSEngine.tsx, which never imports any of them.
 *
 * Allowed always (per ADR-0009 D3):
 *   - studio/StudioContext.tsx, studio/events.ts: small, no-op-friendly,
 *     consumed by visitor mode too.
 *
 * Run with:  node scripts/check-runtime-decoupling.mjs
 *            (also wired into the package's `test:boundary` script).
 *
 * Exits 0 on success, 1 on violation.
 */

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, dirname, resolve as pathResolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SRC = pathResolve(__dirname, '..', 'src');
const RUNTIME_DIR = join(SRC, 'runtime');

/** Files under runtime/ that are allowed to import from studio/admin/. */
const ALLOWED_INTEGRATION_POINTS = new Set([
  pathResolve(RUNTIME_DIR, 'engine', 'JsonPagesEngine.tsx'),
  pathResolve(RUNTIME_DIR, 'engine', 'StudioRoute.tsx'),
  pathResolve(RUNTIME_DIR, 'engine', 'PreviewRoute.tsx'),
]);

/**
 * Forbidden import targets. Each pattern is matched only against actual
 * import-statement lines, not comments — see isImportStatement() below.
 */
const FORBIDDEN_PATTERNS = [
  /from\s+['"][^'"]*\/studio\/admin\//,
  /from\s+['"][^'"]*\/studio\/orchestration\//,
  /from\s+['"][^'"]*\/studio\/ui\//,
  /import\s+['"][^'"]*\/studio\/admin\//,        // bare side-effect imports
  /import\s+['"][^'"]*\/studio\/orchestration\//,
  /import\s+['"][^'"]*\/studio\/ui\//,
  /import\s+\S+\s+from\s+['"][^'"]*admin-skin\.css/,
];

/**
 * Returns true if the line looks like an actual ES module import. Filters
 * out comment lines (// or * inside JSDoc block) so prose mentioning
 * "admin-skin.css" inside a doc comment does not trigger a false positive.
 */
function isImportStatement(line) {
  const trimmed = line.trim();
  if (trimmed.startsWith('//')) return false;
  if (trimmed.startsWith('*') || trimmed.startsWith('/*')) return false;
  if (trimmed.startsWith('export ')) return true; // re-exports count
  return trimmed.startsWith('import ') || /\bfrom\s+['"]/.test(trimmed);
}

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    const st = statSync(full);
    if (st.isDirectory()) yield* walk(full);
    else if (/\.(ts|tsx|mjs|cjs|js|jsx)$/.test(name)) yield full;
  }
}

const violations = [];

for (const file of walk(RUNTIME_DIR)) {
  if (ALLOWED_INTEGRATION_POINTS.has(file)) continue;

  const content = readFileSync(file, 'utf8');
  const lines = content.split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!isImportStatement(line)) continue;
    for (const pattern of FORBIDDEN_PATTERNS) {
      if (pattern.test(line)) {
        violations.push({
          file: relative(SRC, file),
          line: i + 1,
          content: line.trim(),
        });
        break;
      }
    }
  }
}

if (violations.length === 0) {
  console.log(
    `✅ runtime/ is decoupled from studio/admin (${ALLOWED_INTEGRATION_POINTS.size} integration points allowed)`,
  );
  process.exit(0);
}

console.error('\n❌ runtime/ → studio/ boundary violations found (ADR-0009):\n');
for (const v of violations) {
  console.error(`  ${v.file}:${v.line}`);
  console.error(`    ${v.content}`);
}
console.error('\nThe runtime bundle (@olonjs/core/runtime) must not pull in');
console.error('studio admin code. Either:');
console.error('  - move the imported symbol into runtime/ (per ADR-0009 D5 pattern), or');
console.error('  - keep the import only inside JsonPagesEngine.tsx / StudioRoute.tsx /');
console.error('    PreviewRoute.tsx (the full-engine integration points), or');
console.error('  - add a documented exception above to ALLOWED_INTEGRATION_POINTS\n');
process.exit(1);
