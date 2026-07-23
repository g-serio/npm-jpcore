import { describe, expect, it } from 'vitest';
import type { PageConfig } from '@olonjs/core';
import { loadVisitorPage } from './visitorLoad';

describe('loadVisitorPage', () => {
  it('returns empty when the page registry has no pages', () => {
    const result = loadVisitorPage({ pages: {}, slug: 'home' });
    expect(result).toEqual({ kind: 'empty' });
  });

  it('returns the matched page for a known slug', () => {
    const page = { meta: { title: 'Home' }, sections: [] } as PageConfig;
    const result = loadVisitorPage({
      pages: { home: page },
      slug: 'home',
    });
    expect(result.kind).toBe('page');
    if (result.kind === 'page') {
      expect(result.registrySlug).toBe('home');
      expect(result.page).toEqual(page);
    }
  });
});
