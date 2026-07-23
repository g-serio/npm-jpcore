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

