import path from 'node:path';
import { describe, expect, it, vi } from 'vitest';
import { resolvePublicPageJson } from '@olonjs/next/server';
import { loadStaticPublicPageBundle } from './loadStaticPublicPageBundle';

describe('loadStaticPublicPageBundle', () => {
  const appRoot = path.resolve(__dirname, '../../..');

  it('builds a resolveable bundle from mocked published static content', async () => {
    const fetchImpl = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.endsWith('/config/site.json')) {
        return new Response(
          JSON.stringify({
            identity: { title: 'Static Site' },
            footer: { id: 'footer', type: 'footer', data: { brandText: 'S' } },
          }),
          { status: 200 },
        );
      }
      if (url.includes('/pages/') && url.endsWith('.json')) {
        return new Response(
          JSON.stringify({
            id: 'home-page',
            slug: 'home',
            meta: { title: 'Static Home' },
            sections: [],
          }),
          { status: 200 },
        );
      }
      return new Response('no', { status: 404 });
    });

    const bundle = await loadStaticPublicPageBundle({
      appRoot,
      baseUrl: 'https://static.example/',
      fetchImpl: fetchImpl as typeof fetch,
    });

    expect(bundle.siteConfig).toMatchObject({ identity: { title: 'Static Site' } });
    const resolved = resolvePublicPageJson({ slug: 'home.json', bundle });
    expect(resolved?.page.meta?.title).toBe('Static Home');
  });
});
