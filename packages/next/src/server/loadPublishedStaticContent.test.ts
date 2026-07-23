import { describe, expect, it, vi } from 'vitest';
import { loadPublishedStaticContent } from './loadPublishedStaticContent';

describe('loadPublishedStaticContent', () => {
  it('loads site and pages from published /config and /pages URLs', async () => {
    const fetchImpl = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.endsWith('/config/site.json')) {
        return new Response(JSON.stringify({ identity: { title: 'Published' } }), { status: 200 });
      }
      if (url.endsWith('/pages/home.json')) {
        return new Response(
          JSON.stringify({
            id: 'home-page',
            slug: 'home',
            meta: { title: 'Home' },
            sections: [],
          }),
          { status: 200 },
        );
      }
      return new Response('missing', { status: 404 });
    });

    const result = await loadPublishedStaticContent({
      knownSlugs: ['home'],
      baseUrl: 'https://cdn.example/',
      fetchImpl: fetchImpl as typeof fetch,
    });

    expect(result.siteConfig).toMatchObject({ identity: { title: 'Published' } });
    expect(result.pages.home?.meta?.title).toBe('Home');
    expect(fetchImpl).toHaveBeenCalledWith(
      'https://cdn.example/config/site.json',
      expect.objectContaining({ cache: 'no-store' }),
    );
    expect(fetchImpl).toHaveBeenCalledWith(
      'https://cdn.example/pages/home.json',
      expect.objectContaining({ cache: 'no-store' }),
    );
  });

  it('throws when published site config is unavailable', async () => {
    const fetchImpl = vi.fn(async () => new Response('no', { status: 503 }));
    await expect(
      loadPublishedStaticContent({
        knownSlugs: ['home'],
        baseUrl: 'https://cdn.example/',
        fetchImpl: fetchImpl as typeof fetch,
      }),
    ).rejects.toThrow(/Static site config unavailable/);
  });
});
