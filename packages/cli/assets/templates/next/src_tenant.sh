#!/bin/bash
set -e

echo "Starting project reconstruction..."

mkdir -p "app"
mkdir -p "app/[[...slug]]"
echo "Creating app/[[...slug]]/page.tsx..."
cat << 'END_OF_FILE_CONTENT' > "app/[[...slug]]/page.tsx"
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import {
  buildPageContractHref,
  buildPageManifestHref,
  resolveCollectionContext,
  resolveRuntimeConfig,
  type PageConfig,
} from '@olonjs/core';
import { loadVisitorPage } from '@olonjs/next/server';
import { EmptyTenantView } from '@/components/empty-tenant';
import { CollectionRegistry } from '@/lib/CollectionRegistry';
import { buildVisitorWebPageJsonLd } from '@/lib/buildVisitorWebPageJsonLd';
import { getFileCollections } from '@/lib/loaders/getFileCollections';
import { getFilePages } from '@/lib/loaders/getFilePages';
import { getFileSiteBundle } from '@/lib/loaders/getFileSiteConfig';
import { resolveVisitorShell } from '@/lib/resolveVisitorShell';
import { VisitorSection } from '@/lib/VisitorSection';

export const dynamic = 'force-dynamic';

type PageProps = {
  params: Promise<{ slug?: string[] }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

function slugFromParams(segments: string[] | undefined): string {
  if (!segments || segments.length === 0) return 'home';
  return segments.map((s) => decodeURIComponent(s)).join('/');
}

function firstSearchValue(value: string | string[] | undefined): string | null {
  if (Array.isArray(value)) return value[0] ?? null;
  return value ?? null;
}

function resolveAuthorFilter(
  params: Record<string, string>,
  searchParams: Record<string, string | string[] | undefined>,
): string | null {
  if (params.authorId) return params.authorId;
  return firstSearchValue(searchParams.author);
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug: segments } = await params;
  const pages = getFilePages();
  const result = loadVisitorPage({ pages, slug: slugFromParams(segments) });
  if (result.kind === 'empty') {
    return { title: 'Empty tenant' };
  }
  if (result.kind === 'not-found') {
    return { title: 'Page not found' };
  }
  return {
    title: result.page.meta?.title ?? 'OlonJS',
    description: result.page.meta?.description,
  };
}

/**
 * Public visitor catch-all — RSC only.
 * Must not import @olonjs/studio or JsonPagesEngine (ADR-0017).
 */
export default async function VisitorCatchAllPage({ params, searchParams }: PageProps) {
  const { slug: segments } = await params;
  const query = await searchParams;
  const requestSlug = slugFromParams(segments);
  const pathname = requestSlug === 'home' ? '/' : `/${requestSlug}`;

  const pages = getFilePages();
  const result = loadVisitorPage({ pages, slug: requestSlug });

  if (result.kind === 'empty') {
    return <EmptyTenantView />;
  }

  if (result.kind === 'not-found') {
    notFound();
  }

  const collections = getFileCollections();
  const { siteConfig, menuConfig, themeConfig } = getFileSiteBundle();
  const collectionContext = resolveCollectionContext(result.page, result.params, collections);

  const resolved = resolveRuntimeConfig({
    pages: { [result.registrySlug]: result.page } as Record<string, PageConfig>,
    siteConfig,
    themeConfig,
    menuConfig,
    collections,
    collectionSchemas: CollectionRegistry as never,
    collectionContext,
    refDocuments: {
      'menu.json': menuConfig,
      'config/menu.json': menuConfig,
      'src/data/config/menu.json': menuConfig,
    },
  });

  const page = resolved.pages[result.registrySlug] ?? result.page;
  const authorId = resolveAuthorFilter(result.params, query);
  const pageNum = Number(firstSearchValue(query.page) ?? '1') || 1;
  const shell = resolveVisitorShell(page, resolved.siteConfig ?? siteConfig);
  const sectionExtras = { authorId, page: pageNum, pathname };
  const title = page.meta?.title ?? result.registrySlug;
  const description = typeof page.meta?.description === 'string' ? page.meta.description : '';
  const jsonLd = buildVisitorWebPageJsonLd({
    title,
    description,
    slug: requestSlug,
  });

  return (
    <>
      <link rel="mcp-manifest" href={buildPageManifestHref(requestSlug)} />
      <link rel="olon-contract" href={buildPageContractHref(requestSlug)} />
      <script
        type="application/ld+json"
        // eslint-disable-next-line react/no-danger -- Schema.org JSON-LD payload (parity alpha bake)
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      {shell.header ? (
        <VisitorSection section={shell.header} extras={sectionExtras} />
      ) : null}
      <main>
        {page.sections.map((section) => (
          <VisitorSection
            key={section.id}
            section={section}
            extras={sectionExtras}
          />
        ))}
      </main>
      {shell.footer ? (
        <VisitorSection section={shell.footer} extras={sectionExtras} />
      ) : null}
    </>
  );
}

END_OF_FILE_CONTENT
mkdir -p "app/admin"
mkdir -p "app/admin/[[...slug]]"
echo "Creating app/admin/[[...slug]]/page.tsx..."
cat << 'END_OF_FILE_CONTENT' > "app/admin/[[...slug]]/page.tsx"
import { AdminStudioDynamic } from '@/components/admin/AdminStudioDynamic';
import { getFileCollections } from '@/lib/loaders/getFileCollections';
import { getFilePages } from '@/lib/loaders/getFilePages';
import { getFileSiteBundle } from '@/lib/loaders/getFileSiteConfig';

export const dynamic = 'force-dynamic';

/**
 * Admin Studio entry — client island only (ADR-0017).
 * Persistence: local save-to-file, or Save2Repo cold save when NEXT_PUBLIC_* cloud env is set.
 * HotSave is out of scope for Next v1.
 *
 * Studio is loaded with next/dynamic ssr:false because JsonPagesEngine uses
 * createBrowserRouter (needs `document`) and Next still SSRs `'use client'` once.
 */
export default function AdminCatchAllPage() {
  const pages = getFilePages();
  const collections = getFileCollections();
  const { siteConfig, menuConfig, themeConfig } = getFileSiteBundle();

  return (
    <AdminStudioDynamic
      initialPages={pages}
      initialSiteConfig={siteConfig}
      initialMenuConfig={menuConfig}
      initialThemeConfig={themeConfig}
      initialCollections={collections}
    />
  );
}

END_OF_FILE_CONTENT
mkdir -p "app/api"
mkdir -p "app/api/list-assets"
echo "Creating app/api/list-assets/route.ts..."
cat << 'END_OF_FILE_CONTENT' > "app/api/list-assets/route.ts"
import { NextResponse } from 'next/server';
import path from 'node:path';
import { listLocalImages, resolveLocalDataRoots } from '@olonjs/next/server';

export async function GET() {
  try {
    const roots = resolveLocalDataRoots(path.resolve(process.cwd()));
    return NextResponse.json(listLocalImages(roots.assetsImagesDir));
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'List failed' },
      { status: 500 },
    );
  }
}

END_OF_FILE_CONTENT
mkdir -p "app/api/public-page"
mkdir -p "app/api/public-page/[...slug]"
echo "Creating app/api/public-page/[...slug]/route.ts..."
cat << 'END_OF_FILE_CONTENT' > "app/api/public-page/[...slug]/route.ts"
import { NextResponse } from 'next/server';
import path from 'node:path';
import {
  createPublicPageJsonHttpResult,
  resolvePublicPageJson,
} from '@olonjs/next/server';
import { readServerCloudPolicy } from '@/lib/env/serverCloudPolicy';
import { loadPublicPageBundleForRequest } from '@/lib/loaders/loadPublicPageBundleForRequest';

/**
 * Public page JSON API — Local / Static / Live via server cloud policy bootSource
 * (Vite `GET /{slug}.json` parity).
 */
export async function GET(
  request: Request,
  context: { params: Promise<{ slug?: string[] }> },
) {
  try {
    const { slug: parts } = await context.params;
    const slug = (parts ?? []).join('/');
    const policy = readServerCloudPolicy();
    const bundle = await loadPublicPageBundleForRequest({
      bootSource: policy.bootSource,
      slug,
      requestUrl: request.url,
      appRoot: path.resolve(process.cwd()),
      apiUrl: policy.apiUrl,
      apiKey: policy.apiKey,
    });
    const resolved = resolvePublicPageJson({ slug, bundle });
    const http = createPublicPageJsonHttpResult(resolved);
    return NextResponse.json(http.body, { status: http.status });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Page JSON resolution failed' },
      { status: 500 },
    );
  }
}

END_OF_FILE_CONTENT
mkdir -p "app/api/save-to-file"
echo "Creating app/api/save-to-file/route.ts..."
cat << 'END_OF_FILE_CONTENT' > "app/api/save-to-file/route.ts"
import { NextResponse } from 'next/server';
import path from 'node:path';
import {
  resolveLocalDataRoots,
  saveProjectStateToDisk,
  type ProjectStateLike,
} from '@olonjs/next/server';

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as { projectState?: ProjectStateLike; slug?: string };
    if (!body.projectState || typeof body.slug !== 'string') {
      return NextResponse.json({ error: 'Missing projectState or slug' }, { status: 400 });
    }
    const roots = resolveLocalDataRoots(path.resolve(process.cwd()));
    saveProjectStateToDisk(roots, body.projectState, body.slug);
    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Save to file failed' },
      { status: 500 },
    );
  }
}

END_OF_FILE_CONTENT
mkdir -p "app/api/upload-asset"
echo "Creating app/api/upload-asset/route.ts..."
cat << 'END_OF_FILE_CONTENT' > "app/api/upload-asset/route.ts"
import { NextResponse } from 'next/server';
import path from 'node:path';
import { resolveLocalDataRoots, saveUploadedImage } from '@olonjs/next/server';

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as {
      filename?: string;
      mimeType?: string;
      data?: string;
    };
    if (!body.filename || typeof body.data !== 'string') {
      return NextResponse.json({ error: 'Missing filename or data' }, { status: 400 });
    }
    const roots = resolveLocalDataRoots(path.resolve(process.cwd()));
    const result = saveUploadedImage({
      assetsImagesDir: roots.assetsImagesDir,
      filename: body.filename,
      mimeType: body.mimeType,
      base64Data: body.data,
    });
    return NextResponse.json(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Upload failed';
    const status = message.includes('too large') ? 413 : message.includes('Invalid file') ? 400 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}

END_OF_FILE_CONTENT
echo "Creating app/globals.css..."
cat << 'END_OF_FILE_CONTENT' > "app/globals.css"
@import "tailwindcss";

/*
  TOKEN BRIDGE only — values come from theme.json via layout <style> (buildThemeVariableMap).
  Do not hardcode --theme-* color literals here.
*/
:root {
  --background: var(--theme-colors-background);
  --foreground: var(--theme-colors-foreground);
  --muted-foreground: var(--theme-colors-muted-foreground);
  --border: var(--theme-colors-border);
  --card: var(--theme-colors-card);
  --primary: var(--theme-colors-primary);
  --primary-foreground: var(--theme-colors-primary-foreground);
  --theme-font-primary: var(--theme-typography-font-family-primary);
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-muted-foreground: var(--muted-foreground);
  --color-border: var(--border);
  --color-card: var(--card);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
}

body {
  background: var(--background);
  color: var(--foreground);
  font-family: var(--theme-font-primary, system-ui, sans-serif);
}

END_OF_FILE_CONTENT
echo "Creating app/layout.tsx..."
cat << 'END_OF_FILE_CONTENT' > "app/layout.tsx"
import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import { getFileSiteBundle } from '@/lib/loaders/getFileSiteConfig';
import { serializeThemeRootCss } from '@/lib/css/serializeThemeRootCss';
import './globals.css';

export const metadata: Metadata = {
  title: 'OlonJS Next Starter',
  description: 'RSC visitors + admin client island (ADR-0017)',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  const { themeConfig } = getFileSiteBundle();
  const themeCss = serializeThemeRootCss(themeConfig);

  return (
    <html lang="en">
      <head>
        {themeCss ? (
          <style id="olon-theme-vars" dangerouslySetInnerHTML={{ __html: themeCss }} />
        ) : null}
      </head>
      <body className="min-h-screen bg-background text-foreground antialiased">{children}</body>
    </html>
  );
}

END_OF_FILE_CONTENT
echo "Creating app/not-found.tsx..."
cat << 'END_OF_FILE_CONTENT' > "app/not-found.tsx"
export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-[50vh] max-w-xl flex-col justify-center px-6 py-16 text-[var(--foreground)]">
      <p className="text-sm opacity-60">404</p>
      <h1 className="mt-2 text-2xl font-semibold tracking-tight">Page not found</h1>
      <p className="mt-3 opacity-80">This route does not match any page in the tenant.</p>
      <a href="/" className="mt-8 text-sm underline underline-offset-4 opacity-80 hover:opacity-100">
        Back to home
      </a>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating middleware.ts..."
cat << 'END_OF_FILE_CONTENT' > "middleware.ts"
import { NextResponse, type NextRequest } from 'next/server';
import {
  authorizeAdminRequest,
  buildAdminSessionCookie,
} from '@olonjs/next/admin-gate';

/**
 * Admin protection (tenant-alpha Vite middleware parity, no SSO).
 * Active only when VERCEL_ENV is set + ADMIN_PUBLIC_KEY present.
 * Protects Studio HTML and local mutate APIs — not public page JSON.
 */
export async function middleware(request: NextRequest) {
  const result = await authorizeAdminRequest(request, {
    VERCEL_ENV: process.env.VERCEL_ENV,
    ADMIN_PUBLIC_KEY: process.env.ADMIN_PUBLIC_KEY,
  });

  if (result.kind === 'bypass' || result.kind === 'allow') {
    return NextResponse.next();
  }

  if (result.kind === 'set-session') {
    const response = NextResponse.redirect(result.location, 302);
    response.headers.set('Set-Cookie', buildAdminSessionCookie(result.token));
    return response;
  }

  console.error(`[admin-middleware] 401 reason: ${result.hint}`);
  return new NextResponse('Unauthorized', { status: 401 });
}

export const config = {
  matcher: [
    '/admin',
    '/admin/:path*',
    '/api/save-to-file',
    '/api/upload-asset',
    '/api/list-assets',
  ],
};

END_OF_FILE_CONTENT
echo "Creating next-env.d.ts..."
cat << 'END_OF_FILE_CONTENT' > "next-env.d.ts"
/// <reference types="next" />
/// <reference types="next/image-types/global" />
/// <reference path="./.next/types/routes.d.ts" />

// NOTE: This file should not be edited
// see https://nextjs.org/docs/app/api-reference/config/typescript for more information.

END_OF_FILE_CONTENT
echo "Creating next.config.ts..."
cat << 'END_OF_FILE_CONTENT' > "next.config.ts"
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

END_OF_FILE_CONTENT
echo "Creating package.json..."
cat << 'END_OF_FILE_CONTENT' > "package.json"
{
  "name": "tenant-next",
  "version": "0.0.1",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "next dev",
    "prebuild": "node scripts/sync-pages-to-public.mjs && node scripts/generate-llms-txt.mjs && node scripts/bake.mjs && node scripts/sitemap.mjs && node scripts/robots.mjs",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "vitest run",
    "typecheck": "tsc --noEmit",
    "verify:webmcp": "node scripts/webmcp-feature-check.mjs",
    "dist": "bash ./src2Code.sh --template next app src scripts templates middleware.ts next.config.ts postcss.config.mjs tsconfig.json package.json next-env.d.ts vitest.config.ts",
    "dist:dna": "npm run dist"
  },
  "dependencies": {
    "@olonjs/core": "^1.1.28",
    "@olonjs/next": "^0.0.8",
    "@olonjs/react": "^0.1.11",
    "@olonjs/studio": "^0.1.11",
    "clsx": "^2.1.1",
    "lucide-react": "^0.474.0",
    "next": "^15.5.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^6.29.0",
    "tailwind-merge": "^3.0.1",
    "zod": "^3.24.1"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4.0.0",
    "@types/node": "^22.13.1",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "tailwindcss": "^4.0.0",
    "tsx": "^4.20.5",
    "typescript": "^5.7.3",
    "vitest": "^3.0.0"
  }
}

END_OF_FILE_CONTENT
echo "Creating postcss.config.mjs..."
cat << 'END_OF_FILE_CONTENT' > "postcss.config.mjs"
/** @type {import('postcss-load-config').Config} */
const config = {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};

export default config;

END_OF_FILE_CONTENT
mkdir -p "scripts"
echo "Creating scripts/bake.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/bake.mjs"
/**
 * Next bake entry — agentic WebMCP artifacts only (no Vite / no HTML SSG).
 * Runs scripts/bake.ts via tsx so SECTION_SCHEMAS can be imported from the tenant.
 */
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const bakeTs = path.join(__dirname, 'bake.ts');

const result = spawnSync(
  process.platform === 'win32' ? 'npx.cmd' : 'npx',
  ['tsx', '--tsconfig', 'tsconfig.json', bakeTs],
  {
    cwd: rootDir,
    stdio: 'inherit',
    env: process.env,
    shell: process.platform === 'win32',
  },
);

process.exit(result.status ?? 1);

END_OF_FILE_CONTENT
echo "Creating scripts/bake.ts..."
cat << 'END_OF_FILE_CONTENT' > "scripts/bake.ts"
/**
 * Next bake — agentic WebMCP artifacts only (no Vite / no HTML SSG).
 * Invoked by scripts/bake.mjs via tsx.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  resolvePageMatchFromRegistry,
  resolvePublicPageDocument,
  webmcp,
} from '@olonjs/core';
import { CollectionRegistry } from '../src/lib/CollectionRegistry';
import { SECTION_SCHEMAS, SECTION_SUBMISSION_SCHEMAS } from '../src/lib/schemas';
import { getFileCollections } from '../src/lib/loaders/getFileCollections';
import { getFilePages } from '../src/lib/loaders/getFilePages';
import { getFileSiteBundle } from '../src/lib/loaders/getFileSiteConfig';

const {
  buildPageContract,
  buildPageManifest,
  buildPageManifestHref,
  buildSiteManifest,
  buildLlmsTxt,
} = webmcp;

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const publicDir = path.join(root, 'public');
const pagesDir = path.join(root, 'src', 'data', 'pages');
const collectionsDir = path.join(root, 'src', 'data', 'collections');

async function writePublic(relativePath: string, content: string): Promise<void> {
  const target = path.join(publicDir, relativePath);
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, content, 'utf-8');
}

async function writePublicJson(relativePath: string, value: unknown): Promise<void> {
  await writePublic(relativePath, `${JSON.stringify(value, null, 2)}\n`);
}

async function readJsonFile(filePath: string): Promise<unknown> {
  return JSON.parse(await fs.readFile(filePath, 'utf-8'));
}

async function listJsonFilesRecursive(dir: string): Promise<string[]> {
  const items = await fs.readdir(dir, { withFileTypes: true });
  const files: string[] = [];
  for (const item of items) {
    const fullPath = path.join(dir, item.name);
    if (item.isDirectory()) {
      files.push(...(await listJsonFilesRecursive(fullPath)));
      continue;
    }
    if (item.isFile() && item.name.toLowerCase().endsWith('.json')) files.push(fullPath);
  }
  return files;
}

function toCanonicalSlug(relativeJsonPath: string): string {
  const slug = relativeJsonPath.replace(/\\/g, '/').replace(/\.json$/i, '').replace(/^\/+|\/+$/g, '');
  if (!slug) throw new Error('[bake] Invalid page slug: empty path segment');
  return slug;
}

async function expandCollectionTarget(slug: string, pageFilePath: string): Promise<string[]> {
  let pageConfig: Record<string, unknown>;
  try {
    pageConfig = (await readJsonFile(pageFilePath)) as Record<string, unknown>;
  } catch {
    return [slug];
  }

  const binding = pageConfig?.collection as { source?: string; paramKey?: string } | undefined;
  if (!binding || typeof binding.source !== 'string' || typeof binding.paramKey !== 'string') {
    return [slug];
  }

  const token = `[${binding.paramKey}]`;
  const authoredSlug =
    typeof pageConfig.slug === 'string'
      ? String(pageConfig.slug).replace(/\\/g, '/').replace(/^\/+|\/+$/g, '')
      : '';
  const routePattern =
    authoredSlug.includes(token) ? authoredSlug : slug.includes(token) ? slug : '';
  if (!routePattern) return [slug];

  const collectionPath = path.resolve(collectionsDir, binding.source, `${binding.source}.json`);
  let collection: Record<string, unknown>;
  try {
    collection = (await readJsonFile(collectionPath)) as Record<string, unknown>;
  } catch {
    return [slug];
  }

  if (!collection || typeof collection !== 'object' || Array.isArray(collection)) return [slug];
  const itemIds = Object.keys(collection).sort((a, b) => a.localeCompare(b));
  return itemIds.length > 0
    ? itemIds.map((itemId) => routePattern.replace(token, itemId))
    : [slug];
}

async function discoverSlugs(): Promise<string[]> {
  let files: string[] = [];
  try {
    files = await listJsonFilesRecursive(pagesDir);
  } catch {
    files = [];
  }

  const rawSlugs = (
    await Promise.all(
      files.map(async (fullPath) => {
        const slug = toCanonicalSlug(path.relative(pagesDir, fullPath));
        return expandCollectionTarget(slug, fullPath);
      }),
    )
  ).flat();

  return Array.from(new Set(rawSlugs)).sort((a, b) => a.localeCompare(b));
}

async function main(): Promise<void> {
  console.log('\n[bake] Next agentic artifacts (no Vite SSG)...');

  const pages = getFilePages(root);
  const collections = getFileCollections(root);
  const { siteConfig, themeConfig, menuConfig } = getFileSiteBundle(root);
  const collectionSchemas = CollectionRegistry as unknown as Record<string, unknown>;
  const schemas = SECTION_SCHEMAS as unknown as Record<string, unknown>;
  const submissionSchemas = SECTION_SUBMISSION_SCHEMAS as unknown as Record<string, unknown>;
  const refDocuments = {
    'menu.json': menuConfig,
    'config/menu.json': menuConfig,
    'src/data/config/menu.json': menuConfig,
  };

  const slugs = await discoverSlugs();
  if (slugs.length === 0) {
    throw new Error('[bake] No pages discovered under src/data/pages');
  }
  console.log(`[bake] Targets: ${slugs.join(', ')}`);

  const pagesForManifest: Record<string, (typeof pages)[string]> = { ...pages };

  for (const slug of slugs) {
    const pageConfig = resolvePageMatchFromRegistry(pages, slug)?.page;
    if (!pageConfig) continue;

    const resolvedPageDocument = resolvePublicPageDocument({
      slug,
      pages,
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      collectionSchemas: collectionSchemas as never,
      refDocuments,
    });
    const publicPageConfig = resolvedPageDocument?.page ?? pageConfig;
    pagesForManifest[slug] = publicPageConfig;

    await writePublicJson(`pages/${slug}.json`, publicPageConfig);

    const contract = buildPageContract({
      slug,
      pageConfig: publicPageConfig,
      schemas: schemas as never,
      submissionSchemas: submissionSchemas as never,
      siteConfig,
    });
    await writePublicJson(`schemas/${slug}.schema.json`, contract);

    const pageManifest = buildPageManifest({
      slug,
      pageConfig: publicPageConfig,
      schemas: schemas as never,
      siteConfig,
    });
    await writePublicJson(buildPageManifestHref(slug).replace(/^\//, ''), pageManifest);
  }

  await writePublicJson('config/site.json', siteConfig);

  const mcpManifest = buildSiteManifest({
    pages: pagesForManifest,
    schemas: schemas as never,
    siteConfig,
  });
  await writePublicJson('mcp-manifest.json', mcpManifest);

  const llmsTxtContent = buildLlmsTxt({
    pages: pagesForManifest,
    schemas: schemas as never,
    siteConfig,
  });
  await writePublic('llms.txt', `${llmsTxtContent}\n`);

  console.log('[bake] Wrote public/mcp-manifest.json, mcp-manifests/, schemas/, pages/, llms.txt, config/site.json');
  console.log('[bake] OK\n');
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exit(1);
});

END_OF_FILE_CONTENT
echo "Creating scripts/generate-SystemsArchitect-next.test.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/generate-SystemsArchitect-next.test.mjs"
/**
 * Static gates for generate_SystemsArchitect_next.sh (TDD for the Next SystemsArchitect generator).
 * Run: node --test scripts/generate-SystemsArchitect-next.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCRIPT = path.resolve(__dirname, '../templates/generate_SystemsArchitect_next.sh');

function readScript() {
  assert.ok(fs.existsSync(SCRIPT), `missing ${SCRIPT}`);
  return fs.readFileSync(SCRIPT, 'utf8');
}

describe('generate_SystemsArchitect_next.sh harness gates', () => {
  it('exists and is a bash script', () => {
    const src = readScript();
    assert.match(src, /^#!\/usr\/bin\/env bash|^#!\/bin\/bash/m);
  });

  it('must not target Vite-only surfaces', () => {
    const src = readScript();
    assert.doesNotMatch(src, /cat > index\.html/);
    assert.doesNotMatch(src, /cat > src\/index\.css/);
    assert.doesNotMatch(src, /cat > src\/App\.tsx/);
    assert.doesNotMatch(src, /from ['"]@\/components\/ThemeProvider['"]/);
    assert.doesNotMatch(src, /useTheme\s*\(/);
  });

  it('must write Next theme bridge to app/globals.css', () => {
    const src = readScript();
    assert.match(src, /cat > app\/globals\.css/);
    assert.match(src, /\[data-theme=["']light["']\]/);
  });

  it('must verify Next admin wiring instead of App.tsx', () => {
    const src = readScript();
    assert.match(src, /AdminStudioClient/);
    assert.doesNotMatch(src, /verifying App\.tsx/);
  });

  it('must cd to tenant root (parent of templates/) before writing files', () => {
    const src = readScript();
    assert.match(src, /cd "\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\." && pwd\)"/);
  });

  it('must wipe tenant content surfaces without DNA denylist', () => {
    const src = readScript();
    assert.match(src, /Wiping tenant content surfaces/);
    assert.match(src, /find src\/components -mindepth 1 -maxdepth 1 ! -name 'ui' ! -name 'admin'/);
    assert.match(src, /rm -rf \\\s*\n\s*src\/collections/m);
    assert.match(src, /rm -rf \\\s*\n[\s\S]*?src\/data\/pages/m);
    assert.match(src, /cat > src\/lib\/VisitorSection\.tsx/);
    assert.doesNotMatch(src, /from '@\/components\/books-list'/);
    assert.doesNotMatch(src, /src\/components\/books-list/);
  });

  it('must install react-markdown deps used by post-detail', () => {
    const src = readScript();
    assert.match(src, /npm install[^\n]*react-markdown/);
    assert.match(src, /from 'react-markdown'/);
    assert.match(src, /from 'remark-gfm'/);
    assert.match(src, /from 'rehype-sanitize'/);
  });

  it('must not generate empty-tenant registry wiring', () => {
    const src = readScript();
    assert.doesNotMatch(src, /@\/components\/empty-tenant/);
    assert.doesNotMatch(src, /['"]empty-tenant['"]/);
  });

  it('must force shadcn radix base non-interactively', () => {
    const src = readScript();
    assert.match(src, /shadcn@latest init[^\n]*--base radix/);
    assert.match(src, /shadcn@latest init[^\n]*--defaults/);
  });
});

END_OF_FILE_CONTENT
echo "Creating scripts/generate-inkwell-next.test.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/generate-inkwell-next.test.mjs"
/**
 * Static gates for generate_inkwell_next.sh (TDD for the Next Inkwell generator).
 * Run: node --test scripts/generate-inkwell-next.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCRIPT = path.resolve(__dirname, '../templates/generate_inkwell_next.sh');

function readScript() {
  assert.ok(fs.existsSync(SCRIPT), `missing ${SCRIPT}`);
  return fs.readFileSync(SCRIPT, 'utf8');
}

describe('generate_inkwell_next.sh harness gates', () => {
  it('exists and is a bash script', () => {
    const src = readScript();
    assert.match(src, /^#!\/usr\/bin\/env bash|^#!\/bin\/bash/m);
  });

  it('must not target Vite-only surfaces', () => {
    const src = readScript();
    assert.doesNotMatch(src, /cat > index\.html/);
    assert.doesNotMatch(src, /cat > src\/index\.css/);
    assert.doesNotMatch(src, /cat > src\/App\.tsx/);
    assert.doesNotMatch(src, /from ['"]@\/components\/ThemeProvider['"]/);
    assert.doesNotMatch(src, /useTheme\s*\(/);
  });

  it('must write Next theme bridge to app/globals.css', () => {
    const src = readScript();
    assert.match(src, /cat > app\/globals\.css/);
    assert.match(src, /\[data-theme=["']light["']\]/);
  });

  it('must verify Next admin wiring instead of App.tsx', () => {
    const src = readScript();
    assert.match(src, /AdminStudioClient/);
    assert.doesNotMatch(src, /verifying App\.tsx/);
  });

  it('must cd to tenant root (parent of templates/) before writing files', () => {
    const src = readScript();
    assert.match(src, /cd "\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\." && pwd\)"/);
  });

  it('must wipe tenant content surfaces without DNA denylist', () => {
    const src = readScript();
    assert.match(src, /Wiping tenant content surfaces/);
    assert.match(src, /find src\/components -mindepth 1 -maxdepth 1 ! -name 'ui' ! -name 'admin'/);
    assert.match(src, /rm -rf \\\s*\n\s*src\/collections/m);
    assert.match(src, /rm -rf \\\s*\n[\s\S]*?src\/data\/pages/m);
    assert.match(src, /cat > src\/lib\/VisitorSection\.tsx/);
    assert.match(src, /EmptyTenantView empty-branch/);
    assert.doesNotMatch(src, /from '@\/components\/books-list'/);
    assert.doesNotMatch(src, /src\/components\/books-list/);
  });
});

END_OF_FILE_CONTENT
echo "Creating scripts/generate-llms-txt.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/generate-llms-txt.mjs"
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { webmcp } from '@olonjs/core';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const { buildLlmsTxt } = webmcp;

const pagesDir = path.join(rootDir, 'src', 'data', 'pages');
const siteConfig = JSON.parse(fs.readFileSync(path.join(rootDir, 'src', 'data', 'config', 'site.json'), 'utf-8'));

function listJsonFilesRecursive(dir) {
  const items = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const item of items) {
    const fullPath = path.join(dir, item.name);
    if (item.isDirectory()) {
      files.push(...listJsonFilesRecursive(fullPath));
      continue;
    }
    if (item.isFile() && item.name.toLowerCase().endsWith('.json')) files.push(fullPath);
  }
  return files;
}

const pages = {};
for (const fullPath of listJsonFilesRecursive(pagesDir)) {
  const slug = path.relative(pagesDir, fullPath).replace(/\\/g, '/').replace(/\.json$/i, '');
  pages[slug] = JSON.parse(fs.readFileSync(fullPath, 'utf-8'));
}

const llmsTxt = buildLlmsTxt({ pages, schemas: {}, siteConfig });

const outPath = path.join(rootDir, 'public', 'llms.txt');
fs.writeFileSync(outPath, llmsTxt, 'utf-8');
console.log('[generate-llms-txt] Written -> public/llms.txt');

END_OF_FILE_CONTENT
echo "Creating scripts/prebuild-bake.test.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/prebuild-bake.test.mjs"
/**
 * Gates for bake.mjs (Task 4 — plan 001). Agentic artifacts only; no Vite SSG.
 * Run: node --test scripts/prebuild-bake.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const SCRIPT = path.join(__dirname, 'bake.mjs');

describe('next bake.mjs (agentic artifacts)', () => {
  it('exists and does not import vite / write HTML SSG', () => {
    assert.ok(fs.existsSync(SCRIPT), `missing ${SCRIPT}`);
    const src = fs.readFileSync(SCRIPT, 'utf8');
    assert.doesNotMatch(src, /from ['"]vite['"]/);
    assert.doesNotMatch(src, /vite\.build|entry-ssg/);
    // May spawn tsx helper — check companion if present
    const impl = path.join(__dirname, 'bake.ts');
    if (fs.existsSync(impl)) {
      const implSrc = fs.readFileSync(impl, 'utf8');
      assert.doesNotMatch(implSrc, /from ['"]vite['"]/);
      assert.doesNotMatch(implSrc, /entry-ssg/);
    }
  });

  it('writes reachable public agentic artifacts', () => {
    const result = spawnSync(process.execPath, [SCRIPT], {
      cwd: ROOT,
      encoding: 'utf8',
      env: { ...process.env },
    });
    assert.equal(result.status, 0, result.stderr || result.stdout);

    assert.ok(fs.existsSync(path.join(ROOT, 'public', 'mcp-manifest.json')));
    assert.ok(fs.existsSync(path.join(ROOT, 'public', 'llms.txt')));
    assert.ok(fs.existsSync(path.join(ROOT, 'public', 'schemas', 'home.schema.json')));
    assert.ok(fs.existsSync(path.join(ROOT, 'public', 'mcp-manifests', 'home.json')));
    assert.ok(fs.existsSync(path.join(ROOT, 'public', 'config', 'site.json')));

    const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, 'public', 'mcp-manifest.json'), 'utf8'));
    assert.equal(manifest.kind, 'olonjs-mcp-manifest-index');
    assert.ok(Array.isArray(manifest.pages));
  });
});

END_OF_FILE_CONTENT
echo "Creating scripts/prebuild-generate-llms-txt.test.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/prebuild-generate-llms-txt.test.mjs"
/**
 * Gates for generate-llms-txt.mjs (Task 2 — plan 001).
 * Run: node --test scripts/prebuild-generate-llms-txt.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const SCRIPT = path.join(__dirname, 'generate-llms-txt.mjs');

describe('next prebuild generate-llms-txt', () => {
  it('script exists and uses @olonjs/core webmcp', () => {
    assert.ok(fs.existsSync(SCRIPT), `missing ${SCRIPT}`);
    const src = fs.readFileSync(SCRIPT, 'utf8');
    assert.match(src, /@olonjs\/core/);
    assert.match(src, /buildLlmsTxt|webmcp/);
    assert.match(src, /public\/llms\.txt|llms\.txt/);
  });

  it('writes public/llms.txt when run', () => {
    const out = path.join(ROOT, 'public', 'llms.txt');
    if (fs.existsSync(out)) fs.unlinkSync(out);

    const result = spawnSync(process.execPath, [SCRIPT], { cwd: ROOT, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.ok(fs.existsSync(out));
    const body = fs.readFileSync(out, 'utf8');
    assert.ok(body.trim().length > 0);
  });
});

END_OF_FILE_CONTENT
echo "Creating scripts/prebuild-robots-sitemap.test.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/prebuild-robots-sitemap.test.mjs"
/**
 * Static + smoke gates for robots.mjs / sitemap.mjs (Task 1 — plan 001).
 * Run: node --test scripts/prebuild-robots-sitemap.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const ROBOTS = path.join(__dirname, 'robots.mjs');
const SITEMAP = path.join(__dirname, 'sitemap.mjs');

describe('next prebuild robots + sitemap', () => {
  it('scripts exist', () => {
    assert.ok(fs.existsSync(ROBOTS), `missing ${ROBOTS}`);
    assert.ok(fs.existsSync(SITEMAP), `missing ${SITEMAP}`);
  });

  it('defaults to Next localhost:3000 (not Vite 5173)', () => {
    const robots = fs.readFileSync(ROBOTS, 'utf8');
    const sitemap = fs.readFileSync(SITEMAP, 'utf8');
    assert.match(robots, /localhost:3000/);
    assert.match(sitemap, /localhost:3000/);
    assert.doesNotMatch(robots, /localhost:5173/);
    assert.doesNotMatch(sitemap, /localhost:5173/);
  });

  it('writes public/robots.txt and public/sitemap.xml when run', () => {
    const robotsOut = path.join(ROOT, 'public', 'robots.txt');
    const sitemapOut = path.join(ROOT, 'public', 'sitemap.xml');
    for (const p of [robotsOut, sitemapOut]) {
      if (fs.existsSync(p)) fs.unlinkSync(p);
    }

    const r1 = spawnSync(process.execPath, [ROBOTS], { cwd: ROOT, encoding: 'utf8' });
    assert.equal(r1.status, 0, r1.stderr || r1.stdout);
    const r2 = spawnSync(process.execPath, [SITEMAP], { cwd: ROOT, encoding: 'utf8' });
    assert.equal(r2.status, 0, r2.stderr || r2.stdout);

    assert.ok(fs.existsSync(robotsOut));
    assert.ok(fs.existsSync(sitemapOut));
    const robotsTxt = fs.readFileSync(robotsOut, 'utf8');
    const sitemapXml = fs.readFileSync(sitemapOut, 'utf8');
    assert.match(robotsTxt, /Sitemap: http:\/\/localhost:3000\/sitemap\.xml/);
    assert.match(sitemapXml, /<urlset/);
    assert.match(sitemapXml, /\/home\.json|PAGE: HOME|loc>http:\/\/localhost:3000\/</);
  });
});

END_OF_FILE_CONTENT
echo "Creating scripts/prebuild-webmcp-feature-check.test.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/prebuild-webmcp-feature-check.test.mjs"
/**
 * Gates for webmcp-feature-check.mjs (Task 3 — plan 001).
 * Run: node --test scripts/prebuild-webmcp-feature-check.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const SCRIPT = path.join(__dirname, 'webmcp-feature-check.mjs');
const PKG = path.join(ROOT, 'package.json');

describe('next verify:webmcp script', () => {
  it('exists and uses document.modelContextTesting only', () => {
    assert.ok(fs.existsSync(SCRIPT), `missing ${SCRIPT}`);
    const src = fs.readFileSync(SCRIPT, 'utf8');
    assert.match(src, /document\.modelContextTesting/);
    assert.doesNotMatch(src, /navigator\.modelContextTesting/);
    assert.doesNotMatch(src, /navigator\.modelContext(?!Testing)/);
  });

  it('is wired as verify:webmcp and not in prebuild', () => {
    const pkg = JSON.parse(fs.readFileSync(PKG, 'utf8'));
    assert.equal(pkg.scripts?.['verify:webmcp'], 'node scripts/webmcp-feature-check.mjs');
    assert.ok(pkg.scripts?.prebuild);
    assert.doesNotMatch(pkg.scripts.prebuild, /webmcp-feature-check/);
  });
});

END_OF_FILE_CONTENT
echo "Creating scripts/prebuild-wire.test.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/prebuild-wire.test.mjs"
/**
 * Gates for package.json prebuild wiring (Task 5 — plan 001).
 * Run: node --test scripts/prebuild-wire.test.mjs
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PKG = path.resolve(__dirname, '../package.json');

describe('next prebuild wiring', () => {
  it('runs sync → llms → bake → sitemap → robots (alpha order)', () => {
    const pkg = JSON.parse(fs.readFileSync(PKG, 'utf8'));
    const prebuild = pkg.scripts?.prebuild ?? '';
    assert.match(prebuild, /sync-pages-to-public\.mjs/);
    assert.match(prebuild, /generate-llms-txt\.mjs/);
    assert.match(prebuild, /bake\.mjs/);
    assert.match(prebuild, /sitemap\.mjs/);
    assert.match(prebuild, /robots\.mjs/);
    assert.doesNotMatch(prebuild, /webmcp-feature-check/);

    const order = ['sync-pages-to-public', 'generate-llms-txt', 'bake', 'sitemap', 'robots'].map((name) =>
      prebuild.indexOf(name),
    );
    for (let i = 1; i < order.length; i += 1) {
      assert.ok(order[i] > order[i - 1], `expected ${i} after previous in: ${prebuild}`);
    }
  });

  it('dist DNA includes scripts/', () => {
    const pkg = JSON.parse(fs.readFileSync(PKG, 'utf8'));
    assert.match(pkg.scripts?.dist ?? '', /\bscripts\b/);
  });
});

END_OF_FILE_CONTENT
echo "Creating scripts/robots.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/robots.mjs"
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');

const baseUrl = process.env.VERCEL_PROJECT_PRODUCTION_URL
  ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
  : 'http://localhost:3000';

const robotsTxt = `User-agent: *
Allow: /
Disallow: /api/

User-agent: GPTBot
User-agent: ChatGPT-User
User-agent: ClaudeBot
User-agent: Claude-Web
User-agent: PerplexityBot
User-agent: OAI-SearchBot
Allow: /
Allow: /*.json
Allow: /schemas/
Allow: /llms.txt
Allow: /mcp-manifest.json
Disallow: /api/

Sitemap: ${baseUrl}/sitemap.xml
`;

const outPath = path.join(rootDir, 'public', 'robots.txt');
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, robotsTxt, 'utf-8');
console.log('[robots] Written -> public/robots.txt');

END_OF_FILE_CONTENT
echo "Creating scripts/sitemap.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/sitemap.mjs"
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');

const baseUrl = process.env.VERCEL_PROJECT_PRODUCTION_URL
  ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
  : 'http://localhost:3000';

function listJsonFilesRecursive(dir) {
  const items = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const item of items) {
    const fullPath = path.join(dir, item.name);
    if (item.isDirectory()) {
      files.push(...listJsonFilesRecursive(fullPath));
      continue;
    }
    if (item.isFile() && item.name.toLowerCase().endsWith('.json')) files.push(fullPath);
  }
  return files;
}

function toW3CDate(date) {
  return date.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

function urlEntry({ loc, lastmod, changefreq, priority, comment }) {
  const lines = [];
  if (comment) lines.push(`  <!-- ${comment} -->`);
  lines.push(`  <url>`);
  lines.push(`    <loc>${loc}</loc>`);
  lines.push(`    <lastmod>${lastmod}</lastmod>`);
  lines.push(`    <changefreq>${changefreq}</changefreq>`);
  lines.push(`    <priority>${priority}</priority>`);
  lines.push(`  </url>`);
  return lines.join('\n');
}

function sectionComment(label) {
  const bar = '='.repeat(42);
  return [
    `  <!-- ${bar} -->`,
    `  <!-- ${label.padEnd(42)} -->`,
    `  <!-- ${bar} -->`,
  ].join('\n');
}

const pagesDir = path.join(rootDir, 'src', 'data', 'pages');
const buildTime = toW3CDate(new Date());

const pageFiles = listJsonFilesRecursive(pagesDir);
const pages = pageFiles.map((fullPath) => {
  const slug = path
    .relative(pagesDir, fullPath)
    .replace(/\\/g, '/')
    .replace(/\.json$/i, '');
  const lastmod = toW3CDate(fs.statSync(fullPath).mtime);
  return { slug, lastmod };
});

const entries = [];

entries.push(sectionComment('GLOBAL AGENT DISCOVERY NODES'));
entries.push(
  urlEntry({ loc: `${baseUrl}/llms.txt`, lastmod: buildTime, changefreq: 'weekly', priority: '1.0' }),
);
entries.push(
  urlEntry({ loc: `${baseUrl}/mcp-manifest.json`, lastmod: buildTime, changefreq: 'weekly', priority: '1.0' }),
);

for (const { slug, lastmod } of pages) {
  const humanPath = slug === 'home' ? '/' : `/${slug}`;
  const label = `PAGE: ${slug.toUpperCase()}`;

  entries.push(sectionComment(label));
  entries.push(
    urlEntry({ loc: `${baseUrl}${humanPath}`, lastmod, changefreq: 'daily', priority: '0.9', comment: 'Human UI' }),
  );
  entries.push(
    urlEntry({ loc: `${baseUrl}/${slug}.json`, lastmod, changefreq: 'daily', priority: '0.9', comment: 'Machine Payload' }),
  );
  entries.push(
    urlEntry({
      loc: `${baseUrl}/schemas/${slug}.schema.json`,
      lastmod: buildTime,
      changefreq: 'weekly',
      priority: '0.8',
      comment: 'Machine Contract (Schema)',
    }),
  );
}

const xml = [
  `<?xml version="1.0" encoding="UTF-8"?>`,
  `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">`,
  ``,
  entries.join('\n'),
  ``,
  `</urlset>`,
].join('\n');

const outPath = path.join(rootDir, 'public', 'sitemap.xml');
fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, xml, 'utf-8');
console.log('[sitemap] Written -> public/sitemap.xml');

END_OF_FILE_CONTENT
echo "Creating scripts/sync-pages-to-public.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/sync-pages-to-public.mjs"
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

/**
 * Mirror Vite/alpha Save2Repo publish surface:
 * src/data/pages → public/pages
 * src/data/collections → public/collections
 * src/data/config/site.json → public/config/site.json
 *
 * Required so static boot can HTTP-fetch same-origin published JSON without
 * hitting the /*.json → /api/public-page rewrite loop (afterFiles only skips
 * when a real file exists under public/).
 */
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const sourceDir = path.join(rootDir, 'src', 'data', 'pages');
const targetDir = path.join(rootDir, 'public', 'pages');
const sourceCollectionsDir = path.join(rootDir, 'src', 'data', 'collections');
const targetCollectionsDir = path.join(rootDir, 'public', 'collections');
const sourceSiteConfigPath = path.join(rootDir, 'src', 'data', 'config', 'site.json');
const targetConfigDir = path.join(rootDir, 'public', 'config');
const targetSiteConfigPath = path.join(targetConfigDir, 'site.json');

if (!fs.existsSync(sourceDir)) {
  console.warn('[sync-pages-to-public] Source directory not found:', sourceDir);
  process.exit(0);
}

fs.rmSync(targetDir, { recursive: true, force: true });
fs.mkdirSync(targetDir, { recursive: true });
fs.cpSync(sourceDir, targetDir, { recursive: true });

fs.rmSync(targetCollectionsDir, { recursive: true, force: true });
if (fs.existsSync(sourceCollectionsDir)) {
  fs.mkdirSync(targetCollectionsDir, { recursive: true });
  fs.cpSync(sourceCollectionsDir, targetCollectionsDir, { recursive: true });
}

if (fs.existsSync(sourceSiteConfigPath)) {
  fs.mkdirSync(targetConfigDir, { recursive: true });
  fs.cpSync(sourceSiteConfigPath, targetSiteConfigPath);
}

console.log('[sync-pages-to-public] Synced pages, collections, and site config to public/');

END_OF_FILE_CONTENT
echo "Creating scripts/webmcp-feature-check.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/webmcp-feature-check.mjs"
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const baseUrl = process.env.WEBMCP_BASE_URL ?? 'http://127.0.0.1:3000';

function pageFilePathFromSlug(slug) {
  return path.resolve(rootDir, 'src', 'data', 'pages', `${slug}.json`);
}

function adminUrlFromSlug(slug) {
  return `${baseUrl}/admin${slug === 'home' ? '' : `/${slug}`}`;
}

function isStringSchema(schema) {
  if (!schema || typeof schema !== 'object') return false;
  if (schema.type === 'string') return true;
  if (Array.isArray(schema.anyOf)) {
    return schema.anyOf.some((entry) => entry && typeof entry === 'object' && entry.type === 'string');
  }
  return false;
}

function findTopLevelStringField(sectionSchema) {
  const properties = sectionSchema?.properties;
  if (!properties || typeof properties !== 'object') return null;
  const preferred = ['title', 'sectionTitle', 'label', 'headline', 'name'];
  for (const key of preferred) {
    if (isStringSchema(properties[key])) return key;
  }
  for (const [key, value] of Object.entries(properties)) {
    if (isStringSchema(value)) return key;
  }
  return null;
}

async function loadPlaywright() {
  const require = createRequire(import.meta.url);
  try {
    return require('playwright');
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(
      `Playwright is required for WebMCP verification. Install it before running this script. Original error: ${message}`
    );
  }
}

async function readPageJson(slug) {
  const pageFilePath = pageFilePathFromSlug(slug);
  const raw = await fs.readFile(pageFilePath, 'utf8');
  return { raw, json: JSON.parse(raw), pageFilePath };
}

async function waitFor(predicate, timeoutMs, label) {
  const startedAt = Date.now();
  for (;;) {
    const result = await predicate();
    if (result) return result;
    if (Date.now() - startedAt > timeoutMs) {
      throw new Error(`Timed out while waiting for ${label}.`);
    }
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
}

async function waitForFileFieldValue(slug, sectionId, fieldKey, expectedValue) {
  await waitFor(async () => {
    const { json } = await readPageJson(slug);
    const section = Array.isArray(json.sections)
      ? json.sections.find((item) => item?.id === sectionId)
      : null;
    return section?.data?.[fieldKey] === expectedValue;
  }, 8_000, `file field "${fieldKey}" = "${expectedValue}"`);
}

async function ensureResponseOk(response, label) {
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`${label} failed with ${response.status}: ${text}`);
  }
  return response;
}

async function fetchJson(relativePath, label) {
  const response = await ensureResponseOk(await fetch(`${baseUrl}${relativePath}`), label);
  return response.json();
}

async function selectTarget() {
  const siteIndex = await fetchJson('/mcp-manifest.json', 'Manifest index request');
  const requestedSlug = typeof process.env.WEBMCP_TARGET_SLUG === 'string' && process.env.WEBMCP_TARGET_SLUG.trim()
    ? process.env.WEBMCP_TARGET_SLUG.trim()
    : null;

  const candidatePages = requestedSlug
    ? (siteIndex.pages ?? []).filter((page) => page?.slug === requestedSlug)
    : (siteIndex.pages ?? []);

  for (const pageEntry of candidatePages) {
    if (!pageEntry?.slug || !pageEntry?.manifestHref || !pageEntry?.contractHref) continue;
    const pageManifest = await fetchJson(pageEntry.manifestHref, `Page manifest request for ${pageEntry.slug}`);
    const pageContract = await fetchJson(pageEntry.contractHref, `Page contract request for ${pageEntry.slug}`);
    const localInstances = Array.isArray(pageContract.sectionInstances)
      ? pageContract.sectionInstances.filter((section) => section?.scope === 'local')
      : [];
    const tools = Array.isArray(pageManifest.tools) ? pageManifest.tools : [];

    for (const tool of tools) {
      const sectionType = tool?.sectionType;
      if (typeof tool?.name !== 'string' || typeof sectionType !== 'string') continue;
      const targetInstance = localInstances.find((section) => section?.type === sectionType);
      if (!targetInstance?.id) continue;
      const targetFieldKey = findTopLevelStringField(pageContract.sectionSchemas?.[sectionType]);
      if (!targetFieldKey) continue;
      const pageState = await readPageJson(pageEntry.slug);
      const section = Array.isArray(pageState.json.sections)
        ? pageState.json.sections.find((item) => item?.id === targetInstance.id)
        : null;
      const originalValue = section?.data?.[targetFieldKey];
      if (typeof originalValue !== 'string') continue;

      return {
        slug: pageEntry.slug,
        manifestHref: pageEntry.manifestHref,
        contractHref: pageEntry.contractHref,
        toolName: tool.name,
        sectionId: targetInstance.id,
        fieldKey: targetFieldKey,
        originalValue,
        originalState: pageState,
      };
    }
  }

  throw new Error(
    requestedSlug
      ? `No valid WebMCP verification target found for page "${requestedSlug}".`
      : 'No valid WebMCP verification target found in manifest index.'
  );
}

async function main() {
  const { chromium } = await loadPlaywright();
  const target = await selectTarget();
  const nextValue = `${target.originalValue} WebMCP ${Date.now()}`;
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  const consoleEvents = [];
  let mutationApplied = false;

  page.on('console', (message) => {
    if (message.type() === 'error' || message.type() === 'warning') {
      consoleEvents.push(`[console:${message.type()}] ${message.text()}`);
    }
  });
  page.on('pageerror', (error) => {
    consoleEvents.push(`[pageerror] ${error.message}`);
  });

  const restoreOriginal = async () => {
    try {
      await page.evaluate(
        async ({ toolName, slug, sectionId, fieldKey, value }) => {
          const runtime = document.modelContextTesting;
          if (!runtime?.executeTool) return;
          await runtime.executeTool(
            toolName,
            JSON.stringify({
              slug,
              sectionId,
              fieldKey,
              value,
            })
          );
        },
        {
          toolName: target.toolName,
          slug: target.slug,
          sectionId: target.sectionId,
          fieldKey: target.fieldKey,
          value: target.originalValue,
        }
      );
      await waitForFileFieldValue(target.slug, target.sectionId, target.fieldKey, target.originalValue);
    } catch {
      await fs.writeFile(target.originalState.pageFilePath, target.originalState.raw, 'utf8');
    }
  };

  try {
    const pageManifest = await fetchJson(target.manifestHref, `Manifest request for ${target.slug}`);
    if (!Array.isArray(pageManifest.tools) || !pageManifest.tools.some((tool) => tool?.name === target.toolName)) {
      throw new Error(`Manifest does not expose ${target.toolName}.`);
    }

    const pageContract = await fetchJson(target.contractHref, `Page contract request for ${target.slug}`);
    if (!Array.isArray(pageContract.tools) || !pageContract.tools.some((tool) => tool?.name === target.toolName)) {
      throw new Error(`Page contract does not expose ${target.toolName}.`);
    }

    await page.goto(adminUrlFromSlug(target.slug), { waitUntil: 'networkidle' });

    try {
      await page.waitForFunction(
        ({ manifestHref, contractHref }) => {
          const manifestLink = document.head.querySelector('link[rel="mcp-manifest"]');
          const contractLink = document.head.querySelector('link[rel="olon-contract"]');
          return manifestLink?.getAttribute('href') === manifestHref
            && contractLink?.getAttribute('href') === contractHref;
        },
        { manifestHref: target.manifestHref, contractHref: target.contractHref },
        { timeout: 10_000 }
      );
    } catch (error) {
      const diagnostics = await page.evaluate(() => ({
        head: document.head.innerHTML,
        bodyText: document.body.innerText,
      }));
      throw new Error(
        [
          error instanceof Error ? error.message : String(error),
          `head=${diagnostics.head}`,
          `body=${diagnostics.bodyText}`,
          ...consoleEvents,
        ].join('\n')
      );
    }

    const toolNames = await page.evaluate(() => {
      const runtime = document.modelContextTesting;
      return runtime?.listTools?.().map((tool) => tool.name) ?? [];
    });
    if (!toolNames.includes(target.toolName)) {
      throw new Error(`Runtime did not register ${target.toolName}. Found: ${toolNames.join(', ')}`);
    }

    const rawResult = await page.evaluate(
      async ({ toolName, slug, sectionId, fieldKey, value }) => {
        const runtime = document.modelContextTesting;
        if (!runtime?.executeTool) {
          throw new Error('document.modelContextTesting.executeTool is unavailable.');
        }
        return runtime.executeTool(
          toolName,
          JSON.stringify({
            slug,
            sectionId,
            fieldKey,
            value,
          })
        );
      },
      {
        toolName: target.toolName,
        slug: target.slug,
        sectionId: target.sectionId,
        fieldKey: target.fieldKey,
        value: nextValue,
      }
    );

    const parsedResult = JSON.parse(rawResult);
    if (parsedResult?.isError) {
      throw new Error(`WebMCP tool returned an error: ${rawResult}`);
    }

    mutationApplied = true;
    await waitForFileFieldValue(target.slug, target.sectionId, target.fieldKey, nextValue);
    await page.frameLocator('iframe').getByText(nextValue, { exact: true }).waitFor({ state: 'attached' });

    console.log(
      JSON.stringify({
        ok: true,
        slug: target.slug,
        manifestHref: target.manifestHref,
        contractHref: target.contractHref,
        toolName: target.toolName,
        sectionId: target.sectionId,
        fieldKey: target.fieldKey,
        toolNames,
      })
    );
  } finally {
    if (mutationApplied) {
      await restoreOriginal();
    }
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exit(1);
});

END_OF_FILE_CONTENT
mkdir -p "src"
# SKIP: src/App.tsx is binary and cannot be embedded as text.
mkdir -p "src/collections"
mkdir -p "src/collections/autori"
echo "Creating src/collections/autori/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/autori/index.ts"
export { AutoreSchema, AutoriCollectionSchema } from './schema';
export type { Autore, AutoriCollection } from './types';

END_OF_FILE_CONTENT
echo "Creating src/collections/autori/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/autori/schema.ts"
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const AutoreSchema = BaseCollectionItem.extend({
  name: z.string().describe('ui:text'),
});

export const AutoriCollectionSchema = z.record(z.string(), AutoreSchema);

END_OF_FILE_CONTENT
echo "Creating src/collections/autori/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/autori/types.ts"
import { z } from 'zod';
import { AutoreSchema, AutoriCollectionSchema } from './schema';

export type Autore = z.infer<typeof AutoreSchema>;
export type AutoriCollection = z.infer<typeof AutoriCollectionSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/collections/libri"
echo "Creating src/collections/libri/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/libri/index.ts"
export { LibroSchema, LibriCollectionSchema } from './schema';
export type { Libro, LibriCollection } from './types';

END_OF_FILE_CONTENT
echo "Creating src/collections/libri/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/libri/schema.ts"
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';
import { AutoreSchema } from '@/collections/autori';

const CollectionRefSchema = z.object({
  $ref: z.string(),
});

export const LibroSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  author: z.union([AutoreSchema, CollectionRefSchema]).describe('ui:collection-ref:autori'),
  year: z.number().describe('ui:number'),
  genre: z.string().describe('ui:text'),
  summary: z.string().describe('ui:textarea'),
});

export const LibriCollectionSchema = z.record(z.string(), LibroSchema);

END_OF_FILE_CONTENT
echo "Creating src/collections/libri/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/collections/libri/types.ts"
import { z } from 'zod';
import { LibroSchema, LibriCollectionSchema } from './schema';

export type Libro = z.infer<typeof LibroSchema>;
export type LibriCollection = z.infer<typeof LibriCollectionSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components"
mkdir -p "src/components/admin"
echo "Creating src/components/admin/AdminStudioClient.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/admin/AdminStudioClient.tsx"
'use client';

import { useCallback, useMemo, useState, type ReactNode } from 'react';
import type {
  JsonPagesConfig,
  MenuConfig,
  PageConfig,
  ProjectState,
  SiteConfig,
  ThemeConfig,
} from '@olonjs/core';
import { AdminIsland } from '@olonjs/next/client';
import { addSectionConfig } from '@/lib/addSectionConfig';
import { hydrateLocalProjectState } from '@/lib/admin/hydrateLocalProjectState';
import { CollectionRegistry } from '@/lib/CollectionRegistry';
import { ComponentRegistry } from '@/lib/ComponentRegistry';
import { iconMap } from '@/lib/IconResolver';
import { SECTION_SCHEMAS } from '@/lib/schemas';

export type AdminStudioClientProps = {
  tenantId?: string;
  initialPages: Record<string, PageConfig>;
  initialSiteConfig: SiteConfig;
  initialMenuConfig: MenuConfig;
  initialThemeConfig: ThemeConfig;
  initialCollections: NonNullable<JsonPagesConfig['collections']>;
  /** When false (Save2Repo cloud), hide local disk save. Default true for T9. */
  showLocalSave?: boolean;
  /** Save2Repo cold save — wired in Task 10. */
  showColdSave?: boolean;
  coldSave?: (state: ProjectState, slug: string) => Promise<void>;
  /** Optional drawer / overlays (cold-save UI). */
  children?: ReactNode;
};

/**
 * Tenant-wired admin island: protocol registries + local persistence.
 * HotSave is intentionally omitted (out of scope for Next v1).
 */
export function AdminStudioClient({
  tenantId = 'next',
  initialPages,
  initialSiteConfig,
  initialMenuConfig,
  initialThemeConfig,
  initialCollections,
  showLocalSave = true,
  showColdSave = false,
  coldSave,
  children,
}: AdminStudioClientProps) {
  const [pages, setPages] = useState(initialPages);
  const [siteConfig, setSiteConfig] = useState(initialSiteConfig);
  const [menuConfig, setMenuConfig] = useState(initialMenuConfig);
  const [themeConfig, setThemeConfig] = useState(initialThemeConfig);
  const [collections, setCollections] = useState(initialCollections);

  const saveToFile = useCallback(
    async (state: ProjectState, slug: string): Promise<void> => {
      const res = await fetch('/api/save-to-file', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ projectState: state, slug }),
      });
      const body = (await res.json().catch(() => ({}))) as { error?: string };
      if (!res.ok) throw new Error(body.error ?? `Save to file failed: ${res.status}`);
      hydrateLocalProjectState({
        state,
        slug,
        setPages,
        setSiteConfig,
        setMenuConfig,
        setThemeConfig,
        setCollections,
      });
    },
    [],
  );

  const refDocuments = useMemo(
    () => ({
      'menu.json': menuConfig,
      'config/menu.json': menuConfig,
      'src/data/config/menu.json': menuConfig,
    }),
    [menuConfig],
  );

  const config: JsonPagesConfig = useMemo(
    () => ({
      tenantId,
      basePath: '/',
      registry: ComponentRegistry as JsonPagesConfig['registry'],
      schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
      collectionSchemas: CollectionRegistry as unknown as JsonPagesConfig['collectionSchemas'],
      pages,
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      refDocuments,
      // Visitor theme lives in app/globals.css; engine still requires themeCss.
      themeCss: { tenant: '' },
      iconRegistry: iconMap,
      addSection: addSectionConfig,
      persistence: {
        saveToFile,
        ...(coldSave ? { coldSave } : {}),
        showLocalSave,
        showHotSave: false,
        showColdSave,
      },
    }),
    [
      tenantId,
      pages,
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      refDocuments,
      saveToFile,
      coldSave,
      showLocalSave,
      showColdSave,
    ],
  );

  return <AdminIsland config={config}>{children}</AdminIsland>;
}

END_OF_FILE_CONTENT
echo "Creating src/components/admin/AdminStudioDynamic.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/admin/AdminStudioDynamic.tsx"
'use client';

import dynamic from 'next/dynamic';
import type { ComponentProps } from 'react';
import type { AdminStudioWithCloud } from '@/components/admin/AdminStudioWithCloud';

/**
 * BrowserRouter / createBrowserRouter need `document`.
 * Next still SSRs `'use client'` trees once — disable SSR for the Studio island.
 */
export const AdminStudioDynamic = dynamic(
  () =>
    import('@/components/admin/AdminStudioWithCloud').then((m) => ({
      default: m.AdminStudioWithCloud,
    })),
  {
    ssr: false,
    loading: () => (
      <main className="flex min-h-screen items-center justify-center bg-background text-muted-foreground">
        Loading Studio…
      </main>
    ),
  },
);

export type AdminStudioDynamicProps = ComponentProps<typeof AdminStudioWithCloud>;

END_OF_FILE_CONTENT
echo "Creating src/components/admin/AdminStudioWithCloud.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/admin/AdminStudioWithCloud.tsx"
'use client';

import { lazy, Suspense, useCallback } from 'react';
import type {
  JsonPagesConfig,
  MenuConfig,
  PageConfig,
  ProjectState,
  SiteConfig,
  ThemeConfig,
} from '@olonjs/core';
import { AdminStudioClient } from '@/components/admin/AdminStudioClient';
import { useCloudSave } from '@/lib/admin/useCloudSave';
import { getCloudPolicy, TENANT_ID } from '@/lib/env/tenantEnv';

const ColdSaveDrawer = lazy(() =>
  import('@/components/admin/ColdSaveDrawer').then((m) => ({ default: m.ColdSaveDrawer })),
);

export type AdminStudioWithCloudProps = {
  initialPages: Record<string, PageConfig>;
  initialSiteConfig: SiteConfig;
  initialMenuConfig: MenuConfig;
  initialThemeConfig: ThemeConfig;
  initialCollections: NonNullable<JsonPagesConfig['collections']>;
};

/**
 * Admin island + optional Save2Repo cold save (no HotSave).
 * Local save when cloud credentials are absent; cold save when Save2Repo is enabled.
 */
export function AdminStudioWithCloud(props: AdminStudioWithCloudProps) {
  const cloudPolicy = getCloudPolicy();
  const { cloudSaveUi, runCloudSave, closeCloudDrawer, retryCloudSave } = useCloudSave({
    apiUrl: cloudPolicy.apiUrl,
    apiKey: cloudPolicy.apiKey,
  });

  const coldSave = useCallback(
    async (state: ProjectState, slug: string) => {
      await runCloudSave({ state, slug }, true);
    },
    [runCloudSave],
  );

  const mountDrawer =
    cloudPolicy.showColdSave && (cloudSaveUi.isOpen || cloudSaveUi.phase !== 'idle');

  return (
    <AdminStudioClient
      tenantId={TENANT_ID}
      {...props}
      showLocalSave={cloudPolicy.showLocalSave}
      showColdSave={cloudPolicy.showColdSave}
      coldSave={cloudPolicy.showColdSave ? coldSave : undefined}
    >
      {mountDrawer ? (
        <Suspense fallback={null}>
          <ColdSaveDrawer
            isOpen={cloudSaveUi.isOpen}
            phase={cloudSaveUi.phase}
            currentStepId={cloudSaveUi.currentStepId}
            doneSteps={cloudSaveUi.doneSteps}
            progress={cloudSaveUi.progress}
            errorMessage={cloudSaveUi.errorMessage}
            deployUrl={cloudSaveUi.deployUrl}
            onClose={closeCloudDrawer}
            onRetry={retryCloudSave}
          />
        </Suspense>
      ) : null}
    </AdminStudioClient>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/admin/ColdSaveDrawer.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/admin/ColdSaveDrawer.tsx"
'use client';

import { useMemo, type CSSProperties } from 'react';
import { createPortal } from 'react-dom';
import { DEPLOY_STEPS, type StepId } from '@olonjs/core';
import type { CloudSaveUiState } from '@/lib/admin/useCloudSave';

export type ColdSaveDrawerProps = Pick<
  CloudSaveUiState,
  'isOpen' | 'phase' | 'currentStepId' | 'doneSteps' | 'progress' | 'errorMessage' | 'deployUrl'
> & {
  onClose: () => void;
  onRetry: () => void;
};

/**
 * Slim Save2Repo progress drawer for the Next admin island.
 * Lazy-load from the admin client only — never import on visitor routes.
 */
export function ColdSaveDrawer({
  isOpen,
  phase,
  currentStepId,
  doneSteps,
  progress,
  errorMessage,
  deployUrl,
  onClose,
  onRetry,
}: ColdSaveDrawerProps) {
  const currentStep = useMemo(
    () => DEPLOY_STEPS.find((step) => step.id === currentStepId) ?? null,
    [currentStepId],
  );

  if (typeof document === 'undefined' || !isOpen || phase === 'idle') return null;

  const isRunning = phase === 'running';
  const isDone = phase === 'done';
  const isError = phase === 'error';

  return createPortal(
    <div
      role="status"
      aria-live="polite"
      aria-label={isDone ? 'Deploy completed' : isError ? 'Deploy failed' : 'Deploying'}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 2147483600,
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
        padding: '1rem',
        background: 'rgb(0 0 0 / 0.45)',
      }}
      onClick={isDone || isError ? onClose : undefined}
    >
      <div
        style={{
          width: '100%',
          maxWidth: '28rem',
          marginBottom: '1.5rem',
          borderRadius: '0.75rem',
          border: '1px solid rgb(255 255 255 / 0.08)',
          background: 'hsl(222 18% 8%)',
          color: 'hsl(210 20% 96%)',
          padding: '1.25rem',
          boxShadow: '0 20px 50px rgb(0 0 0 / 0.55)',
        }}
        onClick={(event) => event.stopPropagation()}
      >
        <p style={{ margin: 0, fontSize: '0.75rem', letterSpacing: '0.04em', textTransform: 'uppercase', opacity: 0.7 }}>
          {isDone ? 'Live' : isError ? 'Build failed' : currentStep?.verb ?? 'Saving'}
        </p>
        <p style={{ margin: '0.5rem 0 0', fontSize: '1.05rem', fontWeight: 600 }}>
          {isDone
            ? 'Your content is live.'
            : isError
              ? 'Deploy failed.'
              : currentStep
                ? currentStep.poem[0]
                : 'Starting Save2Repo…'}
        </p>
        <p style={{ margin: '0.35rem 0 0', fontSize: '0.85rem', opacity: 0.75 }}>
          {isDone
            ? 'Deployed to production successfully'
            : isError
              ? (errorMessage ?? 'Check your logs or retry below')
              : currentStep
                ? currentStep.poem[1]
                : null}
        </p>

        <ol style={{ listStyle: 'none', margin: '1rem 0 0', padding: 0, display: '0.35rem' }}>
          {DEPLOY_STEPS.map((step) => {
            const done = doneSteps.includes(step.id as StepId);
            const active = isRunning && currentStepId === step.id;
            return (
              <li
                key={step.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem',
                  fontSize: '0.8rem',
                  opacity: done || active ? 1 : 0.45,
                }}
              >
                <span
                  aria-hidden
                  style={{
                    width: '0.55rem',
                    height: '0.55rem',
                    borderRadius: '999px',
                    background: done ? step.color : active ? step.color : 'rgb(255 255 255 / 0.25)',
                    boxShadow: active ? `0 0 8px ${step.color}` : undefined,
                  }}
                />
                {step.verb}
              </li>
            );
          })}
        </ol>

        <div
          style={{
            marginTop: '1rem',
            height: '0.35rem',
            borderRadius: '999px',
            background: 'rgb(255 255 255 / 0.08)',
            overflow: 'hidden',
          }}
        >
          <div
            style={{
              height: '100%',
              width: `${Math.max(0, Math.min(100, progress))}%`,
              background: isError ? 'hsl(0 72% 51%)' : 'linear-gradient(90deg, #60a5fa, #34d399)',
              transition: 'width 0.35s ease',
            }}
          />
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.5rem', marginTop: '1rem' }}>
          {isDone ? (
            <>
              <button type="button" onClick={onClose} style={btnStyle('ghost')}>
                Close
              </button>
              <button
                type="button"
                disabled={!deployUrl}
                onClick={() => {
                  if (deployUrl) window.open(deployUrl, '_blank', 'noopener,noreferrer');
                }}
                style={btnStyle('primary')}
              >
                Open site
              </button>
            </>
          ) : null}
          {isError ? (
            <>
              <button type="button" onClick={onClose} style={btnStyle('ghost')}>
                Cancel
              </button>
              <button type="button" onClick={onRetry} style={btnStyle('danger')}>
                Retry
              </button>
            </>
          ) : null}
          {isRunning ? (
            <span style={{ fontSize: '0.75rem', opacity: 0.6 }}>
              {doneSteps.length + 1} / {DEPLOY_STEPS.length}
            </span>
          ) : null}
        </div>
      </div>
    </div>,
    document.body,
  );
}

function btnStyle(kind: 'ghost' | 'primary' | 'danger'): CSSProperties {
  const base: CSSProperties = {
    borderRadius: '0.5rem',
    border: '1px solid transparent',
    padding: '0.45rem 0.85rem',
    fontSize: '0.85rem',
    cursor: 'pointer',
  };
  if (kind === 'primary') {
    return { ...base, background: '#34d399', color: '#0a0f1a', fontWeight: 600 };
  }
  if (kind === 'danger') {
    return { ...base, background: 'hsl(0 72% 51%)', color: '#fff', fontWeight: 600 };
  }
  return { ...base, background: 'transparent', color: 'inherit', borderColor: 'rgb(255 255 255 / 0.15)' };
}

END_OF_FILE_CONTENT
mkdir -p "src/components/authors-list"
echo "Creating src/components/authors-list/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/authors-list/View.tsx"
import type { Autore } from '@/collections/autori';
import type { AuthorsListData, AuthorsListSettings } from './types';

type AuthorsListViewProps = {
  data: AuthorsListData;
  settings?: AuthorsListSettings;
};

function toAuthors(items: AuthorsListData['items']): Autore[] {
  return Object.values(items ?? {}).sort((a, b) => a.name.localeCompare(b.name));
}

/** RSC-safe authors directory — plain href links, no react-router. */
export function AuthorsListView({ data }: AuthorsListViewProps) {
  const authors = toAuthors(data.items);

  return (
    <main className="min-h-screen bg-background px-6 py-16 text-foreground">
      <section className="mx-auto flex w-full max-w-5xl flex-col gap-10">
        <div className="max-w-2xl">
          {data.eyebrow ? (
            <p
              data-jp-field="eyebrow"
              className="text-sm font-medium uppercase tracking-[0.18em] text-muted-foreground"
            >
              {data.eyebrow}
            </p>
          ) : null}
          <h1
            data-jp-field="title"
            className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl"
          >
            {data.title}
          </h1>
          {data.description ? (
            <p
              data-jp-field="description"
              className="mt-4 text-base leading-7 text-muted-foreground"
            >
              {data.description}
            </p>
          ) : null}
        </div>

        <div data-jp-field="items" className="grid gap-4 sm:grid-cols-2">
          {authors.map((author) => (
            <a
              key={author.id}
              href={`/authors/${encodeURIComponent(author.id)}/libri`}
              data-jp-item-id={author.id}
              data-jp-item-field="items"
              className="block rounded-xl border border-border bg-card p-5 shadow-sm transition-colors hover:bg-muted/40"
            >
              <h2 className="text-xl font-semibold">{author.name}</h2>
              <p className="mt-2 text-sm text-muted-foreground">Vedi libri di {author.name}</p>
            </a>
          ))}
        </div>
      </section>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/authors-list/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/authors-list/index.ts"
export { AuthorsListView } from './View';
export { AuthorsListSchema, AuthorsListSettingsSchema } from './schema';
export type { AuthorsListData, AuthorsListSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/authors-list/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/authors-list/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { AutoreSchema } from '@/collections/autori';

export const AuthorsListSchema = BaseSectionData.extend({
  eyebrow: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), AutoreSchema).describe('ui:collection-ref:autori'),
});

export const AuthorsListSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/authors-list/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/authors-list/types.ts"
import { z } from 'zod';
import { AuthorsListSchema, AuthorsListSettingsSchema } from './schema';

export type AuthorsListData = z.infer<typeof AuthorsListSchema>;
export type AuthorsListSettings = z.infer<typeof AuthorsListSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/book-detail"
echo "Creating src/components/book-detail/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/book-detail/View.tsx"
import type { BookDetailData, BookDetailSettings } from './types';

type BookDetailViewProps = {
  data: BookDetailData;
  settings?: BookDetailSettings;
};

function getAuthorName(author: BookDetailData['item']['author']): string {
  if (typeof author === 'object' && author !== null && 'name' in author) {
    return String(author.name);
  }
  return 'Autore';
}

/** RSC-safe book detail — plain href back link, no react-router. */
export function BookDetailView({ data }: BookDetailViewProps) {
  const book = data.item;

  return (
    <main className="min-h-screen bg-background px-6 py-16 text-foreground">
      <article
        data-jp-field="item"
        data-jp-item-id={book.id}
        data-jp-item-field="item"
        className="mx-auto w-full max-w-3xl rounded-2xl border border-border bg-card p-8 shadow-sm"
      >
        <a href="/libri" className="text-sm font-medium text-muted-foreground hover:text-foreground">
          {data.backLabel}
        </a>
        <p className="mt-10 text-sm font-medium uppercase tracking-[0.18em] text-muted-foreground">
          {book.genre} · {book.year}
        </p>
        <h1 className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl">{book.title}</h1>
        <p className="mt-4 text-lg text-muted-foreground">{getAuthorName(book.author)}</p>
        <p className="mt-8 text-base leading-8 text-muted-foreground">{book.summary}</p>
      </article>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/book-detail/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/book-detail/index.ts"
export { BookDetailView } from './View';
export { BookDetailSchema, BookDetailSettingsSchema } from './schema';
export type { BookDetailData, BookDetailSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/book-detail/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/book-detail/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { LibroSchema } from '@/collections/libri';

export const BookDetailSchema = BaseSectionData.extend({
  item: LibroSchema.describe('ui:collection-ref'),
  backLabel: z.string().default('Torna ai libri').describe('ui:text'),
});

export const BookDetailSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/book-detail/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/book-detail/types.ts"
import { z } from 'zod';
import { BookDetailSchema, BookDetailSettingsSchema } from './schema';

export type BookDetailData = z.infer<typeof BookDetailSchema>;
export type BookDetailSettings = z.infer<typeof BookDetailSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/books-list"
echo "Creating src/components/books-list/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/books-list/View.tsx"
import type { Libro } from '@/collections/libri';
import type { BooksListData, BooksListSettings } from './types';

type BooksListViewProps = {
  data: BooksListData;
  settings?: BooksListSettings;
  /** From Next route params (`/authors/[authorId]/libri`) or `?author=`. */
  authorId?: string | null;
  /** 1-based page from `?page=` searchParams (RSC-safe pagination). */
  page?: number;
  /** Current pathname for pagination hrefs. */
  pathname?: string;
};

function toBooks(items: BooksListData['items']): Libro[] {
  return Object.values(items ?? {}).sort((a, b) => a.title.localeCompare(b.title));
}

function getAuthorName(author: Libro['author']): string {
  if (typeof author === 'object' && author !== null && 'name' in author) {
    return String(author.name);
  }
  return 'Autore';
}

function getAuthorId(author: Libro['author']): string | null {
  if (typeof author === 'object' && author !== null && 'id' in author && typeof author.id === 'string') {
    return author.id;
  }
  if (typeof author === 'object' && author !== null && '$ref' in author && typeof author.$ref === 'string') {
    const pointer = author.$ref.split('#')[1]?.replace(/^\//, '') ?? '';
    return pointer.split('/')[0] || null;
  }
  return null;
}

function pageHref(pathname: string, page: number, authorQuery?: string | null): string {
  const params = new URLSearchParams();
  if (page > 1) params.set('page', String(page));
  if (authorQuery) params.set('author', authorQuery);
  const qs = params.toString();
  return qs ? `${pathname}?${qs}` : pathname;
}

/** RSC-safe books catalog — author filter via props, pagination via href + searchParams. */
export function BooksListView({
  data,
  authorId = null,
  page = 1,
  pathname = '/',
}: BooksListViewProps) {
  const books = toBooks(data.items);
  const filteredBooks = authorId
    ? books.filter((book) => getAuthorId(book.author) === authorId)
    : books;
  const pageSize = Math.max(1, Math.floor(data.pageSize || 10));
  const totalPages = Math.max(1, Math.ceil(filteredBooks.length / pageSize));
  const currentPage = Math.min(Math.max(1, Math.floor(page) || 1), totalPages);
  const startIndex = (currentPage - 1) * pageSize;
  const visibleBooks = filteredBooks.slice(startIndex, startIndex + pageSize);
  const authorInQuery = pathname.includes('/authors/') ? null : authorId;

  return (
    <main className="min-h-screen bg-background px-6 py-16 text-foreground">
      <section className="mx-auto flex w-full max-w-5xl flex-col gap-10">
        <div className="max-w-2xl">
          {data.eyebrow ? (
            <p
              data-jp-field="eyebrow"
              className="text-sm font-medium uppercase tracking-[0.18em] text-muted-foreground"
            >
              {data.eyebrow}
            </p>
          ) : null}
          <h1
            data-jp-field="title"
            className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl"
          >
            {data.title}
          </h1>
          {data.description ? (
            <p
              data-jp-field="description"
              className="mt-4 text-base leading-7 text-muted-foreground"
            >
              {data.description}
            </p>
          ) : null}
        </div>

        <div data-jp-field="items" className="grid gap-4">
          {authorId ? (
            <p className="text-sm text-muted-foreground">
              Filtro autore: {authorId} · {filteredBooks.length} libri
            </p>
          ) : null}
          {visibleBooks.map((book) => (
            <article
              key={book.id}
              data-jp-item-id={book.id}
              data-jp-item-field="items"
              className="rounded-xl border border-border bg-card p-5 shadow-sm"
            >
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h2 className="text-xl font-semibold">{book.title}</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {getAuthorName(book.author)} · {book.year} · {book.genre}
                  </p>
                  <p className="mt-3 max-w-3xl text-sm leading-6 text-muted-foreground">
                    {book.summary}
                  </p>
                </div>
                <a
                  href={`/libri/${encodeURIComponent(book.id)}`}
                  className="inline-flex shrink-0 items-center justify-center rounded-md border border-border px-3 py-2 text-sm font-medium hover:bg-muted"
                >
                  Apri scheda
                </a>
              </div>
            </article>
          ))}
        </div>

        <nav className="flex items-center justify-between border-t border-border pt-6 text-sm">
          {currentPage > 1 ? (
            <a
              href={pageHref(pathname, currentPage - 1, authorInQuery)}
              className="rounded-md border border-border px-3 py-2 font-medium hover:bg-muted"
            >
              Precedente
            </a>
          ) : (
            <span className="rounded-md border border-border px-3 py-2 font-medium opacity-40">
              Precedente
            </span>
          )}
          <span className="text-muted-foreground">
            Pagina {currentPage} di {totalPages} · {filteredBooks.length} libri
          </span>
          {currentPage < totalPages ? (
            <a
              href={pageHref(pathname, currentPage + 1, authorInQuery)}
              className="rounded-md border border-border px-3 py-2 font-medium hover:bg-muted"
            >
              Successiva
            </a>
          ) : (
            <span className="rounded-md border border-border px-3 py-2 font-medium opacity-40">
              Successiva
            </span>
          )}
        </nav>
      </section>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/books-list/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/books-list/index.ts"
export { BooksListView } from './View';
export { BooksListSchema, BooksListSettingsSchema } from './schema';
export type { BooksListData, BooksListSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/books-list/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/books-list/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { LibroSchema } from '@/collections/libri';

export const BooksListSchema = BaseSectionData.extend({
  eyebrow: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), LibroSchema).describe('ui:collection-ref:libri'),
  pageSize: z.number().default(10).describe('ui:number'),
});

export const BooksListSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/books-list/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/books-list/types.ts"
import { z } from 'zod';
import { BooksListSchema, BooksListSettingsSchema } from './schema';

export type BooksListData = z.infer<typeof BooksListSchema>;
export type BooksListSettings = z.infer<typeof BooksListSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/empty-tenant"
echo "Creating src/components/empty-tenant/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/View.tsx"
import type { EmptyTenantData, EmptyTenantSettings } from './types';

type EmptyTenantViewProps = {
  data?: EmptyTenantData;
  settings?: EmptyTenantSettings;
};

/** Server empty-tenant UI when the page registry has no pages. */
export function EmptyTenantView({ data }: EmptyTenantViewProps) {
  const title = data?.title?.trim() || 'Your tenant is empty.';
  const description =
    data?.description?.trim() || 'Create your first page to start building your site.';

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-6 text-foreground">
      <section className="w-full max-w-xl rounded-xl border border-border bg-card p-8 shadow-sm">
        <h1 data-jp-field="title" className="text-2xl font-semibold tracking-tight">
          {title}
        </h1>
        <p data-jp-field="description" className="mt-3 text-sm text-muted-foreground">
          {description}
        </p>
      </section>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/empty-tenant/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/index.ts"
export { EmptyTenantView } from './View';
export { EmptyTenantSchema, EmptyTenantSettingsSchema } from './schema';
export type { EmptyTenantData, EmptyTenantSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/empty-tenant/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

export const EmptyTenantSchema = BaseSectionData.extend({
  title: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
});

export const EmptyTenantSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/empty-tenant/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/types.ts"
import { z } from 'zod';
import { EmptyTenantSchema, EmptyTenantSettingsSchema } from './schema';

export type EmptyTenantData = z.infer<typeof EmptyTenantSchema>;
export type EmptyTenantSettings = z.infer<typeof EmptyTenantSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/footer"
echo "Creating src/components/footer/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/footer/View.tsx"
import type { CSSProperties } from 'react';
import type { FooterData, FooterSettings } from './types';

export function FooterView({
  data,
}: {
  data: FooterData;
  settings?: FooterSettings;
}) {
  return (
    <footer
      style={
        {
          '--local-bg': 'var(--background)',
          '--local-text': 'var(--foreground)',
        } as CSSProperties
      }
      className="bg-[var(--local-bg)] px-6 py-8 text-[var(--local-text)]"
    >
      <p data-jp-field="brandText">{data.brandText}</p>
    </footer>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/footer/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/footer/index.ts"
export { FooterView } from './View';
export { FooterSchema, FooterSettingsSchema } from './schema';
export type { FooterData, FooterSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/footer/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/footer/schema.ts"
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';

export const FooterLinkSchema = BaseArrayItem.extend({
  id: z.string(),
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  external: z.boolean().optional(),
});

export const FooterSchema = BaseSectionData.extend({
  brandText: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  copyright: z.string().describe('ui:text'),
  links: z.array(FooterLinkSchema).default([]).describe('ui:list'),
  designSystemHref: z.string().optional().describe('ui:text'),
});

export const FooterSettingsSchema = z.object({
  showLogo: z.boolean().default(true),
});

END_OF_FILE_CONTENT
echo "Creating src/components/footer/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/footer/types.ts"
import { z } from 'zod';
import { FooterSchema, FooterSettingsSchema } from './schema';

export type FooterData = z.infer<typeof FooterSchema>;
export type FooterSettings = z.infer<typeof FooterSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/form-demo"
echo "Creating src/components/form-demo/FormDemoClient.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/FormDemoClient.tsx"
'use client';

import { useCallback, useState, type FormEvent } from 'react';
import { OlonFormsContext, useFormState, type FormState } from '@olonjs/react';
import type { FormDemoData } from './types';

type FormDemoClientProps = {
  formId: string;
  data: FormDemoData;
};

function FormDemoFields({
  formId,
  data,
  onSubmit,
}: FormDemoClientProps & { onSubmit: (event: FormEvent<HTMLFormElement>) => void }) {
  const { status, message } = useFormState(formId);

  return (
    <form
      id={formId}
      data-olon-recipient={data.recipientEmail ?? ''}
      className="space-y-4"
      onSubmit={onSubmit}
    >
      <div>
        <label className="mb-1 block text-xs font-medium text-muted-foreground">Nome</label>
        <input
          name="name"
          type="text"
          required
          className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
        />
      </div>

      <div>
        <label className="mb-1 block text-xs font-medium text-muted-foreground">Email</label>
        <input
          name="email"
          type="email"
          required
          className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
        />
      </div>

      <div>
        <label className="mb-1 block text-xs font-medium text-muted-foreground">Messaggio</label>
        <textarea
          name="message"
          required
          rows={4}
          className="w-full resize-none rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
        />
      </div>

      {status === 'error' ? <p className="text-xs text-red-500">{message}</p> : null}
      {status === 'success' ? <p className="text-xs text-green-600">{message}</p> : null}

      <button
        type="submit"
        disabled={status === 'submitting'}
        className="w-full rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {status === 'submitting' ? 'Invio...' : data.submitLabel || 'Invia'}
      </button>
    </form>
  );
}

/**
 * Client leaf for form-demo — OlonFormsContext is scoped HERE only (not root layout).
 */
export function FormDemoClient({ formId, data }: FormDemoClientProps) {
  const [states, setStates] = useState<Record<string, FormState>>({});

  const onSubmit = useCallback(
    async (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();
      const form = event.currentTarget;
      setStates((prev) => ({
        ...prev,
        [formId]: { status: 'submitting', message: 'Invio in corso...' },
      }));

      // Stub submit UX for local Next visitor (cloud submit can replace later).
      await new Promise((resolve) => setTimeout(resolve, 400));
      const fd = new FormData(form);
      const name = String(fd.get('name') ?? '').trim();
      const email = String(fd.get('email') ?? '').trim();
      const body = String(fd.get('message') ?? '').trim();

      if (!name || !email || !body) {
        setStates((prev) => ({
          ...prev,
          [formId]: { status: 'error', message: 'Compila tutti i campi.' },
        }));
        return;
      }

      setStates((prev) => ({
        ...prev,
        [formId]: {
          status: 'success',
          message: data.successMessage || 'Richiesta inviata con successo.',
        },
      }));
      form.reset();
    },
    [data.successMessage, formId],
  );

  return (
    <OlonFormsContext.Provider value={states}>
      <FormDemoFields formId={formId} data={data} onSubmit={onSubmit} />
    </OlonFormsContext.Provider>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/View.tsx"
import { Icon } from '@/lib/IconResolver';
import type { FormDemoData, FormDemoSettings } from './types';
import { FormDemoClient } from './FormDemoClient';

type FormDemoViewProps = {
  data: FormDemoData;
  settings?: FormDemoSettings;
};

/**
 * RSC shell for form-demo — chrome + IDAC attrs; interactivity lives in FormDemoClient.
 */
export function FormDemoView({ data }: FormDemoViewProps) {
  const formId = data.anchorId?.trim() || 'form-demo';

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-6 text-foreground">
      <section className="w-full max-w-xl space-y-6 rounded-xl border border-border bg-card p-8 shadow-sm">
        {data.icon ? (
          <div data-jp-field="icon" className="mb-2">
            <Icon name={data.icon} size={24} />
          </div>
        ) : null}
        {data.title ? (
          <div>
            <h1 data-jp-field="title" className="text-2xl font-semibold tracking-tight">
              {data.title}
            </h1>
            {data.description ? (
              <p data-jp-field="description" className="mt-3 text-sm text-muted-foreground">
                {data.description}
              </p>
            ) : null}
          </div>
        ) : null}

        <FormDemoClient formId={formId} data={data} />
      </section>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/index.ts"
export { FormDemoView } from './View';
export { FormDemoClient } from './FormDemoClient';
export { FormDemoSchema, FormDemoSettingsSchema, FormDemoSubmissionSchema } from './schema';
export type { FormDemoData, FormDemoSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/schema.ts"
import { z } from 'zod';
import { BaseSectionData, WithFormRecipient } from '@olonjs/core';

export const FormDemoSchema = BaseSectionData.merge(WithFormRecipient).extend({
  icon: z.string().optional().describe('ui:icon-picker'),
  title: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  submitLabel: z.string().default('Invia').describe('ui:text'),
  successMessage: z.string().default('Richiesta inviata con successo.').describe('ui:text'),
});

export const FormDemoSettingsSchema = z.object({});

/**
 * Submission payload schema for the `form-demo` section.
 */
export const FormDemoSubmissionSchema = z.object({
  name: z.string().min(1).describe('Full name of the person submitting the form'),
  email: z.string().email().describe('Contact email address where we will reply'),
  message: z.string().min(1).describe('Free-form message body'),
});

END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/types.ts"
import { z } from 'zod';
import { FormDemoSchema, FormDemoSettingsSchema } from './schema';

export type FormDemoData = z.infer<typeof FormDemoSchema>;
export type FormDemoSettings = z.infer<typeof FormDemoSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/header"
echo "Creating src/components/header/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/header/View.tsx"
import type { CSSProperties } from 'react';
import type { HeaderData, HeaderSettings } from './types';

export function HeaderView({
  data,
}: {
  data: HeaderData;
  settings?: HeaderSettings;
}) {
  return (
    <header
      style={
        {
          '--local-bg': 'var(--background)',
          '--local-text': 'var(--foreground)',
          '--local-primary': 'var(--primary)',
        } as CSSProperties
      }
      className="border-b border-black/10 bg-[var(--local-bg)] px-6 py-4 text-[var(--local-text)]"
    >
      <div className="mx-auto flex max-w-5xl items-center justify-between gap-6">
        <a href="/" className="flex items-baseline gap-1 font-semibold tracking-tight">
          <span data-jp-field="logoText">{data.logoText}</span>
          {data.badge ? (
            <span data-jp-field="badge" className="text-[var(--local-primary)]">
              {data.badge}
            </span>
          ) : null}
        </a>
        <nav className="flex flex-wrap items-center gap-4 text-sm">
          {(data.links ?? []).map((link, index) => (
            <a
              key={`${link.href}-${index}`}
              href={link.href}
              data-jp-item-id={link.id ?? String(index)}
              data-jp-item-field="links"
              className="opacity-80 hover:opacity-100"
            >
              {link.label}
            </a>
          ))}
        </nav>
      </div>
    </header>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/header/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/header/index.ts"
export { HeaderView } from './View';
export { HeaderSchema, HeaderSettingsSchema } from './schema';
export type { HeaderData, HeaderSettings } from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/header/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/header/schema.ts"
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';

export const HeaderLinkSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
});

/** Matches authored `site.json` header.data shape for the Next demo tenant. */
export const HeaderSchema = BaseSectionData.extend({
  logoText: z.string().describe('ui:text'),
  badge: z.string().optional().describe('ui:text'),
  links: z.array(HeaderLinkSchema).default([]).describe('ui:list'),
  ctaLabel: z.string().optional().describe('ui:text'),
  ctaHref: z.string().optional().describe('ui:text'),
  signinHref: z.string().optional().describe('ui:text'),
});

export const HeaderSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/header/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/header/types.ts"
import { z } from 'zod';
import { HeaderSchema, HeaderSettingsSchema } from './schema';

export type HeaderData = z.infer<typeof HeaderSchema>;
export type HeaderSettings = z.infer<typeof HeaderSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/data"
mkdir -p "src/data/collections"
mkdir -p "src/data/collections/autori"
echo "Creating src/data/collections/autori/autori.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/collections/autori/autori.json"
{
  "george-orwell": {
    "id": "george-orwell",
    "name": "George Orwell"
  },
  "umberto-eco": {
    "id": "umberto-eco",
    "name": "Umberto Eco"
  },
  "primo-levi": {
    "id": "primo-levi",
    "name": "Primo Levi"
  },
  "italo-calvino": {
    "id": "italo-calvino",
    "name": "Italo Calvino"
  },
  "giuseppe-tomasi-di-lampedusa": {
    "id": "giuseppe-tomasi-di-lampedusa",
    "name": "Giuseppe Tomasi di Lampedusa"
  },
  "italo-svevo": {
    "id": "italo-svevo",
    "name": "Italo Svevo"
  },
  "alessandro-manzoni": {
    "id": "alessandro-manzoni",
    "name": "Alessandro Manzoni"
  },
  "roberto-saviano": {
    "id": "roberto-saviano",
    "name": "Roberto Saviano"
  },
  "alessandro-baricco": {
    "id": "alessandro-baricco",
    "name": "Alessandro Baricco"
  },
  "natalia-ginzburg": {
    "id": "natalia-ginzburg",
    "name": "Natalia Ginzburg"
  },
  "gabriel-garcia-marquez": {
    "id": "gabriel-garcia-marquez",
    "name": "Gabriel Garcia Marquez"
  },
  "ray-bradbury": {
    "id": "ray-bradbury",
    "name": "Ray Bradbury"
  },
  "frank-herbert": {
    "id": "frank-herbert",
    "name": "Frank Herbert"
  },
  "william-gibson": {
    "id": "william-gibson",
    "name": "William Gibson"
  },
  "j-r-r-tolkien": {
    "id": "j-r-r-tolkien",
    "name": "J. R. R. Tolkien"
  },
  "j-k-rowling": {
    "id": "j-k-rowling",
    "name": "J. K. Rowling"
  },
  "jane-austen": {
    "id": "jane-austen",
    "name": "Jane Austen"
  },
  "herman-melville": {
    "id": "herman-melville",
    "name": "Herman Melville"
  },
  "fedor-dostoevskij": {
    "id": "fedor-dostoevskij",
    "name": "Fedor Dostoevskij"
  },
  "lev-tolstoj": {
    "id": "lev-tolstoj",
    "name": "Lev Tolstoj"
  },
  "michail-bulgakov": {
    "id": "michail-bulgakov",
    "name": "Michail Bulgakov"
  },
  "cormac-mccarthy": {
    "id": "cormac-mccarthy",
    "name": "Cormac McCarthy"
  },
  "david-mitchell": {
    "id": "david-mitchell",
    "name": "David Mitchell"
  },
  "haruki-murakami": {
    "id": "haruki-murakami",
    "name": "Haruki Murakami"
  },
  "chimamanda-ngozi-adichie": {
    "id": "chimamanda-ngozi-adichie",
    "name": "Chimamanda Ngozi Adichie"
  },
  "isabel-allende": {
    "id": "isabel-allende",
    "name": "Isabel Allende"
  },
  "toni-morrison": {
    "id": "toni-morrison",
    "name": "Toni Morrison"
  },
  "junot-diaz": {
    "id": "junot-diaz",
    "name": "Junot Diaz"
  },
  "jonathan-franzen": {
    "id": "jonathan-franzen",
    "name": "Jonathan Franzen"
  }
}
END_OF_FILE_CONTENT
mkdir -p "src/data/collections/libri"
echo "Creating src/data/collections/libri/libri.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/collections/libri/libri.json"
{
  "1984": {
    "id": "1984",
    "title": "1984",
    "author": {
      "$ref": "../autori/autori.json#/george-orwell"
    },
    "year": 1949,
    "genre": "Distopia",
    "summary": "Un regime totalitario controlla linguaggio, memoria e pensiero."
  },
  "il-nome-della-rosa": {
    "id": "il-nome-della-rosa",
    "title": "Il nome della rosa",
    "author": {
      "$ref": "../autori/autori.json#/umberto-eco"
    },
    "year": 1980,
    "genre": "Romanzo storico",
    "summary": "Un'indagine in un'abbazia medievale diventa una riflessione su conoscenza, potere e interpretazione."
  },
  "se-questo-e-un-uomo": {
    "id": "se-questo-e-un-uomo",
    "title": "Se questo e un uomo",
    "author": {
      "$ref": "../autori/autori.json#/primo-levi"
    },
    "year": 1947,
    "genre": "Memoria",
    "summary": "La testimonianza essenziale di Levi sull'esperienza del lager e sulla dignita umana."
  },
  "le-citta-invisibili": {
    "id": "le-citta-invisibili",
    "title": "Le citta invisibili",
    "author": {
      "$ref": "../autori/autori.json#/italo-calvino"
    },
    "year": 1972,
    "genre": "Letteratura fantastica",
    "summary": "Marco Polo racconta a Kublai Khan citta immaginarie che parlano di memoria, desiderio e linguaggio."
  },
  "il-gattopardo": {
    "id": "il-gattopardo",
    "title": "Il Gattopardo",
    "author": {
      "$ref": "../autori/autori.json#/giuseppe-tomasi-di-lampedusa"
    },
    "year": 1958,
    "genre": "Romanzo storico",
    "summary": "Il tramonto dell'aristocrazia siciliana durante l'unificazione italiana."
  },
  "la-coscienza-di-zeno": {
    "id": "la-coscienza-di-zeno",
    "title": "La coscienza di Zeno",
    "author": {
      "$ref": "../autori/autori.json#/italo-svevo"
    },
    "year": 1923,
    "genre": "Romanzo psicologico",
    "summary": "Un diario ironico e nevrotico attraversa memoria, terapia e autoinganno."
  },
  "i-promessi-sposi": {
    "id": "i-promessi-sposi",
    "title": "I promessi sposi",
    "author": {
      "$ref": "../autori/autori.json#/alessandro-manzoni"
    },
    "year": 1842,
    "genre": "Classico",
    "summary": "La vicenda di Renzo e Lucia dentro carestia, guerra, peste e provvidenza."
  },
  "il-barone-rampante": {
    "id": "il-barone-rampante",
    "title": "Il barone rampante",
    "author": {
      "$ref": "../autori/autori.json#/italo-calvino"
    },
    "year": 1957,
    "genre": "Romanzo filosofico",
    "summary": "Cosimo sceglie di vivere sugli alberi e trasforma la distanza in una forma di liberta."
  },
  "gomorra": {
    "id": "gomorra",
    "title": "Gomorra",
    "author": {
      "$ref": "../autori/autori.json#/roberto-saviano"
    },
    "year": 2006,
    "genre": "Inchiesta",
    "summary": "Un reportage narrativo sulle economie e le violenze del sistema camorristico."
  },
  "oceano-mare": {
    "id": "oceano-mare",
    "title": "Oceano mare",
    "author": {
      "$ref": "../autori/autori.json#/alessandro-baricco"
    },
    "year": 1993,
    "genre": "Romanzo letterario",
    "summary": "Storie diverse si incontrano in una locanda sul mare, tra cura, naufragio e mistero."
  },
  "lessico-famigliare": {
    "id": "lessico-famigliare",
    "title": "Lessico famigliare",
    "author": {
      "$ref": "../autori/autori.json#/natalia-ginzburg"
    },
    "year": 1963,
    "genre": "Memoria narrativa",
    "summary": "Una famiglia prende forma attraverso parole, tic linguistici e memoria civile."
  },
  "cent-anni-di-solitudine": {
    "id": "cent-anni-di-solitudine",
    "title": "Cent'anni di solitudine",
    "author": {
      "$ref": "../autori/autori.json#/gabriel-garcia-marquez"
    },
    "year": 1967,
    "genre": "Realismo magico",
    "summary": "La saga dei Buendia e di Macondo intreccia mito, storia e destino."
  },
  "fahrenheit-451": {
    "id": "fahrenheit-451",
    "title": "Fahrenheit 451",
    "author": {
      "$ref": "../autori/autori.json#/ray-bradbury"
    },
    "year": 1953,
    "genre": "Distopia",
    "summary": "In un futuro dove i libri bruciano, leggere diventa un atto di resistenza."
  },
  "dune": {
    "id": "dune",
    "title": "Dune",
    "author": {
      "$ref": "../autori/autori.json#/frank-herbert"
    },
    "year": 1965,
    "genre": "Fantascienza",
    "summary": "Politica, ecologia e messianismo si scontrano sul pianeta desertico Arrakis."
  },
  "neuromancer": {
    "id": "neuromancer",
    "title": "Neuromancer",
    "author": {
      "$ref": "../autori/autori.json#/william-gibson"
    },
    "year": 1984,
    "genre": "Cyberpunk",
    "summary": "Un hacker decaduto viene trascinato in un colpo che attraversa cyberspazio e intelligenze artificiali."
  },
  "il-signore-degli-anelli": {
    "id": "il-signore-degli-anelli",
    "title": "Il Signore degli Anelli",
    "author": {
      "$ref": "../autori/autori.json#/j-r-r-tolkien"
    },
    "year": 1954,
    "genre": "Fantasy",
    "summary": "La Compagnia affronta il potere dell'Anello in una delle grandi epopee moderne."
  },
  "harry-potter-e-la-pietra-filosofale": {
    "id": "harry-potter-e-la-pietra-filosofale",
    "title": "Harry Potter e la pietra filosofale",
    "author": {
      "$ref": "../autori/autori.json#/j-k-rowling"
    },
    "year": 1997,
    "genre": "Fantasy",
    "summary": "Un ragazzo scopre il mondo magico e il proprio posto in una storia piu grande."
  },
  "orgoglio-e-pregiudizio": {
    "id": "orgoglio-e-pregiudizio",
    "title": "Orgoglio e pregiudizio",
    "author": {
      "$ref": "../autori/autori.json#/jane-austen"
    },
    "year": 1813,
    "genre": "Classico",
    "summary": "Elizabeth Bennet e Mr. Darcy si misurano con classe, carattere e giudizio sociale."
  },
  "moby-dick": {
    "id": "moby-dick",
    "title": "Moby Dick",
    "author": {
      "$ref": "../autori/autori.json#/herman-melville"
    },
    "year": 1851,
    "genre": "Avventura",
    "summary": "La caccia alla balena bianca diventa ossessione metafisica e viaggio nell'abisso."
  },
  "delitto-e-castigo": {
    "id": "delitto-e-castigo",
    "title": "Delitto e castigo",
    "author": {
      "$ref": "../autori/autori.json#/fedor-dostoevskij"
    },
    "year": 1866,
    "genre": "Romanzo psicologico",
    "summary": "Raskolnikov attraversa colpa, febbre morale e possibilita di redenzione."
  },
  "anna-karenina": {
    "id": "anna-karenina",
    "title": "Anna Karenina",
    "author": {
      "$ref": "../autori/autori.json#/lev-tolstoj"
    },
    "year": 1877,
    "genre": "Classico",
    "summary": "Una storia d'amore e rovina dentro la societa russa dell'Ottocento."
  },
  "il-maestro-e-margherita": {
    "id": "il-maestro-e-margherita",
    "title": "Il maestro e Margherita",
    "author": {
      "$ref": "../autori/autori.json#/michail-bulgakov"
    },
    "year": 1967,
    "genre": "Satira fantastica",
    "summary": "Il diavolo visita Mosca in un romanzo visionario su arte, censura e amore."
  },
  "la-strada": {
    "id": "la-strada",
    "title": "La strada",
    "author": {
      "$ref": "../autori/autori.json#/cormac-mccarthy"
    },
    "year": 2006,
    "genre": "Post-apocalittico",
    "summary": "Padre e figlio attraversano un mondo bruciato portando con se una fragile idea di bene."
  },
  "cloud-atlas": {
    "id": "cloud-atlas",
    "title": "Cloud Atlas",
    "author": {
      "$ref": "../autori/autori.json#/david-mitchell"
    },
    "year": 2004,
    "genre": "Romanzo corale",
    "summary": "Sei storie in epoche diverse compongono una meditazione su potere, memoria e reincorrenza."
  },
  "kafka-sulla-spiaggia": {
    "id": "kafka-sulla-spiaggia",
    "title": "Kafka sulla spiaggia",
    "author": {
      "$ref": "../autori/autori.json#/haruki-murakami"
    },
    "year": 2002,
    "genre": "Surrealismo",
    "summary": "Fuga, destino e sogno si intrecciano in un romanzo sospeso tra reale e mitico."
  },
  "americanah": {
    "id": "americanah",
    "title": "Americanah",
    "author": {
      "$ref": "../autori/autori.json#/chimamanda-ngozi-adichie"
    },
    "year": 2013,
    "genre": "Romanzo contemporaneo",
    "summary": "Migrazione, razza e identita raccontate attraverso una storia d'amore tra Nigeria e Stati Uniti."
  },
  "la-casa-degli-spiriti": {
    "id": "la-casa-degli-spiriti",
    "title": "La casa degli spiriti",
    "author": {
      "$ref": "../autori/autori.json#/isabel-allende"
    },
    "year": 1982,
    "genre": "Saga familiare",
    "summary": "La storia della famiglia Trueba intreccia politica, memoria e realismo magico."
  },
  "beloved": {
    "id": "beloved",
    "title": "Beloved",
    "author": {
      "$ref": "../autori/autori.json#/toni-morrison"
    },
    "year": 1987,
    "genre": "Romanzo storico",
    "summary": "Il trauma della schiavitu ritorna come presenza viva nella casa di Sethe."
  },
  "la-breve-favolosa-vita-di-oscar-wao": {
    "id": "la-breve-favolosa-vita-di-oscar-wao",
    "title": "La breve favolosa vita di Oscar Wao",
    "author": {
      "$ref": "../autori/autori.json#/junot-diaz"
    },
    "year": 2007,
    "genre": "Romanzo contemporaneo",
    "summary": "Famiglia, diaspora dominicana e cultura pop si intrecciano nella storia di Oscar."
  },
  "le-correzioni": {
    "id": "le-correzioni",
    "title": "Le correzioni",
    "author": {
      "$ref": "../autori/autori.json#/jonathan-franzen"
    },
    "year": 2001,
    "genre": "Romanzo familiare",
    "summary": "Una famiglia americana tenta di ritrovarsi mentre ciascuno affronta le proprie fratture."
  }
}
END_OF_FILE_CONTENT
mkdir -p "src/data/config"
echo "Creating src/data/config/menu.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/menu.json"
{
  "main": [
    {
      "label": "Why",
      "href": "#Why"
    },
    {
      "label": "Architecture",
      "href": "#Architecture"
    },
    {
      "label": "Example",
      "href": "#Example"
    },
    {
      "label": "Get started",
      "href": "#Getstarted"
    },
    {
      "label": "GitHub",
      "href": "https://github.com/olonjs/core"
    }
  ],
  "footer": [
    {
      "id": "footer-home",
      "label": "Home",
      "href": "/"
    },
    {
      "id": "footer-libri",
      "label": "Libri",
      "href": "/libri"
    },
    {
      "id": "footer-github",
      "label": "GitHub",
      "href": "https://github.com/olonjs/core",
      "external": true
    }
  ]
}
END_OF_FILE_CONTENT
echo "Creating src/data/config/site.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/site.json"
{
  "identity": {
    "title": "OlonJS",
    "logoUrl": "/brand/mark/olon-mark-dark.svg"
  },
  "header": {
    "id": "global-header",
    "type": "header",
    "data": {
      "logoText": "Olon",
      "badge": "JS",
      "links": [
        {
          "label": "Why",
          "href": "#Why"
        },
        {
          "label": "Architecture",
          "href": "#Architecture"
        },
        {
          "label": "Example",
          "href": "#Example"
        },
        {
          "label": "Get started",
          "href": "#Getstarted"
        },
        {
          "label": "GitHub",
          "href": "https://github.com/olonjs/core"
        }
      ],
      "ctaLabel": "",
      "ctaHref": "",
      "signinHref": ""
    }
  },
  "footer": {
    "id": "global-footer",
    "type": "footer",
    "data": {
      "brandText": "OlonJS",
      "description": "AI-native content infrastructure for deterministic, sovereign, git-backed sites.",
      "copyright": "© 2026 OlonJS · v1.5 · Guido Serio",
      "links": {
        "$ref": "../config/menu.json#/footer"
      },
      "designSystemHref": ""
    },
    "settings": {
      "showLogo": true
    }
  }
}
END_OF_FILE_CONTENT
echo "Creating src/data/config/theme.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/theme.json"
{
  "name": "Olon",
  "tokens": {
    "colors": {
      "background": "hsl(215 28% 7%)",
      "card": "hsl(218 44% 9%)",
      "elevated": "#141B24",
      "overlay": "#1C2433",
      "popover": "hsl(218 44% 9%)",
      "popover-foreground": "hsl(214 33% 84%)",
      "foreground": "hsl(214 33% 84%)",
      "card-foreground": "hsl(214 33% 84%)",
      "muted-foreground": "hsl(215 23% 57%)",
      "placeholder": "#4A5C78",
      "primary": "hsl(222 100% 54%)",
      "primary-foreground": "hsl(0 0% 100%)",
      "primary-light": "#84ABFF",
      "primary-dark": "#0F52E0",
      "primary-50": "#EEF3FF",
      "primary-100": "#D6E4FF",
      "primary-200": "#ADC8FF",
      "primary-300": "#84ABFF",
      "primary-400": "#5B8EFF",
      "primary-500": "#1763FF",
      "primary-600": "#0F52E0",
      "primary-700": "#0940B8",
      "primary-800": "#063090",
      "primary-900": "#031E68",
      "accent": "hsl(216 28% 15%)",
      "accent-foreground": "hsl(214 33% 84%)",
      "secondary": "hsl(217 30% 11%)",
      "secondary-foreground": "hsl(214 33% 84%)",
      "muted": "hsl(217 30% 11%)",
      "border": "hsl(216 27% 21%)",
      "border-strong": "#2F3D55",
      "input": "hsl(216 27% 21%)",
      "ring": "hsl(222 100% 54%)",
      "destructive": "hsl(0 40% 46%)",
      "destructive-foreground": "hsl(210 58% 93%)",
      "destructive-border": "#7F2626",
      "destructive-ring": "#E06060",
      "success": "hsl(152 83% 26%)",
      "success-foreground": "hsl(210 58% 93%)",
      "success-border": "#1DB87A",
      "success-indicator": "#1DB87A",
      "warning": "hsl(46 100% 21%)",
      "warning-foreground": "hsl(210 58% 93%)",
      "warning-border": "#C49A00",
      "info": "hsl(214 100% 40%)",
      "info-foreground": "hsl(210 58% 93%)",
      "info-border": "#4D9FE0"
    },
    "modes": {
      "light": {
        "colors": {
          "background": "hsl(0 0% 96%)",
          "card": "hsl(0 0% 100%)",
          "elevated": "#F4F3EF",
          "overlay": "#E5E3DC",
          "popover": "hsl(0 0% 100%)",
          "popover-foreground": "hsl(0 0% 3%)",
          "foreground": "hsl(0 0% 3%)",
          "card-foreground": "hsl(0 0% 3%)",
          "muted-foreground": "hsl(0 0% 42%)",
          "placeholder": "#B4B2AD",
          "primary": "hsl(222 100% 54%)",
          "primary-foreground": "hsl(0 0% 100%)",
          "primary-light": "#5B8EFF",
          "primary-dark": "#0F52E0",
          "primary-50": "#EEF3FF",
          "primary-100": "#D6E4FF",
          "primary-200": "#ADC8FF",
          "primary-300": "#84ABFF",
          "primary-400": "#5B8EFF",
          "primary-500": "#1763FF",
          "primary-600": "#0F52E0",
          "primary-700": "#0940B8",
          "primary-800": "#063090",
          "primary-900": "#031E68",
          "accent": "hsl(222 100% 92%)",
          "accent-foreground": "hsl(222 100% 54%)",
          "secondary": "hsl(0 0% 92%)",
          "secondary-foreground": "hsl(0 0% 3%)",
          "muted": "hsl(0 0% 92%)",
          "border": "hsl(0 0% 84%)",
          "border-strong": "#B4B2AD",
          "input": "hsl(0 0% 84%)",
          "ring": "hsl(222 100% 54%)",
          "destructive": "hsl(0 72% 51%)",
          "destructive-foreground": "hsl(0 0% 100%)",
          "destructive-border": "#FECACA",
          "destructive-ring": "#EF4444",
          "success": "hsl(160 84% 39%)",
          "success-foreground": "hsl(0 0% 100%)",
          "success-border": "#D4F0E2",
          "success-indicator": "#0A7C4E",
          "warning": "hsl(38 92% 50%)",
          "warning-foreground": "hsl(0 0% 3%)",
          "warning-border": "#F5EAD4",
          "info": "hsl(222 100% 54%)",
          "info-foreground": "hsl(0 0% 100%)",
          "info-border": "#D4E5F5"
        }
      }
    },
    "typography": {
      "fontFamily": {
        "primary": "\"Instrument Sans\", Helvetica, Arial, sans-serif",
        "mono": "\"JetBrains Mono\", \"Fira Code\", monospace",
        "display": "\"Instrument Sans\", Helvetica, Arial, sans-serif"
      },
      "wordmark": {
        "fontFamily": "\"Instrument Sans\", Helvetica, Arial, sans-serif",
        "weight": "700",
        "tracking": "-0.05em"
      },
      "scale": {
        "xs": "0.75rem",
        "sm": "0.875rem",
        "base": "1rem",
        "lg": "1.125rem",
        "xl": "1.25rem",
        "2xl": "1.5rem",
        "3xl": "1.875rem",
        "4xl": "2.25rem",
        "5xl": "3rem",
        "6xl": "3rem",
        "7xl": "4.5rem"
      },
      "tracking": {
        "tight": "-0.04em",
        "normal": "0em",
        "wide": "0.04em",
        "widest": "0.14em"
      },
      "leading": {
        "tight": "1.2",
        "normal": "1.5",
        "relaxed": "1.7"
      }
    },
    "borderRadius": {
      "xl": "1rem",
      "lg": "0.75rem",
      "md": "0.5rem",
      "sm": "0.25rem",
      "full": "9999px"
    },
    "spacing": {
      "container-max": "72rem",
      "section-y": "4rem",
      "header-h": "4rem"
    },
    "zIndex": {
      "base": "0",
      "elevated": "10",
      "dropdown": "20",
      "sticky": "40",
      "overlay": "50",
      "modal": "60",
      "toast": "100"
    }
  }
}
END_OF_FILE_CONTENT
mkdir -p "src/data/pages"
mkdir -p "src/data/pages/authors"
echo "Creating src/data/pages/authors.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/authors.json"
{
  "id": "authors-page",
  "slug": "authors",
  "meta": {
    "title": "Authors",
    "description": "Author directory powered by the autori collection."
  },
  "sections": [
    {
      "id": "authors-list-1",
      "type": "authors-list",
      "data": {
        "anchorId": "authors",
        "eyebrow": "Collection demo",
        "title": "Authors",
        "description": "A collection-backed directory of authors referenced by books.",
        "items": {
          "$ref": "../collections/autori/autori.json"
        }
      }
    }
  ],
  "global-header": false
}

END_OF_FILE_CONTENT
mkdir -p "src/data/pages/authors/[authorId]"
echo "Creating src/data/pages/authors/[authorId]/libri.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/authors/[authorId]/libri.json"
{
  "id": "author-books-page",
  "slug": "authors/[authorId]/libri",
  "meta": {
    "title": "Libri per autore",
    "description": "Catalogo libri filtrato per autore."
  },
  "sections": [
    {
      "id": "books-list-author-filter",
      "type": "books-list",
      "data": {
        "anchorId": "libri-autore",
        "eyebrow": "Author books",
        "title": "Libri",
        "description": "Libri filtrati per autore dalla collection autori.",
        "items": {
          "$ref": "../../collections/libri/libri.json"
        },
        "pageSize": 10
      }
    }
  ],
  "global-header": false
}

END_OF_FILE_CONTENT
echo "Creating src/data/pages/form.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/form.json"
{
  "id": "form-page",
  "slug": "form",
  "meta": {
    "title": "Home",
    "description": "OlonJS tenant alpha — form smoke test"
  },
  "sections": [
    {
      "id": "form-demo-1",
      "type": "form-demo",
      "data": {
        "anchorId": "form-demo",
        "recipientEmail": "test@olonjs.io",
        "icon": "mail",
        "title": "contact us",
        "description": "Compila il modulo e ti risponderemo al più presto.",
        "submitLabel": "Invia",
        "successMessage": "Richiesta inviata con successo."
      }
    }
  ],
  "global-header": false
}

END_OF_FILE_CONTENT
echo "Creating src/data/pages/home.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/home.json"
{
  "id": "libri-page",
  "slug": "home",
  "meta": {
    "title": "Libri",
    "description": "Catalogo libri dimostrativo alimentato da COP collections."
  },
  "sections": [
    {
      "id": "books-list-1",
      "type": "books-list",
      "data": {
        "anchorId": "catalogo-libri",
        "eyebrow": "Collection demo",
        "title": "Collections",
        "description": "Una pagina collection con 30 titoli, paginazione lato componente e link alle schede dinamiche.",
        "items": {
          "$ref": "../collections/libri/libri.json"
        },
        "pageSize": 10
      }
    }
  ],
  "global-header": false
}
END_OF_FILE_CONTENT
mkdir -p "src/data/pages/libri"
echo "Creating src/data/pages/libri.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/libri.json"
{
  "id": "libri-page",
  "slug": "libri",
  "meta": {
    "title": "Libri",
    "description": "Catalogo libri dimostrativo alimentato da COP collections."
  },
  "sections": [
    {
      "id": "books-list-1",
      "type": "books-list",
      "data": {
        "anchorId": "catalogo-libri",
        "eyebrow": "Collection demo",
        "title": "Libri",
        "description": "Una pagina collection con titoli, paginazione lato componente e filtro autore.",
        "items": {
          "$ref": "../collections/libri/libri.json"
        },
        "pageSize": 10
      }
    }
  ],
  "global-header": false
}

END_OF_FILE_CONTENT
echo "Creating src/data/pages/libri/[slug].json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/libri/[slug].json"
{
  "id": "libro-detail-page",
  "slug": "libri/[slug]",
  "meta": {
    "title": "Dettaglio libro",
    "description": "Pagina dinamica dettaglio libro alimentata dalla collection libri."
  },
  "sections": [
    {
      "id": "book-detail-1",
      "type": "book-detail",
      "data": {
        "anchorId": "dettaglio-libro",
        "item": {
          "$ref": "collection:current"
        },
        "backLabel": "← Torna ai libri"
      }
    }
  ],
  "collection": {
    "source": "libri",
    "paramKey": "slug"
  },
  "global-header": false
}

END_OF_FILE_CONTENT
# SKIP: src/index.css is binary and cannot be embedded as text.
mkdir -p "src/lib"
echo "Creating src/lib/CollectionRegistry.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/CollectionRegistry.ts"
import { AutoriCollectionSchema } from '@/collections/autori';
import { LibriCollectionSchema } from '@/collections/libri';

export const CollectionRegistry = {
  autori: AutoriCollectionSchema,
  libri: LibriCollectionSchema,
} as const;

export type CollectionType = keyof typeof CollectionRegistry;

END_OF_FILE_CONTENT
echo "Creating src/lib/ComponentRegistry.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/ComponentRegistry.tsx"
import type React from 'react';
import type { SectionType } from '@/types';
import type { SectionComponentPropsMap } from '@/types';
import { AuthorsListView } from '@/components/authors-list';
import { BookDetailView } from '@/components/book-detail';
import { BooksListView } from '@/components/books-list';
import { EmptyTenantView } from '@/components/empty-tenant';
import { FooterView } from '@/components/footer';
import { FormDemoView } from '@/components/form-demo';
import { HeaderView } from '@/components/header';

export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = {
  'authors-list': AuthorsListView as React.FC<SectionComponentPropsMap['authors-list']>,
  'book-detail': BookDetailView as React.FC<SectionComponentPropsMap['book-detail']>,
  'books-list': BooksListView as React.FC<SectionComponentPropsMap['books-list']>,
  'empty-tenant': EmptyTenantView as React.FC<SectionComponentPropsMap['empty-tenant']>,
  footer: FooterView as React.FC<SectionComponentPropsMap['footer']>,
  'form-demo': FormDemoView as React.FC<SectionComponentPropsMap['form-demo']>,
  header: HeaderView as React.FC<SectionComponentPropsMap['header']>,
};

END_OF_FILE_CONTENT
echo "Creating src/lib/IconResolver.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/IconResolver.tsx"
import React from 'react';
import {
  Layers,
  Github,
  ArrowRight,
  Box,
  Terminal,
  ChevronRight,
  Menu,
  X,
  Sparkles,
  Zap,
  Mail,
  type LucideIcon,
} from 'lucide-react';

export const iconMap = {
  layers: Layers,
  github: Github,
  'arrow-right': ArrowRight,
  box: Box,
  terminal: Terminal,
  'chevron-right': ChevronRight,
  menu: Menu,
  x: X,
  sparkles: Sparkles,
  zap: Zap,
  mail: Mail,
} as const satisfies Record<string, LucideIcon>;

export type IconName = keyof typeof iconMap;

export function isIconName(s: string): s is IconName {
  return s in iconMap;
}

interface IconProps {
  name: string;
  size?: number;
  className?: string;
}

export const Icon: React.FC<IconProps> = ({ name, size = 20, className }) => {
  const IconComponent = isIconName(name) ? iconMap[name] : undefined;

  if (!IconComponent) {
    if (process.env.NODE_ENV === 'development') {
      console.warn(`[IconResolver] Unknown icon: "${name}". Add it to iconMap.`);
    }
    return null;
  }

  return <IconComponent size={size} className={className} />;
};

END_OF_FILE_CONTENT
echo "Creating src/lib/VisitorSection.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/VisitorSection.tsx"
import type { FC } from 'react';
import type { Section, SectionType } from '@/types';
import type { BooksListData } from '@/components/books-list';
import { BooksListView } from '@/components/books-list';
import { ComponentRegistry } from '@/lib/ComponentRegistry';

export type VisitorSectionExtras = {
  authorId?: string | null;
  page?: number;
  pathname?: string;
};

/** Render a resolved page section via the tenant ComponentRegistry (RSC path). */
export function VisitorSection({
  section,
  extras,
}: {
  section: Section;
  extras?: VisitorSectionExtras;
}) {
  if (section.type === 'books-list') {
    return (
      <BooksListView
        data={section.data as BooksListData}
        authorId={extras?.authorId}
        page={extras?.page}
        pathname={extras?.pathname}
      />
    );
  }

  const type = section.type as SectionType;
  const Comp = ComponentRegistry[type];
  if (!Comp) {
    return (
      <section className="px-6 py-8 text-muted-foreground">
        Unknown section type: {String(section.type)}
      </section>
    );
  }

  // Registry Views accept { data, settings? }; cast keeps MTRP map flexible for RSC host.
  const View = Comp as FC<{ data: unknown; settings?: unknown }>;
  return <View data={section.data} settings={section.settings} />;
}

END_OF_FILE_CONTENT
echo "Creating src/lib/addSectionConfig.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/addSectionConfig.ts"
import type { AddSectionConfig } from '@olonjs/core';

const addableSectionTypes = ['authors-list', 'book-detail', 'books-list', 'empty-tenant', 'footer', 'form-demo'] as const;

const sectionTypeLabels: Record<string, string> = {
  'authors-list': 'Authors List',
  'book-detail': 'Book Detail',
  'books-list': 'Books List',
  'empty-tenant': 'Empty Tenant',
  footer: 'Footer',
  'form-demo': 'Form Demo',
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'authors-list':
      return {
        eyebrow: 'Collection demo',
        title: 'Authors',
        description: 'Authors loaded from the autori collection.',
        items: { $ref: '../collections/autori/autori.json' },
      };
    case 'book-detail':
      return {
        item: { $ref: 'collection:current' },
        backLabel: 'Torna ai libri',
      };
    case 'books-list':
      return {
        eyebrow: 'Collection demo',
        title: 'Libri',
        description: 'Catalogo dimostrativo alimentato dalla collection libri.',
        items: { $ref: '../collections/libri/libri.json' },
        pageSize: 10,
      };
    case 'empty-tenant':
      return {
        title: 'Your tenant is empty.',
        description: 'Create your first page to start building your site.',
      };
    case 'footer':
      return {
        brandText: 'OlonJS',
        description: 'AI-native content infrastructure for deterministic, git-backed sites.',
        copyright: '© 2026 OlonJS',
        links: [],
        designSystemHref: '',
      };
    case 'form-demo':
      return {
        title: 'Contattaci',
        description: 'Compila il modulo e ti risponderemo al più presto.',
        recipientEmail: '',
        submitLabel: 'Invia',
        successMessage: 'Richiesta inviata con successo.',
      };
    default:
      return {};
  }
}

export const addSectionConfig: AddSectionConfig = {
  addableSectionTypes: [...addableSectionTypes],
  sectionTypeLabels,
  getDefaultSectionData,
};

END_OF_FILE_CONTENT
mkdir -p "src/lib/admin"
echo "Creating src/lib/admin/hydrateLocalProjectState.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/admin/hydrateLocalProjectState.ts"
import type { JsonPagesConfig, MenuConfig, PageConfig, ProjectState, SiteConfig, ThemeConfig } from '@olonjs/core';

type HydrateLocalProjectStateArgs = {
  state: ProjectState;
  slug: string;
  setPages: (updater: (prev: Record<string, PageConfig>) => Record<string, PageConfig>) => void;
  setSiteConfig: (site: SiteConfig) => void;
  setMenuConfig: (menu: MenuConfig) => void;
  setThemeConfig: (theme: ThemeConfig) => void;
  setCollections: (collections: NonNullable<JsonPagesConfig['collections']>) => void;
};

/**
 * Write-through hydrate after local `/api/save-to-file`.
 * Pushes only the slices present in the saved ProjectState into island state.
 */
export function hydrateLocalProjectState({
  state,
  slug,
  setPages,
  setSiteConfig,
  setMenuConfig,
  setThemeConfig,
  setCollections,
}: HydrateLocalProjectStateArgs): void {
  if (state.menu != null) setMenuConfig(state.menu);
  if (state.site != null) setSiteConfig(state.site);
  if (state.theme != null) setThemeConfig(state.theme);
  if (state.page != null) {
    setPages((prev) => ({ ...prev, [slug]: state.page }));
  }
  if (state.collections != null) {
    setCollections(state.collections as NonNullable<JsonPagesConfig['collections']>);
  }
}

END_OF_FILE_CONTENT
echo "Creating src/lib/admin/useCloudSave.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/admin/useCloudSave.ts"
'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import type { DeployPhase, ProjectState, StepId } from '@olonjs/core';
import { DEPLOY_STEPS, startCloudSaveStream } from '@olonjs/core';

export interface CloudSaveUiState {
  isOpen: boolean;
  phase: DeployPhase;
  currentStepId: StepId | null;
  doneSteps: StepId[];
  progress: number;
  errorMessage?: string;
  deployUrl?: string;
}

function getInitialCloudSaveUiState(): CloudSaveUiState {
  return {
    isOpen: false,
    phase: 'idle',
    currentStepId: null,
    doneSteps: [],
    progress: 0,
  };
}

function stepProgress(doneSteps: StepId[]): number {
  return Math.round((doneSteps.length / DEPLOY_STEPS.length) * 100);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function cloneJson<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function normalizePathSegments(value: string): string {
  return value
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean)
    .join('/');
}

function resolveAdminContentSlug(basePath = '/'): string | null {
  if (typeof window === 'undefined') return null;

  const normalizedBase = basePath.replace(/\/+$/, '');
  let path = window.location.pathname;
  if (normalizedBase && normalizedBase !== '/' && path.startsWith(normalizedBase)) {
    path = path.slice(normalizedBase.length) || '/';
  }

  const slug = normalizePathSegments(path.replace(/^\/admin\/?/, ''));
  return slug || null;
}

function resolveTemplateParamValue(templateSlug: string, concreteSlug: string, paramKey: string): string | null {
  const templateSegments = normalizePathSegments(templateSlug).split('/').filter(Boolean);
  const concreteSegments = normalizePathSegments(concreteSlug).split('/').filter(Boolean);
  if (templateSegments.length !== concreteSegments.length) return null;

  for (let index = 0; index < templateSegments.length; index += 1) {
    const templateSegment = templateSegments[index];
    const concreteSegment = concreteSegments[index];
    const paramMatch = templateSegment.match(/^\[([A-Za-z0-9_-]+)\]$/);
    if (paramMatch?.[1] === paramKey) return concreteSegment;
    if (!paramMatch && templateSegment !== concreteSegment) return null;
  }

  return null;
}

function hasCollectionCurrentRef(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(hasCollectionCurrentRef);
  if (!isRecord(value)) return false;
  if (value.$ref === 'collection:current') return true;
  return Object.values(value).some(hasCollectionCurrentRef);
}

function replaceCollectionCurrentRefs(value: unknown, currentItem: unknown): unknown {
  if (Array.isArray(value)) return value.map((item) => replaceCollectionCurrentRefs(item, currentItem));
  if (!isRecord(value)) return value;
  if (value.$ref === 'collection:current') return cloneJson(currentItem);
  return Object.fromEntries(
    Object.entries(value).map(([key, entryValue]) => [key, replaceCollectionCurrentRefs(entryValue, currentItem)]),
  );
}

function buildSaveStreamPagePayload(state: ProjectState, fallbackSlug: string): { slug: string; page: ProjectState['page'] } {
  const page = state.page;
  const collection = page.collection;
  if (!collection || !hasCollectionCurrentRef(page)) {
    return { slug: fallbackSlug, page };
  }

  const concreteSlug = resolveAdminContentSlug();
  if (!concreteSlug) {
    throw new Error('Cannot resolve concrete admin route for collection page save.');
  }

  const paramValue = resolveTemplateParamValue(page.slug, concreteSlug, collection.paramKey);
  if (!paramValue) {
    throw new Error(`Cannot resolve collection param "${collection.paramKey}" from route "${concreteSlug}".`);
  }

  const collectionDocument = state.collections?.[collection.source];
  const currentItem = isRecord(collectionDocument) ? collectionDocument[paramValue] : undefined;
  if (!currentItem) {
    throw new Error(`Cannot resolve collection item "${collection.source}/${paramValue}" for save.`);
  }

  const resolvedPage = replaceCollectionCurrentRefs(page, currentItem) as ProjectState['page'];
  return {
    slug: concreteSlug,
    page: {
      ...resolvedPage,
      slug: concreteSlug,
    },
  };
}

export type UseCloudSaveOptions = {
  apiUrl: string;
  apiKey: string;
};

/**
 * Slim Save2Repo cold-save hook (alpha useCloudSave pattern).
 * HotSave is intentionally not included.
 */
export function useCloudSave({ apiUrl, apiKey }: UseCloudSaveOptions) {
  const [cloudSaveUi, setCloudSaveUi] = useState<CloudSaveUiState>(getInitialCloudSaveUiState);
  const activeCloudSaveController = useRef<AbortController | null>(null);
  const pendingCloudSave = useRef<{ state: ProjectState; slug: string } | null>(null);

  useEffect(() => {
    return () => {
      activeCloudSaveController.current?.abort();
    };
  }, []);

  const runCloudSave = useCallback(
    async (payload: { state: ProjectState; slug: string }, rejectOnError: boolean): Promise<void> => {
      if (!apiUrl || !apiKey) {
        const noCloudError = new Error('Cloud mode is not configured.');
        if (rejectOnError) throw noCloudError;
        return;
      }

      pendingCloudSave.current = payload;
      activeCloudSaveController.current?.abort();
      const controller = new AbortController();
      activeCloudSaveController.current = controller;

      setCloudSaveUi({
        isOpen: true,
        phase: 'running',
        currentStepId: null,
        doneSteps: [],
        progress: 0,
      });

      try {
        const savePage = buildSaveStreamPagePayload(payload.state, payload.slug);
        await startCloudSaveStream({
          apiBaseUrl: apiUrl,
          apiKey,
          path: `src/data/pages/${savePage.slug}.json`,
          content: savePage.page,
          additionalFiles: [
            { path: 'src/data/config/site.json', content: payload.state.site },
            { path: 'src/data/config/menu.json', content: payload.state.menu },
          ],
          changedScopes: ['page', 'site', 'menu'],
          message: `Content update for ${savePage.slug} via Visual Editor`,
          signal: controller.signal,
          onStep: (event) => {
            setCloudSaveUi((prev) => {
              if (event.status === 'running') {
                return {
                  ...prev,
                  isOpen: true,
                  phase: 'running',
                  currentStepId: event.id,
                  errorMessage: undefined,
                };
              }

              if (prev.doneSteps.includes(event.id)) {
                return prev;
              }

              const nextDone = [...prev.doneSteps, event.id];
              return {
                ...prev,
                isOpen: true,
                phase: 'running',
                currentStepId: event.id,
                doneSteps: nextDone,
                progress: stepProgress(nextDone),
              };
            });
          },
          onDone: (event) => {
            const completed = DEPLOY_STEPS.map((step) => step.id);
            setCloudSaveUi({
              isOpen: true,
              phase: 'done',
              currentStepId: 'live',
              doneSteps: completed,
              progress: 100,
              deployUrl: event.deployUrl,
            });
          },
        });
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : 'Cloud save failed.';
        setCloudSaveUi((prev) => ({
          ...prev,
          isOpen: true,
          phase: 'error',
          errorMessage: message,
        }));
        if (rejectOnError) throw new Error(message);
      } finally {
        if (activeCloudSaveController.current === controller) {
          activeCloudSaveController.current = null;
        }
      }
    },
    [apiUrl, apiKey],
  );

  const closeCloudDrawer = useCallback(() => {
    setCloudSaveUi(getInitialCloudSaveUiState());
  }, []);

  const retryCloudSave = useCallback(() => {
    if (!pendingCloudSave.current) return;
    void runCloudSave(pendingCloudSave.current, false);
  }, [runCloudSave]);

  return { cloudSaveUi, runCloudSave, closeCloudDrawer, retryCloudSave };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/buildVisitorWebPageJsonLd.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/buildVisitorWebPageJsonLd.test.ts"
import { describe, expect, it } from 'vitest';
import { buildVisitorWebPageJsonLd } from './buildVisitorWebPageJsonLd';

describe('buildVisitorWebPageJsonLd', () => {
  it('builds Schema.org WebPage for home at /', () => {
    expect(
      buildVisitorWebPageJsonLd({
        title: 'Home',
        description: 'Welcome',
        slug: 'home',
      }),
    ).toEqual({
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: 'Home',
      description: 'Welcome',
      url: '/',
    });
  });

  it('builds Schema.org WebPage for nested slug paths', () => {
    expect(
      buildVisitorWebPageJsonLd({
        title: 'Dune',
        description: 'Book',
        slug: 'libri/dune',
      }),
    ).toEqual({
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: 'Dune',
      description: 'Book',
      url: '/libri/dune',
    });
  });
});

END_OF_FILE_CONTENT
echo "Creating src/lib/buildVisitorWebPageJsonLd.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/buildVisitorWebPageJsonLd.ts"
/**
 * Schema.org WebPage JSON-LD for Next visitor RSC (parity with tenant-alpha bake HTML injection).
 */
export type VisitorWebPageJsonLd = {
  '@context': 'https://schema.org';
  '@type': 'WebPage';
  name: string;
  description: string;
  url: string;
};

export function buildVisitorWebPageJsonLd(input: {
  title: string;
  description?: string;
  slug: string;
}): VisitorWebPageJsonLd {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: input.title,
    description: input.description ?? '',
    url: input.slug === 'home' ? '/' : `/${input.slug}`,
  };
}

END_OF_FILE_CONTENT
mkdir -p "src/lib/css"
echo "Creating src/lib/css/serializeThemeRootCss.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/css/serializeThemeRootCss.test.ts"
import { describe, expect, it } from 'vitest';
import type { ThemeConfig } from '@olonjs/core';
import { serializeThemeRootCss } from './serializeThemeRootCss';

describe('serializeThemeRootCss', () => {
  it('emits :root --theme-* from theme.json (no CSS color literals as source)', () => {
    const theme = {
      name: 'test',
      tokens: {
        colors: { background: 'hsl(10 20% 30%)', foreground: 'hsl(0 0% 100%)' },
        typography: { fontFamily: { primary: 'Inter, sans-serif' } },
        borderRadius: {},
      },
    } as ThemeConfig;

    const css = serializeThemeRootCss(theme);
    expect(css).toContain('--theme-colors-background:hsl(10 20% 30%)');
    expect(css).toContain('--theme-colors-foreground:hsl(0 0% 100%)');
    expect(css).not.toContain('hsl(215 28% 7%)');
  });
});

END_OF_FILE_CONTENT
echo "Creating src/lib/css/serializeThemeRootCss.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/css/serializeThemeRootCss.ts"
import { buildThemeVariableMap, type ThemeConfig } from '@olonjs/core';

/** Publish theme.json as `:root{--theme-*}` (CIP / alpha entry-ssg parity). */
export function serializeThemeRootCss(theme: ThemeConfig): string {
  const mappings = buildThemeVariableMap(theme);
  const entries = Object.entries(mappings);
  if (entries.length === 0) return '';
  return `:root{${entries.map(([name, value]) => `${name}:${value}`).join(';')}}`;
}

END_OF_FILE_CONTENT
echo "Creating src/lib/dnaDistWiring.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/dnaDistWiring.test.ts"
import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { fileURLToPath } from 'node:url';

const appRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

describe('tenant-next DNA dist wiring', () => {
  it('has src2Code.sh and a dist script targeting template next', () => {
    const encoder = path.join(appRoot, 'src2Code.sh');
    expect(fs.existsSync(encoder)).toBe(true);

    const pkg = JSON.parse(fs.readFileSync(path.join(appRoot, 'package.json'), 'utf8')) as {
      scripts?: Record<string, string>;
    };
    const dist = pkg.scripts?.dist ?? '';
    expect(dist).toContain('src2Code.sh');
    expect(dist).toContain('--template next');
    expect(dist).toMatch(/\bapp\b/);
    expect(dist).toMatch(/\bsrc\b/);
    expect(pkg.scripts?.['dist:dna']).toBe('npm run dist');
  });
});

END_OF_FILE_CONTENT
echo "Creating src/lib/dnaTemplateNextAssets.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/dnaTemplateNextAssets.test.ts"
import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const templateDir = path.join(repoRoot, 'packages/cli/assets/templates/next');

describe('CLI template next DNA assets', () => {
  it('has src_tenant.sh + manifest with expected markers', () => {
    const dna = path.join(templateDir, 'src_tenant.sh');
    const manifestPath = path.join(templateDir, 'manifest.json');
    expect(fs.existsSync(dna)).toBe(true);
    expect(fs.existsSync(manifestPath)).toBe(true);

    const content = fs.readFileSync(dna, 'utf8');
    expect(content).toContain('set -e');
    expect(content).toContain('package.json');
    expect(content).toContain('middleware.ts');
    expect(content).toMatch(/app\//);

    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8')) as {
      name?: string;
      dnaScript?: string;
    };
    expect(manifest.name).toBe('next');
    expect(manifest.dnaScript).toBe('src_tenant.sh');
  });
});

END_OF_FILE_CONTENT
mkdir -p "src/lib/env"
echo "Creating src/lib/env/serverCloudPolicy.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/env/serverCloudPolicy.test.ts"
import { describe, expect, it } from 'vitest';
import { buildServerApiCandidates, readServerCloudPolicy } from './serverCloudPolicy';

describe('readServerCloudPolicy', () => {
  it('defaults to local without credentials', () => {
    expect(readServerCloudPolicy({}).bootSource).toBe('local');
  });

  it('selects live with credentials and Save2Repo off', () => {
    expect(
      readServerCloudPolicy({
        NEXT_PUBLIC_OLONJS_CLOUD_URL: 'https://api.example',
        NEXT_PUBLIC_OLONJS_API_KEY: 'k',
      }).bootSource,
    ).toBe('live');
  });

  it('selects static with credentials and Save2Repo on', () => {
    expect(
      readServerCloudPolicy({
        NEXT_PUBLIC_OLONJS_CLOUD_URL: 'https://api.example',
        NEXT_PUBLIC_OLONJS_API_KEY: 'k',
        NEXT_PUBLIC_SAVE2REPO: 'true',
      }).bootSource,
    ).toBe('static');
  });
});

describe('buildServerApiCandidates', () => {
  it('prefers /api/v1 and keeps raw base', () => {
    expect(buildServerApiCandidates('https://api.example')).toEqual([
      'https://api.example/api/v1',
      'https://api.example',
    ]);
  });
});

END_OF_FILE_CONTENT
echo "Creating src/lib/env/serverCloudPolicy.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/env/serverCloudPolicy.ts"
export type ServerCloudBootSource = 'local' | 'static' | 'live';

export type ServerCloudPolicy = {
  bootSource: ServerCloudBootSource;
  apiUrl: string;
  apiKey: string;
  save2RepoEnabled: boolean;
};

/**
 * Server-safe cloud policy (mirrors `@olonjs/react` resolveCloudPolicy).
 * Do not import `@olonjs/react` from Route Handlers — its package entry is client-bound.
 */
export function readServerCloudPolicy(
  env: Record<string, string | undefined> = process.env,
): ServerCloudPolicy {
  const apiUrl =
    (env.NEXT_PUBLIC_OLONJS_CLOUD_URL ?? env.NEXT_PUBLIC_JSONPAGES_CLOUD_URL ?? '').trim();
  const apiKey =
    (env.NEXT_PUBLIC_OLONJS_API_KEY ?? env.NEXT_PUBLIC_JSONPAGES_API_KEY ?? '').trim();
  const save2RepoRaw =
    env.NEXT_PUBLIC_OLONJS_SAVE2REPO ?? env.NEXT_PUBLIC_SAVE2REPO ?? '';
  const save2RepoFlag = save2RepoRaw === 'true';
  const isCloudMode = Boolean(apiUrl && apiKey);
  const save2RepoEnabled = isCloudMode && save2RepoFlag;

  let bootSource: ServerCloudBootSource = 'local';
  if (isCloudMode) {
    bootSource = save2RepoEnabled ? 'static' : 'live';
  }

  return { bootSource, apiUrl, apiKey, save2RepoEnabled };
}

/** Prefer …/api/v1, keep raw base as fallback (mirrors `@olonjs/react` buildApiCandidates). */
export function buildServerApiCandidates(raw: string): string[] {
  const base = raw.trim().replace(/\/+$/, '');
  if (!base) return [];
  const withApi = /\/api\/v1$/i.test(base) ? base : `${base}/api/v1`;
  return Array.from(new Set([withApi, base]));
}

END_OF_FILE_CONTENT
echo "Creating src/lib/env/tenantEnv.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/env/tenantEnv.test.ts"
import assert from 'node:assert/strict';
import { describe, it } from 'vitest';
import { getCloudPolicy, readCloudEnvFromNext } from './tenantEnv';

describe('readCloudEnvFromNext', () => {
  it('maps OLONJS public env to cloud + Save2Repo policy inputs', () => {
    const input = readCloudEnvFromNext({
      NEXT_PUBLIC_OLONJS_CLOUD_URL: ' https://api.example.com ',
      NEXT_PUBLIC_OLONJS_API_KEY: ' key ',
      NEXT_PUBLIC_OLONJS_SAVE2REPO: 'true',
    });
    assert.equal(input.apiUrl, 'https://api.example.com');
    assert.equal(input.apiKey, 'key');
    assert.equal(input.save2RepoFlag, true);
  });

  it('treats SAVE2REPO other than exact "true" as off', () => {
    const input = readCloudEnvFromNext({
      NEXT_PUBLIC_OLONJS_CLOUD_URL: 'https://api.example.com',
      NEXT_PUBLIC_OLONJS_API_KEY: 'key',
      NEXT_PUBLIC_OLONJS_SAVE2REPO: '1',
    });
    assert.equal(input.save2RepoFlag, false);
  });
});

describe('getCloudPolicy', () => {
  it('enables cold save and disables local save when credentials + Save2Repo', () => {
    const policy = getCloudPolicy({
      NEXT_PUBLIC_OLONJS_CLOUD_URL: 'https://api.example.com',
      NEXT_PUBLIC_OLONJS_API_KEY: 'key',
      NEXT_PUBLIC_OLONJS_SAVE2REPO: 'true',
    });
    assert.equal(policy.isCloudMode, true);
    assert.equal(policy.bootSource, 'static');
    assert.equal(policy.showLocalSave, false);
    assert.equal(policy.showColdSave, true);
  });

  it('stays local when credentials are missing', () => {
    const policy = getCloudPolicy({
      NEXT_PUBLIC_OLONJS_SAVE2REPO: 'true',
    });
    assert.equal(policy.isCloudMode, false);
    assert.equal(policy.showLocalSave, true);
    assert.equal(policy.showColdSave, false);
  });
});

END_OF_FILE_CONTENT
echo "Creating src/lib/env/tenantEnv.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/env/tenantEnv.ts"
import { resolveCloudPolicy, type CloudEnvInput, type CloudPolicy } from '@olonjs/react';

/**
 * Read Next.js public env → CloudEnvInput.
 * Prefer NEXT_PUBLIC_OLONJS_* ; also accept NEXT_PUBLIC_JSONPAGES_* and
 * NEXT_PUBLIC_SAVE2REPO (alpha-style flag name under the Next public prefix).
 *
 * CRITICAL: default path MUST use direct `process.env.NEXT_PUBLIC_*` property
 * access so the Next client bundler can inline values at build time.
 * Indexing via `const env = process.env; env.NEXT_PUBLIC_…` stays empty in the
 * browser → Studio always thinks it is Local → save-to-file → EROFS on Vercel.
 *
 * Pass `env` only in unit tests.
 */
export function readCloudEnvFromNext(
  env?: Record<string, string | undefined>,
): CloudEnvInput {
  if (env) {
    const apiUrl =
      (env.NEXT_PUBLIC_OLONJS_CLOUD_URL ?? env.NEXT_PUBLIC_JSONPAGES_CLOUD_URL ?? '').trim();
    const apiKey =
      (env.NEXT_PUBLIC_OLONJS_API_KEY ?? env.NEXT_PUBLIC_JSONPAGES_API_KEY ?? '').trim();
    const save2RepoRaw =
      env.NEXT_PUBLIC_OLONJS_SAVE2REPO ?? env.NEXT_PUBLIC_SAVE2REPO ?? '';
    return {
      apiUrl,
      apiKey,
      save2RepoFlag: save2RepoRaw === 'true',
    };
  }

  const apiUrl = (
    process.env.NEXT_PUBLIC_OLONJS_CLOUD_URL ??
    process.env.NEXT_PUBLIC_JSONPAGES_CLOUD_URL ??
    ''
  ).trim();
  const apiKey = (
    process.env.NEXT_PUBLIC_OLONJS_API_KEY ??
    process.env.NEXT_PUBLIC_JSONPAGES_API_KEY ??
    ''
  ).trim();
  const save2RepoRaw =
    process.env.NEXT_PUBLIC_OLONJS_SAVE2REPO ?? process.env.NEXT_PUBLIC_SAVE2REPO ?? '';

  return {
    apiUrl,
    apiKey,
    save2RepoFlag: save2RepoRaw === 'true',
  };
}

/** Resolve policy (call from client components; do not cache across env shapes in tests). */
export function getCloudPolicy(env?: Record<string, string | undefined>): CloudPolicy {
  return resolveCloudPolicy(readCloudEnvFromNext(env));
}

/** Module policy for the Next admin island (build-time inlined NEXT_PUBLIC_*). */
export const cloudPolicy: CloudPolicy = getCloudPolicy();

export const CLOUD_API_URL = cloudPolicy.apiUrl;
export const CLOUD_API_KEY = cloudPolicy.apiKey;
export const TENANT_ID = 'next';

END_OF_FILE_CONTENT
mkdir -p "src/lib/loaders"
echo "Creating src/lib/loaders/getFileCollections.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/getFileCollections.ts"
import fs from 'node:fs';
import path from 'node:path';
import type { JsonPagesConfig } from '@olonjs/core';
import { resolveLocalDataRoots } from '@olonjs/next/server';

type CollectionDocuments = NonNullable<JsonPagesConfig['collections']>;

/** Collection documents from src/data/collections/<source>/<source>.json. */
export function getFileCollections(appRoot = process.cwd()): CollectionDocuments {
  const { collectionsDir } = resolveLocalDataRoots(appRoot);
  const collections: CollectionDocuments = {};
  if (!fs.existsSync(collectionsDir)) return collections;

  for (const source of fs.readdirSync(collectionsDir, { withFileTypes: true })) {
    if (!source.isDirectory()) continue;
    const sourceName = source.name.trim();
    if (!sourceName) continue;
    const filePath = path.join(collectionsDir, sourceName, `${sourceName}.json`);
    if (!fs.existsSync(filePath)) continue;
    const raw = JSON.parse(fs.readFileSync(filePath, 'utf8')) as unknown;
    if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) continue;
    collections[sourceName] = raw as CollectionDocuments[string];
  }
  return collections;
}

END_OF_FILE_CONTENT
echo "Creating src/lib/loaders/getFilePages.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/getFilePages.ts"
import fs from 'node:fs';
import path from 'node:path';
import type { PageConfig } from '@olonjs/core';
import { resolveLocalDataRoots } from '@olonjs/next/server';

function slugFromRelative(relPath: string): string {
  const withoutExt = relPath.replace(/\.json$/i, '');
  const canonical = withoutExt
    .split(/[/\\]/)
    .map((segment) => segment.trim())
    .filter(Boolean)
    .join('/');
  return canonical || 'home';
}

function walkJsonFiles(dir: string, baseDir: string, out: string[]): void {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const abs = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walkJsonFiles(abs, baseDir, out);
      continue;
    }
    if (entry.isFile() && entry.name.toLowerCase().endsWith('.json')) {
      out.push(path.relative(baseDir, abs));
    }
  }
}

/** Page registry from nested JSON under src/data/pages (JSP). */
export function getFilePages(appRoot = process.cwd()): Record<string, PageConfig> {
  const { pagesDir } = resolveLocalDataRoots(appRoot);
  const relFiles: string[] = [];
  walkJsonFiles(pagesDir, pagesDir, relFiles);
  relFiles.sort((a, b) => a.localeCompare(b));

  const bySlug = new Map<string, PageConfig>();
  for (const rel of relFiles) {
    const abs = path.join(pagesDir, rel);
    const raw = JSON.parse(fs.readFileSync(abs, 'utf8')) as unknown;
    if (raw == null || typeof raw !== 'object') continue;
    const slug = slugFromRelative(rel);
    bySlug.set(slug, raw as PageConfig);
  }

  const slugs = Array.from(bySlug.keys()).sort((a, b) =>
    a === 'home' ? -1 : b === 'home' ? 1 : a.localeCompare(b),
  );
  const record: Record<string, PageConfig> = {};
  for (const slug of slugs) {
    const config = bySlug.get(slug);
    if (config) record[slug] = config;
  }
  return record;
}

END_OF_FILE_CONTENT
echo "Creating src/lib/loaders/getFileSiteConfig.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/getFileSiteConfig.ts"
import fs from 'node:fs';
import path from 'node:path';
import type { MenuConfig, SiteConfig, ThemeConfig } from '@olonjs/core';
import { resolveLocalDataRoots } from '@olonjs/next/server';

function readJson<T>(filePath: string, fallback: T): T {
  if (!fs.existsSync(filePath)) return fallback;
  return JSON.parse(fs.readFileSync(filePath, 'utf8')) as T;
}

export function getFileSiteBundle(appRoot = process.cwd()): {
  siteConfig: SiteConfig;
  menuConfig: MenuConfig;
  themeConfig: ThemeConfig;
} {
  const { configDir } = resolveLocalDataRoots(appRoot);
  return {
    siteConfig: readJson(
      path.join(configDir, 'site.json'),
      {
        identity: { title: 'OlonJS' },
        footer: { id: 'footer', type: 'footer', data: { brandText: 'OlonJS' } },
      } as unknown as SiteConfig,
    ),
    menuConfig: readJson<MenuConfig>(path.join(configDir, 'menu.json'), {}),
    themeConfig: readJson(path.join(configDir, 'theme.json'), {
      name: 'default',
      tokens: { colors: {}, typography: { fontFamily: {} }, borderRadius: {} },
    } as ThemeConfig),
  };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/loaders/loadLivePublicPageBundle.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/loadLivePublicPageBundle.test.ts"
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

END_OF_FILE_CONTENT
echo "Creating src/lib/loaders/loadLivePublicPageBundle.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/loadLivePublicPageBundle.ts"
import type { PublicPageContentBundle } from '@olonjs/next/server';
import { loadLivePublicPageContent } from '@olonjs/next/server';
import { CollectionRegistry } from '@/lib/CollectionRegistry';
import { getFileSiteBundle } from './getFileSiteConfig';

/**
 * Live public-page bundle: SPP render for one slug + local theme/schemas.
 */
export async function loadLivePublicPageBundle(input: {
  slug: string;
  apiBases: string[];
  apiKey: string;
  appRoot?: string;
  fetchImpl?: typeof fetch;
}): Promise<PublicPageContentBundle> {
  const appRoot = input.appRoot ?? process.cwd();
  const { themeConfig } = getFileSiteBundle(appRoot);
  const live = await loadLivePublicPageContent({
    slug: input.slug,
    apiBases: input.apiBases,
    apiKey: input.apiKey,
    fetchImpl: input.fetchImpl,
  });
  return {
    pages: live.pages,
    siteConfig: live.siteConfig,
    menuConfig: live.menuConfig,
    themeConfig,
    collectionSchemas: CollectionRegistry as PublicPageContentBundle['collectionSchemas'],
    refDocuments: {
      'menu.json': live.menuConfig,
      'config/menu.json': live.menuConfig,
      'src/data/config/menu.json': live.menuConfig,
    },
  };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/loaders/loadLocalPublicPageBundle.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/loadLocalPublicPageBundle.test.ts"
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

END_OF_FILE_CONTENT
echo "Creating src/lib/loaders/loadLocalPublicPageBundle.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/loadLocalPublicPageBundle.ts"
import type { PublicPageContentBundle } from '@olonjs/next/server';
import { CollectionRegistry } from '@/lib/CollectionRegistry';
import { getFileCollections } from './getFileCollections';
import { getFilePages } from './getFilePages';
import { getFileSiteBundle } from './getFileSiteConfig';

/** Local filesystem content bundle for public page JSON (Vite local parity). */
export function loadLocalPublicPageBundle(appRoot = process.cwd()): PublicPageContentBundle {
  const { siteConfig, menuConfig, themeConfig } = getFileSiteBundle(appRoot);
  return {
    pages: getFilePages(appRoot),
    siteConfig,
    themeConfig,
    menuConfig,
    collections: getFileCollections(appRoot),
    collectionSchemas: CollectionRegistry as PublicPageContentBundle['collectionSchemas'],
    refDocuments: {
      'menu.json': menuConfig,
      'config/menu.json': menuConfig,
      'src/data/config/menu.json': menuConfig,
    },
  };
}


END_OF_FILE_CONTENT
echo "Creating src/lib/loaders/loadPublicPageBundleForRequest.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/loadPublicPageBundleForRequest.test.ts"
import path from 'node:path';
import { describe, expect, it, vi } from 'vitest';

vi.mock('./loadLocalPublicPageBundle', () => ({
  loadLocalPublicPageBundle: vi.fn(() => ({
    pages: { home: { id: 'local', slug: 'home', meta: { title: 'Local' }, sections: [] } },
    siteConfig: { identity: { title: 'L' } },
    themeConfig: {},
    menuConfig: {},
  })),
}));

vi.mock('./loadStaticPublicPageBundle', () => ({
  loadStaticPublicPageBundle: vi.fn(async () => ({
    pages: { home: { id: 'static', slug: 'home', meta: { title: 'Static' }, sections: [] } },
    siteConfig: { identity: { title: 'S' } },
    themeConfig: {},
    menuConfig: {},
  })),
}));

vi.mock('./loadLivePublicPageBundle', () => ({
  loadLivePublicPageBundle: vi.fn(async () => ({
    pages: { home: { id: 'live', slug: 'home', meta: { title: 'Live' }, sections: [] } },
    siteConfig: { identity: { title: 'V' } },
    themeConfig: {},
    menuConfig: {},
  })),
}));

import { loadLocalPublicPageBundle } from './loadLocalPublicPageBundle';
import { loadStaticPublicPageBundle } from './loadStaticPublicPageBundle';
import { loadLivePublicPageBundle } from './loadLivePublicPageBundle';
import { loadPublicPageBundleForRequest } from './loadPublicPageBundleForRequest';

describe('loadPublicPageBundleForRequest', () => {
  const appRoot = path.resolve(__dirname, '../../..');

  it('selects Local when bootSource is local', async () => {
    const bundle = await loadPublicPageBundleForRequest({
      bootSource: 'local',
      slug: 'home',
      requestUrl: 'http://localhost:3000/home.json',
      appRoot,
    });
    expect(bundle.pages.home?.meta?.title).toBe('Local');
    expect(loadLocalPublicPageBundle).toHaveBeenCalled();
    expect(loadStaticPublicPageBundle).not.toHaveBeenCalled();
    expect(loadLivePublicPageBundle).not.toHaveBeenCalled();
  });

  it('selects Static when bootSource is static', async () => {
    const bundle = await loadPublicPageBundleForRequest({
      bootSource: 'static',
      slug: 'home',
      requestUrl: 'http://localhost:3000/home.json',
      appRoot,
      fetchImpl: vi.fn() as unknown as typeof fetch,
    });
    expect(bundle.pages.home?.meta?.title).toBe('Static');
    expect(loadStaticPublicPageBundle).toHaveBeenCalled();
  });

  it('selects Live when bootSource is live', async () => {
    const bundle = await loadPublicPageBundleForRequest({
      bootSource: 'live',
      slug: 'home',
      requestUrl: 'http://localhost:3000/home.json',
      appRoot,
      apiUrl: 'https://api.example',
      apiKey: 'k',
      fetchImpl: vi.fn() as unknown as typeof fetch,
    });
    expect(bundle.pages.home?.meta?.title).toBe('Live');
    expect(loadLivePublicPageBundle).toHaveBeenCalled();
  });
});

END_OF_FILE_CONTENT
echo "Creating src/lib/loaders/loadPublicPageBundleForRequest.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/loadPublicPageBundleForRequest.ts"
import type { PublicPageContentBundle } from '@olonjs/next/server';
import {
  buildServerApiCandidates,
  type ServerCloudBootSource,
} from '@/lib/env/serverCloudPolicy';
import { loadLivePublicPageBundle } from './loadLivePublicPageBundle';
import { loadLocalPublicPageBundle } from './loadLocalPublicPageBundle';
import { loadStaticPublicPageBundle } from './loadStaticPublicPageBundle';

export type LoadPublicPageBundleForRequestInput = {
  bootSource: ServerCloudBootSource;
  slug: string;
  /** Absolute request URL (used for Static same-origin base). */
  requestUrl: string;
  appRoot?: string;
  apiUrl?: string;
  apiKey?: string;
  fetchImpl?: typeof fetch;
};

/**
 * Select Local / Static / Live content bundle from server cloud policy bootSource.
 */
export async function loadPublicPageBundleForRequest(
  input: LoadPublicPageBundleForRequestInput,
): Promise<PublicPageContentBundle> {
  const appRoot = input.appRoot ?? process.cwd();

  if (input.bootSource === 'static') {
    const origin = new URL(input.requestUrl).origin;
    return loadStaticPublicPageBundle({
      baseUrl: `${origin}/`,
      appRoot,
      fetchImpl: input.fetchImpl,
    });
  }

  if (input.bootSource === 'live') {
    const apiUrl = (input.apiUrl ?? '').trim();
    const apiKey = (input.apiKey ?? '').trim();
    if (!apiUrl || !apiKey) {
      throw new Error('Live public page JSON requires cloud API URL and key');
    }
    return loadLivePublicPageBundle({
      slug: input.slug,
      apiBases: buildServerApiCandidates(apiUrl),
      apiKey,
      appRoot,
      fetchImpl: input.fetchImpl,
    });
  }

  return loadLocalPublicPageBundle(appRoot);
}

END_OF_FILE_CONTENT
echo "Creating src/lib/loaders/loadStaticPublicPageBundle.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/loadStaticPublicPageBundle.test.ts"
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

END_OF_FILE_CONTENT
echo "Creating src/lib/loaders/loadStaticPublicPageBundle.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/loaders/loadStaticPublicPageBundle.ts"
import type { PublicPageContentBundle } from '@olonjs/next/server';
import { loadPublishedStaticContent } from '@olonjs/next/server';
import { CollectionRegistry } from '@/lib/CollectionRegistry';
import { getFileCollections } from './getFileCollections';
import { getFilePages } from './getFilePages';
import { getFileSiteBundle } from './getFileSiteConfig';

/**
 * Static (Save2Repo) public-page bundle: published pages + site from baseUrl,
 * menu/theme/collections from local seeds (alpha bootStatic parity).
 */
export async function loadStaticPublicPageBundle(input: {
  baseUrl: string;
  appRoot?: string;
  fetchImpl?: typeof fetch;
}): Promise<PublicPageContentBundle> {
  const appRoot = input.appRoot ?? process.cwd();
  const knownSlugs = Object.keys(getFilePages(appRoot));
  const { pages, siteConfig } = await loadPublishedStaticContent({
    knownSlugs,
    baseUrl: input.baseUrl,
    fetchImpl: input.fetchImpl,
  });
  const { menuConfig, themeConfig } = getFileSiteBundle(appRoot);
  return {
    pages,
    siteConfig,
    themeConfig,
    menuConfig,
    collections: getFileCollections(appRoot),
    collectionSchemas: CollectionRegistry as PublicPageContentBundle['collectionSchemas'],
    refDocuments: {
      'menu.json': menuConfig,
      'config/menu.json': menuConfig,
      'src/data/config/menu.json': menuConfig,
    },
  };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/resolveVisitorShell.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/resolveVisitorShell.test.ts"
import { describe, expect, it } from 'vitest';
import type { PageConfig, SiteConfig } from '@olonjs/core';
import { resolveVisitorShell } from './resolveVisitorShell';

const site = {
  identity: { title: 'T' },
  header: { id: 'h', type: 'header', data: { logoText: 'Olon' } },
  footer: { id: 'f', type: 'footer', data: { brandText: 'OlonJS' } },
} as unknown as SiteConfig;

describe('resolveVisitorShell', () => {
  it('always returns footer when present on site', () => {
    const page = { id: 'p', slug: 'home', sections: [], 'global-header': false } as PageConfig;
    const shell = resolveVisitorShell(page, site);
    expect(shell.footer?.id).toBe('f');
    expect(shell.header).toBeNull();
  });

  it('shows header when global-header is absent (default true)', () => {
    const page = { id: 'p', slug: 'home', sections: [] } as PageConfig;
    const shell = resolveVisitorShell(page, site);
    expect(shell.header?.id).toBe('h');
    expect(shell.footer?.id).toBe('f');
  });

  it('shows header when global-header is true', () => {
    const page = { id: 'p', slug: 'home', sections: [], 'global-header': true } as PageConfig;
    expect(resolveVisitorShell(page, site).header?.id).toBe('h');
  });
});

END_OF_FILE_CONTENT
echo "Creating src/lib/resolveVisitorShell.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/resolveVisitorShell.ts"
import {
  shouldRenderSiteGlobalHeader,
  type PageConfig,
  type Section,
  type SiteConfig,
} from '@olonjs/core';

export type VisitorShellSections = {
  header: Section | null;
  footer: Section | null;
};

/**
 * Visitor chrome: footer always (when site has one); header gated by page `global-header`
 * (absent ⇒ true; false ⇒ hide). Uses core `shouldRenderSiteGlobalHeader`.
 */
export function resolveVisitorShell(page: PageConfig, site: SiteConfig): VisitorShellSections {
  const header =
    shouldRenderSiteGlobalHeader(page, site) && site.header != null ? (site.header as Section) : null;
  const footer = site.footer != null ? (site.footer as Section) : null;
  return { header, footer };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/schemas.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/schemas.ts"
import { AuthorsListSchema } from '@/components/authors-list';
import { BookDetailSchema } from '@/components/book-detail';
import { BooksListSchema } from '@/components/books-list';
import { EmptyTenantSchema } from '@/components/empty-tenant';
import { FooterSchema } from '@/components/footer';
import { FormDemoSchema, FormDemoSubmissionSchema } from '@/components/form-demo';
import { HeaderSchema } from '@/components/header';

export const SECTION_SCHEMAS = {
  'authors-list': AuthorsListSchema,
  'book-detail': BookDetailSchema,
  'books-list': BooksListSchema,
  'empty-tenant': EmptyTenantSchema,
  footer: FooterSchema,
  'form-demo': FormDemoSchema,
  header: HeaderSchema,
} as const;

/**
 * Registry of per-section-type submission schemas. Keys MUST match a key of
 * SECTION_SCHEMAS. A section type appearing here is declaring itself as
 * MCP-submittable: the Zod schema describes the payload accepted by the form.
 *
 * See ADR-0002 (docs/decisions/ADR-0002-form-submission-schemas.md).
 */
export const SECTION_SUBMISSION_SCHEMAS = {
  'form-demo': FormDemoSubmissionSchema,
} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseCollectionItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core';

END_OF_FILE_CONTENT
echo "Creating src/lib/utils.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/utils.ts"
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

END_OF_FILE_CONTENT
echo "Creating src/lib/visitorSurface.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/visitorSurface.test.ts"
import { describe, expect, it } from 'vitest';
import { VISITOR_SURFACE } from './visitorSurface';

describe('visitorSurface', () => {
  it('marks the public path as RSC (not a Studio client island)', () => {
    expect(VISITOR_SURFACE.mode).toBe('rsc');
    expect(VISITOR_SURFACE.loadsStudio).toBe(false);
  });
});

END_OF_FILE_CONTENT
echo "Creating src/lib/visitorSurface.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/visitorSurface.ts"
export const VISITOR_SURFACE = {
  mode: 'rsc' as const,
  loadsStudio: false,
};

END_OF_FILE_CONTENT
echo "Creating src/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/types.ts"
import type { AuthorsListData, AuthorsListSettings } from '@/components/authors-list';
import type { BookDetailData, BookDetailSettings } from '@/components/book-detail';
import type { BooksListData, BooksListSettings } from '@/components/books-list';
import type { EmptyTenantData, EmptyTenantSettings } from '@/components/empty-tenant';
import type { FooterData, FooterSettings } from '@/components/footer';
import type { FormDemoData, FormDemoSettings } from '@/components/form-demo';
import type { HeaderData, HeaderSettings } from '@/components/header';
import type { Autore } from '@/collections/autori';
import type { Libro } from '@/collections/libri';

export type SectionComponentPropsMap = {
  'authors-list': { data: AuthorsListData; settings?: AuthorsListSettings };
  'book-detail': { data: BookDetailData; settings?: BookDetailSettings };
  'books-list': { data: BooksListData; settings?: BooksListSettings };
  'empty-tenant': { data?: EmptyTenantData; settings?: EmptyTenantSettings };
  footer: { data: FooterData; settings?: FooterSettings };
  header: { data: HeaderData; settings?: HeaderSettings };
  'form-demo': { data: FormDemoData; settings?: FormDemoSettings };
};

declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    'authors-list': AuthorsListData;
    'book-detail': BookDetailData;
    'books-list': BooksListData;
    'empty-tenant': EmptyTenantData;
    footer: FooterData;
    header: HeaderData;
    'form-demo': FormDemoData;
  }
  export interface SectionSettingsRegistry {
    'authors-list': AuthorsListSettings;
    'book-detail': BookDetailSettings;
    'books-list': BooksListSettings;
    'empty-tenant': EmptyTenantSettings;
    footer: FooterSettings;
    header: HeaderSettings;
    'form-demo': FormDemoSettings;
  }
  export interface CollectionItemRegistry {
    autori: Autore;
    libri: Libro;
  }
}

export * from '@olonjs/core';

END_OF_FILE_CONTENT
mkdir -p "templates"
echo "Creating templates/generate_SystemsArchitect_next.sh..."
cat << 'END_OF_FILE_CONTENT' > "templates/generate_SystemsArchitect_next.sh"
#!/bin/bash
set -e

# Always operate in the tenant root (parent of templates/).
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# =============================================================================
# Andrew Linh — Portfolio & Blog (OlonJS v1.6 tenant-gen — Next harness)
# Neo-brutalist · dark-first · terminal green
# Typography: Instrument Sans + Instrument Serif + JetBrains Mono
# Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
# Lives in templates/; cds to tenant root (parent). Run from apps/next/templates/.
# No ThemeProvider — light/dark via document.documentElement.dataset.theme
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           ANDREW LINH — portfolio & editorial site           ║"
echo "║     systems architect · technical writer · Next harness      ║"
echo "║     CWD = tenant root ($(pwd))                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
# -----------------------------------------------------------------------------
# 0. SHADCN/UI INIT
# -----------------------------------------------------------------------------
echo "-- Step 0: shadcn/ui init..."
npm install class-variance-authority clsx tailwind-merge lucide-react
npm install react-markdown remark-gfm rehype-sanitize motion
# Non-interactive + force Radix (2026 default is Base UI — Views use asChild / radix APIs).
npx shadcn@latest init --yes --defaults --base radix --force
npx shadcn@latest add --yes --overwrite \
  button card badge separator avatar table tabs accordion dialog sheet tooltip \
  navigation-menu dropdown-menu hover-card breadcrumb skeleton progress input \
  label textarea select checkbox switch toggle toggle-group scroll-area aspect-ratio
echo "   shadcn/ui components installed"

# -----------------------------------------------------------------------------
# PREFLIGHT — Next App Router layout must exist
# -----------------------------------------------------------------------------
echo "-- Preflight: checking app/layout.tsx..."
if [[ -f app/layout.tsx ]]; then
  echo "   app/layout.tsx found"
else
  echo "!! app/layout.tsx NOT found — expected tenant root (parent of templates/); run from apps/next/templates/"
  exit 1
fi

# -----------------------------------------------------------------------------
# WIPE tenant content — no DNA name denylist (orphans break the compiler).
# Preserve: src/components/ui (shadcn), src/components/admin (studio).
# Wipe includes overlap dirs (e.g. header) — generators rewrite them fresh.
# -----------------------------------------------------------------------------
echo "-- Wiping tenant content surfaces (components/collections/pages/config)..."
if [[ -d src/components ]]; then
  find src/components -mindepth 1 -maxdepth 1 ! -name 'ui' ! -name 'admin' -exec rm -rf {} +
fi
rm -rf \
  src/collections \
  src/data/collections \
  src/data/pages \
  public/pages \
  public/collections
rm -f public/config/site.json
if [[ -d src/data/config ]]; then
  find src/data/config -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi

# Drop DNA special-cases so wiped capsules cannot break the visitor RSC path.
echo "-- Resetting VisitorSection to registry-only..."
mkdir -p src/lib
cat > src/lib/VisitorSection.tsx << 'EOF'
import type { FC } from 'react';
import type { Section, SectionType } from '@/types';
import { ComponentRegistry } from '@/lib/ComponentRegistry';

export type VisitorSectionExtras = {
  authorId?: string | null;
  page?: number;
  pathname?: string;
};

/** Render a resolved page section via the tenant ComponentRegistry (RSC path). */
export function VisitorSection({
  section,
}: {
  section: Section;
  extras?: VisitorSectionExtras;
}) {
  const type = section.type as SectionType;
  const Comp = ComponentRegistry[type];
  if (!Comp) {
    return (
      <section className="px-6 py-8 text-muted-foreground">
        Unknown section type: {String(section.type)}
      </section>
    );
  }

  const View = Comp as FC<{ data: unknown; settings?: unknown }>;
  return <View data={section.data} settings={section.settings} />;
}
EOF

# DNA catch-all imports EmptyTenantView — drop it after rm of that capsule.
if [[ -f 'app/[[...slug]]/page.tsx' ]]; then
  echo "-- Patching app/[[...slug]]/page.tsx empty fallback..."
  python3 - <<'PY'
from pathlib import Path
p = Path("app/[[...slug]]/page.tsx")
src = p.read_text()
capsule = "empty" + "-tenant"
src = src.replace(f"import {{ EmptyTenantView }} from '@/components/{capsule}';\n", "")
old = "  if (result.kind === 'empty') {\n    return <EmptyTenantView />;\n  }"
new = """  if (result.kind === 'empty') {
    return (
      <main className="mx-auto max-w-3xl px-8 py-24">
        <h1 className="text-2xl font-bold">Your tenant is empty.</h1>
        <p className="mt-2 text-muted-foreground">Create your first page.</p>
      </main>
    );
  }"""
if old not in src:
    raise SystemExit("EmptyTenantView empty-branch not found in page.tsx")
p.write_text(src.replace(old, new))
print("   page.tsx empty fallback inlined")
PY
fi

mkdir -p \
  src/components/{header,footer,home-hero,featured-projects,recent-posts,bio-band,cta-band,page-hero,about-story,skills-stack,philosophy,projects-list,project-detail,posts-list,post-detail,contact-form} \
  src/collections/{projects,posts} \
  src/data/collections/{projects,posts} \
  src/data/pages/{work,blog} \
  src/data/config src/lib

if [ -f src/lib/env/tenantEnv.ts ]; then
  sed -i "s/TENANT_ID = 'alpha'/TENANT_ID = 'al'/g" src/lib/env/tenantEnv.ts || true
fi

if [ -f src/lib/env/tenantEnv.ts ]; then
  sed -i "s/TENANT_ID = 'alpha'/TENANT_ID = 'al'/g" src/lib/env/tenantEnv.ts || true
  sed -i "s/TENANT_ID = 'next'/TENANT_ID = 'al'/g" src/lib/env/tenantEnv.ts || true
fi

# =============================================================================
# app/globals.css — fonts first line, semantic bridge, light mode, TOCC
# =============================================================================
echo "-- Writing app/globals.css..."
cat > app/globals.css << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=Instrument+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400&family=Instrument+Serif:ital@0;1&family=JetBrains+Mono:wght@400;500;600;700&display=swap');
@import "tailwindcss";
@source "../src/**/*.tsx";

@theme {
  --color-background:           var(--background);
  --color-foreground:           var(--foreground);
  --color-card:                 var(--card);
  --color-card-foreground:      var(--card-foreground);
  --color-primary:              var(--primary);
  --color-primary-foreground:   var(--primary-foreground);
  --color-secondary:            var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted:                var(--muted);
  --color-muted-foreground:     var(--muted-foreground);
  --color-accent:               var(--accent);
  --color-border:               var(--border);
  --radius-lg:                  var(--theme-radius-lg);
  --radius-md:                  var(--theme-radius-md);
  --radius-sm:                  var(--theme-radius-sm);
  --font-primary: var(--theme-font-primary);
  --font-mono:    var(--theme-font-mono);
  --font-display: var(--theme-font-display);
}

:root {
  --background:           var(--theme-colors-background);
  --foreground:           var(--theme-colors-foreground);
  --card:                 var(--theme-colors-card);
  --card-foreground:      var(--theme-colors-card-foreground);
  --elevated:             var(--theme-colors-elevated);
  --overlay:              var(--theme-colors-overlay);
  --primary:              var(--theme-colors-primary);
  --primary-foreground:   var(--theme-colors-primary-foreground);
  --primary-light:        var(--theme-colors-primary-light);
  --primary-dark:         var(--theme-colors-primary-dark);
  --secondary:            var(--theme-colors-secondary);
  --secondary-foreground: var(--theme-colors-secondary-foreground);
  --muted:                var(--theme-colors-muted);
  --muted-foreground:     var(--theme-colors-muted-foreground);
  --accent:               var(--theme-colors-accent);
  --accent-foreground:    var(--theme-colors-accent-foreground);
  --border:               var(--theme-colors-border);
  --border-strong:        var(--theme-colors-border-strong);
  --input:                var(--theme-colors-input);
  --ring:                 var(--theme-colors-ring);
  --destructive:          var(--theme-colors-destructive);
  --destructive-foreground: var(--theme-colors-destructive-foreground);
  --success:              var(--theme-colors-success);
  --success-foreground:   var(--theme-colors-success-foreground);
  --warning:              var(--theme-colors-warning);
  --warning-foreground:   var(--theme-colors-warning-foreground);
  --info:                 var(--theme-colors-info);
  --info-foreground:      var(--theme-colors-info-foreground);
  --radius:               var(--theme-radius-lg);
  --demo-surface:         color-mix(in oklch, var(--card) 86%, var(--background));
  --demo-surface-soft:    color-mix(in oklch, var(--card) 72%, var(--background));
  --demo-surface-strong:  color-mix(in oklch, var(--background) 82%, black);
  --demo-surface-deep:    color-mix(in oklch, var(--background) 70%, black);
  --demo-border-soft:     color-mix(in oklch, var(--foreground) 8%, transparent);
  --demo-border-strong:   color-mix(in oklch, var(--primary) 24%, transparent);
  --demo-accent-soft:     color-mix(in oklch, var(--primary) 10%, transparent);
  --demo-accent-strong:   color-mix(in oklch, var(--primary) 18%, transparent);
  --demo-text-soft:       color-mix(in oklch, var(--foreground) 88%, var(--muted-foreground));
  --demo-text-faint:      color-mix(in oklch, var(--muted-foreground) 72%, transparent);
}

[data-theme="light"] {
  --background:           var(--theme-modes-light-colors-background);
  --foreground:           var(--theme-modes-light-colors-foreground);
  --card:                 var(--theme-modes-light-colors-card);
  --card-foreground:      var(--theme-modes-light-colors-card-foreground);
  --elevated:             var(--theme-modes-light-colors-elevated);
  --overlay:              var(--theme-modes-light-colors-overlay);
  --primary:              var(--theme-modes-light-colors-primary);
  --primary-foreground:   var(--theme-modes-light-colors-primary-foreground);
  --primary-light:        var(--theme-modes-light-colors-primary-light);
  --primary-dark:         var(--theme-modes-light-colors-primary-dark);
  --secondary:            var(--theme-modes-light-colors-secondary);
  --secondary-foreground: var(--theme-modes-light-colors-secondary-foreground);
  --muted:                var(--theme-modes-light-colors-muted);
  --muted-foreground:     var(--theme-modes-light-colors-muted-foreground);
  --accent:               var(--theme-modes-light-colors-accent);
  --accent-foreground:    var(--theme-modes-light-colors-accent-foreground);
  --border:               var(--theme-modes-light-colors-border);
  --border-strong:        var(--theme-modes-light-colors-border-strong);
  --input:                var(--theme-modes-light-colors-input);
  --ring:                 var(--theme-modes-light-colors-ring);
  --destructive:          var(--theme-modes-light-colors-destructive);
  --destructive-foreground: var(--theme-modes-light-colors-destructive-foreground);
  --success:              var(--theme-modes-light-colors-success);
  --success-foreground:   var(--theme-modes-light-colors-success-foreground);
  --warning:              var(--theme-modes-light-colors-warning);
  --warning-foreground:   var(--theme-modes-light-colors-warning-foreground);
  --info:                 var(--theme-modes-light-colors-info);
  --info-foreground:      var(--theme-modes-light-colors-info-foreground);
}

@layer base {
  * { border-color: var(--border); }
  body {
    background-color: var(--background);
    color: var(--foreground);
    font-family: var(--font-primary);
    line-height: 1.7;
    overflow-x: hidden;
    @apply antialiased;
  }
}
.font-display { font-family: var(--font-display, var(--font-primary)); }
html { scroll-behavior: smooth; }
@keyframes jp-fadeUp { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
.jp-animate-in { opacity: 0; animation: jp-fadeUp 0.7s ease forwards; }
.jp-d1 { animation-delay: 0.1s; }
.jp-d2 { animation-delay: 0.2s; }
.jp-d3 { animation-delay: 0.3s; }
.jp-d4 { animation-delay: 0.4s; }
@keyframes jp-pulseDot { 0%, 100% { opacity: 1; transform: scale(1); } 50% { opacity: 0.5; transform: scale(0.85); } }
.jp-pulse-dot { animation: jp-pulseDot 2s ease infinite; }
[data-jp-section-overlay] { position: absolute; inset: 0; z-index: 9999; pointer-events: none; border: 2px solid transparent; transition: border-color 0.15s, background-color 0.15s; }
[data-section-id]:hover [data-jp-section-overlay] { border: 2px dashed color-mix(in oklch, var(--primary) 50%, transparent); background-color: color-mix(in oklch, var(--primary) 6%, transparent); }
[data-section-id][data-jp-selected] [data-jp-section-overlay] { border: 2px solid var(--primary); background-color: color-mix(in oklch, var(--primary) 10%, transparent); }
[data-jp-section-overlay] > div { position: absolute; top: 0; right: 0; padding: 0.2rem 0.55rem; font-size: 9px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.1em; background: var(--primary); color: #fff; opacity: 0; transition: opacity 0.15s; }
[data-section-id]:hover [data-jp-section-overlay] > div,
[data-section-id][data-jp-selected] [data-jp-section-overlay] > div { opacity: 1; }
EOF

# =============================================================================
# COLLECTIONS + IconResolver + CollectionRegistry
# =============================================================================
echo "-- Writing collections..."
cat > src/collections/projects/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseCollectionItem, ImageSelectionSchema } from '@olonjs/core';

export const ProjectSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  subtitle: z.string().describe('ui:text'),
  year: z.number().describe('ui:number'),
  role: z.string().describe('ui:text'),
  context: z.string().describe('ui:textarea'),
  problem: z.string().describe('ui:textarea'),
  architecture: z.string().describe('ui:textarea'),
  result: z.string().describe('ui:textarea'),
  stack: z.array(z.string()).default([]).describe('ui:list'),
  image: ImageSelectionSchema.optional(),
  tags: z.array(z.string()).default([]).describe('ui:list'),
  featured: z.boolean().default(false).describe('ui:checkbox'),
});
export const ProjectsCollectionSchema = z.record(z.string(), ProjectSchema);
EOF
cat > src/collections/projects/types.ts << 'EOF'
import { z } from 'zod';
import { ProjectSchema, ProjectsCollectionSchema } from './schema';
export type Project = z.infer<typeof ProjectSchema>;
export type ProjectsCollection = z.infer<typeof ProjectsCollectionSchema>;
EOF
cat > src/collections/projects/index.ts << 'EOF'
export { ProjectSchema, ProjectsCollectionSchema } from './schema';
export type { Project, ProjectsCollection } from './types';
EOF

cat > src/collections/posts/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseCollectionItem, ImageSelectionSchema } from '@olonjs/core';
export const PostSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  dek: z.string().describe('ui:textarea'),
  date: z.string().describe('ui:text'),
  readingTime: z.string().describe('ui:text'),
  tags: z.array(z.string()).default([]).describe('ui:list'),
  body: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
});
export const PostsCollectionSchema = z.record(z.string(), PostSchema);
EOF
cat > src/collections/posts/types.ts << 'EOF'
import { z } from 'zod';
import { PostSchema, PostsCollectionSchema } from './schema';
export type Post = z.infer<typeof PostSchema>;
export type PostsCollection = z.infer<typeof PostsCollectionSchema>;
EOF
cat > src/collections/posts/index.ts << 'EOF'
export { PostSchema, PostsCollectionSchema } from './schema';
export type { Post, PostsCollection } from './types';
EOF

cat > src/lib/CollectionRegistry.ts << 'EOF'
import { ProjectsCollectionSchema } from '@/collections/projects';
import { PostsCollectionSchema } from '@/collections/posts';
export const CollectionRegistry = {
  projects: ProjectsCollectionSchema,
  posts: PostsCollectionSchema,
} as const;
export type CollectionType = keyof typeof CollectionRegistry;
EOF

cat > src/lib/IconResolver.tsx << 'EOF'
import React from 'react';
import type { LucideIcon } from 'lucide-react';
import {
  ArrowRight, Boxes, Braces, Cloud, Code2, Cpu, Database, FileJson, GitBranch,
  Github, Linkedin, Mail, Menu, Moon, Rss, Server, Shield, Sun, Terminal, Workflow,
} from 'lucide-react';

export const iconMap: Record<string, LucideIcon> = {
  'arrow-right': ArrowRight, boxes: Boxes, braces: Braces, cloud: Cloud, code: Code2,
  cpu: Cpu, database: Database, 'file-json': FileJson, 'git-branch': GitBranch,
  github: Github, linkedin: Linkedin, mail: Mail, menu: Menu, moon: Moon, rss: Rss,
  server: Server, shield: Shield, sun: Sun, terminal: Terminal, workflow: Workflow,
};
export type IconName = keyof typeof iconMap;
export function isIconName(s: string): s is IconName { return s in iconMap; }
export const Icon: React.FC<{ name: string; size?: number; className?: string }> = ({ name, size = 20, className }) => {
  const C = isIconName(name) ? iconMap[name] : undefined;
  if (!C) return null;
  return <C size={size} className={className} />;
};
EOF

# =============================================================================
# CAPSULES — header / footer / home / about / work / blog / contact
# (Views use string concat instead of template literals for heredoc safety)
# =============================================================================
echo "-- Writing capsule: header..."
cat > src/components/header/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';
const HeaderMenuItemSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  isCta: z.boolean().optional().describe('ui:checkbox'),
});
export const HeaderSchema = BaseSectionData.extend({
  logoText: z.string().describe('ui:text'),
  logoHighlight: z.string().optional().describe('ui:text'),
  announcement: z.string().optional().describe('ui:text'),
  menu: z.array(HeaderMenuItemSchema).optional().describe('ui:list'),
});
EOF
cat > src/components/header/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { HeaderSchema } from './schema';
export type HeaderData = z.infer<typeof HeaderSchema>;
export type HeaderSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/header/View.tsx << 'EOF'
'use client';

// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Button } from '@/components/ui/button';
import { NavigationMenu, NavigationMenuItem, NavigationMenuLink, NavigationMenuList } from '@/components/ui/navigation-menu';
import { Sheet, SheetClose, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Menu, Moon, Sun } from 'lucide-react';
import type { HeaderData, HeaderSettings } from './types';

export const Header: React.FC<{ data: HeaderData; settings: HeaderSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];
  const [theme, setTheme] = React.useState<'light' | 'dark'>(() => {
    if (typeof document === 'undefined') return 'dark';
    return (document.documentElement.dataset.theme as 'light' | 'dark') || 'dark';
  });
  const toggleTheme = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    setTheme(next);
  };
  return (
    <header style={{ '--local-bg': 'color-mix(in oklch, var(--background) 90%, transparent)', '--local-text': 'var(--foreground)', '--local-border': 'var(--border)', '--local-surface': 'color-mix(in oklch, var(--card) 88%, transparent)', '--local-primary': 'var(--primary)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className="sticky top-0 z-10 border-b border-[var(--local-border)] bg-[var(--local-bg)]/95 backdrop-blur-xl">
      <div className="max-w-[1200px] mx-auto px-8">
        {data.announcement && <div className="border-b border-[var(--local-border)] py-2 text-center text-[0.72rem] font-mono uppercase tracking-[0.16em] text-[var(--local-text)]/70" data-jp-field="announcement">{data.announcement}</div>}
        <div className="flex h-20 items-center justify-between gap-6">
          <a href="/" className="flex items-baseline gap-2">
            <span className="font-display text-2xl tracking-tight text-[var(--local-text)]" data-jp-field="logoText">{data.logoText}</span>
            {data.logoHighlight && <span className="font-mono text-[0.72rem] uppercase tracking-[0.24em] text-[var(--local-primary)]" data-jp-field="logoHighlight">{data.logoHighlight}</span>}
          </a>
          <div className="hidden items-center gap-4 lg:flex">
            <NavigationMenu>
              <NavigationMenuList className="gap-1">
                {navItems.map((item, idx) => (
                  <NavigationMenuItem key={item.id || item.href + '-' + idx} data-jp-item-id={item.id || 'menu-' + idx} data-jp-item-field="menu">
                    <NavigationMenuLink href={item.href} className="rounded-[var(--local-radius-md)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:bg-[var(--local-surface)]">{item.label}</NavigationMenuLink>
                  </NavigationMenuItem>
                ))}
              </NavigationMenuList>
            </NavigationMenu>
            <Button type="button" variant="outline" onClick={toggleTheme} className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]">{theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}</Button>
          </div>
          <div className="flex items-center gap-3 lg:hidden">
            <Button type="button" variant="outline" onClick={toggleTheme} className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]">{theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}</Button>
            <Sheet>
              <SheetTrigger asChild><Button variant="outline" className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"><Menu className="h-4 w-4" /></Button></SheetTrigger>
              <SheetContent className="flex flex-col gap-0 bg-card text-foreground">
                <SheetHeader className="border-b border-border px-6 py-5"><SheetTitle className="font-display text-lg text-foreground">{data.logoText || 'Menu'}</SheetTitle></SheetHeader>
                <nav className="flex flex-1 flex-col divide-y divide-border overflow-y-auto">
                  {navItems.map((item, idx) => (
                    <SheetClose asChild key={item.id || item.href + '-m-' + idx}><a href={item.href} className="flex items-center px-6 py-4 text-base font-medium text-foreground hover:bg-muted">{item.label}</a></SheetClose>
                  ))}
                </nav>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </div>
    </header>
  );
};
EOF
cat > src/components/header/index.ts << 'EOF'
export { Header } from './View';
export { HeaderSchema } from './schema';
export type { HeaderData, HeaderSettings } from './types';
EOF

echo "-- Writing capsule: footer..."
cat > src/components/footer/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';
const FooterMenuItemSchema = BaseArrayItem.extend({ label: z.string().describe('ui:text'), href: z.string().describe('ui:text') });
const FooterSocialItemSchema = BaseArrayItem.extend({ label: z.string().describe('ui:text'), href: z.string().describe('ui:text'), icon: z.string().describe('ui:icon-picker') });
export const FooterSchema = BaseSectionData.extend({
  brandText: z.string().describe('ui:text'),
  brandHighlight: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  copyright: z.string().describe('ui:text'),
  menu: z.array(FooterMenuItemSchema).optional().describe('ui:list'),
  social: z.array(FooterSocialItemSchema).optional().describe('ui:list'),
});
EOF
cat > src/components/footer/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { FooterSchema } from './schema';
export type FooterData = z.infer<typeof FooterSchema>;
export type FooterSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/footer/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Separator } from '@/components/ui/separator';
import { Icon } from '@/lib/IconResolver';
import type { FooterData, FooterSettings } from './types';
export const Footer: React.FC<{ data: FooterData; settings: FooterSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];
  const socialItems = Array.isArray(data.social) ? data.social : [];
  return (
    <footer style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-border': 'var(--border)', '--local-primary': 'var(--primary)' } as React.CSSProperties} className="relative z-0 border-t border-[var(--local-border)] bg-[var(--local-bg)] py-20">
      <div className="max-w-[1200px] mx-auto px-8">
        <div className="grid gap-12 md:grid-cols-3">
          <div>
            <h3 className="font-display text-2xl text-[var(--local-text)]" data-jp-field="brandText">{data.brandText}</h3>
            {data.brandHighlight && <p className="mt-1 font-mono text-[0.7rem] uppercase tracking-[0.2em] text-[var(--local-primary)]" data-jp-field="brandHighlight">{data.brandHighlight}</p>}
            {data.description && <p className="mt-4 max-w-sm text-sm text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
          </div>
          <div>
            <p className="mb-4 font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--local-text-muted)]">Navigate</p>
            <nav className="flex flex-col gap-3">
              {navItems.map((item, idx) => (
                <a key={item.id || 'menu-' + idx} href={item.href} data-jp-item-id={item.id || 'menu-' + idx} data-jp-item-field="menu" className="text-sm text-[var(--local-text)] hover:text-[var(--local-primary)]">{item.label}</a>
              ))}
            </nav>
          </div>
          <div>
            <p className="mb-4 font-mono text-[0.7rem] uppercase tracking-[0.18em] text-[var(--local-text-muted)]">Social</p>
            <div className="flex flex-col gap-3">
              {socialItems.map((item, idx) => (
                <a key={item.id || 'social-' + idx} href={item.href} target="_blank" rel="noreferrer" data-jp-item-id={item.id || 'social-' + idx} data-jp-item-field="social" className="inline-flex items-center gap-2 text-sm text-[var(--local-text)] hover:text-[var(--local-primary)]"><Icon name={item.icon} size={16} /><span>{item.label}</span></a>
              ))}
            </div>
          </div>
        </div>
        <Separator className="my-10 bg-[var(--local-border)]" />
        <p className="font-mono text-xs text-[var(--local-text-muted)]" data-jp-field="copyright">{data.copyright}</p>
      </div>
    </footer>
  );
};
EOF
cat > src/components/footer/index.ts << 'EOF'
export { Footer } from './View';
export { FooterSchema } from './schema';
export type { FooterData, FooterSettings } from './types';
EOF

# Shared padding helper note: each capsule inlines PADDING maps per skill.

write_capsule_types() {
  local dir="$1" schema="$2" dataType="$3" settingsType="$4"
  cat > "src/components/${dir}/types.ts" << EOF
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ${schema} } from './schema';
export type ${dataType} = z.infer<typeof ${schema}>;
export type ${settingsType} = z.infer<typeof BaseSectionSettingsSchema>;
EOF
  cat > "src/components/${dir}/index.ts" << EOF
export { ${dataType%Data} } from './View';
export { ${schema} } from './schema';
export type { ${dataType}, ${settingsType} } from './types';
EOF
}

# --- home-hero ---
echo "-- Writing capsule: home-hero..."
cat > src/components/home-hero/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';
export const HomeHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  titleHighlight: z.string().optional().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema.optional(),
  secondaryCta: CtaSchema.optional(),
});
EOF
cat > src/components/home-hero/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { HomeHeroSchema } from './schema';
export type HomeHeroData = z.infer<typeof HomeHeroSchema>;
export type HomeHeroSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/home-hero/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { HomeHeroData, HomeHeroSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const HomeHero: React.FC<{ data: HomeHeroData; settings: HomeHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-border': 'var(--border)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="max-w-3xl jp-animate-in">
          {data.label && <div className="mb-6 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
          <h1 className="font-display font-black text-[clamp(3rem,6vw,5.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}{data.titleHighlight ? <>{' '}<em className="not-italic text-[var(--local-primary)]" data-jp-field="titleHighlight">{data.titleHighlight}</em></> : null}</h1>
          <p className="mt-8 max-w-2xl text-lg text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>
          <div className="mt-10 flex flex-wrap gap-4">
            {data.primaryCta && <Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5"><a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a></Button>}
            {data.secondaryCta && <Button asChild variant="outline" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5"><a href={data.secondaryCta.href} data-jp-field="secondaryCta">{data.secondaryCta.label}</a></Button>}
          </div>
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/home-hero/index.ts << 'EOF'
export { HomeHero } from './View';
export { HomeHeroSchema } from './schema';
export type { HomeHeroData, HomeHeroSettings } from './types';
EOF

# --- featured-projects ---
echo "-- Writing capsule: featured-projects..."
cat > src/components/featured-projects/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';
export const FeaturedProjectsSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  limit: z.number().default(4).describe('ui:number'),
  items: z.record(z.string(), ProjectSchema).describe('ui:collection-ref'),
});
EOF
cat > src/components/featured-projects/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { FeaturedProjectsSchema } from './schema';
export type FeaturedProjectsData = z.infer<typeof FeaturedProjectsSchema>;
export type FeaturedProjectsSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/featured-projects/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
import React, { useMemo } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { Project } from '@/collections/projects';
import type { FeaturedProjectsData, FeaturedProjectsSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const FeaturedProjects: React.FC<{ data: FeaturedProjectsData; settings: FeaturedProjectsSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const projects = useMemo(() => {
    const all = Object.values(data.items ?? {}) as Project[];
    const featured = all.filter((p) => p.featured).sort((a, b) => b.year - a.year);
    const source = featured.length > 0 ? featured : all.sort((a, b) => b.year - a.year);
    return source.slice(0, Math.max(1, data.limit || 4));
  }, [data.items, data.limit]);
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        {data.description && <p className="mt-4 max-w-2xl text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
        <div className="mt-12 grid gap-4 md:grid-cols-4 md:auto-rows-[220px]">
          {projects.map((project, idx) => {
            const span = idx === 0 ? 'md:col-span-2 md:row-span-2' : idx === 1 ? 'md:col-span-2' : 'md:col-span-1';
            return (
              <a key={project.id || 'legacy-' + idx} href={'/work/' + project.id} data-jp-item-id={project.id || 'legacy-' + idx} data-jp-item-field="items" className={span + ' block'}>
                <Card className="h-full rounded-[var(--local-radius-lg)] border-[var(--local-border)] bg-[var(--local-surface)] transition hover:border-[var(--local-primary)]">
                  <CardContent className="flex h-full flex-col justify-between p-6">
                    <div>
                      <p className="font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--local-primary)]">{project.year}</p>
                      <h3 className="mt-3 font-display font-bold text-[1.2rem] text-[var(--local-text)]">{project.title}</h3>
                      <p className="mt-3 text-sm text-[var(--local-text-muted)]">{project.subtitle}</p>
                    </div>
                    <p className="mt-6 font-mono text-xs text-[var(--local-text-muted)]">{project.role}</p>
                  </CardContent>
                </Card>
              </a>
            );
          })}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/featured-projects/index.ts << 'EOF'
export { FeaturedProjects } from './View';
export { FeaturedProjectsSchema } from './schema';
export type { FeaturedProjectsData, FeaturedProjectsSettings } from './types';
EOF

# --- recent-posts ---
echo "-- Writing capsule: recent-posts..."
cat > src/components/recent-posts/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';
export const RecentPostsSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  limit: z.number().default(3).describe('ui:number'),
  items: z.record(z.string(), PostSchema).describe('ui:collection-ref'),
});
EOF
cat > src/components/recent-posts/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { RecentPostsSchema } from './schema';
export type RecentPostsData = z.infer<typeof RecentPostsSchema>;
export type RecentPostsSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/recent-posts/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React, { useMemo } from 'react';
import type { Post } from '@/collections/posts';
import type { RecentPostsData, RecentPostsSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const RecentPosts: React.FC<{ data: RecentPostsData; settings: RecentPostsSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const posts = useMemo(() => (Object.values(data.items ?? {}) as Post[]).sort((a, b) => b.date.localeCompare(a.date)).slice(0, Math.max(1, data.limit || 3)), [data.items, data.limit]);
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        <div className="mt-10 flex gap-6 overflow-x-auto pb-4">
          {posts.map((post, idx) => (
            <a key={post.id || 'legacy-' + idx} href={'/blog/' + post.id} data-jp-item-id={post.id || 'legacy-' + idx} data-jp-item-field="items" className="min-w-[280px] max-w-sm flex-1 rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6 hover:border-[var(--local-primary)]">
              <div className="flex gap-3 font-mono text-[0.7rem] uppercase tracking-[0.14em] text-[var(--local-text-muted)]"><span>{post.date}</span><span className="text-[var(--local-primary)]">{post.readingTime}</span></div>
              <h3 className="mt-4 font-display font-bold text-[1.2rem] text-[var(--local-text)]">{post.title}</h3>
              <p className="mt-3 text-sm text-[var(--local-text-muted)]">{post.dek}</p>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/recent-posts/index.ts << 'EOF'
export { RecentPosts } from './View';
export { RecentPostsSchema } from './schema';
export type { RecentPostsData, RecentPostsSettings } from './types';
EOF

# --- bio-band ---
echo "-- Writing capsule: bio-band..."
cat > src/components/bio-band/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema, ImageSelectionSchema } from '@olonjs/core';
export const BioBandSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
  cta: CtaSchema.optional(),
});
EOF
cat > src/components/bio-band/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { BioBandSchema } from './schema';
export type BioBandData = z.infer<typeof BioBandSchema>;
export type BioBandSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/bio-band/View.tsx << 'EOF'
// Layout: Hero=A (SPLIT 60/40), Features=E (TABBED)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { BioBandData, BioBandSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const BioBand: React.FC<{ data: BioBandData; settings: BioBandSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="grid items-center gap-12 md:grid-cols-[1.4fr_1fr]">
          <div>
            {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
            <p className="mt-6 whitespace-pre-line text-base leading-relaxed text-[var(--local-text-muted)]" data-jp-field="body">{data.body}</p>
            {data.cta && <div className="mt-8"><Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5"><a href={data.cta.href} data-jp-field="cta">{data.cta.label}</a></Button></div>}
          </div>
          {data.image?.url && <div className="overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]"><img src={data.image.url} alt={data.image.alt || ''} className="aspect-[4/5] w-full object-cover" data-jp-field="image" /></div>}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/bio-band/index.ts << 'EOF'
export { BioBand } from './View';
export { BioBandSchema } from './schema';
export type { BioBandData, BioBandSettings } from './types';
EOF

# --- cta-band ---
echo "-- Writing capsule: cta-band..."
cat > src/components/cta-band/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';
export const CtaBandSchema = BaseSectionData.extend({
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  primaryCta: CtaSchema,
});
EOF
cat > src/components/cta-band/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { CtaBandSchema } from './schema';
export type CtaBandData = z.infer<typeof CtaBandSchema>;
export type CtaBandSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/cta-band/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=D (ACCORDION)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { CtaBandData, CtaBandSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const CtaBand: React.FC<{ data: CtaBandData; settings: CtaBandSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass + ' text-center'}>
        <h2 className="font-display font-black text-[clamp(3rem,7vw,6.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        {data.description && <p className="mx-auto mt-6 max-w-xl text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
        <div className="mt-10"><Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5"><a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a></Button></div>
      </div>
    </section>
  );
};
EOF
cat > src/components/cta-band/index.ts << 'EOF'
export { CtaBand } from './View';
export { CtaBandSchema } from './schema';
export type { CtaBandData, CtaBandSettings } from './types';
EOF

# --- page-hero ---
echo "-- Writing capsule: page-hero..."
cat > src/components/page-hero/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
export const PageHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
});
EOF
cat > src/components/page-hero/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PageHeroSchema } from './schema';
export type PageHeroData = z.infer<typeof PageHeroSchema>;
export type PageHeroSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/page-hero/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=C (TIMELINE)
import React from 'react';
import type { PageHeroData, PageHeroSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const PageHero: React.FC<{ data: PageHeroData; settings: PageHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass + ' max-w-3xl'}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h1 className="font-display font-black text-[clamp(2.5rem,5vw,4.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h1>
        {data.description && <p className="mt-6 text-lg text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
      </div>
    </section>
  );
};
EOF
cat > src/components/page-hero/index.ts << 'EOF'
export { PageHero } from './View';
export { PageHeroSchema } from './schema';
export type { PageHeroData, PageHeroSettings } from './types';
EOF

# --- about-story ---
echo "-- Writing capsule: about-story..."
cat > src/components/about-story/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, ImageSelectionSchema } from '@olonjs/core';
export const AboutStorySchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
});
EOF
cat > src/components/about-story/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { AboutStorySchema } from './schema';
export type AboutStoryData = z.infer<typeof AboutStorySchema>;
export type AboutStorySettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/about-story/View.tsx << 'EOF'
// Layout: Hero=D (EDITORIAL), Features=C (TIMELINE)
import React from 'react';
import type { AboutStoryData, AboutStorySettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const AboutStory: React.FC<{ data: AboutStoryData; settings: AboutStorySettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="grid gap-12 md:grid-cols-2 md:items-start">
          <div>
            {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
            <p className="mt-6 whitespace-pre-line text-base leading-relaxed text-[var(--local-text-muted)]" data-jp-field="body">{data.body}</p>
          </div>
          {data.image?.url && <div className="overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]"><img src={data.image.url} alt={data.image.alt || ''} className="aspect-square w-full object-cover" data-jp-field="image" /></div>}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/about-story/index.ts << 'EOF'
export { AboutStory } from './View';
export { AboutStorySchema } from './schema';
export type { AboutStoryData, AboutStorySettings } from './types';
EOF

# --- skills-stack ---
echo "-- Writing capsule: skills-stack..."
cat > src/components/skills-stack/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';
const SkillItemSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  category: z.string().optional().describe('ui:text'),
  icon: z.string().describe('ui:icon-picker'),
});
export const SkillsStackSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  items: z.array(SkillItemSchema).describe('ui:list'),
});
EOF
cat > src/components/skills-stack/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { SkillsStackSchema } from './schema';
export type SkillsStackData = z.infer<typeof SkillsStackSchema>;
export type SkillsStackSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/skills-stack/View.tsx << 'EOF'
// Layout: Hero=B (BENTO GRID), Features=A (BENTO)
import React from 'react';
import { Icon } from '@/lib/IconResolver';
import type { SkillsStackData, SkillsStackSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const SkillsStack: React.FC<{ data: SkillsStackData; settings: SkillsStackSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {data.items.map((item, idx) => (
            <div key={item.id || 'legacy-' + idx} data-jp-item-id={item.id || 'legacy-' + idx} data-jp-item-field="items" className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-5">
              <Icon name={item.icon} size={20} className="text-[var(--local-primary)]" />
              <h3 className="mt-4 font-display font-bold text-[1.05rem] text-[var(--local-text)]">{item.label}</h3>
              {item.category && <p className="mt-1 font-mono text-[0.7rem] uppercase tracking-[0.14em] text-[var(--local-text-muted)]">{item.category}</p>}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/skills-stack/index.ts << 'EOF'
export { SkillsStack } from './View';
export { SkillsStackSchema } from './schema';
export type { SkillsStackData, SkillsStackSettings } from './types';
EOF

# --- philosophy ---
echo "-- Writing capsule: philosophy..."
cat > src/components/philosophy/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';
const PhilosophyItemSchema = BaseArrayItem.extend({
  title: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea'),
});
export const PhilosophySchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  items: z.array(PhilosophyItemSchema).describe('ui:list'),
});
EOF
cat > src/components/philosophy/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PhilosophySchema } from './schema';
export type PhilosophyData = z.infer<typeof PhilosophySchema>;
export type PhilosophySettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/philosophy/View.tsx << 'EOF'
// Layout: Hero=E (MAGAZINE), Features=D (ACCORDION)
import React from 'react';
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/accordion';
import type { PhilosophyData, PhilosophySettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const Philosophy: React.FC<{ data: PhilosophyData; settings: PhilosophySettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass + ' max-w-3xl'}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        <Accordion type="single" collapsible className="mt-10 border-t border-[var(--local-border)]">
          {data.items.map((item, idx) => (
            <AccordionItem key={item.id || 'legacy-' + idx} value={item.id || 'item-' + idx} data-jp-item-id={item.id || 'legacy-' + idx} data-jp-item-field="items" className="border-[var(--local-border)]">
              <AccordionTrigger className="font-display text-left text-lg text-[var(--local-text)] hover:no-underline">{item.title}</AccordionTrigger>
              <AccordionContent className="text-[var(--local-text-muted)]">{item.body}</AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  );
};
EOF
cat > src/components/philosophy/index.ts << 'EOF'
export { Philosophy } from './View';
export { PhilosophySchema } from './schema';
export type { PhilosophyData, PhilosophySettings } from './types';
EOF

# --- projects-list ---
echo "-- Writing capsule: projects-list..."
cat > src/components/projects-list/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';
export const ProjectsListSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), ProjectSchema).describe('ui:collection-ref'),
});
EOF
cat > src/components/projects-list/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ProjectsListSchema } from './schema';
export type ProjectsListData = z.infer<typeof ProjectsListSchema>;
export type ProjectsListSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/projects-list/View.tsx << 'EOF'
// Layout: Hero=B (BENTO GRID), Features=A (BENTO)
import React, { useMemo } from 'react';
import type { Project } from '@/collections/projects';
import type { ProjectsListData, ProjectsListSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const ProjectsList: React.FC<{ data: ProjectsListData; settings: ProjectsListSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const projects = useMemo(() => (Object.values(data.items ?? {}) as Project[]).sort((a, b) => b.year - a.year), [data.items]);
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        {data.description && <p className="mt-4 max-w-2xl text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
        <div className="mt-12 grid gap-4 md:grid-cols-2">
          {projects.map((project, idx) => (
            <a key={project.id || 'legacy-' + idx} href={'/work/' + project.id} data-jp-item-id={project.id || 'legacy-' + idx} data-jp-item-field="items" className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-8 transition hover:border-[var(--local-primary)]">
              <p className="font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--local-primary)]">{project.year} · {project.role}</p>
              <h3 className="mt-3 font-display font-bold text-2xl text-[var(--local-text)]">{project.title}</h3>
              <p className="mt-3 text-sm text-[var(--local-text-muted)]">{project.subtitle}</p>
              <p className="mt-6 text-sm text-[var(--local-text-muted)] line-clamp-3">{project.result}</p>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/projects-list/index.ts << 'EOF'
export { ProjectsList } from './View';
export { ProjectsListSchema } from './schema';
export type { ProjectsListData, ProjectsListSettings } from './types';
EOF

# --- project-detail ---
echo "-- Writing capsule: project-detail..."
cat > src/components/project-detail/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';
export const ProjectDetailSchema = BaseSectionData.extend({
  item: ProjectSchema.describe('ui:collection-ref'),
  backLabel: z.string().default('Back to work').describe('ui:text'),
});
EOF
cat > src/components/project-detail/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ProjectDetailSchema } from './schema';
export type ProjectDetailData = z.infer<typeof ProjectDetailSchema>;
export type ProjectDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/project-detail/View.tsx << 'EOF'
// Layout: Hero=D (EDITORIAL), Features=C (TIMELINE)
import React from 'react';
import { Badge } from '@/components/ui/badge';
import type { ProjectDetailData, ProjectDetailSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const ProjectDetail: React.FC<{ data: ProjectDetailData; settings: ProjectDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const item = data.item;
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <a href="/work" className="font-mono text-xs uppercase tracking-[0.16em] text-[var(--local-primary)]" data-jp-field="backLabel">{data.backLabel}</a>
        <p className="mt-8 font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)]">{item.year} · {item.role}</p>
        <h1 className="mt-4 font-display font-black text-[clamp(2.5rem,5vw,4.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]">{item.title}</h1>
        <p className="mt-4 text-xl text-[var(--local-text-muted)]">{item.subtitle}</p>
        {item.image?.url && <div className="mt-10 overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]"><img src={item.image.url} alt={item.image.alt || ''} className="aspect-[21/9] w-full object-cover" /></div>}
        <div className="mt-12 grid gap-10 md:grid-cols-2">
          <div><h2 className="font-display text-xl text-[var(--local-text)]">Context</h2><p className="mt-3 text-[var(--local-text-muted)]">{item.context}</p></div>
          <div><h2 className="font-display text-xl text-[var(--local-text)]">Problem</h2><p className="mt-3 text-[var(--local-text-muted)]">{item.problem}</p></div>
          <div><h2 className="font-display text-xl text-[var(--local-text)]">Architecture</h2><p className="mt-3 text-[var(--local-text-muted)]">{item.architecture}</p></div>
          <div><h2 className="font-display text-xl text-[var(--local-text)]">Result</h2><p className="mt-3 text-[var(--local-text-muted)]">{item.result}</p></div>
        </div>
        <div className="mt-12">
          <h2 className="font-display text-xl text-[var(--local-text)]">Stack</h2>
          <div className="mt-4 flex flex-wrap gap-2">{(item.stack || []).map((s) => <Badge key={s} variant="outline" className="rounded-[var(--theme-radius-md)] border-[var(--local-border)] font-mono text-[0.7rem] uppercase tracking-[0.12em] text-[var(--local-text)]">{s}</Badge>)}</div>
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/project-detail/index.ts << 'EOF'
export { ProjectDetail } from './View';
export { ProjectDetailSchema } from './schema';
export type { ProjectDetailData, ProjectDetailSettings } from './types';
EOF

# --- posts-list ---
echo "-- Writing capsule: posts-list..."
cat > src/components/posts-list/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';
export const PostsListSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), PostSchema).describe('ui:collection-ref'),
});
EOF
cat > src/components/posts-list/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PostsListSchema } from './schema';
export type PostsListData = z.infer<typeof PostsListSchema>;
export type PostsListSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/posts-list/View.tsx << 'EOF'
// Layout: Hero=E (MAGAZINE), Features=B (HORIZONTAL SCROLL)
import React, { useMemo } from 'react';
import type { Post } from '@/collections/posts';
import type { PostsListData, PostsListSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const PostsList: React.FC<{ data: PostsListData; settings: PostsListSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const posts = useMemo(() => (Object.values(data.items ?? {}) as Post[]).sort((a, b) => b.date.localeCompare(a.date)), [data.items]);
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        {data.description && <p className="mt-4 max-w-2xl text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
        <div className="mt-12 divide-y divide-[var(--local-border)] border-y border-[var(--local-border)]">
          {posts.map((post, idx) => (
            <a key={post.id || 'legacy-' + idx} href={'/blog/' + post.id} data-jp-item-id={post.id || 'legacy-' + idx} data-jp-item-field="items" className="grid gap-4 py-8 transition hover:opacity-80 md:grid-cols-[180px_1fr]">
              <div className="font-mono text-[0.7rem] uppercase tracking-[0.14em] text-[var(--local-text-muted)]"><div>{post.date}</div><div className="mt-1 text-[var(--local-primary)]">{post.readingTime}</div></div>
              <div><h3 className="font-display font-bold text-2xl text-[var(--local-text)]">{post.title}</h3><p className="mt-3 text-[var(--local-text-muted)]">{post.dek}</p></div>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/posts-list/index.ts << 'EOF'
export { PostsList } from './View';
export { PostsListSchema } from './schema';
export type { PostsListData, PostsListSettings } from './types';
EOF

# --- post-detail ---
echo "-- Writing capsule: post-detail..."
cat > src/components/post-detail/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';
export const PostDetailSchema = BaseSectionData.extend({
  item: PostSchema.describe('ui:collection-ref'),
  backLabel: z.string().default('Back to blog').describe('ui:text'),
});
EOF
cat > src/components/post-detail/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PostDetailSchema } from './schema';
export type PostDetailData = z.infer<typeof PostDetailSchema>;
export type PostDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/post-detail/View.tsx << 'EOF'
// Layout: Hero=D (EDITORIAL), Features=E (TABBED)
import React from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeSanitize from 'rehype-sanitize';
import { Badge } from '@/components/ui/badge';
import type { PostDetailData, PostDetailSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const PostDetail: React.FC<{ data: PostDetailData; settings: PostDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const item = data.item;
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-border': 'var(--border)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass + ' max-w-3xl'}>
        <a href="/blog" className="font-mono text-xs uppercase tracking-[0.16em] text-[var(--local-primary)]" data-jp-field="backLabel">{data.backLabel}</a>
        <div className="mt-8 flex flex-wrap gap-3 font-mono text-[0.7rem] uppercase tracking-[0.14em] text-[var(--local-text-muted)]"><span>{item.date}</span><span className="text-[var(--local-primary)]">{item.readingTime}</span></div>
        <h1 className="mt-4 font-display font-black text-[clamp(2.5rem,5vw,4.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]">{item.title}</h1>
        <p className="mt-6 text-xl text-[var(--local-text-muted)]">{item.dek}</p>
        <div className="mt-4 flex flex-wrap gap-2">{(item.tags || []).map((tag) => <Badge key={tag} variant="outline" className="rounded-[var(--theme-radius-md)] border-[var(--local-border)] font-mono text-[0.65rem] uppercase tracking-[0.12em]">{tag}</Badge>)}</div>
        {item.image?.url && <div className="mt-10 overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]"><img src={item.image.url} alt={item.image.alt || ''} className="aspect-[16/9] w-full object-cover" /></div>}
        <article className="prose prose-invert mt-12 max-w-none text-[var(--local-text)] [&_h2]:font-display [&_h2]:text-2xl [&_h2]:mt-10 [&_p]:text-[var(--local-text-muted)] [&_p]:leading-relaxed [&_code]:font-mono [&_code]:text-[var(--local-primary)]">
          <ReactMarkdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeSanitize]}>{item.body}</ReactMarkdown>
        </article>
      </div>
    </section>
  );
};
EOF
cat > src/components/post-detail/index.ts << 'EOF'
export { PostDetail } from './View';
export { PostDetailSchema } from './schema';
export type { PostDetailData, PostDetailSettings } from './types';
EOF

# --- contact-form ---
echo "-- Writing capsule: contact-form..."
cat > src/components/contact-form/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseArrayItem, BaseSectionData, WithFormRecipient } from '@olonjs/core';
const SocialLinkSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  icon: z.string().describe('ui:icon-picker'),
});
export const ContactFormSchema = BaseSectionData.merge(WithFormRecipient).extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  submitLabel: z.string().default('Send message').describe('ui:text'),
  successMessage: z.string().default('Message sent. I will reply soon.').describe('ui:text'),
  social: z.array(SocialLinkSchema).optional().describe('ui:list'),
});
export const ContactFormSubmissionSchema = z.object({
  name: z.string().min(1).describe('Full name'),
  email: z.string().email().describe('Reply email'),
  message: z.string().min(1).describe('Message body'),
});
EOF
cat > src/components/contact-form/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ContactFormSchema } from './schema';
export type ContactFormData = z.infer<typeof ContactFormSchema>;
export type ContactFormSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF
cat > src/components/contact-form/View.tsx << 'EOF'
'use client';

// Layout: Hero=F (MINIMAL HERO), Features=D (ACCORDION)
import React from 'react';
import { useFormState } from '@olonjs/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Icon } from '@/lib/IconResolver';
import type { ContactFormData, ContactFormSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const ContactForm: React.FC<{ data: ContactFormData; settings: ContactFormSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const formId = data.anchorId?.trim() || 'contact-form';
  const { status, message } = useFormState(formId);
  const socialItems = Array.isArray(data.social) ? data.social : [];
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-md': 'var(--theme-radius-md)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="grid gap-12 md:grid-cols-2">
          <div>
            {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
            {data.description && <p className="mt-4 text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
            <div className="mt-8 flex flex-col gap-3">
              {socialItems.map((item, idx) => (
                <a key={item.id || 'social-' + idx} href={item.href} target="_blank" rel="noreferrer" data-jp-item-id={item.id || 'social-' + idx} data-jp-item-field="social" className="inline-flex items-center gap-2 text-sm text-[var(--local-text)] hover:text-[var(--local-primary)]"><Icon name={item.icon} size={16} /><span>{item.label}</span></a>
              ))}
            </div>
          </div>
          <form id={formId} data-olon-recipient={data.recipientEmail ?? ''} className="space-y-4 rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6">
            <div><Label htmlFor={formId + '-name'} className="text-[var(--local-text-muted)]">Name</Label><Input id={formId + '-name'} name="name" required className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <div><Label htmlFor={formId + '-email'} className="text-[var(--local-text-muted)]">Email</Label><Input id={formId + '-email'} name="email" type="email" required className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <div><Label htmlFor={formId + '-message'} className="text-[var(--local-text-muted)]">Message</Label><Textarea id={formId + '-message'} name="message" required rows={6} className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <Button type="submit" variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5" data-jp-field="submitLabel">{data.submitLabel}</Button>
            {status === 'success' && <p className="text-sm text-[var(--local-primary)]" data-jp-field="successMessage">{data.successMessage}</p>}
            {status === 'error' && <p className="text-sm text-destructive">{message || 'Something went wrong.'}</p>}
          </form>
        </div>
      </div>
    </section>
  );
};
EOF
cat > src/components/contact-form/index.ts << 'EOF'
export { ContactForm } from './View';
export { ContactFormSchema, ContactFormSubmissionSchema } from './schema';
export type { ContactFormData, ContactFormSettings } from './types';
EOF

# =============================================================================
# WIRING — types / registry / schemas / addSectionConfig
# =============================================================================
echo "-- Writing src/types.ts..."
cat > src/types.ts << 'EOF'
import type { HeaderData, HeaderSettings } from '@/components/header';
import type { FooterData, FooterSettings } from '@/components/footer';
import type { HomeHeroData, HomeHeroSettings } from '@/components/home-hero';
import type { FeaturedProjectsData, FeaturedProjectsSettings } from '@/components/featured-projects';
import type { RecentPostsData, RecentPostsSettings } from '@/components/recent-posts';
import type { BioBandData, BioBandSettings } from '@/components/bio-band';
import type { CtaBandData, CtaBandSettings } from '@/components/cta-band';
import type { PageHeroData, PageHeroSettings } from '@/components/page-hero';
import type { AboutStoryData, AboutStorySettings } from '@/components/about-story';
import type { SkillsStackData, SkillsStackSettings } from '@/components/skills-stack';
import type { PhilosophyData, PhilosophySettings } from '@/components/philosophy';
import type { ProjectsListData, ProjectsListSettings } from '@/components/projects-list';
import type { ProjectDetailData, ProjectDetailSettings } from '@/components/project-detail';
import type { PostsListData, PostsListSettings } from '@/components/posts-list';
import type { PostDetailData, PostDetailSettings } from '@/components/post-detail';
import type { ContactFormData, ContactFormSettings } from '@/components/contact-form';
import type { Project } from '@/collections/projects';
import type { Post } from '@/collections/posts';

export type SectionComponentPropsMap = {
  header: { data: HeaderData; settings: HeaderSettings };
  footer: { data: FooterData; settings: FooterSettings };
  'home-hero': { data: HomeHeroData; settings: HomeHeroSettings };
  'featured-projects': { data: FeaturedProjectsData; settings: FeaturedProjectsSettings };
  'recent-posts': { data: RecentPostsData; settings: RecentPostsSettings };
  'bio-band': { data: BioBandData; settings: BioBandSettings };
  'cta-band': { data: CtaBandData; settings: CtaBandSettings };
  'page-hero': { data: PageHeroData; settings: PageHeroSettings };
  'about-story': { data: AboutStoryData; settings: AboutStorySettings };
  'skills-stack': { data: SkillsStackData; settings: SkillsStackSettings };
  philosophy: { data: PhilosophyData; settings: PhilosophySettings };
  'projects-list': { data: ProjectsListData; settings: ProjectsListSettings };
  'project-detail': { data: ProjectDetailData; settings: ProjectDetailSettings };
  'posts-list': { data: PostsListData; settings: PostsListSettings };
  'post-detail': { data: PostDetailData; settings: PostDetailSettings };
  'contact-form': { data: ContactFormData; settings: ContactFormSettings };
};

declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    header: HeaderData;
    footer: FooterData;
    'home-hero': HomeHeroData;
    'featured-projects': FeaturedProjectsData;
    'recent-posts': RecentPostsData;
    'bio-band': BioBandData;
    'cta-band': CtaBandData;
    'page-hero': PageHeroData;
    'about-story': AboutStoryData;
    'skills-stack': SkillsStackData;
    philosophy: PhilosophyData;
    'projects-list': ProjectsListData;
    'project-detail': ProjectDetailData;
    'posts-list': PostsListData;
    'post-detail': PostDetailData;
    'contact-form': ContactFormData;
  }
  export interface SectionSettingsRegistry {
    header: HeaderSettings;
    footer: FooterSettings;
    'home-hero': HomeHeroSettings;
    'featured-projects': FeaturedProjectsSettings;
    'recent-posts': RecentPostsSettings;
    'bio-band': BioBandSettings;
    'cta-band': CtaBandSettings;
    'page-hero': PageHeroSettings;
    'about-story': AboutStorySettings;
    'skills-stack': SkillsStackSettings;
    philosophy: PhilosophySettings;
    'projects-list': ProjectsListSettings;
    'project-detail': ProjectDetailSettings;
    'posts-list': PostsListSettings;
    'post-detail': PostDetailSettings;
    'contact-form': ContactFormSettings;
  }
  export interface CollectionItemRegistry {
    projects: Project;
    posts: Post;
  }
}

export * from '@olonjs/core';
EOF

echo "-- Writing ComponentRegistry / schemas / addSectionConfig..."
cat > src/lib/ComponentRegistry.tsx << 'EOF'
import type { SectionType } from '@/types';
import type { SectionComponentPropsMap } from '@/types';
import { Header } from '@/components/header';
import { Footer } from '@/components/footer';
import { HomeHero } from '@/components/home-hero';
import { FeaturedProjects } from '@/components/featured-projects';
import { RecentPosts } from '@/components/recent-posts';
import { BioBand } from '@/components/bio-band';
import { CtaBand } from '@/components/cta-band';
import { PageHero } from '@/components/page-hero';
import { AboutStory } from '@/components/about-story';
import { SkillsStack } from '@/components/skills-stack';
import { Philosophy } from '@/components/philosophy';
import { ProjectsList } from '@/components/projects-list';
import { ProjectDetail } from '@/components/project-detail';
import { PostsList } from '@/components/posts-list';
import { PostDetail } from '@/components/post-detail';
import { ContactForm } from '@/components/contact-form';

export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = {
  header: Header,
  footer: Footer,
  'home-hero': HomeHero,
  'featured-projects': FeaturedProjects,
  'recent-posts': RecentPosts,
  'bio-band': BioBand,
  'cta-band': CtaBand,
  'page-hero': PageHero,
  'about-story': AboutStory,
  'skills-stack': SkillsStack,
  philosophy: Philosophy,
  'projects-list': ProjectsList,
  'project-detail': ProjectDetail,
  'posts-list': PostsList,
  'post-detail': PostDetail,
  'contact-form': ContactForm,
};
EOF

cat > src/lib/schemas.ts << 'EOF'
import { HeaderSchema } from '@/components/header';
import { FooterSchema } from '@/components/footer';
import { HomeHeroSchema } from '@/components/home-hero';
import { FeaturedProjectsSchema } from '@/components/featured-projects';
import { RecentPostsSchema } from '@/components/recent-posts';
import { BioBandSchema } from '@/components/bio-band';
import { CtaBandSchema } from '@/components/cta-band';
import { PageHeroSchema } from '@/components/page-hero';
import { AboutStorySchema } from '@/components/about-story';
import { SkillsStackSchema } from '@/components/skills-stack';
import { PhilosophySchema } from '@/components/philosophy';
import { ProjectsListSchema } from '@/components/projects-list';
import { ProjectDetailSchema } from '@/components/project-detail';
import { PostsListSchema } from '@/components/posts-list';
import { PostDetailSchema } from '@/components/post-detail';
import { ContactFormSchema, ContactFormSubmissionSchema } from '@/components/contact-form';

export const SECTION_SCHEMAS = {
  header: HeaderSchema,
  footer: FooterSchema,
  'home-hero': HomeHeroSchema,
  'featured-projects': FeaturedProjectsSchema,
  'recent-posts': RecentPostsSchema,
  'bio-band': BioBandSchema,
  'cta-band': CtaBandSchema,
  'page-hero': PageHeroSchema,
  'about-story': AboutStorySchema,
  'skills-stack': SkillsStackSchema,
  philosophy: PhilosophySchema,
  'projects-list': ProjectsListSchema,
  'project-detail': ProjectDetailSchema,
  'posts-list': PostsListSchema,
  'post-detail': PostDetailSchema,
  'contact-form': ContactFormSchema,
} as const;

export const SECTION_SUBMISSION_SCHEMAS = {
  'contact-form': ContactFormSubmissionSchema,
} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseCollectionItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core';
EOF

cat > src/lib/addSectionConfig.ts << 'EOF'
import type { AddSectionConfig } from '@olonjs/core';

const addableSectionTypes = [
  'home-hero', 'featured-projects', 'recent-posts', 'bio-band', 'cta-band',
  'page-hero', 'about-story', 'skills-stack', 'philosophy', 'projects-list',
  'project-detail', 'posts-list', 'post-detail', 'contact-form',
] as const;

const sectionTypeLabels: Record<string, string> = {
  'home-hero': 'Home Hero',
  'featured-projects': 'Featured Projects',
  'recent-posts': 'Recent Posts',
  'bio-band': 'Bio Band',
  'cta-band': 'CTA Band',
  'page-hero': 'Page Hero',
  'about-story': 'About Story',
  'skills-stack': 'Skills Stack',
  philosophy: 'Philosophy',
  'projects-list': 'Projects List',
  'project-detail': 'Project Detail',
  'posts-list': 'Posts List',
  'post-detail': 'Post Detail',
  'contact-form': 'Contact Form',
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'home-hero': return { title: 'Headline', description: 'Positioning line.', primaryCta: { id: 'cta-1', label: 'Contact', href: '/contact', variant: 'primary' } };
    case 'featured-projects': return { title: 'Selected work', limit: 4, items: { $ref: '../collections/projects/projects.json' } };
    case 'recent-posts': return { title: 'Writing', limit: 3, items: { $ref: '../collections/posts/posts.json' } };
    case 'bio-band': return { title: 'About', body: 'Short bio.' };
    case 'cta-band': return { title: 'Get in touch', primaryCta: { id: 'cta-1', label: 'Contact', href: '/contact', variant: 'primary' } };
    case 'page-hero': return { title: 'Page title' };
    case 'about-story': return { title: 'Story', body: 'Career path.' };
    case 'skills-stack': return { title: 'Stack', items: [] };
    case 'philosophy': return { title: 'Principles', items: [] };
    case 'projects-list': return { title: 'Work', items: { $ref: '../collections/projects/projects.json' } };
    case 'project-detail': return { item: { $ref: 'collection:current' }, backLabel: 'Back to work' };
    case 'posts-list': return { title: 'Blog', items: { $ref: '../collections/posts/posts.json' } };
    case 'post-detail': return { item: { $ref: 'collection:current' }, backLabel: 'Back to blog' };
    case 'contact-form': return { title: 'Contact', submitLabel: 'Send message', successMessage: 'Message sent.', social: [] };
    default: return {};
  }
}

export const addSectionConfig: AddSectionConfig = {
  addableSectionTypes: [...addableSectionTypes],
  sectionTypeLabels,
  getDefaultSectionData,
};
EOF

# =============================================================================
# DATA — theme / site / menu / collections / pages
# =============================================================================
echo "-- Writing theme.json / site.json / menu.json..."
cat > src/data/config/theme.json << 'EOF'
{
  "name": "Andrew Linh",
  "tokens": {
    "colors": {
      "background": "#0a0a0a",
      "foreground": "#e8e8e6",
      "card": "#111111",
      "card-foreground": "#e8e8e6",
      "elevated": "#161616",
      "overlay": "#1c1c1c",
      "primary": "#3ddc84",
      "primary-foreground": "#06140c",
      "primary-light": "#6ee7a8",
      "primary-dark": "#22a35c",
      "accent": "#141414",
      "accent-foreground": "#e8e8e6",
      "secondary": "#151515",
      "secondary-foreground": "#e8e8e6",
      "muted": "#151515",
      "muted-foreground": "#8a8a86",
      "border": "#242424",
      "border-strong": "#333333",
      "input": "#242424",
      "ring": "#3ddc84",
      "destructive": "#b33a3a",
      "destructive-foreground": "#f5e9e9",
      "success": "#1f8a55",
      "success-foreground": "#e8e8e6",
      "warning": "#8a6b12",
      "warning-foreground": "#e8e8e6",
      "info": "#2a6f9a",
      "info-foreground": "#e8e8e6"
    },
    "typography": {
      "fontFamily": {
        "primary": "'Instrument Sans', system-ui, sans-serif",
        "mono": "'JetBrains Mono', monospace",
        "display": "'Instrument Serif', system-ui, serif"
      },
      "wordmark": {
        "fontFamily": "'Instrument Serif', system-ui, serif",
        "weight": "700"
      }
    },
    "borderRadius": { "sm": "2px", "md": "4px", "lg": "6px", "xl": "10px", "full": "9999px" },
    "spacing": {
      "container-max": "1200px",
      "section-y": "96px",
      "header-h": "80px",
      "sidebar-w": "240px"
    },
    "zIndex": {
      "base": "0", "elevated": "10", "dropdown": "100",
      "sticky": "200", "overlay": "300", "modal": "400", "toast": "500"
    },
    "modes": {
      "light": {
        "colors": {
          "background": "#f7f7f5",
          "foreground": "#121212",
          "card": "#ffffff",
          "card-foreground": "#121212",
          "elevated": "#efefec",
          "overlay": "#e4e4e0",
          "primary": "#0f7a45",
          "primary-foreground": "#f4fff8",
          "primary-light": "#1aa05c",
          "primary-dark": "#0a5a32",
          "accent": "#eef6f1",
          "accent-foreground": "#121212",
          "secondary": "#ecece8",
          "secondary-foreground": "#121212",
          "muted": "#ecece8",
          "muted-foreground": "#5c5c58",
          "border": "#d6d6d0",
          "border-strong": "#b8b8b0",
          "input": "#d6d6d0",
          "ring": "#0f7a45",
          "destructive": "#a12d2d",
          "destructive-foreground": "#fff5f5",
          "success": "#0f7a45",
          "success-foreground": "#f4fff8",
          "warning": "#8a6b12",
          "warning-foreground": "#121212",
          "info": "#1d5f88",
          "info-foreground": "#f4f9fc"
        }
      }
    }
  }
}
EOF

cat > src/data/config/site.json << 'EOF'
{
  "identity": {
    "title": "Andrew Linh"
  },
  "header": {
    "id": "global-header",
    "type": "header",
    "data": {
      "logoText": "Andrew Linh",
      "logoHighlight": "AL",
      "menu": { "$ref": "../config/menu.json#/main" }
    },
    "settings": { "sticky": true }
  },
  "footer": {
    "id": "global-footer",
    "type": "footer",
    "data": {
      "brandText": "Andrew Linh",
      "brandHighlight": "systems · writing",
      "description": "Systems architect and technical writer. Backend architectures, structured data infrastructure, developer tools, and AI-native systems.",
      "copyright": "© 2026 Andrew Linh.",
      "menu": { "$ref": "../config/menu.json#/footer" },
      "social": [
        { "id": "gh", "label": "GitHub", "href": "https://github.com/andrewlinh", "icon": "github" },
        { "id": "li", "label": "LinkedIn", "href": "https://linkedin.com/in/andrewlinh", "icon": "linkedin" },
        { "id": "rss", "label": "RSS", "href": "/blog/rss.xml", "icon": "rss" }
      ]
    },
    "settings": { "showLogo": true }
  }
}
EOF

cat > src/data/config/menu.json << 'EOF'
{
  "main": [
    { "id": "nav-about", "label": "About", "href": "/about" },
    { "id": "nav-work", "label": "Work", "href": "/work" },
    { "id": "nav-blog", "label": "Blog", "href": "/blog" },
    { "id": "nav-contact", "label": "Contact", "href": "/contact", "isCta": true }
  ],
  "footer": [
    { "id": "ft-work", "label": "Work", "href": "/work" },
    { "id": "ft-blog", "label": "Blog", "href": "/blog" },
    { "id": "ft-contact", "label": "Contact", "href": "/contact" },
    { "id": "ft-rss", "label": "RSS", "href": "/blog/rss.xml" }
  ]
}
EOF

echo "-- Writing collection data (projects + posts)..."
# Reuse existing rich JSON if present; otherwise write full content
if [ ! -f src/data/collections/projects/projects.json ] || [ ! -s src/data/collections/projects/projects.json ]; then
cat > src/data/collections/projects/projects.json << 'EOF'
{
  "schemaforge-cms": {
    "id": "schemaforge-cms",
    "title": "SchemaForge CMS",
    "subtitle": "Schema-driven content publishing for multi-tenant sites",
    "year": 2025,
    "role": "Lead systems architect",
    "context": "A content platform serving 40+ tenants needed deterministic page assembly without CMS drift or silent field mismatches.",
    "problem": "Editors published broken pages weekly because free-form JSON and ad-hoc React sections diverged. Publish errors averaged 12% of releases, and rollback windows stretched past two hours.",
    "architecture": "Introduced Zod collection contracts, keyed collection documents, and section capsules that bind via $ref. Studio inspector surfaces were generated from the same schemas used at render time. CI validated every page and collection against registry schemas before merge.",
    "result": "Publish errors dropped 40%. Mean time to recover from a bad content release fell from 2.1 hours to 18 minutes. New tenant onboarding time moved from weeks to a two-day scaffold.",
    "stack": ["TypeScript", "Zod", "React", "Vite", "PostgreSQL"],
    "image": { "url": "https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=1600&q=80", "alt": "Dark IDE with structured code on a widescreen monitor" },
    "tags": ["cms", "schemas", "content-infra"],
    "featured": true
  },
  "typebridge-api": {
    "id": "typebridge-api",
    "title": "Typebridge API",
    "subtitle": "End-to-end type safety from Zod to OpenAPI to clients",
    "year": 2024,
    "role": "Principal engineer",
    "context": "A developer-tools company shipped three client SDKs from a hand-maintained OpenAPI document that routinely drifted from runtime validators.",
    "problem": "Contract mismatches caused 23 production incidents in six months. SDK releases lagged API changes by an average of nine days.",
    "architecture": "Made Zod schemas the single source of truth. Generated OpenAPI 3.1, TypeScript clients, and contract tests from the same definitions.",
    "result": "Contract-related incidents fell 78%. SDK lag dropped from nine days to same-day.",
    "stack": ["Zod", "OpenAPI", "Node.js", "GitHub Actions"],
    "image": { "url": "https://images.unsplash.com/photo-1518770660439-4636190af475?w=1600&q=80", "alt": "Circuit board traces representing API connectivity" },
    "tags": ["api", "type-safety", "dx"],
    "featured": true
  },
  "agentops-runner": {
    "id": "agentops-runner",
    "title": "AgentOps Runner",
    "subtitle": "Deterministic evaluation harness for AI agent workflows",
    "year": 2025,
    "role": "Architecture lead",
    "context": "An AI product team needed reproducible evals for multi-step agents before promoting prompts and tools to production.",
    "problem": "Ad-hoc notebook evals produced non-comparable scores. Regressions slipped into production twice a month.",
    "architecture": "Built a runner with frozen fixtures, tool stubs, deterministic seeding, and structured trace artifacts with typed scorecards.",
    "result": "Eval variance across identical runs dropped below 1%. Production agent regressions fell from ~8/month to 1/month.",
    "stack": ["Python", "TypeScript", "Redis", "OpenTelemetry", "Docker"],
    "image": { "url": "https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=1600&q=80", "alt": "Abstract neural network visualization on a dark display" },
    "tags": ["ai", "evals", "observability"],
    "featured": true
  },
  "lakehouse-ledger": {
    "id": "lakehouse-ledger",
    "title": "Lakehouse Ledger",
    "subtitle": "Structured audit-trail infrastructure for regulated data pipelines",
    "year": 2023,
    "role": "Systems architect",
    "context": "A fintech data platform needed immutable lineage across batch and streaming transforms.",
    "problem": "Compliance reviews could not reconstruct metric definition changes. Audit prep consumed three engineer-weeks per quarter.",
    "architecture": "Designed an append-only ledger of schema versions, transform fingerprints, and partition manifests wired into Spark and Flink jobs.",
    "result": "Quarterly audit prep dropped from three engineer-weeks to four engineer-days. Lineage lookup latency stayed under 200ms p95.",
    "stack": ["Apache Iceberg", "Spark", "Flink", "PostgreSQL", "gRPC"],
    "image": { "url": "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=1600&q=80", "alt": "Earth from orbit with illuminated city lights" },
    "tags": ["data-infra", "audit", "lakehouse"],
    "featured": true
  }
}
EOF
fi

if [ ! -f src/data/collections/posts/posts.json ] || [ ! -s src/data/collections/posts/posts.json ]; then
cat > src/data/collections/posts/posts.json << 'EOF'
{
  "schema-driven-content": {
    "id": "schema-driven-content",
    "title": "Schema-driven content is the missing layer",
    "dek": "Why treating page sections as typed contracts beats free-form CMS blobs for multi-tenant sites.",
    "date": "2026-03-12",
    "readingTime": "9 min",
    "tags": ["schemas", "cms", "content-infra"],
    "image": { "url": "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1600&q=80", "alt": "Laptop showing structured documents" },
    "body": "## The quiet failure mode\n\nMost content platforms fail the same way: the editor UI drifts from the renderer, and nobody notices until a publish breaks production.\n\n## Contracts over conventions\n\nSchema-driven content means every section, collection item, and form submission has a Zod contract shared by Studio, CI, and runtime.\n\n## The payoff\n\nYou trade a little authoring friction for operational calm. Publish errors become schema errors you can fix before merge."
  },
  "e2e-type-safety": {
    "id": "e2e-type-safety",
    "title": "End-to-end type safety without the ceremony",
    "dek": "How to keep Zod, OpenAPI, and generated clients honest without drowning teams in codegen rituals.",
    "date": "2026-01-28",
    "readingTime": "8 min",
    "tags": ["type-safety", "api", "dx"],
    "image": { "url": "https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=1600&q=80", "alt": "Developer working at a desk with code on screen" },
    "body": "## The split brain problem\n\nTeams often maintain three truths: runtime validators, OpenAPI, and handwritten clients.\n\n## One source, many projections\n\nStart with Zod at the boundary. Generate OpenAPI. Generate clients. Contract-test responses against the same types.\n\n## DX that sticks\n\nDevelopers adopt type safety when it removes toil."
  },
  "ai-agent-tooling": {
    "id": "ai-agent-tooling",
    "title": "Building AI agent tooling that can be graded",
    "dek": "Deterministic fixtures, typed traces, and golden scorecards turn agent demos into operable systems.",
    "date": "2025-11-04",
    "readingTime": "11 min",
    "tags": ["ai", "agents", "evals"],
    "image": { "url": "https://images.unsplash.com/photo-1677442136019-21780ecad995?w=1600&q=80", "alt": "Abstract glowing network suggesting AI systems" },
    "body": "## Demos are not systems\n\nAn agent that works in a notebook is not ready for production.\n\n## Make evaluation first-class\n\nDefine scenarios as data. Persist every tool call as a typed event log.\n\n## Calm over clever\n\nThe goal is an agent you can reason about — graded, bisected, and rolled back like any other service."
  },
  "dx-of-structured-systems": {
    "id": "dx-of-structured-systems",
    "title": "Developer experience for structured systems",
    "dek": "Precision tooling should feel quiet: fast feedback, honest errors, and fewer places to look.",
    "date": "2025-09-18",
    "readingTime": "7 min",
    "tags": ["dx", "tooling", "architecture"],
    "image": { "url": "https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=1600&q=80", "alt": "Laptop with code editor beside a notebook" },
    "body": "## DX is an architecture outcome\n\nIn structured systems, DX is the system. If the feedback loop is slow, the architecture will be circumvented.\n\n## Terminal aesthetics, human patience\n\nGood tools feel like a well-tuned terminal: dense signal, low noise, predictable commands."
  }
}
EOF
fi

echo "-- Writing pages..."
cat > src/data/pages/home.json << 'EOF'
{
  "id": "home-page",
  "slug": "home",
  "meta": {
    "title": "Andrew Linh — Systems Architect & Technical Writer",
    "description": "Portfolio and editorial site of Andrew Linh. Backend architecture, structured data infrastructure, developer tools, and AI-native systems — written with precision."
  },
  "sections": [
    {
      "id": "home-hero-1",
      "type": "home-hero",
      "data": {
        "label": "Systems architect · technical writer",
        "title": "I design backends that stay honest,",
        "titleHighlight": "then write about why.",
        "description": "Architecture for structured data platforms, developer tools, and AI-native systems — with the calm of a well-tuned terminal.",
        "primaryCta": { "id": "cta-work", "label": "View work", "href": "/work", "variant": "primary" },
        "secondaryCta": { "id": "cta-blog", "label": "Read writing", "href": "/blog", "variant": "secondary" }
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "lg" }
    },
    {
      "id": "home-featured-1",
      "type": "featured-projects",
      "data": {
        "label": "Selected work",
        "title": "Case studies",
        "description": "Four engagements where schema contracts, type safety, and measurable outcomes mattered more than slide decks.",
        "limit": 4,
        "items": { "$ref": "../collections/projects/projects.json" }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "md" }
    },
    {
      "id": "home-posts-1",
      "type": "recent-posts",
      "data": {
        "label": "Writing",
        "title": "Latest notes",
        "limit": 3,
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "md" }
    },
    {
      "id": "home-bio-1",
      "type": "bio-band",
      "data": {
        "label": "Briefly",
        "title": "Precision over performance.",
        "body": "I spend most of my time on the seams: schemas that bind editors to runtimes, APIs that stay typed end-to-end, and agent tooling you can actually grade.\n\nThis site is the professional surface and the editorial notebook — same standards in both.",
        "image": {
          "url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=1200&q=80",
          "alt": "Portrait of a man in a dark shirt looking calmly at the camera"
        },
        "cta": { "id": "bio-about", "label": "Full about", "href": "/about", "variant": "secondary" }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "md" }
    },
    {
      "id": "home-cta-1",
      "type": "cta-band",
      "data": {
        "title": "Need a calm systems partner?",
        "description": "Architecture reviews, schema design, and technical writing for teams shipping structured platforms.",
        "primaryCta": { "id": "cta-contact", "label": "Start a conversation", "href": "/contact", "variant": "primary" }
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/about.json << 'EOF'
{
  "id": "about-page",
  "slug": "about",
  "meta": {
    "title": "About Andrew Linh — Path, Stack, Principles",
    "description": "Professional path, technical stack, and design philosophy of Andrew Linh: systems architecture for structured data, developer tools, and AI-native platforms."
  },
  "sections": [
    {
      "id": "about-hero-1",
      "type": "page-hero",
      "data": {
        "label": "About",
        "title": "Built for precision, not spectacle.",
        "description": "A short path through the work: backends, contracts, and writing that keeps teams honest."
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "md" }
    },
    {
      "id": "about-story-1",
      "type": "about-story",
      "data": {
        "label": "Path",
        "title": "From data pipelines to content contracts.",
        "body": "I started in data infrastructure — lineage, ledgers, and systems that had to answer auditors without improvisation. That habit of append-only truth carried into developer tools and content platforms.\n\nToday I design backend architectures and write about the seams where schemas, APIs, and AI agents meet. The through-line is simple: make the structure visible, make failures loud, keep the surface calm.",
        "image": {
          "url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=1200&q=80",
          "alt": "Portrait of Andrew Linh"
        }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "md" }
    },
    {
      "id": "about-skills-1",
      "type": "skills-stack",
      "data": {
        "label": "Stack",
        "title": "Tools I reach for",
        "items": [
          { "id": "sk-ts", "label": "TypeScript", "category": "Language", "icon": "code" },
          { "id": "sk-zod", "label": "Zod", "category": "Contracts", "icon": "braces" },
          { "id": "sk-node", "label": "Node.js", "category": "Runtime", "icon": "server" },
          { "id": "sk-pg", "label": "PostgreSQL", "category": "Data", "icon": "database" },
          { "id": "sk-redis", "label": "Redis", "category": "Infra", "icon": "workflow" },
          { "id": "sk-otel", "label": "OpenTelemetry", "category": "Observability", "icon": "cpu" },
          { "id": "sk-iceberg", "label": "Apache Iceberg", "category": "Lakehouse", "icon": "boxes" },
          { "id": "sk-cloud", "label": "Cloud / CI", "category": "Delivery", "icon": "cloud" }
        ]
      },
      "settings": { "paddingTop": "md", "paddingBottom": "md" }
    },
    {
      "id": "about-philosophy-1",
      "type": "philosophy",
      "data": {
        "label": "Principles",
        "title": "How I design",
        "items": [
          { "id": "ph-1", "title": "One source of truth", "body": "If a field exists in three places, it will disagree. Prefer generated projections of a single contract." },
          { "id": "ph-2", "title": "Fail before merge", "body": "Schema validation in CI is cheaper than incident response. Loud errors beat silent drift." },
          { "id": "ph-3", "title": "Grade what you ship", "body": "Agents, pipelines, and content systems need fixtures and scorecards — not demos that only work once." },
          { "id": "ph-4", "title": "Calm surfaces", "body": "Dense signal, low noise. The aesthetic of a good terminal is respect for attention." }
        ]
      },
      "settings": { "paddingTop": "md", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/work.json << 'EOF'
{
  "id": "work-page",
  "slug": "work",
  "meta": {
    "title": "Work — Case Studies by Andrew Linh",
    "description": "Selected systems architecture case studies: schema-driven CMS, end-to-end type safety, AI agent evals, and lakehouse audit infrastructure."
  },
  "sections": [
    {
      "id": "work-hero-1",
      "type": "page-hero",
      "data": {
        "label": "Work",
        "title": "Case studies with receipts.",
        "description": "Each project is its own entity — context, problem, architecture, result, and stack."
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "md" }
    },
    {
      "id": "work-list-1",
      "type": "projects-list",
      "data": {
        "title": "Selected engagements",
        "description": "Real systems work with measurable outcomes.",
        "items": { "$ref": "../collections/projects/projects.json" }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/blog.json << 'EOF'
{
  "id": "blog-page",
  "slug": "blog",
  "meta": {
    "title": "Blog — Andrew Linh on Schemas, Types, and Agents",
    "description": "Essays on schema-driven content, end-to-end type safety, AI agent tooling, and developer experience for structured systems."
  },
  "sections": [
    {
      "id": "blog-hero-1",
      "type": "page-hero",
      "data": {
        "label": "Blog",
        "title": "Notes from the seams.",
        "description": "Writing on contracts, type safety, agent evals, and the DX of structured systems."
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "md" }
    },
    {
      "id": "blog-list-1",
      "type": "posts-list",
      "data": {
        "title": "All posts",
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": { "paddingTop": "md", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/contact.json << 'EOF'
{
  "id": "contact-page",
  "slug": "contact",
  "meta": {
    "title": "Contact Andrew Linh — Architecture & Writing",
    "description": "Get in touch for systems architecture, schema design, technical writing, and reviews of structured platforms. GitHub, LinkedIn, and blog RSS linked."
  },
  "sections": [
    {
      "id": "contact-hero-1",
      "type": "page-hero",
      "data": {
        "label": "Contact",
        "title": "Say hello.",
        "description": "Architecture reviews, schema design, and technical writing for teams shipping structured platforms."
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "md" }
    },
    {
      "id": "contact-form-1",
      "type": "contact-form",
      "data": {
        "anchorId": "contact",
        "label": "Message",
        "title": "Start a conversation",
        "description": "Prefer email? Use the form. Prefer async social? Links below.",
        "recipientEmail": "hello@andrewlinh.dev",
        "submitLabel": "Send message",
        "successMessage": "Message sent. I will reply soon.",
        "social": [
          { "id": "c-gh", "label": "GitHub", "href": "https://github.com/andrewlinh", "icon": "github" },
          { "id": "c-li", "label": "LinkedIn", "href": "https://linkedin.com/in/andrewlinh", "icon": "linkedin" },
          { "id": "c-rss", "label": "Blog RSS", "href": "/blog/rss.xml", "icon": "rss" },
          { "id": "c-mail", "label": "Email", "href": "mailto:hello@andrewlinh.dev", "icon": "mail" }
        ]
      },
      "settings": { "paddingTop": "md", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/work/\[slug\].json << 'EOF'
{
  "id": "project-detail-page",
  "slug": "work/[slug]",
  "collection": { "source": "projects", "paramKey": "slug" },
  "meta": {
    "title": "Project case study — Andrew Linh",
    "description": "Detailed case study covering context, problem, architecture decisions, measurable results, and technology stack."
  },
  "sections": [
    {
      "id": "project-detail-1",
      "type": "project-detail",
      "data": {
        "item": { "$ref": "collection:current" },
        "backLabel": "Back to work"
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "lg" }
    }
  ]
}
EOF

cat > src/data/pages/blog/\[slug\].json << 'EOF'
{
  "id": "post-detail-page",
  "slug": "blog/[slug]",
  "collection": { "source": "posts", "paramKey": "slug" },
  "meta": {
    "title": "Blog post — Andrew Linh",
    "description": "Long-form writing on schema-driven content, type safety, AI agent tooling, and developer experience for structured systems."
  },
  "sections": [
    {
      "id": "post-detail-1",
      "type": "post-detail",
      "data": {
        "item": { "$ref": "collection:current" },
        "backLabel": "Back to blog"
      },
      "settings": { "paddingTop": "lg", "paddingBottom": "lg" }
    }
  ]
}
EOF

# =============================================================================
# STEP 9 — AdminStudioClient wiring check (iconRegistry + collections + collectionSchemas)
# =============================================================================
echo "-- Step 9: checking AdminStudioClient wiring (iconRegistry + collections)..."
ADMIN_CLIENT="src/components/admin/AdminStudioClient.tsx"
if [[ -f "$ADMIN_CLIENT" ]] \
  && grep -q "iconRegistry" "$ADMIN_CLIENT" \
  && grep -q "collectionSchemas" "$ADMIN_CLIENT" \
  && grep -q "collections" "$ADMIN_CLIENT"; then
  echo "   AdminStudioClient wires iconRegistry, collections and collectionSchemas — ok"
else
  echo "!! AdminStudioClient missing iconRegistry / collections / collectionSchemas."
  echo "!! Refusing to guess a patch location. Current wiring found:"
  grep -n "iconRegistry\|collectionSchemas\|collections\|CollectionRegistry\|iconMap" "$ADMIN_CLIENT" 2>/dev/null || true
  echo "!! Manually ensure AdminStudioClient builds JsonPagesConfig with:"
  echo "     iconRegistry: iconMap,                  // import { iconMap } from '@/lib/IconResolver'"
  echo "     collections: <collections data map>,    // e.g. getFileCollections() or explicit JSON imports"
  echo "     collectionSchemas: CollectionRegistry,  // import { CollectionRegistry } from '@/lib/CollectionRegistry'"
  exit 1
fi


# =============================================================================
# POST-PASS — UI polish (shad Button hover+border / typography / pointer)
# =============================================================================
echo "-- Post-pass: shadcn Button + typography + pointer atmosphere..."

mkdir -p src/components/ui src/hooks src/components
rm -f src/components/ui/GradientBorderCta.tsx

# --- shadcn Button (hover + primary border glow; no custom CTA component) ---
cat > src/components/ui/button.tsx << 'EOF'
import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { Slot } from "radix-ui"

import { cn } from "@/lib/utils"

const buttonVariants = cva(
  "inline-flex shrink-0 items-center justify-center gap-1.5 rounded-lg border text-sm font-medium whitespace-nowrap outline-none select-none transition-[color,background-color,border-color,box-shadow] duration-200 focus-visible:ring-3 focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:ring-3 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default:
          "border-primary bg-primary text-primary-foreground hover:bg-primary/85 hover:shadow-[0_0_0_1px_var(--primary),0_0_20px_-4px_var(--primary)]",
        outline:
          "border-border bg-transparent text-foreground hover:border-primary hover:shadow-[0_0_0_1px_var(--primary),0_0_20px_-6px_var(--primary)]",
        secondary:
          "border-secondary bg-secondary text-secondary-foreground hover:bg-secondary/80 hover:border-primary/50",
        ghost:
          "border-transparent bg-transparent hover:bg-muted hover:text-foreground",
        destructive:
          "border-destructive/30 bg-destructive/10 text-destructive hover:bg-destructive/20",
        link:
          "border-transparent text-primary underline-offset-4 hover:underline",
      },
      size: {
        default:
          "h-8 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
        xs: "h-6 gap-1 rounded-[min(var(--radius-md),10px)] px-2 text-xs [&_svg:not([class*='size-'])]:size-3",
        sm: "h-7 gap-1 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] [&_svg:not([class*='size-'])]:size-3.5",
        lg: "h-9 px-3",
        icon: "size-8",
        "icon-xs": "size-6 rounded-[min(var(--radius-md),10px)] [&_svg:not([class*='size-'])]:size-3",
        "icon-sm": "size-7 rounded-[min(var(--radius-md),12px)]",
        "icon-lg": "size-9",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant = "default",
  size = "default",
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot.Root : "button"

  return (
    <Comp
      data-slot="button"
      data-variant={variant}
      data-size={size}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }

EOF

# --- Capsules: CTAs use Button ---
cat > src/components/home-hero/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { HomeHeroData, HomeHeroSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const HomeHero: React.FC<{ data: HomeHeroData; settings: HomeHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  return (
    <section
      style={{
        '--local-bg': 'var(--background)',
        '--local-text': 'var(--foreground)',
        '--local-text-muted': 'var(--muted-foreground)',
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-border': 'var(--border)',
        '--local-radius-md': 'var(--theme-radius-md)',
      } as React.CSSProperties}
      className={'relative z-0 overflow-hidden ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="relative z-[1] max-w-3xl jp-animate-in">
          {data.label && (
            <div
              className="mb-6 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]"
              data-jp-field="label"
            >
              <span className="h-px w-5 bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          <h1
            className="font-display text-[clamp(3rem,6vw,5.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]"
            data-jp-field="title"
          >
            {data.title}
            {data.titleHighlight ? (
              <>
                {' '}
                <em className="not-italic text-[var(--local-primary)]" data-jp-field="titleHighlight">
                  {data.titleHighlight}
                </em>
              </>
            ) : null}
          </h1>
          <p className="mt-8 max-w-2xl text-lg text-[var(--local-text-muted)]" data-jp-field="description">
            {data.description}
          </p>
          <div className="mt-10 flex flex-wrap gap-4">
            {data.primaryCta && (
              <Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5">
                <a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a>
              </Button>
            )}
            {data.secondaryCta && (
              <Button asChild variant="outline" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5">
                <a href={data.secondaryCta.href} data-jp-field="secondaryCta">{data.secondaryCta.label}</a>
              </Button>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};

EOF

cat > src/components/bio-band/View.tsx << 'EOF'
// Layout: Hero=A (SPLIT 60/40), Features=E (TABBED)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { BioBandData, BioBandSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const BioBand: React.FC<{ data: BioBandData; settings: BioBandSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-lg': 'var(--theme-radius-lg)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="grid items-center gap-12 md:grid-cols-[1.4fr_1fr]">
          <div>
            {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
            <h2 className="font-display text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
            <p className="mt-6 whitespace-pre-line text-base leading-relaxed text-[var(--local-text-muted)]" data-jp-field="body">{data.body}</p>
            {data.cta && (
              <div className="mt-8">
                <Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5">
                  <a href={data.cta.href} data-jp-field="cta">{data.cta.label}</a>
                </Button>
              </div>
            )}
          </div>
          {data.image?.url && <div className="overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]"><img src={data.image.url} alt={data.image.alt || ''} className="aspect-[4/5] w-full object-cover" data-jp-field="image" /></div>}
        </div>
      </div>
    </section>
  );
};

EOF

cat > src/components/cta-band/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=D (ACCORDION)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { CtaBandData, CtaBandSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const CtaBand: React.FC<{ data: CtaBandData; settings: CtaBandSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass + ' text-center'}>
        <h2 className="font-display text-[clamp(3rem,7vw,6.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
        {data.description && <p className="mx-auto mt-6 max-w-xl text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
        <div className="mt-10">
          <Button asChild variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5">
            <a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a>
          </Button>
        </div>
      </div>
    </section>
  );
};

EOF

cat > src/components/contact-form/View.tsx << 'EOF'
'use client';

// Layout: Hero=F (MINIMAL HERO), Features=D (ACCORDION)
import React from 'react';
import { useFormState } from '@olonjs/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Icon } from '@/lib/IconResolver';
import type { ContactFormData, ContactFormSettings } from './types';
const PADDING_TOP: Record<string, string> = { none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40' };
const PADDING_BOTTOM: Record<string, string> = { none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40' };
export const ContactForm: React.FC<{ data: ContactFormData; settings: ContactFormSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const formId = data.anchorId?.trim() || 'contact-form';
  const { status, message } = useFormState(formId);
  const socialItems = Array.isArray(data.social) ? data.social : [];
  return (
    <section style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)', '--local-text-muted': 'var(--muted-foreground)', '--local-primary': 'var(--primary)', '--local-primary-foreground': 'var(--primary-foreground)', '--local-border': 'var(--border)', '--local-surface': 'var(--card)', '--local-radius-md': 'var(--theme-radius-md)', '--local-radius-lg': 'var(--theme-radius-lg)' } as React.CSSProperties} className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}>
      <div className={containerClass}>
        <div className="grid gap-12 md:grid-cols-2">
          <div>
            {data.label && <div className="mb-4 inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-primary)]" data-jp-field="label"><span className="h-px w-5 bg-[var(--local-primary)]" />{data.label}</div>}
            <h2 className="font-display text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">{data.title}</h2>
            {data.description && <p className="mt-4 text-[var(--local-text-muted)]" data-jp-field="description">{data.description}</p>}
            <div className="mt-8 flex flex-col gap-3">
              {socialItems.map((item, idx) => (
                <a key={item.id || 'social-' + idx} href={item.href} target="_blank" rel="noreferrer" data-jp-item-id={item.id || 'social-' + idx} data-jp-item-field="social" className="inline-flex items-center gap-2 text-sm text-[var(--local-text)] hover:text-[var(--local-primary)]"><Icon name={item.icon} size={16} /><span>{item.label}</span></a>
              ))}
            </div>
          </div>
          <form id={formId} data-olon-recipient={data.recipientEmail ?? ''} className="space-y-4 rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6">
            <div><Label htmlFor={formId + '-name'} className="text-[var(--local-text-muted)]">Name</Label><Input id={formId + '-name'} name="name" required className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <div><Label htmlFor={formId + '-email'} className="text-[var(--local-text-muted)]">Email</Label><Input id={formId + '-email'} name="email" type="email" required className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <div><Label htmlFor={formId + '-message'} className="text-[var(--local-text-muted)]">Message</Label><Textarea id={formId + '-message'} name="message" required rows={6} className="mt-1 border-[var(--local-border)] bg-[var(--local-bg)] text-[var(--local-text)]" /></div>
            <Button type="submit" variant="default" className="rounded-[var(--local-radius-md)] h-auto px-4 py-2.5" data-jp-field="submitLabel">{data.submitLabel}</Button>
            {status === 'success' && <p className="text-sm text-[var(--local-primary)]" data-jp-field="successMessage">{data.successMessage}</p>}
            {status === 'error' && <p className="text-sm text-destructive">{message || 'Something went wrong.'}</p>}
          </form>
        </div>
      </div>
    </section>
  );
};

EOF

cat > src/components/header/View.tsx << 'EOF'
'use client';

// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Button } from '@/components/ui/button';
import { NavigationMenu, NavigationMenuItem, NavigationMenuLink, NavigationMenuList } from '@/components/ui/navigation-menu';
import { Sheet, SheetClose, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Menu, Moon, Sun } from 'lucide-react';
import type { HeaderData, HeaderSettings } from './types';

export const Header: React.FC<{ data: HeaderData; settings: HeaderSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];
  const [theme, setTheme] = React.useState<'light' | 'dark'>(() => {
    if (typeof document === 'undefined') return 'dark';
    return (document.documentElement.dataset.theme as 'light' | 'dark') || 'dark';
  });
  const toggleTheme = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    setTheme(next);
  };
  return (
    <header style={{ '--local-bg': 'color-mix(in oklch, var(--background) 90%, transparent)', '--local-text': 'var(--foreground)', '--local-border': 'var(--border)', '--local-surface': 'color-mix(in oklch, var(--card) 88%, transparent)', '--local-primary': 'var(--primary)', '--local-radius-md': 'var(--theme-radius-md)' } as React.CSSProperties} className="sticky top-0 z-10 border-b border-[var(--local-border)] bg-[var(--local-bg)]/95 backdrop-blur-xl">
      <div className="max-w-[1200px] mx-auto px-8">
        {data.announcement && <div className="border-b border-[var(--local-border)] py-2 text-center text-[0.72rem] font-mono uppercase tracking-[0.16em] text-[var(--local-text)]/70" data-jp-field="announcement">{data.announcement}</div>}
        <div className="flex h-20 items-center justify-between gap-6">
          <a href="/" className="flex items-baseline gap-2">
            <span className="font-display text-2xl tracking-tight text-[var(--local-text)]" data-jp-field="logoText">{data.logoText}</span>
            {data.logoHighlight && <span className="font-mono text-[0.72rem] uppercase tracking-[0.24em] text-[var(--local-primary)]" data-jp-field="logoHighlight">{data.logoHighlight}</span>}
          </a>
          <div className="hidden items-center gap-4 lg:flex">
            <NavigationMenu>
              <NavigationMenuList className="gap-1">
                {navItems.map((item, idx) => (
                  <NavigationMenuItem key={item.id || item.href + '-' + idx} data-jp-item-id={item.id || 'menu-' + idx} data-jp-item-field="menu">
                    <NavigationMenuLink href={item.href} className="rounded-[var(--local-radius-md)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:bg-[var(--local-surface)]">{item.label}</NavigationMenuLink>
                  </NavigationMenuItem>
                ))}
              </NavigationMenuList>
            </NavigationMenu>
            <Button type="button" variant="outline" size="icon" onClick={toggleTheme} className="rounded-[var(--local-radius-md)]">{theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}</Button>
          </div>
          <div className="flex items-center gap-3 lg:hidden">
            <Button type="button" variant="outline" size="icon" onClick={toggleTheme} className="rounded-[var(--local-radius-md)]">{theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}</Button>
            <Sheet>
              <SheetTrigger asChild><Button variant="outline" size="icon" className="rounded-[var(--local-radius-md)]"><Menu className="h-4 w-4" /></Button></SheetTrigger>
              <SheetContent className="flex flex-col gap-0 bg-card text-foreground">
                <SheetHeader className="border-b border-border px-6 py-5"><SheetTitle className="font-display text-lg text-foreground">{data.logoText || 'Menu'}</SheetTitle></SheetHeader>
                <nav className="flex flex-1 flex-col divide-y divide-border overflow-y-auto">
                  {navItems.map((item, idx) => (
                    <SheetClose asChild key={item.id || item.href + '-m-' + idx}><a href={item.href} className="flex items-center px-6 py-4 text-base font-medium text-foreground hover:bg-muted">{item.label}</a></SheetClose>
                  ))}
                </nav>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </div>
    </header>
  );
};

EOF

# --- Typography: strip font-black from titles; strip font-bold from h3 ---
echo "   stripping font-black / h3 font-bold..."
find src/components -name 'View.tsx' -print0 | while IFS= read -r -d '' f; do
  sed -i 's/font-display font-black/font-display/g' "$f"
  sed -i 's/\(<h3 className="[^"]*\)font-bold /\1/g' "$f"
done

# Fix jp-animate-in if still stuck at opacity 0
sed -i 's/\.jp-animate-in { opacity: 0; animation: jp-fadeUp 0\.7s ease forwards; }/.jp-animate-in { animation: jp-fadeUp 0.7s ease both; }/g' app/globals.css || true

# --- Pointer field + atmosphere ---
cat > src/hooks/usePointerField.tsx << 'EOF'
'use client';

import { createContext, useContext, useEffect, useMemo, type ReactNode } from 'react';
import { useMotionValue, useSpring, type MotionValue } from 'motion/react';

type PointerFieldValue = {
  x: MotionValue<number>;
  y: MotionValue<number>;
  sx: MotionValue<number>;
  sy: MotionValue<number>;
};

const PointerFieldContext = createContext<PointerFieldValue | null>(null);
const SPRING = { stiffness: 140, damping: 28, mass: 0.6 };

export function PointerFieldProvider({ children }: { children: ReactNode }) {
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const sx = useSpring(x, SPRING);
  const sy = useSpring(y, SPRING);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const onMove = (event: PointerEvent) => {
      x.set(event.clientX);
      y.set(event.clientY);
      document.documentElement.style.setProperty('--pointer-x', event.clientX + 'px');
      document.documentElement.style.setProperty('--pointer-y', event.clientY + 'px');
      document.documentElement.style.setProperty('--pointer-nx', String(event.clientX / window.innerWidth));
      document.documentElement.style.setProperty('--pointer-ny', String(event.clientY / window.innerHeight));
    };
    document.documentElement.style.setProperty('--pointer-active', '1');
    window.addEventListener('pointermove', onMove, { passive: true });
    return () => window.removeEventListener('pointermove', onMove);
  }, [x, y]);

  const value = useMemo(() => ({ x, y, sx, sy }), [x, y, sx, sy]);
  return <PointerFieldContext.Provider value={value}>{children}</PointerFieldContext.Provider>;
}

export function usePointerFieldOptional(): PointerFieldValue | null {
  return useContext(PointerFieldContext);
}
EOF

cat > src/components/PointerAtmosphere.tsx << 'EOF'
'use client';

import { useMotionTemplate, motion, useMotionValue } from 'motion/react';
import { usePointerFieldOptional } from '@/hooks/usePointerField';

export function PointerAtmosphere() {
  const field = usePointerFieldOptional();
  const fallbackX = useMotionValue(0);
  const fallbackY = useMotionValue(0);
  const sx = field?.sx ?? fallbackX;
  const sy = field?.sy ?? fallbackY;
  const glow = useMotionTemplate`radial-gradient(640px circle at ${sx}px ${sy}px, color-mix(in oklch, var(--primary) 12%, transparent), transparent 62%)`;
  if (!field) return null;
  return (
    <motion.div
      aria-hidden
      className="pointer-events-none fixed inset-0 z-0 motion-reduce:hidden"
      style={{ background: glow }}
    />
  );
}
EOF

# --- PointerAtmosphere files written above; Next harness has no App.tsx to patch ---
echo "   PointerField/Atmosphere components written (wire in layout if desired)"

echo "   post-pass complete"

# =============================================================================
# BUILD
# =============================================================================
echo "-- Running npm run build..."
npm run build

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                 SPEC COMPLIANCE CHECKLIST                    ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║ [x] Step 0 shadcn init + components                          ║"
echo "║ [x] Capsules (header/footer + 14 section types)              ║"
echo "║ [x] types.ts module augmentation                             ║"
echo "║ [x] ComponentRegistry 1:1                                    ║"
echo "║ [x] SECTION_SCHEMAS + SUBMISSION_SCHEMAS                     ║"
echo "║ [x] addSectionConfig                                         ║"
echo "║ [x] app/globals.css TOCC + [data-theme=light] + Google Fonts L1 ║"
echo "║ [x] theme.json dark default + light mode                     ║"
echo "║ [x] site.json menu \$ref + menu.json                          ║"
echo "║ [x] Pages: home about work blog contact + detail routes      ║"
echo "║ [x] Collections: projects + posts                            ║"
echo "║ [x] IconResolver (ui:icon-picker)                            ║"
echo "║ [x] Typography: Instrument Sans / Serif / JetBrains Mono     ║"
echo "║ [x] Post-pass: shad Button hover + border glow              ║"
echo "║ [x] Post-pass: pointer components + typography strip           ║"
echo "║ [x] VisitorSection registry-only (no books-list)               ║"
echo "║ [x] AdminStudioClient iconRegistry + collections               ║"
echo "║ [x] npm run build                                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Done. Andrew Linh Next tenant scaffold complete."

END_OF_FILE_CONTENT
echo "Creating templates/generate_inkwell_next.sh..."
cat << 'END_OF_FILE_CONTENT' > "templates/generate_inkwell_next.sh"
#!/bin/bash
set -e

# Always operate in the tenant root (parent of templates/).
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=============================================================="
echo "  INKWELL JOURNAL — OlonJS Next harness generator"
echo "  CWD = tenant root ($(pwd))"
echo "  No ThemeProvider — light/dark via document.documentElement.dataset.theme"
echo "  Collections + cross-collection relations demo"
echo "  posts -> tags  (post.tags = tag keys)"
echo "  tags  -> posts (resolved at render by filtering posts)"
echo "=============================================================="

# -----------------------------------------------------------------------------
# 0. SHADCN/UI INIT
# -----------------------------------------------------------------------------
echo "-- Step 0: shadcn/ui init..."

# Install shadcn peer dependencies FIRST (shadcn init does NOT do this automatically)
# NOTE: do NOT manually install radix-ui or @radix-ui/react-* — shadcn handles all radix deps
npm install class-variance-authority clsx tailwind-merge lucide-react

# Non-interactive + force Radix (2026 default is Base UI — Views use asChild / radix APIs).
npx shadcn@latest init --yes --defaults --base radix --force

# Install the full component set used by this tenant
npx shadcn@latest add --yes --overwrite \
  button \
  card \
  badge \
  separator \
  avatar \
  table \
  tabs \
  accordion \
  dialog \
  sheet \
  tooltip \
  navigation-menu \
  dropdown-menu \
  hover-card \
  breadcrumb \
  skeleton \
  progress \
  input \
  label \
  textarea \
  select \
  checkbox \
  switch \
  toggle \
  toggle-group \
  scroll-area \
  aspect-ratio

echo "   shadcn/ui components installed"

# -----------------------------------------------------------------------------
# PREFLIGHT — Next App Router layout must exist
# -----------------------------------------------------------------------------
echo "-- Preflight: checking app/layout.tsx..."
if [[ -f app/layout.tsx ]]; then
  echo "   app/layout.tsx found"
else
  echo "!! app/layout.tsx NOT found — expected tenant root (parent of templates/); run from apps/next/templates/"
  exit 1
fi

# -----------------------------------------------------------------------------
# WIPE tenant content — no DNA name denylist (orphans break the compiler).
# Preserve: src/components/ui (shadcn), src/components/admin (studio).
# Wipe includes overlap dirs (e.g. header) — generators rewrite them fresh.
# -----------------------------------------------------------------------------
echo "-- Wiping tenant content surfaces (components/collections/pages/config)..."
if [[ -d src/components ]]; then
  find src/components -mindepth 1 -maxdepth 1 ! -name 'ui' ! -name 'admin' -exec rm -rf {} +
fi
rm -rf \
  src/collections \
  src/data/collections \
  src/data/pages \
  public/pages \
  public/collections
rm -f public/config/site.json
if [[ -d src/data/config ]]; then
  find src/data/config -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi

# Drop DNA special-cases so wiped capsules cannot break the visitor RSC path.
echo "-- Resetting VisitorSection to registry-only..."
mkdir -p src/lib
cat > src/lib/VisitorSection.tsx << 'EOF'
import type { FC } from 'react';
import type { Section, SectionType } from '@/types';
import { ComponentRegistry } from '@/lib/ComponentRegistry';

export type VisitorSectionExtras = {
  authorId?: string | null;
  page?: number;
  pathname?: string;
};

/** Render a resolved page section via the tenant ComponentRegistry (RSC path). */
export function VisitorSection({
  section,
}: {
  section: Section;
  extras?: VisitorSectionExtras;
}) {
  const type = section.type as SectionType;
  const Comp = ComponentRegistry[type];
  if (!Comp) {
    return (
      <section className="px-6 py-8 text-muted-foreground">
        Unknown section type: {String(section.type)}
      </section>
    );
  }

  const View = Comp as FC<{ data: unknown; settings?: unknown }>;
  return <View data={section.data} settings={section.settings} />;
}
EOF

# DNA catch-all imports EmptyTenantView — drop it after wipe of that capsule.
if [[ -f 'app/[[...slug]]/page.tsx' ]]; then
  echo "-- Patching app/[[...slug]]/page.tsx empty fallback..."
  python3 - <<'PY'
from pathlib import Path
p = Path("app/[[...slug]]/page.tsx")
src = p.read_text()
capsule = "empty" + "-tenant"
src = src.replace(f"import {{ EmptyTenantView }} from '@/components/{capsule}';\n", "")
old = "  if (result.kind === 'empty') {\n    return <EmptyTenantView />;\n  }"
new = """  if (result.kind === 'empty') {
    return (
      <main className="mx-auto max-w-3xl px-8 py-24">
        <h1 className="text-2xl font-bold">Your tenant is empty.</h1>
        <p className="mt-2 text-muted-foreground">Create your first page.</p>
      </main>
    );
  }"""
if old not in src:
    raise SystemExit("EmptyTenantView empty-branch not found in page.tsx")
p.write_text(src.replace(old, new))
print("   page.tsx empty fallback inlined")
PY
fi

# -----------------------------------------------------------------------------
# DIRECTORIES
# -----------------------------------------------------------------------------
echo "-- Creating directories..."
mkdir -p src/components/header \
         src/components/footer \
         src/components/hero \
         src/components/page-hero \
         src/components/posts-list \
         src/components/tags-list \
         src/components/post-detail \
         src/components/related-tags \
         src/components/tag-detail \
         src/components/tag-posts \
         src/components/content-block \
         src/components/stats-band \
         src/components/cta-banner \
         src/collections/posts \
         src/collections/tags \
         src/data/config \
         src/data/pages \
         src/data/collections/posts \
         src/data/collections/tags \
         src/lib


# -----------------------------------------------------------------------------
# app/globals.css — fonts first line, semantic bridge, light mode, TOCC
# -----------------------------------------------------------------------------
echo "-- Writing app/globals.css..."
cat > app/globals.css << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,400..800&family=Instrument+Sans:ital,wght@0,400..700;1,400..700&family=JetBrains+Mono:wght@400..700&display=swap');
@import "tailwindcss";
@source "../src/**/*.tsx";

@theme {
  --color-background:           var(--background);
  --color-foreground:           var(--foreground);
  --color-card:                 var(--card);
  --color-card-foreground:      var(--card-foreground);
  --color-primary:              var(--primary);
  --color-primary-foreground:   var(--primary-foreground);
  --color-secondary:            var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted:                var(--muted);
  --color-muted-foreground:     var(--muted-foreground);
  --color-accent:               var(--accent);
  --color-border:               var(--border);
  --radius-lg:                  var(--theme-radius-lg);
  --radius-md:                  var(--theme-radius-md);
  --radius-sm:                  var(--theme-radius-sm);
  --font-primary: var(--theme-font-primary);
  --font-mono:    var(--theme-font-mono);
  --font-display: var(--theme-font-display, system-ui, sans-serif);
}

:root {
  /* -- Layer 1: semantic bridge ----------------------------- */
  --background:           var(--theme-colors-background);
  --foreground:           var(--theme-colors-foreground);
  --card:                 var(--theme-colors-card);
  --card-foreground:      var(--theme-colors-card-foreground);
  --elevated:             var(--theme-colors-elevated);
  --overlay:              var(--theme-colors-overlay);
  --primary:              var(--theme-colors-primary);
  --primary-foreground:   var(--theme-colors-primary-foreground);
  --primary-light:        var(--theme-colors-primary-light);
  --primary-dark:         var(--theme-colors-primary-dark);
  --secondary:            var(--theme-colors-secondary);
  --secondary-foreground: var(--theme-colors-secondary-foreground);
  --muted:                var(--theme-colors-muted);
  --muted-foreground:     var(--theme-colors-muted-foreground);
  --accent:               var(--theme-colors-accent);
  --accent-foreground:    var(--theme-colors-accent-foreground);
  --border:               var(--theme-colors-border);
  --border-strong:        var(--theme-colors-border-strong);
  --input:                var(--theme-colors-input);
  --ring:                 var(--theme-colors-ring);
  --destructive:          var(--theme-colors-destructive);
  --destructive-foreground: var(--theme-colors-destructive-foreground);
  --success:              var(--theme-colors-success);
  --success-foreground:   var(--theme-colors-success-foreground);
  --warning:              var(--theme-colors-warning);
  --warning-foreground:   var(--theme-colors-warning-foreground);
  --info:                 var(--theme-colors-info);
  --info-foreground:      var(--theme-colors-info-foreground);
  --radius:               var(--theme-radius-lg);

  /* Theme-derived helpers for section-owned surfaces. */
  --demo-surface:         color-mix(in oklch, var(--card) 86%, var(--background));
  --demo-surface-soft:    color-mix(in oklch, var(--card) 72%, var(--background));
  --demo-surface-strong:  color-mix(in oklch, var(--background) 82%, black);
  --demo-surface-deep:    color-mix(in oklch, var(--background) 70%, black);
  --demo-border-soft:     color-mix(in oklch, var(--foreground) 8%, transparent);
  --demo-border-strong:   color-mix(in oklch, var(--primary) 24%, transparent);
  --demo-accent-soft:     color-mix(in oklch, var(--primary) 10%, transparent);
  --demo-accent-strong:   color-mix(in oklch, var(--primary) 18%, transparent);
  --demo-text-soft:       color-mix(in oklch, var(--foreground) 88%, var(--muted-foreground));
  --demo-text-faint:      color-mix(in oklch, var(--muted-foreground) 72%, transparent);
}

/* -- Layer 1 override: LIGHT mode -------------------------- */
[data-theme="light"] {
  --background:           var(--theme-modes-light-colors-background);
  --foreground:           var(--theme-modes-light-colors-foreground);
  --card:                 var(--theme-modes-light-colors-card);
  --card-foreground:      var(--theme-modes-light-colors-card-foreground);
  --elevated:             var(--theme-modes-light-colors-elevated);
  --overlay:              var(--theme-modes-light-colors-overlay);
  --primary:              var(--theme-modes-light-colors-primary);
  --primary-foreground:   var(--theme-modes-light-colors-primary-foreground);
  --primary-light:        var(--theme-modes-light-colors-primary-light);
  --primary-dark:         var(--theme-modes-light-colors-primary-dark);
  --secondary:            var(--theme-modes-light-colors-secondary);
  --secondary-foreground: var(--theme-modes-light-colors-secondary-foreground);
  --muted:                var(--theme-modes-light-colors-muted);
  --muted-foreground:     var(--theme-modes-light-colors-muted-foreground);
  --accent:               var(--theme-modes-light-colors-accent);
  --accent-foreground:    var(--theme-modes-light-colors-accent-foreground);
  --border:               var(--theme-modes-light-colors-border);
  --border-strong:        var(--theme-modes-light-colors-border-strong);
  --input:                var(--theme-modes-light-colors-input);
  --ring:                 var(--theme-modes-light-colors-ring);
  --destructive:          var(--theme-modes-light-colors-destructive);
  --destructive-foreground: var(--theme-modes-light-colors-destructive-foreground);
  --success:              var(--theme-modes-light-colors-success);
  --success-foreground:   var(--theme-modes-light-colors-success-foreground);
  --warning:              var(--theme-modes-light-colors-warning);
  --warning-foreground:   var(--theme-modes-light-colors-warning-foreground);
  --info:                 var(--theme-modes-light-colors-info);
  --info-foreground:      var(--theme-modes-light-colors-info-foreground);
}

@layer base {
  * { border-color: var(--border); }
  body {
    background-color: var(--background);
    color: var(--foreground);
    font-family: var(--font-primary);
    line-height: 1.7;
    overflow-x: hidden;
    @apply antialiased;
  }
}

.font-display {
  font-family: var(--font-display, var(--font-primary));
}

html { scroll-behavior: smooth; }

/* Animations */
@keyframes jp-fadeUp {
  from { opacity: 0; transform: translateY(20px); }
  to   { opacity: 1; transform: translateY(0); }
}
.jp-animate-in { opacity: 0; animation: jp-fadeUp 0.7s ease forwards; }
.jp-d1 { animation-delay: 0.1s; }
.jp-d2 { animation-delay: 0.2s; }
.jp-d3 { animation-delay: 0.3s; }
.jp-d4 { animation-delay: 0.4s; }

@keyframes jp-pulseDot {
  0%, 100% { opacity: 1; transform: scale(1); }
  50%       { opacity: 0.5; transform: scale(0.85); }
}
.jp-pulse-dot { animation: jp-pulseDot 2s ease infinite; }

/* TOCC — required by §7 spec */
[data-jp-section-overlay] {
  position: absolute; inset: 0; z-index: 9999;
  pointer-events: none; border: 2px solid transparent;
  transition: border-color 0.15s, background-color 0.15s;
}
[data-section-id]:hover [data-jp-section-overlay] {
  border: 2px dashed color-mix(in oklch, var(--primary) 50%, transparent);
  background-color: color-mix(in oklch, var(--primary) 6%, transparent);
}
[data-section-id][data-jp-selected] [data-jp-section-overlay] {
  border: 2px solid var(--primary);
  background-color: color-mix(in oklch, var(--primary) 10%, transparent);
}
[data-jp-section-overlay] > div {
  position: absolute; top: 0; right: 0;
  padding: 0.2rem 0.55rem;
  font-size: 9px; font-weight: 800;
  text-transform: uppercase; letter-spacing: 0.1em;
  background: var(--primary); color: #fff;
  opacity: 0; transition: opacity 0.15s;
}
[data-section-id]:hover [data-jp-section-overlay] > div,
[data-section-id][data-jp-selected] [data-jp-section-overlay] > div { opacity: 1; }

/* Studio inspector — isolate from visitor [data-theme] token leaks on <html> */
aside.bg-zinc-950,
[data-jp-inspector] {
  --foreground: #fafafa;
  color: #fafafa;
}

aside.bg-zinc-950 input,
aside.bg-zinc-950 textarea,
aside.bg-zinc-950 select,
[data-jp-inspector] input,
[data-jp-inspector] textarea,
[data-jp-inspector] select {
  color: #fafafa;
}
EOF

# -----------------------------------------------------------------------------
# COLLECTIONS — posts (COP v1.1)
# -----------------------------------------------------------------------------
echo "-- Writing collection contract: posts..."
cat > src/collections/posts/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseCollectionItem, ImageSelectionSchema } from '@olonjs/core';

export const PostSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  excerpt: z.string().describe('ui:textarea'),
  body: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
  date: z.string().describe('ui:text'),
  author: z.string().describe('ui:text'),
  readingTime: z.string().describe('ui:text'),
  // Relation posts -> tags: each string is a key of the `tags` collection.
  // The relation lives ONLY on the post side (single source of truth);
  // the inverse (tags -> posts) is computed at render time by filtering.
  tags: z.array(z.string()).describe('ui:list'),
});

export const PostsCollectionSchema = z.record(z.string(), PostSchema);
EOF

cat > src/collections/posts/types.ts << 'EOF'
import { z } from 'zod';
import { PostSchema, PostsCollectionSchema } from './schema';

export type Post = z.infer<typeof PostSchema>;
export type PostsCollection = z.infer<typeof PostsCollectionSchema>;
EOF

cat > src/collections/posts/index.ts << 'EOF'
export { PostSchema, PostsCollectionSchema } from './schema';
export type { Post, PostsCollection } from './types';
EOF

# -----------------------------------------------------------------------------
# COLLECTIONS — tags (COP v1.1)
# -----------------------------------------------------------------------------
echo "-- Writing collection contract: tags..."
cat > src/collections/tags/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const TagSchema = BaseCollectionItem.extend({
  name: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  accent: z.enum(['primary', 'accent', 'muted']).optional().describe('ui:select'),
});

export const TagsCollectionSchema = z.record(z.string(), TagSchema);
EOF

cat > src/collections/tags/types.ts << 'EOF'
import { z } from 'zod';
import { TagSchema, TagsCollectionSchema } from './schema';

export type Tag = z.infer<typeof TagSchema>;
export type TagsCollection = z.infer<typeof TagsCollectionSchema>;
EOF

cat > src/collections/tags/index.ts << 'EOF'
export { TagSchema, TagsCollectionSchema } from './schema';
export type { Tag, TagsCollection } from './types';
EOF

# -----------------------------------------------------------------------------
# src/lib/CollectionRegistry.ts — one file, every collection source
# -----------------------------------------------------------------------------
echo "-- Writing src/lib/CollectionRegistry.ts..."
cat > src/lib/CollectionRegistry.ts << 'EOF'
import { PostsCollectionSchema } from '@/collections/posts';
import { TagsCollectionSchema } from '@/collections/tags';

export const CollectionRegistry = {
  posts: PostsCollectionSchema,
  tags: TagsCollectionSchema,
} as const;

export type CollectionType = keyof typeof CollectionRegistry;
EOF

# -----------------------------------------------------------------------------
# COLLECTION DATA — keyed objects, collectionKey === entity.id
# -----------------------------------------------------------------------------
echo "-- Writing collection data: posts..."
cat > src/data/collections/posts/posts.json << 'EOF'
{
  "designing-with-constraints": {
    "id": "designing-with-constraints",
    "title": "Designing with constraints, on purpose",
    "excerpt": "Every strong interface we have shipped started with a constraint we refused to negotiate away. Here is how we pick them.",
    "body": "Constraints are not the enemy of good design. They are the only reliable way to make a hundred small decisions coherent with each other. A palette of four colors forces hierarchy; a single display font forces rhythm.\n\nOn Inkwell we hold three constraints fixed: one measure for body text, one accent per surface, and no decoration that does not encode meaning. Everything else is allowed to move.\n\nThe result is not austerity. It is that rare feeling of a page where nothing competes with the words.",
    "image": { "url": "https://images.unsplash.com/photo-1455390582262-044cdead277a?w=1600&q=80", "alt": "Fountain pen resting on a notebook with handwritten notes" },
    "date": "2026-06-28",
    "author": "June Park",
    "readingTime": "6 min",
    "tags": ["design", "process"]
  },
  "the-boring-stack": {
    "id": "the-boring-stack",
    "title": "The boring stack is a feature",
    "excerpt": "We rebuilt our pipeline on tools nobody tweets about. Deploys got faster and the on-call channel went quiet.",
    "body": "There is a special kind of silence that follows choosing boring technology. The pager stops. The changelog reads like a grocery list. Nobody has to relearn the build system on a Tuesday.\n\nBoring does not mean old. It means the failure modes are documented, the upgrade path is known, and the second engineer to touch the code can predict what the first one did.\n\nWe budget our novelty. One genuinely new tool per quarter, everything else deliberately dull. That budget is the most productive constraint we have.",
    "image": { "url": "https://images.unsplash.com/photo-1518770660439-4636190af475?w=1600&q=80", "alt": "Close-up of a circuit board with soldered components" },
    "date": "2026-06-19",
    "author": "Tomas Lindgren",
    "readingTime": "5 min",
    "tags": ["engineering", "tooling"]
  },
  "write-the-readme-first": {
    "id": "write-the-readme-first",
    "title": "Write the README first",
    "excerpt": "If you cannot explain the tool before building it, you are about to build the wrong tool. A practice we stole from technical writers.",
    "body": "Before any code exists, we write the README as if the project were finished: what it does, how you install it, the three commands you will actually use. It takes an hour and it kills bad ideas while they are still cheap.\n\nThe README-first draft exposes the seams. If the usage section needs four paragraphs of caveats, the interface is wrong. If the install steps require a diagram, the packaging is wrong.\n\nDocumentation is not what you write after the work. Often, it is the work.",
    "image": { "url": "https://images.unsplash.com/photo-1517842645767-c639042777db?w=1600&q=80", "alt": "Open notebook with a pen on a wooden desk beside a laptop" },
    "date": "2026-06-10",
    "author": "Ada Osei",
    "readingTime": "4 min",
    "tags": ["writing", "process"]
  },
  "tokens-not-pixels": {
    "id": "tokens-not-pixels",
    "title": "Tokens, not pixels",
    "excerpt": "The day we deleted every hardcoded hex value was the day dark mode became a data change instead of a rewrite.",
    "body": "A design token is a promise: this value has a name, the name has a meaning, and the meaning survives a redesign. A hex code in a component is the opposite — a decision nobody can find later.\n\nOur rule is mechanical. Components consume semantic variables; variables resolve from a theme document; the theme document is data. Light mode, dark mode, a client rebrand: all of them become edits to one JSON file.\n\nIt is the least glamorous migration we ever ran, and the one with the highest return. Every surface in this journal, including the one you are reading, is painted through that chain.",
    "image": { "url": "https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=1600&q=80", "alt": "Monitor showing colorful code in a dark editor theme" },
    "date": "2026-05-30",
    "author": "June Park",
    "readingTime": "7 min",
    "tags": ["design", "engineering", "tooling"]
  },
  "shipping-on-fridays": {
    "id": "shipping-on-fridays",
    "title": "Yes, we ship on Fridays",
    "excerpt": "The no-Friday-deploy rule treats the symptom. We fixed the disease instead, and the weekend stayed quiet anyway.",
    "body": "Teams that fear Friday deploys do not have a calendar problem, they have a confidence problem. The fix is not a freeze window; it is making deploys so small and so reversible that the day of the week stops mattering.\n\nWe ship changes measured in tens of lines, behind flags, with a rollback that takes one command and no meeting. When a deploy is that cheap, Friday afternoon is just another afternoon.\n\nThe cultural shift matters more than the tooling: nobody gets praised here for a heroic weekend fix. We praise the boring deploy that nobody noticed.",
    "image": { "url": "https://images.unsplash.com/photo-1499750310107-5fef28a66643?w=1600&q=80", "alt": "Laptop and coffee cup on a tidy desk in warm morning light" },
    "date": "2026-05-18",
    "author": "Marco Bellini",
    "readingTime": "5 min",
    "tags": ["culture", "process"]
  },
  "notes-on-code-review": {
    "id": "notes-on-code-review",
    "title": "Code review is a writing exercise",
    "excerpt": "The best reviewers on our team are not the fastest readers of code. They are the most careful writers of comments.",
    "body": "A review comment is a tiny piece of technical writing with a hostile audience: a tired author who wants to merge. Precision and kindness are not in tension there — they are the same skill.\n\nWe rewrote our review guidelines around sentences, not checklists. Say what you observed, say why it matters, say what you would accept. Three sentences, no verdicts without reasons.\n\nReview latency dropped by half. Not because people read faster, but because nobody has to decode what a one-word comment meant.",
    "image": { "url": "https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=1600&q=80", "alt": "Two colleagues discussing work in front of a shared screen" },
    "date": "2026-05-04",
    "author": "Ada Osei",
    "readingTime": "6 min",
    "tags": ["engineering", "culture"]
  },
  "the-second-draft": {
    "id": "the-second-draft",
    "title": "The second draft is the real one",
    "excerpt": "Everything on this journal is published twice: once to find out what we think, once to say it properly.",
    "body": "First drafts are for discovering the argument. They meander, they hedge, they bury the point in paragraph four. That is fine — their job is excavation, not presentation.\n\nThe second draft starts from one question: what is the single sentence this piece exists to deliver? Everything that does not serve that sentence gets cut, no matter how much we liked writing it.\n\nOur average post loses forty percent of its words between drafts. Readers never miss them.",
    "image": { "url": "https://images.unsplash.com/photo-1455390582262-044cdead277a?w=1600&q=80", "alt": "Handwritten manuscript pages with edits and crossed-out lines" },
    "date": "2026-04-22",
    "author": "June Park",
    "readingTime": "4 min",
    "tags": ["writing"]
  },
  "tools-that-disappear": {
    "id": "tools-that-disappear",
    "title": "Good tools disappear",
    "excerpt": "The highest compliment for a tool is that nobody remembers using it. On interfaces that get out of the way.",
    "body": "You do not think about a doorknob when you open a door. That is the standard: a tool succeeded when the person forgot it was there and remembers only the work.\n\nEvery affordance we add is tested against one question — does this move attention toward the content or toward the chrome? Toolbars lost that argument here more than once.\n\nInvisible does not mean minimal for its own sake. It means every visible element earns its place by carrying meaning the content cannot carry alone.",
    "image": { "url": "https://images.unsplash.com/photo-1497032628192-86f99bcd76bc?w=1600&q=80", "alt": "Minimal workspace with a laptop, plant and empty desk surface" },
    "date": "2026-04-09",
    "author": "Tomas Lindgren",
    "readingTime": "5 min",
    "tags": ["tooling", "design"]
  }
}
EOF

echo "-- Writing collection data: tags..."
cat > src/data/collections/tags/tags.json << 'EOF'
{
  "design": {
    "id": "design",
    "name": "Design",
    "description": "Interfaces, typography, tokens and the discipline of visual decisions that survive a redesign.",
    "accent": "primary"
  },
  "engineering": {
    "id": "engineering",
    "name": "Engineering",
    "description": "Building software that stays boring in production: architecture, reliability and the craft of the diff.",
    "accent": "accent"
  },
  "process": {
    "id": "process",
    "name": "Process",
    "description": "How work actually gets shipped — constraints, drafts, deploys and the rituals that keep teams honest.",
    "accent": "primary"
  },
  "writing": {
    "id": "writing",
    "name": "Writing",
    "description": "Technical writing as a first-class engineering skill: READMEs, review comments, and second drafts.",
    "accent": "muted"
  },
  "tooling": {
    "id": "tooling",
    "name": "Tooling",
    "description": "The instruments of the trade — editors, pipelines, build systems — and when they should disappear.",
    "accent": "accent"
  },
  "culture": {
    "id": "culture",
    "name": "Culture",
    "description": "The habits behind the code: quiet deploys, kind reviews, and praising the fix nobody noticed.",
    "accent": "muted"
  }
}
EOF

# -----------------------------------------------------------------------------
# CAPSULE: header
# -----------------------------------------------------------------------------
echo "-- Writing capsule: header..."
cat > src/components/header/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const HeaderMenuItemSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  isCta: z.boolean().optional().describe('ui:checkbox'),
});

export const HeaderSchema = BaseSectionData.extend({
  logoText: z.string().describe('ui:text'),
  logoHighlight: z.string().optional().describe('ui:text'),
  announcement: z.string().optional().describe('ui:text'),
  // Resolved editing surface: site.json authors data.menu as a $ref to
  // menu.json; the engine resolves it before the Inspector sees it.
  menu: z.array(HeaderMenuItemSchema).optional().describe('ui:list'),
});
EOF

cat > src/components/header/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { HeaderSchema } from './schema';

export type HeaderData = z.infer<typeof HeaderSchema>;
export type HeaderSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/header/View.tsx << 'EOF'
'use client';

import React from 'react';
import { Button } from '@/components/ui/button';
import {
  NavigationMenu,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList,
} from '@/components/ui/navigation-menu';
import { Sheet, SheetClose, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Menu, Moon, Sun } from 'lucide-react';
import type { HeaderData, HeaderSettings } from './types';

export const Header: React.FC<{ data: HeaderData; settings: HeaderSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];
  const [theme, setTheme] = React.useState<'light' | 'dark'>(() => {
    if (typeof document === 'undefined') return 'dark';
    return (document.documentElement.dataset.theme as 'light' | 'dark') || 'dark';
  });
  const toggleTheme = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = next;
    setTheme(next);
  };

  return (
    <header
      style={{
        '--local-bg': 'color-mix(in oklch, var(--background) 90%, transparent)',
        '--local-text': 'var(--foreground)',
        '--local-border': 'var(--border)',
        '--local-surface': 'color-mix(in oklch, var(--card) 88%, transparent)',
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className="sticky top-0 z-10 border-b border-[var(--local-border)] bg-[var(--local-bg)]/95 backdrop-blur-xl"
    >
      <div className="max-w-[1200px] mx-auto px-8">
        {data.announcement && (
          <div
            className="border-b border-[var(--local-border)] py-2 text-center text-[0.72rem] font-mono uppercase tracking-[0.16em] text-[var(--local-text)]/70"
            data-jp-field="announcement"
          >
            {data.announcement}
          </div>
        )}
        <div className="flex h-20 items-center justify-between gap-6">
          <a href="/" className="flex items-baseline gap-2">
            <span className="font-display text-2xl font-black tracking-tight text-[var(--local-text)]" data-jp-field="logoText">
              {data.logoText}
            </span>
            {data.logoHighlight && (
              <span className="font-mono text-[0.72rem] uppercase tracking-[0.24em] text-[var(--local-primary)]" data-jp-field="logoHighlight">
                {data.logoHighlight}
              </span>
            )}
          </a>

          <div className="hidden items-center gap-4 lg:flex">
            <NavigationMenu>
              <NavigationMenuList className="gap-1">
                {navItems.map((item, idx) => (
                  <NavigationMenuItem
                    key={item.id || `${item.href}-${idx}`}
                    data-jp-item-id={item.id || `menu-${idx}`}
                    data-jp-item-field="menu"
                  >
                    <NavigationMenuLink
                      href={item.href}
                      className={
                        item.isCta
                          ? 'rounded-[var(--local-radius-md)] bg-[var(--local-primary)] px-4 py-2 text-sm font-semibold text-[var(--local-primary-foreground)] transition hover:opacity-90'
                          : 'rounded-[var(--local-radius-md)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:bg-[var(--local-surface)]'
                      }
                    >
                      {item.label}
                    </NavigationMenuLink>
                  </NavigationMenuItem>
                ))}
              </NavigationMenuList>
            </NavigationMenu>
            <Button
              type="button"
              variant="outline"
              onClick={toggleTheme}
              className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
            >
              {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>
          </div>

          <div className="flex items-center gap-3 lg:hidden">
            <Button
              type="button"
              variant="outline"
              onClick={toggleTheme}
              className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
            >
              {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>
            <Sheet>
              <SheetTrigger asChild>
                <Button variant="outline" className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]">
                  <Menu className="h-4 w-4" />
                </Button>
              </SheetTrigger>
              <SheetContent className="flex flex-col gap-0 bg-card text-foreground">
                <SheetHeader className="border-b border-border px-6 py-5">
                  <SheetTitle className="font-display text-lg text-foreground">{data.logoText || 'Menu'}</SheetTitle>
                </SheetHeader>
                <nav className="flex flex-1 flex-col divide-y divide-border overflow-y-auto">
                  {/* Mobile duplicate of navItems: intentionally NOT carrying
                      data-jp-item-id/data-jp-item-field — the desktop list is
                      the canonical IDAC-bound instance. */}
                  {navItems.map((item, idx) => (
                    <SheetClose asChild key={item.id || `${item.href}-mobile-${idx}`}>
                      <a
                        href={item.href}
                        className="flex items-center px-6 py-4 text-base font-medium text-foreground transition hover:bg-muted active:bg-muted"
                      >
                        {item.label}
                      </a>
                    </SheetClose>
                  ))}
                </nav>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </div>
    </header>
  );
};
EOF

cat > src/components/header/index.ts << 'EOF'
export { Header } from './View';
export { HeaderSchema } from './schema';
export type { HeaderData, HeaderSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: footer
# -----------------------------------------------------------------------------
echo "-- Writing capsule: footer..."
cat > src/components/footer/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const FooterMenuItemSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
});

export const FooterSchema = BaseSectionData.extend({
  brandText: z.string().describe('ui:text'),
  tagline: z.string().optional().describe('ui:textarea'),
  email: z.string().optional().describe('ui:text'),
  copyright: z.string().describe('ui:text'),
  menu: z.array(FooterMenuItemSchema).optional().describe('ui:list'),
});
EOF

cat > src/components/footer/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { FooterSchema } from './schema';

export type FooterData = z.infer<typeof FooterSchema>;
export type FooterSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/footer/View.tsx << 'EOF'
import React from 'react';
import { Separator } from '@/components/ui/separator';
import type { FooterData, FooterSettings } from './types';

export const Footer: React.FC<{ data: FooterData; settings: FooterSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];

  return (
    <footer
      style={{
        '--local-bg': 'var(--background)',
        '--local-text': 'var(--foreground)',
        '--local-text-muted': 'var(--muted-foreground)',
        '--local-border': 'var(--border)',
        '--local-primary': 'var(--primary)',
      } as React.CSSProperties}
      className="relative z-0 border-t border-[var(--local-border)] bg-[var(--local-bg)] py-20"
    >
      <div className="max-w-[1200px] mx-auto px-8">
        <div className="grid gap-12 md:grid-cols-3">
          <div>
            <span className="font-display text-2xl font-black tracking-tight text-[var(--local-text)]" data-jp-field="brandText">
              {data.brandText}
            </span>
            {data.tagline && (
              <p className="mt-3 max-w-xs text-sm leading-relaxed text-[var(--local-text-muted)]" data-jp-field="tagline">
                {data.tagline}
              </p>
            )}
          </div>
          <nav aria-label="Footer">
            <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em] text-[var(--local-text)]">Explore</h3>
            <ul className="mt-4 space-y-2">
              {navItems.map((item, idx) => (
                <li key={item.id || `menu-${idx}`} data-jp-item-id={item.id || `menu-${idx}`} data-jp-item-field="menu">
                  <a href={item.href} className="text-sm text-[var(--local-text-muted)] transition hover:text-[var(--local-primary)]">
                    {item.label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
          <div>
            <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em] text-[var(--local-text)]">Contact</h3>
            {data.email && (
              <a
                href={'mailto:' + data.email}
                className="mt-4 inline-block text-sm text-[var(--local-text-muted)] transition hover:text-[var(--local-primary)]"
                data-jp-field="email"
              >
                {data.email}
              </a>
            )}
          </div>
        </div>
        <Separator className="my-10 bg-[var(--local-border)]" />
        <p className="text-xs text-[var(--local-text-muted)]" data-jp-field="copyright">
          {data.copyright}
        </p>
      </div>
    </footer>
  );
};
EOF

cat > src/components/footer/index.ts << 'EOF'
export { Footer } from './View';
export { FooterSchema } from './schema';
export type { FooterData, FooterSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: hero
# -----------------------------------------------------------------------------
echo "-- Writing capsule: hero..."
cat > src/components/hero/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema, ImageSelectionSchema } from '@olonjs/core';

export const HeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  titleHighlight: z.string().optional().describe('ui:text'),
  subtitle: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema,
  secondaryCta: CtaSchema.optional(),
  image: ImageSelectionSchema.optional(),
});
EOF

cat > src/components/hero/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { HeroSchema } from './schema';

export type HeroData = z.infer<typeof HeroSchema>;
export type HeroSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/hero/View.tsx << 'EOF'
// Layout: Hero=D (EDITORIAL), Features=A (BENTO) on home + C (TIMELINE) on posts index
import React from 'react';
import { Button } from '@/components/ui/button';
import { AspectRatio } from '@/components/ui/aspect-ratio';
import type { HeroData, HeroSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const Hero: React.FC<{ data: HeroData; settings: HeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-accent': 'var(--accent)',
        '--local-accent-soft': 'var(--demo-accent-soft)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-md': 'var(--theme-radius-md)',
      } as React.CSSProperties}
      className={`relative z-0 overflow-hidden ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[1100px] h-[650px] bg-[radial-gradient(ellipse_at_50%_0%,var(--local-accent-soft),transparent_65%)] pointer-events-none" />
      <div className={containerClass}>
        {data.label && (
          <div
            className="jp-animate-in inline-flex items-center gap-2 bg-[var(--local-accent-soft)] border border-[var(--local-border)] px-4 py-1.5 rounded-full text-[0.70rem] font-mono font-semibold text-[var(--local-accent)] tracking-widest uppercase"
            data-jp-field="label"
          >
            <span className="w-1.5 h-1.5 rounded-full bg-[var(--local-primary)] jp-pulse-dot" />
            {data.label}
          </div>
        )}
        <h1
          className="jp-animate-in jp-d1 mt-8 max-w-[16ch] font-display font-black text-[clamp(3rem,6vw,5.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]"
          data-jp-field="title"
        >
          {data.title}{' '}
          {data.titleHighlight && (
            <em className="not-italic bg-gradient-to-br from-[var(--local-primary)] to-[var(--local-accent)] bg-clip-text text-transparent" data-jp-field="titleHighlight">
              {data.titleHighlight}
            </em>
          )}
        </h1>
        <p className="jp-animate-in jp-d2 mt-8 max-w-[52ch] text-lg leading-relaxed text-[var(--local-text-muted)]" data-jp-field="subtitle">
          {data.subtitle}
        </p>
        <div className="jp-animate-in jp-d3 mt-10 flex flex-wrap items-center gap-4">
          <Button
            asChild
            variant="default"
            size="lg"
            className="rounded-[var(--local-radius-md)] bg-[var(--local-primary)] text-[var(--local-primary-foreground)] hover:opacity-90"
          >
            <a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a>
          </Button>
          {data.secondaryCta && (
            <Button
              asChild
              variant="outline"
              size="lg"
              className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-transparent text-[var(--local-text)] hover:border-[var(--local-accent)]"
            >
              <a href={data.secondaryCta.href} data-jp-field="secondaryCta">{data.secondaryCta.label}</a>
            </Button>
          )}
        </div>
      </div>
      {data.image?.url && (
        <div className="jp-animate-in jp-d4 relative left-1/2 mt-16 w-screen -translate-x-1/2">
          <AspectRatio ratio={21 / 9}>
            <img src={data.image.url} alt={data.image.alt || ''} className="h-full w-full object-cover" />
          </AspectRatio>
        </div>
      )}
    </section>
  );
};
EOF

cat > src/components/hero/index.ts << 'EOF'
export { Hero } from './View';
export { HeroSchema } from './schema';
export type { HeroData, HeroSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: page-hero
# -----------------------------------------------------------------------------
echo "-- Writing capsule: page-hero..."
cat > src/components/page-hero/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

export const PageHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
});
EOF

cat > src/components/page-hero/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PageHeroSchema } from './schema';

export type PageHeroData = z.infer<typeof PageHeroSchema>;
export type PageHeroSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/page-hero/View.tsx << 'EOF'
import React from 'react';
import type { PageHeroData, PageHeroSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const PageHero: React.FC<{ data: PageHeroData; settings: PageHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
      } as React.CSSProperties}
      className={`relative z-0 border-b border-[var(--local-border)] ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.label && (
          <div
            className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
            data-jp-field="label"
          >
            <span className="w-5 h-px bg-[var(--local-primary)]" />
            {data.label}
          </div>
        )}
        <h1 className="font-display font-black text-[clamp(2.4rem,5vw,4.2rem)] leading-[1.02] tracking-tight text-[var(--local-text)]" data-jp-field="title">
          {data.title}
        </h1>
        {data.description && (
          <p className="mt-6 max-w-[56ch] text-lg leading-relaxed text-[var(--local-text-muted)]" data-jp-field="description">
            {data.description}
          </p>
        )}
      </div>
    </section>
  );
};
EOF

cat > src/components/page-hero/index.ts << 'EOF'
export { PageHero } from './View';
export { PageHeroSchema } from './schema';
export type { PageHeroData, PageHeroSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: posts-list (listing capsule — binds the full posts collection)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: posts-list..."
cat > src/components/posts-list/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';

export const PostsListSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  variant: z.enum(['bento', 'timeline']).optional().describe('ui:select'),
  limit: z.number().optional().describe('ui:number'),
  items: z.record(z.string(), PostSchema).describe('ui:collection-ref'),
});
EOF

cat > src/components/posts-list/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PostsListSchema } from './schema';

export type PostsListData = z.infer<typeof PostsListSchema>;
export type PostsListSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/posts-list/View.tsx << 'EOF'
// Layout: Features=A (BENTO) default variant, C (TIMELINE) alternative variant
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { PostsListData, PostsListSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const PostsList: React.FC<{ data: PostsListData; settings: PostsListSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  const posts = Object.values(data.items ?? {}).sort((a, b) => (b.date || '').localeCompare(a.date || ''));
  const visible = data.limit ? posts.slice(0, data.limit) : posts;
  const variant = data.variant ?? 'bento';

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.label && (
          <div
            className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
            data-jp-field="label"
          >
            <span className="w-5 h-px bg-[var(--local-primary)]" />
            {data.label}
          </div>
        )}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
          {data.title}
        </h2>
        {data.description && (
          <p className="mt-4 max-w-[56ch] text-base leading-relaxed text-[var(--local-text-muted)]" data-jp-field="description">
            {data.description}
          </p>
        )}

        {variant === 'timeline' ? (
          <div className="mt-12 border-l border-[var(--local-border)] pl-8">
            {visible.map((post, idx) => (
              <a
                key={post.id || `legacy-${idx}`}
                href={'/posts/' + (post.id || '')}
                className="group relative block pb-12 last:pb-0"
                data-jp-item-id={post.id || `legacy-${idx}`}
                data-jp-item-field="items"
              >
                <span className="absolute -left-[37px] top-1.5 h-2.5 w-2.5 rounded-full border border-[var(--local-border)] bg-[var(--local-primary)]" />
                <div className="font-mono text-[0.7rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)]">
                  {post.date} · {post.author} · {post.readingTime}
                </div>
                <h3 className="mt-2 font-display text-[1.4rem] font-bold leading-tight tracking-tight text-[var(--local-text)] transition group-hover:text-[var(--local-primary)]">
                  {post.title}
                </h3>
                <p className="mt-2 max-w-[64ch] text-sm leading-relaxed text-[var(--local-text-muted)]">{post.excerpt}</p>
                <div className="mt-3 flex flex-wrap gap-2">
                  {post.tags.map((tagId) => (
                    <span key={tagId} className="font-mono text-[0.65rem] uppercase tracking-widest text-[var(--local-accent)]">
                      #{tagId}
                    </span>
                  ))}
                </div>
              </a>
            ))}
          </div>
        ) : (
          <div className="mt-12 grid gap-6 md:grid-cols-6">
            {visible.map((post, idx) => (
              <a
                key={post.id || `legacy-${idx}`}
                href={'/posts/' + (post.id || '')}
                className={(idx === 0 ? 'md:col-span-4' : 'md:col-span-2') + ' group'}
                data-jp-item-id={post.id || `legacy-${idx}`}
                data-jp-item-field="items"
              >
                <Card className="h-full overflow-hidden rounded-[var(--local-radius-lg)] border-[var(--local-border)] bg-[var(--local-surface)] py-0 transition group-hover:border-[var(--local-accent)]">
                  {post.image?.url && (
                    <div className={idx === 0 ? 'h-64 overflow-hidden' : 'h-40 overflow-hidden'}>
                      <img
                        src={post.image.url}
                        alt={post.image.alt || ''}
                        className="h-full w-full object-cover transition duration-500 group-hover:scale-[1.03]"
                      />
                    </div>
                  )}
                  <CardContent className="p-6">
                    <div className="font-mono text-[0.68rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)]">
                      {post.date} · {post.readingTime}
                    </div>
                    <h3 className="mt-2 font-display text-[1.2rem] font-bold leading-tight tracking-tight text-[var(--local-text)]">
                      {post.title}
                    </h3>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--local-text-muted)]">{post.excerpt}</p>
                    <div className="mt-4 flex flex-wrap gap-2">
                      {post.tags.map((tagId) => (
                        <span key={tagId} className="font-mono text-[0.65rem] uppercase tracking-widest text-[var(--local-accent)]">
                          #{tagId}
                        </span>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              </a>
            ))}
          </div>
        )}
      </div>
    </section>
  );
};
EOF

cat > src/components/posts-list/index.ts << 'EOF'
export { PostsList } from './View';
export { PostsListSchema } from './schema';
export type { PostsListData, PostsListSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: tags-list (listing capsule — binds the full tags collection)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: tags-list..."
cat > src/components/tags-list/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { TagSchema } from '@/collections/tags';

export const TagsListSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), TagSchema).describe('ui:collection-ref'),
});
EOF

cat > src/components/tags-list/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { TagsListSchema } from './schema';

export type TagsListData = z.infer<typeof TagsListSchema>;
export type TagsListSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/tags-list/View.tsx << 'EOF'
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { TagsListData, TagsListSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

const ACCENT_VAR: Record<string, string> = {
  primary: 'var(--local-primary)',
  accent: 'var(--local-accent)',
  muted: 'var(--local-text-muted)',
};

export const TagsList: React.FC<{ data: TagsListData; settings: TagsListSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  const tags = Object.values(data.items ?? {});

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.label && (
          <div
            className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
            data-jp-field="label"
          >
            <span className="w-5 h-px bg-[var(--local-primary)]" />
            {data.label}
          </div>
        )}
        <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
          {data.title}
        </h2>
        {data.description && (
          <p className="mt-4 max-w-[56ch] text-base leading-relaxed text-[var(--local-text-muted)]" data-jp-field="description">
            {data.description}
          </p>
        )}
        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {tags.map((tag, idx) => (
            <a
              key={tag.id || `legacy-${idx}`}
              href={'/tags/' + (tag.id || '')}
              className="group"
              data-jp-item-id={tag.id || `legacy-${idx}`}
              data-jp-item-field="items"
            >
              <Card className="h-full rounded-[var(--local-radius-lg)] border-[var(--local-border)] bg-[var(--local-surface)] transition group-hover:border-[var(--local-accent)]">
                <CardContent className="p-6">
                  <span
                    className="font-mono text-[0.7rem] font-semibold uppercase tracking-[0.2em]"
                    style={{ color: ACCENT_VAR[tag.accent ?? 'primary'] }}
                  >
                    #{tag.id}
                  </span>
                  <h3 className="mt-3 font-display text-[1.2rem] font-bold leading-tight tracking-tight text-[var(--local-text)]">
                    {tag.name}
                  </h3>
                  <p className="mt-2 text-sm leading-relaxed text-[var(--local-text-muted)]">{tag.description}</p>
                </CardContent>
              </Card>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/tags-list/index.ts << 'EOF'
export { TagsList } from './View';
export { TagsListSchema } from './schema';
export type { TagsListData, TagsListSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: post-detail (detail capsule — binds the route-selected post)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: post-detail..."
cat > src/components/post-detail/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';

export const PostDetailSchema = BaseSectionData.extend({
  backLabel: z.string().optional().describe('ui:text'),
  item: PostSchema.describe('ui:collection-ref'),
});
EOF

cat > src/components/post-detail/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PostDetailSchema } from './schema';

export type PostDetailData = z.infer<typeof PostDetailSchema>;
export type PostDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/post-detail/View.tsx << 'EOF'
import React from 'react';
import { ArrowLeft } from 'lucide-react';
import { AspectRatio } from '@/components/ui/aspect-ratio';
import type { PostDetailData, PostDetailSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const PostDetail: React.FC<{ data: PostDetailData; settings: PostDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  const post = data.item;
  const paragraphs = (post.body || '').split('\n\n');

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        <div className="mx-auto max-w-[760px]">
          {data.backLabel && (
            <a
              href="/posts"
              className="inline-flex items-center gap-2 font-mono text-[0.72rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)] transition hover:text-[var(--local-primary)]"
              data-jp-field="backLabel"
            >
              <ArrowLeft className="h-3.5 w-3.5" />
              {data.backLabel}
            </a>
          )}
          <div className="mt-6 font-mono text-[0.72rem] uppercase tracking-[0.16em] text-[var(--local-accent)]">
            <span data-jp-field="item.date">{post.date}</span>
            <span className="mx-2 text-[var(--local-text-muted)]">·</span>
            <span data-jp-field="item.author">{post.author}</span>
            <span className="mx-2 text-[var(--local-text-muted)]">·</span>
            <span data-jp-field="item.readingTime">{post.readingTime}</span>
          </div>
          <h1
            className="mt-4 font-display font-black text-[clamp(2.4rem,5vw,4rem)] leading-[1.02] tracking-tight text-[var(--local-text)]"
            data-jp-field="item.title"
          >
            {post.title}
          </h1>
          <p className="mt-6 text-xl leading-relaxed text-[var(--local-text-muted)]" data-jp-field="item.excerpt">
            {post.excerpt}
          </p>
        </div>
        {post.image?.url && (
          <div className="mx-auto mt-12 max-w-[980px] overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]">
            <AspectRatio ratio={21 / 9}>
              <img src={post.image.url} alt={post.image.alt || ''} className="h-full w-full object-cover" />
            </AspectRatio>
          </div>
        )}
        <div className="mx-auto mt-12 max-w-[680px]" data-jp-field="item.body">
          {paragraphs.map((paragraph, idx) => (
            <p key={idx} className="mb-6 text-base leading-[1.85] text-[var(--local-text)]/90">
              {paragraph}
            </p>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/post-detail/index.ts << 'EOF'
export { PostDetail } from './View';
export { PostDetailSchema } from './schema';
export type { PostDetailData, PostDetailSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: related-tags (RELATION post -> tags, resolved at render time)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: related-tags..."
cat > src/components/related-tags/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';
import { TagSchema } from '@/collections/tags';

// Dual binding: `item` is the route-selected post (collection:current),
// `tags` is the FULL foreign collection. The View resolves the relation
// post.tags (array of tag keys) against the tags map.
export const RelatedTagsSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().optional().describe('ui:text'),
  emptyLabel: z.string().optional().describe('ui:text'),
  item: PostSchema.describe('ui:collection-ref'),
  tags: z.record(z.string(), TagSchema).describe('ui:collection-ref'),
});
EOF

cat > src/components/related-tags/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { RelatedTagsSchema } from './schema';

export type RelatedTagsData = z.infer<typeof RelatedTagsSchema>;
export type RelatedTagsSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/related-tags/View.tsx << 'EOF'
import React from 'react';
import type { Tag } from '@/collections/tags';
import type { RelatedTagsData, RelatedTagsSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

const ACCENT_VAR: Record<string, string> = {
  primary: 'var(--local-primary)',
  accent: 'var(--local-accent)',
  muted: 'var(--local-text-muted)',
};

export const RelatedTags: React.FC<{ data: RelatedTagsData; settings: RelatedTagsSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  // Relation resolution: post.tags is an array of tag collection keys.
  const tagMap = data.tags ?? {};
  const related = (data.item.tags ?? [])
    .map((tagId) => tagMap[tagId])
    .filter((tag): tag is Tag => Boolean(tag));

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-md': 'var(--theme-radius-md)',
      } as React.CSSProperties}
      className={`relative z-0 border-t border-[var(--local-border)] ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        <div className="mx-auto max-w-[760px]">
          {data.label && (
            <div
              className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
              data-jp-field="label"
            >
              <span className="w-5 h-px bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          {data.title && (
            <h2 className="font-display text-[1.4rem] font-bold leading-tight tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
          )}
          {related.length > 0 ? (
            <div className="mt-6 flex flex-wrap gap-3">
              {related.map((tag, idx) => (
                <a
                  key={tag.id || `legacy-${idx}`}
                  href={'/tags/' + (tag.id || '')}
                  className="group inline-flex items-center gap-2 rounded-[var(--local-radius-md)] border border-[var(--local-border)] bg-[var(--local-surface)] px-4 py-2 transition hover:border-[var(--local-accent)]"
                >
                  <span
                    className="font-mono text-[0.7rem] font-semibold uppercase tracking-[0.18em]"
                    style={{ color: ACCENT_VAR[tag.accent ?? 'primary'] }}
                  >
                    #{tag.id}
                  </span>
                  <span className="text-sm font-medium text-[var(--local-text)] transition group-hover:text-[var(--local-primary)]">
                    {tag.name}
                  </span>
                </a>
              ))}
            </div>
          ) : (
            data.emptyLabel && (
              <p className="mt-6 text-sm text-[var(--local-text-muted)]" data-jp-field="emptyLabel">
                {data.emptyLabel}
              </p>
            )
          )}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/related-tags/index.ts << 'EOF'
export { RelatedTags } from './View';
export { RelatedTagsSchema } from './schema';
export type { RelatedTagsData, RelatedTagsSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: tag-detail (detail capsule — binds the route-selected tag)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: tag-detail..."
cat > src/components/tag-detail/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { TagSchema } from '@/collections/tags';

export const TagDetailSchema = BaseSectionData.extend({
  backLabel: z.string().optional().describe('ui:text'),
  item: TagSchema.describe('ui:collection-ref'),
});
EOF

cat > src/components/tag-detail/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { TagDetailSchema } from './schema';

export type TagDetailData = z.infer<typeof TagDetailSchema>;
export type TagDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/tag-detail/View.tsx << 'EOF'
import React from 'react';
import { ArrowLeft } from 'lucide-react';
import type { TagDetailData, TagDetailSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const TagDetail: React.FC<{ data: TagDetailData; settings: TagDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  const tag = data.item;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
      } as React.CSSProperties}
      className={`relative z-0 border-b border-[var(--local-border)] ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.backLabel && (
          <a
            href="/tags"
            className="inline-flex items-center gap-2 font-mono text-[0.72rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)] transition hover:text-[var(--local-primary)]"
            data-jp-field="backLabel"
          >
            <ArrowLeft className="h-3.5 w-3.5" />
            {data.backLabel}
          </a>
        )}
        <div className="mt-6 font-mono text-[0.78rem] font-semibold uppercase tracking-[0.22em] text-[var(--local-accent)]">
          #{tag.id}
        </div>
        <h1
          className="mt-3 font-display font-black text-[clamp(2.4rem,5vw,4.2rem)] leading-[1.02] tracking-tight text-[var(--local-text)]"
          data-jp-field="item.name"
        >
          {tag.name}
        </h1>
        <p className="mt-6 max-w-[56ch] text-lg leading-relaxed text-[var(--local-text-muted)]" data-jp-field="item.description">
          {tag.description}
        </p>
      </div>
    </section>
  );
};
EOF

cat > src/components/tag-detail/index.ts << 'EOF'
export { TagDetail } from './View';
export { TagDetailSchema } from './schema';
export type { TagDetailData, TagDetailSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: tag-posts (RELATION tag -> posts, inverse relation computed at render)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: tag-posts..."
cat > src/components/tag-posts/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';
import { TagSchema } from '@/collections/tags';

// Dual binding: `item` is the route-selected tag (collection:current),
// `posts` is the FULL posts collection. The inverse relation tag -> posts is
// never stored in data: it is computed here by filtering posts whose
// `tags` array contains the current tag key.
export const TagPostsSchema = BaseSectionData.extend({
  title: z.string().optional().describe('ui:text'),
  emptyLabel: z.string().optional().describe('ui:text'),
  item: TagSchema.describe('ui:collection-ref'),
  posts: z.record(z.string(), PostSchema).describe('ui:collection-ref'),
});
EOF

cat > src/components/tag-posts/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { TagPostsSchema } from './schema';

export type TagPostsData = z.infer<typeof TagPostsSchema>;
export type TagPostsSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/tag-posts/View.tsx << 'EOF'
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { TagPostsData, TagPostsSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const TagPosts: React.FC<{ data: TagPostsData; settings: TagPostsSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  // Inverse relation tag -> posts, computed from the single source of truth
  // (post.tags) by filtering the full posts collection.
  const tagId = data.item.id || '';
  const posts = Object.values(data.posts ?? {})
    .filter((post) => (post.tags ?? []).includes(tagId))
    .sort((a, b) => (b.date || '').localeCompare(a.date || ''));

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.title && (
          <h2 className="font-display font-black text-[clamp(1.6rem,3.5vw,2.6rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}
          </h2>
        )}
        {posts.length > 0 ? (
          <div className="mt-10 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {posts.map((post, idx) => (
              <a key={post.id || `legacy-${idx}`} href={'/posts/' + (post.id || '')} className="group">
                <Card className="h-full overflow-hidden rounded-[var(--local-radius-lg)] border-[var(--local-border)] bg-[var(--local-surface)] py-0 transition group-hover:border-[var(--local-accent)]">
                  {post.image?.url && (
                    <div className="h-36 overflow-hidden">
                      <img
                        src={post.image.url}
                        alt={post.image.alt || ''}
                        className="h-full w-full object-cover transition duration-500 group-hover:scale-[1.03]"
                      />
                    </div>
                  )}
                  <CardContent className="p-6">
                    <div className="font-mono text-[0.68rem] uppercase tracking-[0.16em] text-[var(--local-text-muted)]">
                      {post.date} · {post.readingTime}
                    </div>
                    <h3 className="mt-2 font-display text-[1.1rem] font-bold leading-tight tracking-tight text-[var(--local-text)]">
                      {post.title}
                    </h3>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--local-text-muted)]">{post.excerpt}</p>
                  </CardContent>
                </Card>
              </a>
            ))}
          </div>
        ) : (
          data.emptyLabel && (
            <p className="mt-10 text-sm text-[var(--local-text-muted)]" data-jp-field="emptyLabel">
              {data.emptyLabel}
            </p>
          )
        )}
      </div>
    </section>
  );
};
EOF

cat > src/components/tag-posts/index.ts << 'EOF'
export { TagPosts } from './View';
export { TagPostsSchema } from './schema';
export type { TagPostsData, TagPostsSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: content-block
# -----------------------------------------------------------------------------
echo "-- Writing capsule: content-block..."
cat > src/components/content-block/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem, ImageSelectionSchema } from '@olonjs/core';

const ParagraphSchema = BaseArrayItem.extend({
  text: z.string().describe('ui:textarea'),
});

export const ContentBlockSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  paragraphs: z.array(ParagraphSchema).describe('ui:list'),
  image: ImageSelectionSchema.optional(),
});
EOF

cat > src/components/content-block/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ContentBlockSchema } from './schema';

export type ContentBlockData = z.infer<typeof ContentBlockSchema>;
export type ContentBlockSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/content-block/View.tsx << 'EOF'
import React from 'react';
import { AspectRatio } from '@/components/ui/aspect-ratio';
import type { ContentBlockData, ContentBlockSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const ContentBlock: React.FC<{ data: ContentBlockData; settings: ContentBlockSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        <div className={data.image?.url ? 'grid items-start gap-12 md:grid-cols-2' : ''}>
          <div>
            {data.label && (
              <div
                className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
                data-jp-field="label"
              >
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.2rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
            <div className="mt-8 space-y-5">
              {data.paragraphs.map((paragraph, idx) => (
                <p
                  key={paragraph.id || `legacy-${idx}`}
                  className="max-w-[62ch] text-base leading-[1.85] text-[var(--local-text-muted)]"
                  data-jp-item-id={paragraph.id || `legacy-${idx}`}
                  data-jp-item-field="paragraphs"
                >
                  {paragraph.text}
                </p>
              ))}
            </div>
          </div>
          {data.image?.url && (
            <div className="overflow-hidden rounded-[var(--local-radius-lg)] border border-[var(--local-border)]">
              <AspectRatio ratio={4 / 5}>
                <img src={data.image.url} alt={data.image.alt || ''} className="h-full w-full object-cover" />
              </AspectRatio>
            </div>
          )}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/content-block/index.ts << 'EOF'
export { ContentBlock } from './View';
export { ContentBlockSchema } from './schema';
export type { ContentBlockData, ContentBlockSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: stats-band (uses ui:icon-picker -> triggers STEP 9)
# -----------------------------------------------------------------------------
echo "-- Writing capsule: stats-band..."
cat > src/components/stats-band/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const StatSchema = BaseArrayItem.extend({
  icon: z.string().optional().describe('ui:icon-picker'),
  value: z.string().describe('ui:text'),
  label: z.string().describe('ui:text'),
});

export const StatsBandSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().optional().describe('ui:text'),
  stats: z.array(StatSchema).describe('ui:list'),
});
EOF

cat > src/components/stats-band/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { StatsBandSchema } from './schema';

export type StatsBandData = z.infer<typeof StatsBandSchema>;
export type StatsBandSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/stats-band/View.tsx << 'EOF'
import React from 'react';
import { iconMap } from '@/lib/IconResolver';
import type { StatsBandData, StatsBandSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const StatsBand: React.FC<{ data: StatsBandData; settings: StatsBandSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-accent-soft': 'var(--demo-accent-soft)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-lg': 'var(--theme-radius-lg)',
      } as React.CSSProperties}
      className={`relative z-0 ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className={containerClass}>
        {data.label && (
          <div
            className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4"
            data-jp-field="label"
          >
            <span className="w-5 h-px bg-[var(--local-primary)]" />
            {data.label}
          </div>
        )}
        {data.title && (
          <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.2rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}
          </h2>
        )}
        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {data.stats.map((stat, idx) => {
            const Icon = stat.icon ? iconMap[stat.icon] : undefined;
            return (
              <div
                key={stat.id || `legacy-${idx}`}
                className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6"
                data-jp-item-id={stat.id || `legacy-${idx}`}
                data-jp-item-field="stats"
              >
                {Icon && (
                  <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-[var(--local-accent-soft)]">
                    <Icon className="h-5 w-5 text-[var(--local-primary)]" />
                  </span>
                )}
                <div className="mt-4 font-display text-[2.2rem] font-black leading-none tracking-tight text-[var(--local-text)]">
                  {stat.value}
                </div>
                <div className="mt-2 text-sm text-[var(--local-text-muted)]">{stat.label}</div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/stats-band/index.ts << 'EOF'
export { StatsBand } from './View';
export { StatsBandSchema } from './schema';
export type { StatsBandData, StatsBandSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# CAPSULE: cta-banner
# -----------------------------------------------------------------------------
echo "-- Writing capsule: cta-banner..."
cat > src/components/cta-banner/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';

export const CtaBannerSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  primaryCta: CtaSchema,
  secondaryCta: CtaSchema.optional(),
});
EOF

cat > src/components/cta-banner/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { CtaBannerSchema } from './schema';

export type CtaBannerData = z.infer<typeof CtaBannerSchema>;
export type CtaBannerSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/cta-banner/View.tsx << 'EOF'
import React from 'react';
import { Button } from '@/components/ui/button';
import type { CtaBannerData, CtaBannerSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40',
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40',
};

export const CtaBanner: React.FC<{ data: CtaBannerData; settings: CtaBannerSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';

  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      // Mode-aware default: follows the site-wide toggle via the semantic
      // bridge ([data-theme="light"] override in globals.css).
      bg: 'var(--background)',
      text: 'var(--foreground)',
      muted: 'var(--muted-foreground)',
      surface: 'var(--card)',
      border: 'var(--border)',
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)',
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)',
    },
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-accent': 'var(--accent)',
        '--local-accent-soft': 'var(--demo-accent-soft)',
        '--local-border': t.border,
        '--local-radius-md': 'var(--theme-radius-md)',
      } as React.CSSProperties}
      className={`relative z-0 overflow-hidden ${paddingTop} ${paddingBottom} bg-[var(--local-bg)]`}
    >
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[1100px] h-[650px] bg-[radial-gradient(ellipse_at_50%_0%,var(--local-accent-soft),transparent_65%)] pointer-events-none" />
      <div className={containerClass}>
        <div className="mx-auto max-w-[840px] text-center">
          {data.label && (
            <div
              className="inline-flex items-center gap-2 bg-[var(--local-accent-soft)] border border-[var(--local-border)] px-4 py-1.5 rounded-full text-[0.70rem] font-mono font-semibold text-[var(--local-accent)] tracking-widest uppercase"
              data-jp-field="label"
            >
              <span className="w-1.5 h-1.5 rounded-full bg-[var(--local-primary)] jp-pulse-dot" />
              {data.label}
            </div>
          )}
          <h2
            className="mt-8 font-display font-black text-[clamp(3rem,7vw,6.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]"
            data-jp-field="title"
          >
            {data.title}
          </h2>
          {data.description && (
            <p className="mx-auto mt-6 max-w-[52ch] text-lg leading-relaxed text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
          )}
          <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
            <Button
              asChild
              variant="default"
              size="lg"
              className="rounded-[var(--local-radius-md)] bg-[var(--local-primary)] text-[var(--local-primary-foreground)] hover:opacity-90"
            >
              <a href={data.primaryCta.href} data-jp-field="primaryCta">{data.primaryCta.label}</a>
            </Button>
            {data.secondaryCta && (
              <Button
                asChild
                variant="outline"
                size="lg"
                className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-transparent text-[var(--local-text)] hover:border-[var(--local-accent)]"
              >
                <a href={data.secondaryCta.href} data-jp-field="secondaryCta">{data.secondaryCta.label}</a>
              </Button>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/cta-banner/index.ts << 'EOF'
export { CtaBanner } from './View';
export { CtaBannerSchema } from './schema';
export type { CtaBannerData, CtaBannerSettings } from './types';
EOF

# -----------------------------------------------------------------------------
# STEP 2 — src/types.ts (module augmentation — THE BRAIN)
# -----------------------------------------------------------------------------
echo "-- Writing src/types.ts..."
cat > src/types.ts << 'EOF'
import type { HeaderData, HeaderSettings } from '@/components/header';
import type { FooterData, FooterSettings } from '@/components/footer';
import type { HeroData, HeroSettings } from '@/components/hero';
import type { PageHeroData, PageHeroSettings } from '@/components/page-hero';
import type { PostsListData, PostsListSettings } from '@/components/posts-list';
import type { TagsListData, TagsListSettings } from '@/components/tags-list';
import type { PostDetailData, PostDetailSettings } from '@/components/post-detail';
import type { RelatedTagsData, RelatedTagsSettings } from '@/components/related-tags';
import type { TagDetailData, TagDetailSettings } from '@/components/tag-detail';
import type { TagPostsData, TagPostsSettings } from '@/components/tag-posts';
import type { ContentBlockData, ContentBlockSettings } from '@/components/content-block';
import type { StatsBandData, StatsBandSettings } from '@/components/stats-band';
import type { CtaBannerData, CtaBannerSettings } from '@/components/cta-banner';

export type SectionComponentPropsMap = {
  'header': { data: HeaderData; settings: HeaderSettings };
  'footer': { data: FooterData; settings: FooterSettings };
  'hero': { data: HeroData; settings: HeroSettings };
  'page-hero': { data: PageHeroData; settings: PageHeroSettings };
  'posts-list': { data: PostsListData; settings: PostsListSettings };
  'tags-list': { data: TagsListData; settings: TagsListSettings };
  'post-detail': { data: PostDetailData; settings: PostDetailSettings };
  'related-tags': { data: RelatedTagsData; settings: RelatedTagsSettings };
  'tag-detail': { data: TagDetailData; settings: TagDetailSettings };
  'tag-posts': { data: TagPostsData; settings: TagPostsSettings };
  'content-block': { data: ContentBlockData; settings: ContentBlockSettings };
  'stats-band': { data: StatsBandData; settings: StatsBandSettings };
  'cta-banner': { data: CtaBannerData; settings: CtaBannerSettings };
};

declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    'header': HeaderData;
    'footer': FooterData;
    'hero': HeroData;
    'page-hero': PageHeroData;
    'posts-list': PostsListData;
    'tags-list': TagsListData;
    'post-detail': PostDetailData;
    'related-tags': RelatedTagsData;
    'tag-detail': TagDetailData;
    'tag-posts': TagPostsData;
    'content-block': ContentBlockData;
    'stats-band': StatsBandData;
    'cta-banner': CtaBannerData;
  }
  export interface SectionSettingsRegistry {
    'header': HeaderSettings;
    'footer': FooterSettings;
    'hero': HeroSettings;
    'page-hero': PageHeroSettings;
    'posts-list': PostsListSettings;
    'tags-list': TagsListSettings;
    'post-detail': PostDetailSettings;
    'related-tags': RelatedTagsSettings;
    'tag-detail': TagDetailSettings;
    'tag-posts': TagPostsSettings;
    'content-block': ContentBlockSettings;
    'stats-band': StatsBandSettings;
    'cta-banner': CtaBannerSettings;
  }
}

export * from '@olonjs/core';
EOF

# -----------------------------------------------------------------------------
# STEP 3 — src/lib/ComponentRegistry.tsx (THE MAP — 13 imports, 13 keys)
# -----------------------------------------------------------------------------
echo "-- Writing src/lib/ComponentRegistry.tsx..."
cat > src/lib/ComponentRegistry.tsx << 'EOF'
import React from 'react';
import { Header } from '@/components/header';
import { Footer } from '@/components/footer';
import { Hero } from '@/components/hero';
import { PageHero } from '@/components/page-hero';
import { PostsList } from '@/components/posts-list';
import { TagsList } from '@/components/tags-list';
import { PostDetail } from '@/components/post-detail';
import { RelatedTags } from '@/components/related-tags';
import { TagDetail } from '@/components/tag-detail';
import { TagPosts } from '@/components/tag-posts';
import { ContentBlock } from '@/components/content-block';
import { StatsBand } from '@/components/stats-band';
import { CtaBanner } from '@/components/cta-banner';

import type { SectionType } from '@olonjs/core';
import type { SectionComponentPropsMap } from '@/types';

export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = {
  'header': Header,
  'footer': Footer,
  'hero': Hero,
  'page-hero': PageHero,
  'posts-list': PostsList,
  'tags-list': TagsList,
  'post-detail': PostDetail,
  'related-tags': RelatedTags,
  'tag-detail': TagDetail,
  'tag-posts': TagPosts,
  'content-block': ContentBlock,
  'stats-band': StatsBand,
  'cta-banner': CtaBanner,
};
EOF

# -----------------------------------------------------------------------------
# STEP 4 — src/lib/schemas.ts (THE INSPECTOR)
# -----------------------------------------------------------------------------
echo "-- Writing src/lib/schemas.ts..."
cat > src/lib/schemas.ts << 'EOF'
import { HeaderSchema } from '@/components/header';
import { FooterSchema } from '@/components/footer';
import { HeroSchema } from '@/components/hero';
import { PageHeroSchema } from '@/components/page-hero';
import { PostsListSchema } from '@/components/posts-list';
import { TagsListSchema } from '@/components/tags-list';
import { PostDetailSchema } from '@/components/post-detail';
import { RelatedTagsSchema } from '@/components/related-tags';
import { TagDetailSchema } from '@/components/tag-detail';
import { TagPostsSchema } from '@/components/tag-posts';
import { ContentBlockSchema } from '@/components/content-block';
import { StatsBandSchema } from '@/components/stats-band';
import { CtaBannerSchema } from '@/components/cta-banner';

export const SECTION_SCHEMAS = {
  'header': HeaderSchema,
  'footer': FooterSchema,
  'hero': HeroSchema,
  'page-hero': PageHeroSchema,
  'posts-list': PostsListSchema,
  'tags-list': TagsListSchema,
  'post-detail': PostDetailSchema,
  'related-tags': RelatedTagsSchema,
  'tag-detail': TagDetailSchema,
  'tag-posts': TagPostsSchema,
  'content-block': ContentBlockSchema,
  'stats-band': StatsBandSchema,
  'cta-banner': CtaBannerSchema,
} as const;

// Submission schemas per section type. Required runtime export — keep
// even if empty: omitting it makes the engine bootstrap fail at startup.
export const SECTION_SUBMISSION_SCHEMAS = {
  // no form capsules in this tenant
} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core';
EOF

# -----------------------------------------------------------------------------
# STEP 5 — src/lib/addSectionConfig.ts (THE LIBRARY)
# -----------------------------------------------------------------------------
echo "-- Writing src/lib/addSectionConfig.ts..."
cat > src/lib/addSectionConfig.ts << 'EOF'
import type { AddSectionConfig } from '@olonjs/core';

// Detail capsules (post-detail, related-tags, tag-detail, tag-posts) are
// intentionally NOT addable: they depend on the `collection:current` binding,
// which only exists on pages declaring a `collection` route (COP §8).
const addableSectionTypes = [
  'hero',
  'page-hero',
  'posts-list',
  'tags-list',
  'content-block',
  'stats-band',
  'cta-banner',
] as const;

const sectionTypeLabels: Record<string, string> = {
  'hero': 'Editorial Hero',
  'page-hero': 'Page Hero',
  'posts-list': 'Posts List',
  'tags-list': 'Tags List',
  'content-block': 'Content Block',
  'stats-band': 'Stats Band',
  'cta-banner': 'CTA Banner',
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'hero':
      return {
        title: 'A headline worth reading',
        subtitle: 'Say the one thing this page exists to say.',
        primaryCta: { id: 'cta-primary', label: 'Read the journal', href: '/posts', variant: 'primary' },
      };
    case 'page-hero':
      return { title: 'New page title' };
    case 'posts-list':
      return { title: 'Latest posts', items: {} };
    case 'tags-list':
      return { title: 'Browse by topic', items: {} };
    case 'content-block':
      return { title: 'A section worth writing', paragraphs: [] };
    case 'stats-band':
      return { stats: [] };
    case 'cta-banner':
      return {
        title: 'Start reading',
        primaryCta: { id: 'cta-primary', label: 'Browse the posts', href: '/posts', variant: 'primary' },
      };
    default:
      return {};
  }
}

export const addSectionConfig: AddSectionConfig = {
  addableSectionTypes: [...addableSectionTypes],
  sectionTypeLabels,
  getDefaultSectionData,
};
EOF

# -----------------------------------------------------------------------------
# STEP 9 — src/lib/IconResolver.tsx (ui:icon-picker used by stats-band)
# -----------------------------------------------------------------------------
echo "-- Writing src/lib/IconResolver.tsx..."
cat > src/lib/IconResolver.tsx << 'EOF'
import type { LucideIcon } from 'lucide-react';
import { PenLine, Tag, Users, Sparkles, BookOpen, Rss } from 'lucide-react';

export const iconMap: Record<string, LucideIcon> = {
  'pen-line': PenLine,
  'tag': Tag,
  'users': Users,
  'sparkles': Sparkles,
  'book-open': BookOpen,
  'rss': Rss,
};
EOF

# -----------------------------------------------------------------------------
# STEP 7 — CONFIG DATA
# -----------------------------------------------------------------------------
echo "-- Writing src/data/config/theme.json..."
cat > src/data/config/theme.json << 'EOF'
{
  "name": "Inkwell Journal",
  "tokens": {
    "colors": {
      "background": "#101014",
      "foreground": "#ece9e2",
      "card": "#17171d",
      "card-foreground": "#ece9e2",
      "elevated": "#1d1d25",
      "overlay": "#22222b",
      "primary": "#e0745c",
      "primary-foreground": "#14100e",
      "primary-light": "#eb9480",
      "primary-dark": "#b85a45",
      "accent": "#9db4e8",
      "accent-foreground": "#10131c",
      "secondary": "#23232c",
      "secondary-foreground": "#d8d5cd",
      "muted": "#1b1b22",
      "muted-foreground": "#97948c",
      "border": "#26262f",
      "border-strong": "#34343f",
      "input": "#1d1d25",
      "ring": "#e0745c",
      "destructive": "#e5484d",
      "destructive-foreground": "#fff0f0",
      "success": "#4cc38a",
      "success-foreground": "#06130c",
      "warning": "#f5b944",
      "warning-foreground": "#171105",
      "info": "#6ba6f5",
      "info-foreground": "#081321"
    },
    "typography": {
      "fontFamily": {
        "primary": "'Instrument Sans', system-ui, sans-serif",
        "mono": "'JetBrains Mono', monospace",
        "display": "'Bricolage Grotesque', system-ui, sans-serif"
      },
      "wordmark": {
        "fontFamily": "'Bricolage Grotesque', system-ui, sans-serif",
        "weight": "800"
      }
    },
    "borderRadius": { "sm": "4px", "md": "8px", "lg": "14px", "xl": "20px", "full": "9999px" },
    "spacing": {
      "container-max": "1200px",
      "section-y": "96px",
      "header-h": "80px",
      "sidebar-w": "240px"
    },
    "zIndex": {
      "base": "0", "elevated": "10", "dropdown": "100",
      "sticky": "200", "overlay": "300", "modal": "400", "toast": "500"
    },
    "modes": {
      "light": {
        "colors": {
          "background": "#faf8f4",
          "foreground": "#1d1c1a",
          "card": "#ffffff",
          "card-foreground": "#1d1c1a",
          "elevated": "#f2efe8",
          "overlay": "#e8e4da",
          "primary": "#c1543c",
          "primary-foreground": "#fdf6f3",
          "primary-light": "#d4765f",
          "primary-dark": "#9c4230",
          "accent": "#4a66b0",
          "accent-foreground": "#f5f7fd",
          "secondary": "#ece8df",
          "secondary-foreground": "#37352f",
          "muted": "#f0ede5",
          "muted-foreground": "#6d6a61",
          "border": "#e0dcd1",
          "border-strong": "#c9c4b6",
          "input": "#ffffff",
          "ring": "#c1543c",
          "destructive": "#d33c41",
          "destructive-foreground": "#fff5f5",
          "success": "#1f7a4d",
          "success-foreground": "#f0fbf5",
          "warning": "#a86a0b",
          "warning-foreground": "#fffaf0",
          "info": "#2563c4",
          "info-foreground": "#f0f6ff"
        }
      }
    }
  }
}
EOF

echo "-- Writing src/data/config/site.json..."
cat > src/data/config/site.json << 'EOF'
{
  "header": {
    "id": "global-header",
    "type": "header",
    "data": {
      "logoText": "Inkwell",
      "logoHighlight": "journal",
      "announcement": "Collections demo: posts and tags, linked both ways",
      "menu": { "$ref": "../config/menu.json#/main" }
    },
    "settings": { "sticky": true }
  },
  "footer": {
    "id": "global-footer",
    "type": "footer",
    "data": {
      "brandText": "Inkwell",
      "tagline": "Notes on the craft of making software. An OlonJS demo tenant showing collections and cross-collection relations.",
      "email": "hello@inkwell-journal.example",
      "copyright": "© 2026 Inkwell Journal. Written slowly, shipped quietly.",
      "menu": { "$ref": "../config/menu.json#/footer" }
    },
    "settings": { "showLogo": true }
  },
  "identity": { "title": "Inkwell Journal" }
}
EOF

echo "-- Writing src/data/config/menu.json..."
cat > src/data/config/menu.json << 'EOF'
{
  "main": [
    { "id": "menu-home", "label": "Home", "href": "/" },
    { "id": "menu-posts", "label": "Posts", "href": "/posts" },
    { "id": "menu-tags", "label": "Topics", "href": "/tags" },
    { "id": "menu-about", "label": "About", "href": "/about" },
    { "id": "menu-contact", "label": "Contact", "href": "/contact", "isCta": true }
  ],
  "footer": [
    { "id": "footer-posts", "label": "Posts", "href": "/posts" },
    { "id": "footer-tags", "label": "Topics", "href": "/tags" },
    { "id": "footer-about", "label": "About", "href": "/about" },
    { "id": "footer-contact", "label": "Contact", "href": "/contact" }
  ]
}
EOF

# -----------------------------------------------------------------------------
# STEP 7 — PAGES
# -----------------------------------------------------------------------------
echo "-- Writing page: home..."
cat > src/data/pages/home.json << 'EOF'
{
  "id": "home-page",
  "slug": "home",
  "meta": {
    "title": "Inkwell Journal — Notes on the craft of software",
    "description": "An editorial journal about design, engineering and process, built on OlonJS collections: every post and every tag is a first-class entity with its own page."
  },
  "sections": [
    {
      "id": "home-hero",
      "type": "hero",
      "data": {
        "label": "An OlonJS collections demo",
        "title": "Notes on the",
        "titleHighlight": "craft of software",
        "subtitle": "Essays on design, engineering and process — published as a living demo of cross-collection relations: every post belongs to many tags, and every tag knows its posts without storing them twice.",
        "primaryCta": { "id": "home-hero-cta-1", "label": "Read the posts", "href": "/posts", "variant": "primary" },
        "secondaryCta": { "id": "home-hero-cta-2", "label": "Browse topics", "href": "/tags", "variant": "secondary" },
        "image": { "url": "https://images.unsplash.com/photo-1456735190827-d1262f71b8a3?w=2000&q=80", "alt": "Fountain pen nib in sharp close-up over paper" }
      },
      "settings": { "paddingTop": "xl", "paddingBottom": "none" }
    },
    {
      "id": "home-featured-posts",
      "type": "posts-list",
      "data": {
        "label": "Fresh ink",
        "title": "Latest from the desk",
        "description": "The four most recent essays, pulled live from the posts collection and sorted by date.",
        "variant": "bento",
        "limit": 4,
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "home-tags",
      "type": "tags-list",
      "data": {
        "label": "Topics",
        "title": "Browse by topic",
        "description": "Six tags, one collection. Each card links to a tag page that computes its own post list from the relation.",
        "items": { "$ref": "../collections/tags/tags.json" }
      },
      "settings": {}
    },
    {
      "id": "home-stats",
      "type": "stats-band",
      "data": {
        "label": "The journal in numbers",
        "title": "Small, deliberate, linked",
        "stats": [
          { "id": "stat-posts", "icon": "pen-line", "value": "8", "label": "Essays published, each in a posts collection entry" },
          { "id": "stat-tags", "icon": "tag", "value": "6", "label": "Topics in the tags collection" },
          { "id": "stat-relations", "icon": "sparkles", "value": "14", "label": "Post-to-tag links resolved at render time" },
          { "id": "stat-authors", "icon": "users", "value": "4", "label": "Writers behind the desk" }
        ]
      },
      "settings": {}
    },
    {
      "id": "home-cta",
      "type": "cta-banner",
      "data": {
        "label": "Start anywhere",
        "title": "Pick a thread, pull it",
        "description": "Every post links to its topics and every topic links back to its posts. That is the whole demo — and the whole point.",
        "primaryCta": { "id": "home-cta-1", "label": "Read the latest", "href": "/posts", "variant": "primary" },
        "secondaryCta": { "id": "home-cta-2", "label": "About this demo", "href": "/about", "variant": "secondary" }
      },
      "settings": { "paddingTop": "xl", "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: posts..."
cat > src/data/pages/posts.json << 'EOF'
{
  "id": "posts-page",
  "slug": "posts",
  "meta": {
    "title": "All posts — Inkwell Journal essay archive",
    "description": "The complete archive of Inkwell Journal essays on design, engineering, writing and process, rendered as a timeline from the posts collection."
  },
  "sections": [
    {
      "id": "posts-hero",
      "type": "page-hero",
      "data": {
        "label": "Archive",
        "title": "Every post, in order",
        "description": "The full posts collection rendered as a timeline. Each entry carries its tag keys — follow one to jump into the inverse relation."
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "posts-archive",
      "type": "posts-list",
      "data": {
        "title": "The archive",
        "variant": "timeline",
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": {}
    },
    {
      "id": "posts-topics",
      "type": "tags-list",
      "data": {
        "label": "Another way in",
        "title": "Prefer to browse by topic?",
        "items": { "$ref": "../collections/tags/tags.json" }
      },
      "settings": {}
    },
    {
      "id": "posts-cta",
      "type": "cta-banner",
      "data": {
        "title": "Say hello",
        "description": "Questions about the writing, or about how this demo wires its collections together? We read every message.",
        "primaryCta": { "id": "posts-cta-1", "label": "Contact us", "href": "/contact", "variant": "primary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: tags..."
cat > src/data/pages/tags.json << 'EOF'
{
  "id": "tags-page",
  "slug": "tags",
  "meta": {
    "title": "Topics — browse Inkwell Journal by tag",
    "description": "Six topics spanning design, engineering, process, writing, tooling and culture. Each tag page computes its own post list from the posts-to-tags relation."
  },
  "sections": [
    {
      "id": "tags-hero",
      "type": "page-hero",
      "data": {
        "label": "Topics",
        "title": "Browse by topic",
        "description": "Tags are their own collection. No tag stores a post list — each tag page filters the posts collection live, so the relation can never drift out of sync."
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "tags-all",
      "type": "tags-list",
      "data": {
        "title": "All topics",
        "items": { "$ref": "../collections/tags/tags.json" }
      },
      "settings": {}
    },
    {
      "id": "tags-recent-posts",
      "type": "posts-list",
      "data": {
        "label": "Or start reading",
        "title": "Fresh off the press",
        "variant": "bento",
        "limit": 3,
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": {}
    },
    {
      "id": "tags-cta",
      "type": "cta-banner",
      "data": {
        "title": "Lost? Start at the top",
        "primaryCta": { "id": "tags-cta-1", "label": "Back to home", "href": "/", "variant": "primary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: posts/[slug] (post detail + related-tags)..."
cat > src/data/pages/post-detail.json << 'EOF'
{
  "id": "post-detail-page",
  "slug": "posts/[slug]",
  "collection": { "source": "posts", "paramKey": "slug" },
  "meta": {
    "title": "Post — Inkwell Journal essay detail",
    "description": "A single essay from the Inkwell Journal posts collection, with its related topics resolved live from the posts-to-tags relation."
  },
  "sections": [
    {
      "id": "post-detail-body",
      "type": "post-detail",
      "data": {
        "backLabel": "All posts",
        "item": { "$ref": "collection:current" }
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "post-detail-related-tags",
      "type": "related-tags",
      "data": {
        "label": "Relations demo",
        "title": "Filed under",
        "emptyLabel": "This post has no topics yet.",
        "item": { "$ref": "collection:current" },
        "tags": { "$ref": "../collections/tags/tags.json" }
      },
      "settings": {}
    },
    {
      "id": "post-detail-cta",
      "type": "cta-banner",
      "data": {
        "title": "Keep reading",
        "primaryCta": { "id": "post-detail-cta-1", "label": "Back to the archive", "href": "/posts", "variant": "primary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: tags/[slug] (tag detail + tag-posts)..."
cat > src/data/pages/tag-detail.json << 'EOF'
{
  "id": "tag-detail-page",
  "slug": "tags/[slug]",
  "collection": { "source": "tags", "paramKey": "slug" },
  "meta": {
    "title": "Topic — Inkwell Journal posts by tag",
    "description": "A single topic from the tags collection, with every matching essay computed live by filtering the posts collection on the current tag key."
  },
  "sections": [
    {
      "id": "tag-detail-head",
      "type": "tag-detail",
      "data": {
        "backLabel": "All topics",
        "item": { "$ref": "collection:current" }
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "tag-detail-posts",
      "type": "tag-posts",
      "data": {
        "title": "Posts on this topic",
        "emptyLabel": "No posts carry this tag yet.",
        "item": { "$ref": "collection:current" },
        "posts": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": {}
    },
    {
      "id": "tag-detail-cta",
      "type": "cta-banner",
      "data": {
        "title": "Explore another thread",
        "primaryCta": { "id": "tag-detail-cta-1", "label": "All topics", "href": "/tags", "variant": "primary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: about..."
cat > src/data/pages/about.json << 'EOF'
{
  "id": "about-page",
  "slug": "about",
  "meta": {
    "title": "About Inkwell Journal and this collections demo",
    "description": "Inkwell Journal is a working OlonJS demo: posts and tags live as separate collections, related through keys on the post side and resolved at render time."
  },
  "sections": [
    {
      "id": "about-hero",
      "type": "page-hero",
      "data": {
        "label": "About",
        "title": "A journal that is also a diagram",
        "description": "Inkwell exists to show one architectural idea clearly: entities as collections, relations as keys, and rendering as resolution."
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "about-story",
      "type": "content-block",
      "data": {
        "label": "How it works",
        "title": "One source of truth per relation",
        "paragraphs": [
          { "id": "about-p1", "text": "Every essay in this journal is an entry in the posts collection, and every topic is an entry in the tags collection. A post declares its topics as an array of tag keys — that array is the only place the relation is stored." },
          { "id": "about-p2", "text": "The post page resolves those keys against the tags collection to render its topic chips. The tag page runs the relation in reverse: it filters the whole posts collection for entries carrying its key. Nothing is denormalized, so nothing can drift." },
          { "id": "about-p3", "text": "Everything you see — copy, images, colors, even this paragraph — is schema-driven data, editable in the OlonJS Studio without touching a line of component code." }
        ],
        "image": { "url": "https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=1600&q=80", "alt": "Tall library shelves filled with books seen from below" }
      },
      "settings": {}
    },
    {
      "id": "about-stats",
      "type": "stats-band",
      "data": {
        "label": "Under the hood",
        "title": "What powers the demo",
        "stats": [
          { "id": "about-stat-1", "icon": "book-open", "value": "2", "label": "Collections: posts and tags" },
          { "id": "about-stat-2", "icon": "tag", "value": "1", "label": "Direction of stored truth: post to tags" },
          { "id": "about-stat-3", "icon": "sparkles", "value": "2", "label": "Directions rendered: posts to tags, tags to posts" },
          { "id": "about-stat-4", "icon": "rss", "value": "7", "label": "Pages, two of them dynamic collection routes" }
        ]
      },
      "settings": {}
    },
    {
      "id": "about-cta",
      "type": "cta-banner",
      "data": {
        "title": "See it in motion",
        "description": "Open any post, tap a topic chip, and watch the inverse relation resolve on the tag page.",
        "primaryCta": { "id": "about-cta-1", "label": "Open the archive", "href": "/posts", "variant": "primary" },
        "secondaryCta": { "id": "about-cta-2", "label": "Browse topics", "href": "/tags", "variant": "secondary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

echo "-- Writing page: contact..."
cat > src/data/pages/contact.json << 'EOF'
{
  "id": "contact-page",
  "slug": "contact",
  "meta": {
    "title": "Contact the Inkwell Journal editorial desk",
    "description": "Write to the Inkwell Journal desk about the essays, the OlonJS collections demo, or anything in between. We answer within two working days."
  },
  "sections": [
    {
      "id": "contact-hero",
      "type": "page-hero",
      "data": {
        "label": "Contact",
        "title": "Write to the desk",
        "description": "Questions, corrections, or curiosity about how the collections are wired — all welcome."
      },
      "settings": { "paddingTop": "xl" }
    },
    {
      "id": "contact-details",
      "type": "content-block",
      "data": {
        "label": "Reach us",
        "title": "Where to find us",
        "paragraphs": [
          { "id": "contact-p1", "text": "Email is the fastest route: hello@inkwell-journal.example. We read everything and answer within two working days, usually sooner." },
          { "id": "contact-p2", "text": "The desk sits at Via dei Tipografi 12, 40126 Bologna — visits by appointment. If you are writing about a correction, include the post title and the paragraph you mean." }
        ],
        "image": { "url": "https://images.unsplash.com/photo-1504868584819-f8e8b4b6d7e3?w=1600&q=80", "alt": "Vintage typewriter with a blank sheet of paper on a desk" }
      },
      "settings": {}
    },
    {
      "id": "contact-editorial",
      "type": "content-block",
      "data": {
        "label": "Pitches",
        "title": "Want to write for Inkwell?",
        "paragraphs": [
          { "id": "contact-p3", "text": "We publish outside voices a few times a year. Pitch us one paragraph: the single sentence your piece exists to deliver, and why you are the person to write it." },
          { "id": "contact-p4", "text": "Every accepted piece becomes an entry in the posts collection with its own tags — your essay ships wired into the same relation graph you are reading now." }
        ]
      },
      "settings": {}
    },
    {
      "id": "contact-cta",
      "type": "cta-banner",
      "data": {
        "title": "Or just start reading",
        "primaryCta": { "id": "contact-cta-1", "label": "Latest posts", "href": "/posts", "variant": "primary" }
      },
      "settings": { "paddingBottom": "xl" }
    }
  ]
}
EOF

# -----------------------------------------------------------------------------
# STEP 9 — AdminStudioClient wiring check (iconRegistry + collections + collectionSchemas)
# -----------------------------------------------------------------------------
echo "-- Step 9: checking AdminStudioClient wiring (iconRegistry + collections)..."
ADMIN_CLIENT="src/components/admin/AdminStudioClient.tsx"
if [[ -f "$ADMIN_CLIENT" ]] \
  && grep -q "iconRegistry" "$ADMIN_CLIENT" \
  && grep -q "collectionSchemas" "$ADMIN_CLIENT" \
  && grep -q "collections" "$ADMIN_CLIENT"; then
  echo "   AdminStudioClient wires iconRegistry, collections and collectionSchemas — ok"
else
  echo "!! AdminStudioClient missing iconRegistry / collections / collectionSchemas."
  echo "!! Refusing to guess a patch location. Current wiring found:"
  grep -n "iconRegistry\|collectionSchemas\|collections\|CollectionRegistry\|iconMap" "$ADMIN_CLIENT" 2>/dev/null || true
  echo "!! Manually ensure AdminStudioClient builds JsonPagesConfig with:"
  echo "     iconRegistry: iconMap,                  // import { iconMap } from '@/lib/IconResolver'"
  echo "     collections: <collections data map>,    // e.g. getFileCollections() or explicit JSON imports"
  echo "     collectionSchemas: CollectionRegistry,  // import { CollectionRegistry } from '@/lib/CollectionRegistry'"
  exit 1
fi

# -----------------------------------------------------------------------------
# BUILD
# -----------------------------------------------------------------------------
echo "-- Building..."
npm run build

echo ""
echo "=============================================================="
echo "  INKWELL JOURNAL — spec-compliance checklist"
echo "=============================================================="
echo "  [x] Step 0  shadcn/ui init + component set (new-york, slate)"
echo "  [x] Step 1  13 capsules: header, footer, hero, page-hero,"
echo "              posts-list, tags-list, post-detail, related-tags,"
echo "              tag-detail, tag-posts, content-block, stats-band,"
echo "              cta-banner (View/schema/types/index each)"
echo "  [x] Step 2  src/types.ts — 13 entries in PropsMap + both registries"
echo "  [x] Step 3  ComponentRegistry — 13 imports == 13 keys"
echo "  [x] Step 4  SECTION_SCHEMAS (13) + SECTION_SUBMISSION_SCHEMAS (empty)"
echo "  [x] Step 5  addSectionConfig — 7 addable types (detail capsules excluded)"
echo "  [x] Step 6  globals.css — fonts @import first line, semantic bridge,"
echo "              [data-theme=light] override, TOCC overlay, animations"
echo "  [x] Step 7  theme.json (dark + modes.light), site.json ($ref menu),"
echo "              menu.json, 7 pages (all ids end in -page)"
echo "  [x] Step 8  COP: posts + tags collections (keyed objects),"
echo "              CollectionRegistry, ui:collection-ref bindings,"
echo "              posts/[slug] + tags/[slug] dynamic pages,"
echo "              collection:current refs on detail sections"
echo "  [x] Step 9  IconResolver (6 icons) + AdminStudioClient wiring verified"
echo "  [x] Relations: posts->tags stored on post side only;"
echo "              tags->posts computed at render (tag-posts capsule);"
echo "              post detail resolves tag keys (related-tags capsule)"
echo "  [x] Light/dark: both palettes designed; header toggle via dataset.theme"
echo "  [x] Typography: Bricolage Grotesque / Instrument Sans / JetBrains Mono"
echo "  [x] No emoji, no hardcoded theme colors, CTAs use .label,"
echo "              images use optional chaining, z-0 on section roots"
echo "=============================================================="

END_OF_FILE_CONTENT
chmod +x "templates/generate_inkwell_next.sh"
echo "Creating tsconfig.json..."
cat << 'END_OF_FILE_CONTENT' > "tsconfig.json"
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["DOM", "DOM.Iterable", "ES2020"],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    },
    "baseUrl": "."
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules", "src/**/*.test.ts"]
}

END_OF_FILE_CONTENT
echo "Creating vitest.config.ts..."
cat << 'END_OF_FILE_CONTENT' > "vitest.config.ts"
import { defineConfig } from 'vitest/config';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});

END_OF_FILE_CONTENT
