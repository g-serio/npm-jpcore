import { describe, expect, it } from 'vitest';
import type { MenuConfig, PageConfig, SiteConfig } from '@olonjs/core';
import { normalizePublicPageSlug, resolvePublicPageJson } from './resolvePublicPageJson';

const emptySite = {} as SiteConfig;
const emptyMenu = {} as MenuConfig;
const emptyTheme = {} as Record<string, unknown>;

describe('normalizePublicPageSlug', () => {
  it('strips leading pages/ and .json suffix', () => {
    expect(normalizePublicPageSlug('/pages/home.json')).toBe('home');
    expect(normalizePublicPageSlug('home.json')).toBe('home');
    expect(normalizePublicPageSlug('libri/1984.json')).toBe('libri/1984');
  });
});

describe('resolvePublicPageJson', () => {
  const homePage = {
    id: 'home',
    slug: 'home',
    meta: { title: 'Home' },
    sections: [],
  } as PageConfig;

  it('returns null when slug is not in the registry', () => {
    const result = resolvePublicPageJson({
      slug: 'missing.json',
      bundle: {
        pages: { home: homePage },
        siteConfig: emptySite,
        themeConfig: emptyTheme,
        menuConfig: emptyMenu,
      },
    });
    expect(result).toBeNull();
  });

  it('returns the resolved page for a known slug', () => {
    const result = resolvePublicPageJson({
      slug: 'home.json',
      bundle: {
        pages: { home: homePage },
        siteConfig: emptySite,
        themeConfig: emptyTheme,
        menuConfig: emptyMenu,
      },
    });
    expect(result).not.toBeNull();
    expect(result?.registrySlug).toBe('home');
    expect(result?.page.meta?.title).toBe('Home');
  });
});
