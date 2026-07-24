import { describe, expect, it } from 'vitest';
import { createPublicPageJsonHttpResult } from './publicPageJsonHttp';

describe('createPublicPageJsonHttpResult', () => {
  it('returns 404 JSON when page is missing', () => {
    expect(createPublicPageJsonHttpResult(null)).toEqual({
      status: 404,
      body: { error: 'Page JSON not found' },
    });
  });

  it('returns 200 with the resolved page when present', () => {
    const page = { id: 'home', slug: 'home', meta: { title: 'Home' }, sections: [] };
    expect(
      createPublicPageJsonHttpResult({
        page: page as never,
        registrySlug: 'home',
        params: {},
      }),
    ).toEqual({ status: 200, body: page });
  });
});
