/**
 * Static gates for generate_inkwell_next.sh (TDD for the Next Inkwell generator).
 * Run: node --test scripts/generate-inkwell-next.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCRIPT = path.resolve(__dirname, '../generate_inkwell_next.sh');

function readScript() {
  assert.ok(fs.existsSync(SCRIPT), `missing ${SCRIPT}`);
  return fs.readFileSync(SCRIPT, 'utf8');
}

describe('generate_inkwell_next.sh harness gates', () => {
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
});
