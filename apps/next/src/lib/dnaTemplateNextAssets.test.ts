import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const templateDir = path.join(repoRoot, 'packages/cli/assets/templates/next');

describe('CLI template next DNA assets', () => {
  it('has src_tenant.sh + manifest with expected markers', () => {
    const dna = path.join(templateDir, 'src_tenant.sh');
    const manifestPath = path.join(templateDir, 'manifest.json');
    expect(fs.existsSync(dna)).toBe(true);
    expect(fs.existsSync(manifestPath)).toBe(true);

    const content = fs.readFileSync(dna, 'utf8');
    expect(content).toContain('set -e');
    expect(content).toContain('package.json');
    expect(content).toContain('middleware.ts');
    expect(content).toMatch(/app\//);

    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8')) as {
      name?: string;
      dnaScript?: string;
    };
    expect(manifest.name).toBe('next');
    expect(manifest.dnaScript).toBe('src_tenant.sh');
  });
});
