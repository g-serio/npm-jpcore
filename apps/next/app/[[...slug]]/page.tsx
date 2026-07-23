import type { Metadata } from 'next';
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
