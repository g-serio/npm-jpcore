import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { createPublicPageJsonHttpResult, resolvePublicPageJson } from '@olonjs/next/server';
import { loadLocalPublicPageBundle } from './loadLocalPublicPageBundle';

describe('loadLocalPublicPageBundle', () => {
  const appRoot = path.resolve(__dirname, '../../..');

  it('loads local pages and site config into a resolve bundle', () => {
    const bundle = loadLocalPublicPageBundle(appRoot);
    expect(bundle.pages.home).toBeDefined();
    expect(bundle.siteConfig).toBeDefined();
    expect(bundle.menuConfig).toBeDefined();
    expect(bundle.themeConfig).toBeDefined();
  });

  it('resolves home.json to 200 and unknown slug to 404', () => {
    const bundle = loadLocalPublicPageBundle(appRoot);
    const home = createPublicPageJsonHttpResult(
      resolvePublicPageJson({ slug: 'home.json', bundle }),
    );
    expect(home.status).toBe(200);
    expect((home.body as { slug?: string }).slug).toBe('home');

    const missing = createPublicPageJsonHttpResult(
      resolvePublicPageJson({ slug: 'does-not-exist.json', bundle }),
    );
    expect(missing.status).toBe(404);
    expect(missing.body).toEqual({ error: 'Page JSON not found' });
  });
});
