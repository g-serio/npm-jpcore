/**
 * Static gates for generate_SystemsArchitect_next.sh (TDD for the Next SystemsArchitect generator).
 * Run: node --test scripts/generate-SystemsArchitect-next.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCRIPT = path.resolve(__dirname, '../generate_SystemsArchitect_next.sh');

function readScript() {
  assert.ok(fs.existsSync(SCRIPT), `missing ${SCRIPT}`);
  return fs.readFileSync(SCRIPT, 'utf8');
}

describe('generate_SystemsArchitect_next.sh harness gates', () => {
  it('exists and is a bash script', () => {
    const src = readScript();
    assert.match(src, /^#!\/usr\/bin\/env bash|^#!\/bin\/bash/m);
  });

  it('must not target Vite-only surfaces', () => {
    const src = readScript();
    assert.doesNotMatch(src, /cat > index\.html/);
    assert.doesNotMatch(src, /cat > src\/index\.css/);
    assert.doesNotMatch(src, /cat > src\/App\.tsx/);
    assert.doesNotMatch(src, /from ['"]@\/components\/ThemeProvider['"]/);
    assert.doesNotMatch(src, /useTheme\s*\(/);
  });

  it('must write Next theme bridge to app/globals.css', () => {
    const src = readScript();
    assert.match(src, /cat > app\/globals\.css/);
    assert.match(src, /\[data-theme=["']light["']\]/);
  });

  it('must verify Next admin wiring instead of App.tsx', () => {
    const src = readScript();
    assert.match(src, /AdminStudioClient/);
    assert.doesNotMatch(src, /verifying App\.tsx/);
  });

  it('must cd to the script directory before writing files', () => {
    const src = readScript();
    assert.match(src, /cd "\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)" && pwd\)"/);
  });

  it('must clean DNA demo capsules before writing SystemsArchitect', () => {
    const src = readScript();
    assert.match(src, /Cleaning demo capsules/);
    assert.match(src, /rm -rf \\\s*\n\s*src\/components\/books-list/m);
    assert.match(src, /cat > src\/lib\/VisitorSection\.tsx/);
    assert.doesNotMatch(src, /from '@\/components\/books-list'/);
  });

  it('must install react-markdown deps used by post-detail', () => {
    const src = readScript();
    assert.match(src, /npm install[^\n]*react-markdown/);
    assert.match(src, /from 'react-markdown'/);
    assert.match(src, /from 'remark-gfm'/);
    assert.match(src, /from 'rehype-sanitize'/);
  });

  it('must not generate empty-tenant registry wiring (cleanup rm path ok)', () => {
    const src = readScript();
    assert.doesNotMatch(src, /@\/components\/empty-tenant/);
    assert.doesNotMatch(src, /['"]empty-tenant['"]/);
    assert.match(src, /src\/components\/empty-tenant/);
  });

  it('must force shadcn radix base non-interactively', () => {
    const src = readScript();
    assert.match(src, /shadcn@latest init[^\n]*--base radix/);
    assert.match(src, /shadcn@latest init[^\n]*--defaults/);
  });
});
