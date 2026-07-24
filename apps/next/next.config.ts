import type { NextConfig } from 'next';

/**
 * Keep rewrites inline — next.config is loaded via Node/CJS and cannot reliably
 * import `@olonjs/next/server` (exports are ESM `import`-only).
 * Contract guarded by `buildPublicPageJsonRewrites` unit tests in the package.
 */
const publicPageJsonRewrites = [
  {
    source: '/pages/:path*.json',
    destination: '/api/public-page/:path*',
  },
  {
    source: '/:path*.json',
    destination: '/api/public-page/:path*',
  },
];

const nextConfig: NextConfig = {
  reactStrictMode: true,
  transpilePackages: ['@olonjs/next', '@olonjs/core', '@olonjs/react', '@olonjs/studio'],
  /**
   * Visitor/admin loaders read `src/data/**` via runtime `fs` (`getFilePages`, etc.).
   * Those JSON files are never statically imported, so NFT omits them from the
   * Vercel serverless bundle unless we force-include them — otherwise
   * `getFilePages()` returns {} and the site shows EmptyTenantView.
   */
  outputFileTracingIncludes: {
    '/*': ['./src/data/**/*'],
  },
  async rewrites() {
    return publicPageJsonRewrites;
  },
};

export default nextConfig;
