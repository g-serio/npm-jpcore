/**
 * Gates for generate-llms-txt.mjs (Task 2 — plan 001).
 * Run: node --test scripts/prebuild-generate-llms-txt.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const SCRIPT = path.join(__dirname, 'generate-llms-txt.mjs');

describe('next prebuild generate-llms-txt', () => {
  it('script exists and uses @olonjs/core webmcp', () => {
    assert.ok(fs.existsSync(SCRIPT), `missing ${SCRIPT}`);
    const src = fs.readFileSync(SCRIPT, 'utf8');
    assert.match(src, /@olonjs\/core/);
    assert.match(src, /buildLlmsTxt|webmcp/);
    assert.match(src, /public\/llms\.txt|llms\.txt/);
  });

  it('writes public/llms.txt when run', () => {
    const out = path.join(ROOT, 'public', 'llms.txt');
    if (fs.existsSync(out)) fs.unlinkSync(out);

    const result = spawnSync(process.execPath, [SCRIPT], { cwd: ROOT, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.ok(fs.existsSync(out));
    const body = fs.readFileSync(out, 'utf8');
    assert.ok(body.trim().length > 0);
  });
});
