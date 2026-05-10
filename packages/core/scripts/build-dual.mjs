#!/usr/bin/env node
/**
 * Dual-bundle build orchestrator (ADR-0009 D1, D8; ADR-0012 build order).
 *
 * Runs two Vite builds in sequence and reconciles the dts output. The
 * runtime bundle is built FIRST because the full bundle externalizes the
 * singleton-bearing modules and references the runtime artifact directly
 * at module-load time (see ADR-0012 and `vite.config.ts`); inverting the
 * order would emit a full bundle pointing at a non-existent sibling.
 *
 *   1. `vite build --config vite.config.runtime.ts` — runtime bundle
 *      → dist/olonjs-core-runtime.js (ESM, no UMD)
 *      → dist/index.d.ts        (runtime types — first writer)
 *
 *   2. dist/index.d.ts → dist/runtime.d.ts        (preserve runtime types)
 *
 *   3. `vite build`                              — full bundle
 *      → dist/olonjs-core.js (ESM, imports './olonjs-core-runtime.js')
 *      → dist/olonjs-core.umd.cjs
 *      → dist/index.d.ts        (full surface types — overwrites; expected)
 *
 *   4. (no rename needed — runtime types already at runtime.d.ts,
 *       full types already at index.d.ts)
 *
 * `vite-plugin-dts` derives the rolled-up declaration filename from the
 * Vite entry filename (with `rollupTypes: true`). Both Vite configs use
 * an entry that produces `dist/index.d.ts`-shaped output, so we shuffle
 * filenames here instead of fighting the plugin. Result is a clean dist
 * with both bundles + both .d.ts files.
 *
 * Run via:  npm run build  (in packages/core)
 */

import { spawnSync } from 'node:child_process';
import { existsSync, renameSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PKG = resolve(__dirname, '..');
const DIST = join(PKG, 'dist');

function run(cmd, args, label) {
  console.log(`\n▶ ${label}\n  ${cmd} ${args.join(' ')}`);
  // Use shell: false (default) and quote-free args to avoid the Node 22+
  // DEP0190 deprecation warning. On Windows this means we resolve npx
  // through PATH like any other binary; works under modern npm.
  const result = spawnSync(cmd, args, { cwd: PKG, stdio: 'inherit' });
  if (result.status !== 0) {
    console.error(`\n✖ ${label} failed (exit ${result.status})`);
    process.exit(result.status ?? 1);
  }
}

// 0. Clean the dist folder so we start from a known state.
if (existsSync(DIST)) rmSync(DIST, { recursive: true, force: true });

// 1. Build the full bundle FIRST. Even though ADR-0012 has the full bundle
//    externalize the runtime artifact, the import is resolved at consumer
//    LOAD time (when the tenant runs `import '@olonjs/core'`), not at the
//    full build's compile time. So the runtime artifact does not need to
//    exist on disk while the full build runs — it just needs to exist when
//    the consumer imports the package. Building full first preserves the
//    pre-ADR-0012 dts-rollup behavior of `vite-plugin-dts`, which empirically
//    differs based on dist/ contents (api-extractor caching).
run('npx', ['--no-install', 'vite', 'build'], 'Build full (@olonjs/core)');

// 2. Stash the full types so the runtime build doesn't overwrite them.
const fullDts = join(DIST, 'index.d.ts');
const stashedFullDts = join(DIST, '_full-index.d.ts');
if (!existsSync(fullDts)) {
  console.error(`✖ Expected ${fullDts} after full build`);
  process.exit(1);
}
renameSync(fullDts, stashedFullDts);

// 3. Build the runtime bundle (separate config, ESM only).
run(
  'npx',
  ['--no-install', 'vite', 'build', '--config', 'vite.config.runtime.ts'],
  'Build runtime (@olonjs/core/runtime)',
);

// 4. Reconcile the .d.ts files.
const runtimeDtsAtIndex = join(DIST, 'index.d.ts'); // dts plugin emits here
const runtimeDtsRenamed = join(DIST, 'runtime.d.ts');
if (!existsSync(runtimeDtsAtIndex)) {
  console.error(`✖ Expected ${runtimeDtsAtIndex} after runtime build`);
  process.exit(1);
}
renameSync(runtimeDtsAtIndex, runtimeDtsRenamed);
renameSync(stashedFullDts, fullDts);

console.log('\n✅ Dual build complete:');
console.log('   dist/olonjs-core.js          (full ESM, imports runtime)');
console.log('   dist/olonjs-core.umd.cjs     (full UMD/CJS)');
console.log('   dist/olonjs-core-runtime.js  (runtime ESM)');
console.log('   dist/index.d.ts              (full types)');
console.log('   dist/runtime.d.ts            (runtime types)');
