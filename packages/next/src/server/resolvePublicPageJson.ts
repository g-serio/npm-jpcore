import {
  resolvePublicPageDocument,
  type MenuConfig,
  type PageConfig,
  type SiteConfig,
  type JsonPagesConfig,
} from '@olonjs/core';

export type PublicPageContentBundle = {
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  menuConfig: MenuConfig;
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
};

export type ResolvePublicPageJsonResult = {
  page: PageConfig;
  registrySlug: string;
  params: Record<string, string>;
};

/**
 * Normalize public page JSON request paths:
 * `/pages/home.json`, `home.json`, `libri/1984.json` → registry/request slug.
 */
export function normalizePublicPageSlug(raw: string): string {
  let slug = raw.trim();
  if (slug.startsWith('/')) slug = slug.slice(1);
  if (slug.startsWith('pages/')) slug = slug.slice('pages/'.length);
  if (slug.endsWith('.json')) slug = slug.slice(0, -'.json'.length);
  return slug || 'home';
}

/**
 * Resolve a public page document for JSON responses (Vite `/slug.json` parity).
 * Returns null when the slug does not match the page registry.
 */
export function resolvePublicPageJson(input: {
  slug: string;
  bundle: PublicPageContentBundle;
}): ResolvePublicPageJsonResult | null {
  const slug = normalizePublicPageSlug(input.slug);
  const resolved = resolvePublicPageDocument({
    slug,
    pages: input.bundle.pages,
    siteConfig: input.bundle.siteConfig,
    themeConfig: input.bundle.themeConfig,
    menuConfig: input.bundle.menuConfig,
    collections: input.bundle.collections,
    collectionSchemas: input.bundle.collectionSchemas,
    refDocuments: input.bundle.refDocuments,
  });
  if (!resolved) return null;
  return {
    page: resolved.page,
    registrySlug: resolved.pageMatch.registrySlug,
    params: resolved.pageMatch.params,
  };
}
