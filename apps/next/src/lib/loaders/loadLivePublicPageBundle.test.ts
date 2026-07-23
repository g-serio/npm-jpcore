import path from 'node:path';
import { describe, expect, it, vi } from 'vitest';
import { resolvePublicPageJson } from '@olonjs/next/server';
import { loadLivePublicPageBundle } from './loadLivePublicPageBundle';

describe('loadLivePublicPageBundle', () => {
  const appRoot = path.resolve(__dirname, '../../..');

  it('resolves home.json from a mocked live render payload', async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({
          ok: true,
          route: { path: '/', template: 'home', params: {} },
          context: {
            siteConfig: {
              identity: { title: 'Live' },
              footer: { id: 'footer', type: 'footer', data: { brandText: 'L' } },
            },
            menuConfig: {},
          },
          page: {
            id: 'home-page',
            slug: 'home',
            meta: { title: 'Live Home' },
            sections: [],
          },
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      ),
    );

    const bundle = await loadLivePublicPageBundle({
      slug: 'home.json',
      appRoot,
      apiBases: ['https://api.example/api/v1'],
      apiKey: 'k',
      fetchImpl: fetchImpl as typeof fetch,
    });

    const resolved = resolvePublicPageJson({ slug: 'home.json', bundle });
    expect(resolved?.page.meta?.title).toBe('Live Home');
  });
});
