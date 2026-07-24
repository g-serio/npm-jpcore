import { describe, expect, it } from 'vitest';
import { buildPublicPageJsonRewrites } from './publicPageJsonRewrites';

describe('buildPublicPageJsonRewrites', () => {
  it('rewrites /pages/*.json and /*.json to the public-page API', () => {
    expect(buildPublicPageJsonRewrites()).toEqual([
      {
        source: '/pages/:path*.json',
        destination: '/api/public-page/:path*',
      },
      {
        source: '/:path*.json',
        destination: '/api/public-page/:path*',
      },
    ]);
  });
});
