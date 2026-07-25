/**
 * Gates for bake.mjs (Task 4 — plan 001). Agentic artifacts only; no Vite SSG.
 * Run: node --test scripts/prebuild-bake.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const SCRIPT = path.join(__dirname, 'bake.mjs');

describe('next bake.mjs (agentic artifacts)', () => {
  it('exists and does not import vite / write HTML SSG', () => {
    assert.ok(fs.existsSync(SCRIPT), `missing ${SCRIPT}`);
    const src = fs.readFileSync(SCRIPT, 'utf8');
    assert.doesNotMatch(src, /from ['"]vite['"]/);
    assert.doesNotMatch(src, /vite\.build|entry-ssg/);
    // May spawn tsx helper — check companion if present
    const impl = path.join(__dirname, 'bake.ts');
    if (fs.existsSync(impl)) {
      const implSrc = fs.readFileSync(impl, 'utf8');
      assert.doesNotMatch(implSrc, /from ['"]vite['"]/);
      assert.doesNotMatch(implSrc, /entry-ssg/);
    }
  });

  it('writes reachable public agentic artifacts', () => {
    const result = spawnSync(process.execPath, [SCRIPT], {
      cwd: ROOT,
      encoding: 'utf8',
      env: { ...process.env },
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);

    assert.ok(fs.existsSync(path.join(ROOT, 'public', 'mcp-manifest.json')));
    assert.ok(fs.existsSync(path.join(ROOT, 'public', 'llms.txt')));
    assert.ok(fs.existsSync(path.join(ROOT, 'public', 'schemas', 'home.schema.json')));
    assert.ok(fs.existsSync(path.join(ROOT, 'public', 'mcp-manifests', 'home.json')));
    assert.ok(fs.existsSync(path.join(ROOT, 'public', 'config', 'site.json')));

    const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, 'public', 'mcp-manifest.json'), 'utf8'));
    assert.equal(manifest.kind, 'olonjs-mcp-manifest-index');
    assert.ok(Array.isArray(manifest.pages));
  });
});
