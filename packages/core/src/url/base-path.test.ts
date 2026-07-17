import { describe, expect, it } from 'vitest';

import { normalizeBasePath, withBasePath } from './base-path';

describe('normalizeBasePath', () => {
  it('falls back to root when missing', () => {
    expect(normalizeBasePath()).toBe('/');
    expect(normalizeBasePath('')).toBe('/');
    expect(normalizeBasePath('/')).toBe('/');
  });

  it('normalizes non-root base paths with leading and trailing slash', () => {
    expect(normalizeBasePath('core')).toBe('/core/');
    expect(normalizeBasePath('/core')).toBe('/core/');
    expect(normalizeBasePath('/core/')).toBe('/core/');
  });
});

describe('withBasePath', () => {
  it('keeps root-based paths unchanged when base path is root', () => {
    expect(withBasePath('/pages/home.json', '/')).toBe('/pages/home.json');
    expect(withBasePath('pages/home.json', '/')).toBe('/pages/home.json');
  });

  it('prepends base path for sub-route deployments', () => {
    expect(withBasePath('/pages/home.json', '/core/')).toBe('/core/pages/home.json');
    expect(withBasePath('pages/home.json', '/core')).toBe('/core/pages/home.json');
  });

  it('keeps absolute URLs and anchors unchanged', () => {
    expect(withBasePath('https://example.com/a', '/core/')).toBe('https://example.com/a');
    expect(withBasePath('#section', '/core/')).toBe('#section');
  });
});
