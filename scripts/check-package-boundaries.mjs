#!/usr/bin/env node
/**
 * Cross-package dependency-graph boundary check (ADR-0016 D2, package-split
 * plan Task 4.3). Supersedes the old intra-package `check-runtime-decoupling.mjs`
 * / `check-singleton-modules.mjs` / `check-studio-react-boundary.mjs` (all
 * deleted in Task 2.2 once the physical package split made them obsolete —
 * they checked folder-vs-folder coupling inside one package; this checks the
 * real workspace package boundary).
 *
 * Enforces the graph from ADR-0016 D2:
 *
 *                     @olonjs/core
 *                    /            \
 *         @olonjs/studio      @olonjs/react
 *                    \            /
 *                     react → studio
 *          (one directional edge only, dynamic import)
 *
 * Rules (checked against actual import/export/dynamic-import statements only
 * — a comment or JSDoc mentioning a package name, e.g. "consumed by
 * @olonjs/react", is not a violation):
 *
 * 1. @olonjs/core never imports @olonjs/react or @olonjs/studio (zero-React,
 *    framework-agnostic engine).
 * 2. @olonjs/studio never imports @olonjs/react (reusable by any future
 *    rendering-framework binding, per D8).
 * 3. @olonjs/react's only reference to @olonjs/studio is:
 *    - `import type { ... } from '@olonjs/studio'` (erased at compile time) — allowed anywhere.
 *    - a dynamic `import('@olonjs/studio')` — allowed ONLY in the allow-listed bridge file(s).
 *    Any other static/value import (or re-export) of '@olonjs/studio' anywhere
 *    in @olonjs/react fails the check.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

const CORE_SRC = path.join(ROOT, 'packages', 'core', 'src');
const REACT_SRC = path.join(ROOT, 'packages', 'react', 'src');
const STUDIO_SRC = path.join(ROOT, 'packages', 'studio', 'src');

// Files allowed to hold the one dynamic-import bridge edge (react -> studio).
const REACT_STUDIO_BRIDGE_ALLOWLIST = [path.join(REACT_SRC, 'engine', 'StudioRoute.tsx')];

const SOURCE_EXTENSIONS = new Set(['.ts', '.tsx']);

function walk(dir) {
  if (!fs.existsSync(dir)) return [];
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...walk(full));
    } else if (SOURCE_EXTENSIONS.has(path.extname(entry.name))) {
      out.push(full);
    }
  }
  return out;
}

function relative(file) {
  return path.relative(ROOT, file).split(path.sep).join('/');
}

// Any real static import/re-export (type or value) from the given package specifier.
function anyImportOrExportFrom(pkg) {
  const escaped = pkg.replace(/\//g, '\\/');
  return new RegExp(`^\\s*(import|export)\\s+[^;]*from\\s+['"]${escaped}['"]`, 'm');
}

// Any dynamic import('<pkg>') call, anywhere in the file (including inside `typeof import(...)`).
function anyDynamicImport(pkg) {
  const escaped = pkg.replace(/\//g, '\\/');
  return new RegExp(`import\\(\\s*['"]${escaped}['"]\\s*\\)`);
}

// Static VALUE import/re-export (excludes `import type` / `export type`) from the given package.
function staticValueImportOrExportFrom(pkg) {
  const escaped = pkg.replace(/\//g, '\\/');
  return new RegExp(`^\\s*(import|export)\\s+(?!type\\b)[^;]*from\\s+['"]${escaped}['"]`, 'm');
}

const IMPORT_OR_EXPORT_REACT = anyImportOrExportFrom('@olonjs/react');
const IMPORT_OR_EXPORT_STUDIO = anyImportOrExportFrom('@olonjs/studio');
const DYNAMIC_IMPORT_REACT = anyDynamicImport('@olonjs/react');
const DYNAMIC_IMPORT_STUDIO = anyDynamicImport('@olonjs/studio');
const STATIC_VALUE_IMPORT_OR_EXPORT_STUDIO = staticValueImportOrExportFrom('@olonjs/studio');

let failures = [];

// --- Rule 1: @olonjs/core must not import/export/dynamically-import @olonjs/react or @olonjs/studio ---
for (const file of walk(CORE_SRC)) {
  const content = fs.readFileSync(file, 'utf8');
  if (IMPORT_OR_EXPORT_REACT.test(content) || DYNAMIC_IMPORT_REACT.test(content)) {
    failures.push(`[core->react] ${relative(file)} imports '@olonjs/react' — @olonjs/core must stay framework-agnostic.`);
  }
  if (IMPORT_OR_EXPORT_STUDIO.test(content) || DYNAMIC_IMPORT_STUDIO.test(content)) {
    failures.push(`[core->studio] ${relative(file)} imports '@olonjs/studio' — @olonjs/core must stay framework-agnostic.`);
  }
}

// --- Rule 2: @olonjs/studio must not import/export/dynamically-import @olonjs/react ---
for (const file of walk(STUDIO_SRC)) {
  const content = fs.readFileSync(file, 'utf8');
  if (IMPORT_OR_EXPORT_REACT.test(content) || DYNAMIC_IMPORT_REACT.test(content)) {
    failures.push(`[studio->react] ${relative(file)} imports '@olonjs/react' — @olonjs/studio must depend only on @olonjs/core (ADR-0016 D8).`);
  }
}

// --- Rule 3: @olonjs/react's only edge to @olonjs/studio is the allow-listed dynamic-import bridge ---
for (const file of walk(REACT_SRC)) {
  const content = fs.readFileSync(file, 'utf8');
  const isBridgeFile = REACT_STUDIO_BRIDGE_ALLOWLIST.includes(file);

  if (STATIC_VALUE_IMPORT_OR_EXPORT_STUDIO.test(content)) {
    failures.push(`[react->studio] ${relative(file)} has a static VALUE import/re-export of '@olonjs/studio' — only \`import type\` and the allow-listed dynamic import() bridge are permitted.`);
  }

  if (DYNAMIC_IMPORT_STUDIO.test(content) && !isBridgeFile) {
    failures.push(`[react->studio] ${relative(file)} performs a dynamic import('@olonjs/studio') outside the allow-listed bridge file(s): ${REACT_STUDIO_BRIDGE_ALLOWLIST.map(relative).join(', ')}.`);
  }
}

for (const bridgeFile of REACT_STUDIO_BRIDGE_ALLOWLIST) {
  if (!fs.existsSync(bridgeFile)) {
    failures.push(`[react->studio] allow-listed bridge file missing: ${relative(bridgeFile)} — update REACT_STUDIO_BRIDGE_ALLOWLIST if it moved.`);
    continue;
  }
  const content = fs.readFileSync(bridgeFile, 'utf8');
  if (!DYNAMIC_IMPORT_STUDIO.test(content)) {
    failures.push(`[react->studio] allow-listed bridge file ${relative(bridgeFile)} no longer contains the expected dynamic import('@olonjs/studio') — check drifted from actual code.`);
  }
}

if (failures.length > 0) {
  console.error('[package-boundary] FAILED:\n');
  for (const f of failures) console.error(`  - ${f}`);
  console.error(`\n${failures.length} violation(s) found.`);
  process.exit(1);
}

const coreFiles = walk(CORE_SRC).length;
const reactFiles = walk(REACT_SRC).length;
const studioFiles = walk(STUDIO_SRC).length;
console.log(
  `[package-boundary] OK: @olonjs/core (${coreFiles} files) has zero imports of react/studio; ` +
    `@olonjs/studio (${studioFiles} files) has zero imports of react; ` +
    `@olonjs/react (${reactFiles} files) touches @olonjs/studio only via the allow-listed dynamic-import bridge.`
);
