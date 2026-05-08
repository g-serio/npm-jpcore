// One-off image optimization for the hero background. Run from apps/olonjs.io:
//   node scripts/optimize-hero.mjs
//
// Reads `public/assets/images/1778144109633-1776332627579-plug-graded-square.jpg`
// and emits AVIF + WebP variants at 768/1280/1920 widths under the same folder.
// See ADR-0007 and docs/plans/perf-olonjs-io.md (Phase 4).
//
// `sharp` is not a tenant runtime dependency. This script expects sharp to be
// available either from a local install (`npm i --no-save sharp`) or from a
// sibling temp install — `--require-resolve` style: pass SHARP_FROM=/path/to/parent.

import { readFile, writeFile, stat } from 'node:fs/promises';
import { resolve, dirname, join, basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

const __dirname = dirname(fileURLToPath(import.meta.url));
const APP_DIR = resolve(__dirname, '..');
const IN = join(APP_DIR, 'public/assets/images/1778144109633-1776332627579-plug-graded-square.jpg');
const OUT_DIR = join(APP_DIR, 'public/assets/images');
const STEM = 'hero-plug-graded';
// Source is 928×928 and the hero uses it as a decorative full-bleed background
// with mix-blend-mode + opacity 0.5. A single 768w variant covers every viewport
// without perceptible quality loss.
const WIDTHS = [768];

async function loadSharp() {
  try {
    return (await import('sharp')).default;
  } catch {
    const fallback = process.env.SHARP_FROM;
    if (!fallback) throw new Error('sharp not available; set SHARP_FROM=/path/with/node_modules');
    const r = createRequire(pathToFileURL(join(fallback, 'package.json')));
    return r('sharp');
  }
}

async function fmt(bytes) {
  return `${(bytes / 1024).toFixed(1)} KB`;
}

async function run() {
  const sharp = await loadSharp();
  const inBuf = await readFile(IN);
  const meta = await sharp(inBuf).metadata();
  console.log(`source: ${IN}`);
  console.log(`source: ${meta.width}x${meta.height} ${meta.format} ${await fmt(inBuf.length)}`);

  for (const w of WIDTHS) {
    const baseImg = sharp(inBuf).resize({ width: w, withoutEnlargement: true });

    const avif = await baseImg.clone().avif({ quality: 50, effort: 6 }).toBuffer();
    const avifPath = join(OUT_DIR, `${STEM}-${w}.avif`);
    await writeFile(avifPath, avif);
    console.log(`  ${basename(avifPath)}  ${await fmt(avif.length)}`);

    const webp = await baseImg.clone().webp({ quality: 72, effort: 6 }).toBuffer();
    const webpPath = join(OUT_DIR, `${STEM}-${w}.webp`);
    await writeFile(webpPath, webp);
    console.log(`  ${basename(webpPath)}  ${await fmt(webp.length)}`);
  }

  // JPG fallback at 768w — for browsers without WebP/AVIF support.
  const fallback = await sharp(inBuf)
    .resize({ width: 768, withoutEnlargement: true })
    .jpeg({ quality: 78, mozjpeg: true })
    .toBuffer();
  const fbPath = join(OUT_DIR, `${STEM}-768.jpg`);
  await writeFile(fbPath, fallback);
  console.log(`  ${basename(fbPath)}  ${await fmt(fallback.length)}`);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
