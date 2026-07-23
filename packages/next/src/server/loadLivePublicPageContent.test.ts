import { describe, expect, it, vi } from 'vitest';
import { loadLivePublicPageContent, slugToRenderPath } from './loadLivePublicPageContent';

describe('slugToRenderPath', () => {
  it('maps home and nested slugs to SPP render paths', () => {
    expect(slugToRenderPath('home')).toBe('/');
    expect(slugToRenderPath('home.json')).toBe('/');
    expect(slugToRenderPath('libri/1984')).toBe('/libri/1984');
  });
});

describe('loadLivePublicPageContent', () => {
  it('loads a single resolved page + context from GET /render', async () => {
    const fetchImpl = vi.fn(async (input: RequestInfo | URL) => {
      expect(String(input)).toBe('https://api.example/api/v1/render?path=%2F');
      return new Response(
        JSON.stringify({
          ok: true,
          route: { path: '/', template: 'home', params: {} },
          context: {
            siteConfig: { identity: { title: 'Live' } },
            menuConfig: { main: [] },
          },
          page: {
            id: 'home-page',
            slug: 'home',
            meta: { title: 'Live Home' },
            sections: [],
          },
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    });

    const result = await loadLivePublicPageContent({
      slug: 'home.json',
      apiBases: ['https://api.example/api/v1'],
      apiKey: 'test-key',
      fetchImpl: fetchImpl as typeof fetch,
    });

    expect(result.pages.home?.meta?.title).toBe('Live Home');
    expect(result.siteConfig).toMatchObject({ identity: { title: 'Live' } });
    expect(result.menuConfig).toEqual({ main: [] });
    expect(fetchImpl).toHaveBeenCalledWith(
      'https://api.example/api/v1/render?path=%2F',
      expect.objectContaining({
        method: 'GET',
        headers: expect.objectContaining({ Authorization: 'Bearer test-key' }),
      }),
    );
  });

  it('throws when render returns non-OK', async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(JSON.stringify({ ok: false, error: 'not found' }), {
        status: 404,
        headers: { 'content-type': 'application/json' },
      }),
    );

    await expect(
      loadLivePublicPageContent({
        slug: 'missing',
        apiBases: ['https://api.example/api/v1'],
        apiKey: 'test-key',
        fetchImpl: fetchImpl as typeof fetch,
      }),
    ).rejects.toThrow(/Live render unavailable/);
  });
});
