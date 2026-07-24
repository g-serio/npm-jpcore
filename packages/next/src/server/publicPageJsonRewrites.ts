export type PublicPageJsonRewrite = {
  source: string;
  destination: string;
};

/**
 * Next.js rewrites so `/*.json` and `/pages/*.json` hit the public-page API
 * instead of the RSC catch-all.
 */
export function buildPublicPageJsonRewrites(): PublicPageJsonRewrite[] {
  return [
    {
      source: '/pages/:path*.json',
      destination: '/api/public-page/:path*',
    },
    {
      source: '/:path*.json',
      destination: '/api/public-page/:path*',
    },
  ];
}
