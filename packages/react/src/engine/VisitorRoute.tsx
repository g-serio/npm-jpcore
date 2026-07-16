import React, { useEffect, useMemo } from 'react';
import { useLocation } from 'react-router-dom';
import {
  resolveCollectionContext,
  resolveRuntimeConfig,
  buildPageContractHref,
  buildPageManifestHref,
  syncHeadLink,
  syncWebMcpJsonLd,
  resolvePageMatchFromRegistry,
  resolveSlugFromPathname,
  type JsonPagesConfig,
  type MenuConfig,
  type PageConfig,
  type SiteConfig,
} from '@olonjs/core';
import { StudioProvider } from '../studio-mode/StudioContext';
import { PageRenderer } from '../rendering/PageRenderer';
import { ThemeLoader } from '../theme/ThemeLoader';
import { themeManager } from '../theme/theme-manager';

export interface VisitorRouteProps {
  pageRegistry: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  menuConfig: MenuConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
  tenantCss: string;
  adminCss: string;
  NotFoundComponent: React.ComponentType;
}

export const VisitorRoute: React.FC<VisitorRouteProps> = ({
  pageRegistry,
  siteConfig,
  menuConfig,
  themeConfig,
  collections,
  collectionSchemas,
  refDocuments,
  tenantCss,
  adminCss,
  NotFoundComponent,
}) => {
  const location = useLocation();
  const slug = resolveSlugFromPathname(location.pathname);
  const pageMatch = useMemo(
    () => resolvePageMatchFromRegistry(pageRegistry, slug),
    [pageRegistry, slug]
  );
  const collectionContext = useMemo(
    () => pageMatch ? resolveCollectionContext(pageMatch.page, pageMatch.params, collections) : null,
    [collections, pageMatch]
  );
  const resolvedRuntime = useMemo(
    () =>
      resolveRuntimeConfig({
        pages: pageMatch ? { [pageMatch.registrySlug]: pageMatch.page } : {},
        siteConfig,
        themeConfig,
        menuConfig,
        collections,
        collectionSchemas,
        collectionContext,
        refDocuments,
      }),
    [pageMatch, siteConfig, themeConfig, menuConfig, collections, collectionSchemas, collectionContext, refDocuments]
  );
  const pageConfig = pageMatch ? resolvedRuntime.pages[pageMatch.registrySlug] : undefined;

  useEffect(() => {
    try {
      if (resolvedRuntime.themeConfig?.tokens) {
        themeManager.setTheme(resolvedRuntime.themeConfig);
      }
    } catch (e) {
      console.warn('[JsonPages] visitor theme resolution failed', e);
    }
  }, [resolvedRuntime.themeConfig]);

  useEffect(() => {
    if (!pageConfig) return;
    const title = typeof pageConfig.meta?.title === 'string' ? pageConfig.meta.title : slug;
    const description = typeof pageConfig.meta?.description === 'string' ? pageConfig.meta.description : '';
    syncHeadLink('mcp-manifest', buildPageManifestHref(slug));
    syncHeadLink('olon-contract', buildPageContractHref(slug));
    syncWebMcpJsonLd(title, description, slug === 'home' ? '/' : `/${slug}`);
  }, [pageConfig, slug]);

  if (!pageConfig) return <NotFoundComponent />;

  return (
    <ThemeLoader mode="tenant" tenantCss={tenantCss} adminCss={adminCss}>
      <StudioProvider mode="visitor">
        <PageRenderer
          pageConfig={pageConfig}
          siteConfig={resolvedRuntime.siteConfig}
          menuConfig={resolvedRuntime.menuConfig}
        />
      </StudioProvider>
    </ThemeLoader>
  );
};
