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
