/**
 * Static + smoke gates for robots.mjs / sitemap.mjs (Task 1 — plan 001).
 * Run: node --test scripts/prebuild-robots-sitemap.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const ROBOTS = path.join(__dirname, 'robots.mjs');
const SITEMAP = path.join(__dirname, 'sitemap.mjs');

describe('next prebuild robots + sitemap', () => {
  it('scripts exist', () => {
    assert.ok(fs.existsSync(ROBOTS), `missing ${ROBOTS}`);
    assert.ok(fs.existsSync(SITEMAP), `missing ${SITEMAP}`);
  });

  it('defaults to Next localhost:3000 (not Vite 5173)', () => {
    const robots = fs.readFileSync(ROBOTS, 'utf8');
    const sitemap = fs.readFileSync(SITEMAP, 'utf8');
    assert.match(robots, /localhost:3000/);
    assert.match(sitemap, /localhost:3000/);
    assert.doesNotMatch(robots, /localhost:5173/);
    assert.doesNotMatch(sitemap, /localhost:5173/);
  });

  it('writes public/robots.txt and public/sitemap.xml when run', () => {
    const robotsOut = path.join(ROOT, 'public', 'robots.txt');
    const sitemapOut = path.join(ROOT, 'public', 'sitemap.xml');
    for (const p of [robotsOut, sitemapOut]) {
      if (fs.existsSync(p)) fs.unlinkSync(p);
    }

    const r1 = spawnSync(process.execPath, [ROBOTS], { cwd: ROOT, encoding: 'utf8' });
    assert.equal(r1.status, 0, r1.stderr || r1.stdout);
    const r2 = spawnSync(process.execPath, [SITEMAP], { cwd: ROOT, encoding: 'utf8' });
    assert.equal(r2.status, 0, r2.stderr || r2.stdout);

    assert.ok(fs.existsSync(robotsOut));
    assert.ok(fs.existsSync(sitemapOut));
    const robotsTxt = fs.readFileSync(robotsOut, 'utf8');
    const sitemapXml = fs.readFileSync(sitemapOut, 'utf8');
    assert.match(robotsTxt, /Sitemap: http:\/\/localhost:3000\/sitemap\.xml/);
    assert.match(sitemapXml, /<urlset/);
    assert.match(sitemapXml, /\/home\.json|PAGE: HOME|loc>http:\/\/localhost:3000\/</);
  });
});
