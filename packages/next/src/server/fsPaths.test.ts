import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { safeDataSlugPath } from './fsPaths';

describe('safeDataSlugPath', () => {
  const root = path.resolve('/tmp/olon-next-data-pages');

  it('resolves a nested slug inside the data root', () => {
    const resolved = safeDataSlugPath(root, 'authors/home', 'page');
    expect(resolved).toBe(path.join(root, 'authors', 'home.json'));
    expect(resolved.startsWith(`${root}${path.sep}`)).toBe(true);
  });

  it('keeps traversal-like slugs inside the data root after sanitization', () => {
    const resolved = safeDataSlugPath(root, '../../etc/passwd', 'page');
    expect(resolved.startsWith(`${root}${path.sep}`)).toBe(true);
    expect(resolved.includes(`${path.sep}..${path.sep}`)).toBe(false);
    expect(path.relative(root, resolved).startsWith('..')).toBe(false);
  });
});
