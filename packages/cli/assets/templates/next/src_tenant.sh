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
  resolveCollectionContext,
  resolveRuntimeConfig,
  type PageConfig,
} from '@olonjs/core';
import { loadVisitorPage } from '@olonjs/next/server';
import { EmptyTenantView } from '@/components/empty-tenant';
import { CollectionRegistry } from '@/lib/CollectionRegistry';
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

  return (
    <>
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
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "vitest run",
    "typecheck": "tsc --noEmit",
    "dist": "bash ./src2Code.sh --template next app src middleware.ts next.config.ts postcss.config.mjs tsconfig.json package.json next-env.d.ts vitest.config.ts",
    "dist:dna": "npm run dist"
  },
  "dependencies": {
    "@olonjs/core": "^1.1.21",
    "@olonjs/next": "^0.0.2",
    "@olonjs/react": "^0.1.4",
    "@olonjs/studio": "^0.1.4",
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
mkdir -p "src"
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
import { cloudPolicy, TENANT_ID } from '@/lib/env/tenantEnv';

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
echo "Creating src/lib/env/tenantEnv.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/env/tenantEnv.ts"
import { resolveCloudPolicy, type CloudEnvInput, type CloudPolicy } from '@olonjs/react';

/**
 * Read Next.js public env → CloudEnvInput.
 * Prefer NEXT_PUBLIC_OLONJS_* ; also accept NEXT_PUBLIC_JSONPAGES_* and
 * NEXT_PUBLIC_SAVE2REPO (alpha-style flag name under the Next public prefix).
 *
 * Note: `import.meta.env` / VITE_* are not available in the Next client bundle
 * unless mirrored via next.config — do not call readCloudEnvFromVite here.
 */
export function readCloudEnvFromNext(
  env: Record<string, string | undefined> = typeof process !== 'undefined' ? process.env : {},
): CloudEnvInput {
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

/** Single policy path for the Next admin island. */
export const cloudPolicy: CloudPolicy = resolveCloudPolicy(readCloudEnvFromNext());

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
