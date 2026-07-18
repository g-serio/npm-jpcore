import type { JsonPagesConfig } from '@olonjs/core';
import type { PageConfig, SiteConfig } from '@/types';

export function applyCachedBootstrap(params: {
  cachedPages: Record<string, PageConfig> | null;
  cachedSite: SiteConfig | null;
  cachedCollections?: JsonPagesConfig['collections'];
  setPages: (pages: Record<string, PageConfig>) => void;
  setSiteConfig: (site: SiteConfig) => void;
  setCollections: (collections: NonNullable<JsonPagesConfig['collections']>) => void;
}): boolean {
  const { cachedPages, cachedSite, cachedCollections, setPages, setSiteConfig, setCollections } = params;
  const hasPages = Boolean(cachedPages && Object.keys(cachedPages).length > 0);
  const hasSite = Boolean(cachedSite);
  if (!hasPages && !hasSite) return false;
  if (cachedPages && hasPages) setPages(cachedPages);
  if (cachedSite) setSiteConfig(cachedSite);
  if (cachedCollections) setCollections(cachedCollections);
  return true;
}
