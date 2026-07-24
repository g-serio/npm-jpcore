import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { fileURLToPath } from 'node:url';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

describe('tenant-next DNA dist wiring', () => {
  it('has src2Code.sh and a dist script targeting template next', () => {
    const encoder = path.join(appRoot, 'src2Code.sh');
    expect(fs.existsSync(encoder)).toBe(true);

    const pkg = JSON.parse(fs.readFileSync(path.join(appRoot, 'package.json'), 'utf8')) as {
      scripts?: Record<string, string>;
    };
    const dist = pkg.scripts?.dist ?? '';
    expect(dist).toContain('src2Code.sh');
    expect(dist).toContain('--template next');
    expect(dist).toMatch(/\bapp\b/);
    expect(dist).toMatch(/\bsrc\b/);
    expect(pkg.scripts?.['dist:dna']).toBe('npm run dist');
  });
});
