/**
 * Gates for webmcp-feature-check.mjs (Task 3 — plan 001).
 * Run: node --test scripts/prebuild-webmcp-feature-check.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const SCRIPT = path.join(__dirname, 'webmcp-feature-check.mjs');
const PKG = path.join(ROOT, 'package.json');

describe('next verify:webmcp script', () => {
  it('exists and uses document.modelContextTesting only', () => {
    assert.ok(fs.existsSync(SCRIPT), `missing ${SCRIPT}`);
    const src = fs.readFileSync(SCRIPT, 'utf8');
    assert.match(src, /document\.modelContextTesting/);
    assert.doesNotMatch(src, /navigator\.modelContextTesting/);
    assert.doesNotMatch(src, /navigator\.modelContext(?!Testing)/);
  });

  it('is wired as verify:webmcp and not in prebuild', () => {
    const pkg = JSON.parse(fs.readFileSync(PKG, 'utf8'));
    assert.equal(pkg.scripts?.['verify:webmcp'], 'node scripts/webmcp-feature-check.mjs');
    assert.ok(pkg.scripts?.prebuild);
    assert.doesNotMatch(pkg.scripts.prebuild, /webmcp-feature-check/);
  });
});
