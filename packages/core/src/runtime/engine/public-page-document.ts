import {
  resolveCollectionContext,
  resolveRuntimeConfig,
  type CollectionResolutionContext,
} from '../../contract/config-resolver';
import type { MenuConfig, PageConfig, SiteConfig } from '../../contract/kernel';
import type { JsonPagesConfig } from '../../contract/types-engine';
import { resolvePageMatchFromRegistry, type PageRouteMatch } from './route-utils';

export interface ResolvePublicPageDocumentInput {
  slug: string;
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  menuConfig: MenuConfig;
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
}

export interface ResolvedPublicPageDocument {
  page: PageConfig;
  siteConfig: SiteConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  menuConfig: MenuConfig;
  pageMatch: PageRouteMatch;
  collectionContext: CollectionResolutionContext | null;
}

export function resolvePublicPageDocument(
  input: ResolvePublicPageDocumentInput
): ResolvedPublicPageDocument | null {
  const pageMatch = resolvePageMatchFromRegistry(input.pages, input.slug);
  if (!pageMatch) return null;

  const collectionContext = resolveCollectionContext(
    pageMatch.page,
    pageMatch.params,
    input.collections
  );
  const resolvedRuntime = resolveRuntimeConfig({
    pages: { [pageMatch.registrySlug]: pageMatch.page },
    siteConfig: input.siteConfig,
    themeConfig: input.themeConfig,
    menuConfig: input.menuConfig,
    collections: input.collections,
    collectionSchemas: input.collectionSchemas,
    collectionContext,
    refDocuments: input.refDocuments,
  });
  const resolvedPage = resolvedRuntime.pages[pageMatch.registrySlug] ?? pageMatch.page;

  return {
    page: {
      ...resolvedPage,
      slug: pageMatch.requestedSlug,
    },
    siteConfig: resolvedRuntime.siteConfig,
    themeConfig: resolvedRuntime.themeConfig,
    menuConfig: resolvedRuntime.menuConfig,
    pageMatch,
    collectionContext: resolvedRuntime.collectionContext,
  };
}
