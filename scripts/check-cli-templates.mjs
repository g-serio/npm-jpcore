#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(__dirname, '..');
const templatesDir = path.join(ROOT, 'packages', 'cli', 'assets', 'templates');
const requiredTemplates = ['alpha', 'next'];

function fail(message) {
  console.error(`[template-check] ERROR: ${message}`);
  process.exit(1);
}

if (!fs.existsSync(templatesDir)) {
  fail(`Missing templates directory: ${templatesDir}`);
}

for (const name of requiredTemplates) {
  const dir = path.join(templatesDir, name);
  const dna = path.join(dir, 'src_tenant.sh');
  const manifest = path.join(dir, 'manifest.json');

  if (!fs.existsSync(dir)) fail(`Missing template directory: ${name}`);
  if (!fs.existsSync(dna)) fail(`Missing DNA script for template ${name}: ${dna}`);
  if (!fs.existsSync(manifest)) fail(`Missing manifest for template ${name}: ${manifest}`);

  const content = fs.readFileSync(dna, 'utf8');
  if (!content.includes('set -e')) fail(`DNA script for ${name} missing shell safety guard (set -e)`);
  if (!content.includes('package.json')) fail(`DNA script for ${name} seems incomplete (package.json not found)`);

  try {
    const parsed = JSON.parse(fs.readFileSync(manifest, 'utf8'));
    if (parsed.name !== name) fail(`Manifest name mismatch for ${name}`);
    if (parsed.dnaScript !== 'src_tenant.sh') fail(`Manifest dnaScript mismatch for ${name}`);
  } catch (error) {
    fail(`Invalid manifest JSON for ${name}: ${error instanceof Error ? error.message : String(error)}`);
  }
}

console.log('[template-check] OK: template assets are valid.');
