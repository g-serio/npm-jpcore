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
