/**
 * Gates for package.json prebuild wiring (Task 5 — plan 001).
 * Run: node --test scripts/prebuild-wire.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PKG = path.resolve(__dirname, '../package.json');

describe('next prebuild wiring', () => {
  it('runs sync → llms → bake → sitemap → robots (alpha order)', () => {
    const pkg = JSON.parse(fs.readFileSync(PKG, 'utf8'));
    const prebuild = pkg.scripts?.prebuild ?? '';
    assert.match(prebuild, /sync-pages-to-public\.mjs/);
    assert.match(prebuild, /generate-llms-txt\.mjs/);
    assert.match(prebuild, /bake\.mjs/);
    assert.match(prebuild, /sitemap\.mjs/);
    assert.match(prebuild, /robots\.mjs/);
    assert.doesNotMatch(prebuild, /webmcp-feature-check/);

    const order = ['sync-pages-to-public', 'generate-llms-txt', 'bake', 'sitemap', 'robots'].map((name) =>
      prebuild.indexOf(name),
    );
    for (let i = 1; i < order.length; i += 1) {
      assert.ok(order[i] > order[i - 1], `expected ${i} after previous in: ${prebuild}`);
    }
  });

  it('dist DNA includes scripts/', () => {
    const pkg = JSON.parse(fs.readFileSync(PKG, 'utf8'));
    assert.match(pkg.scripts?.dist ?? '', /\bscripts\b/);
  });
});
