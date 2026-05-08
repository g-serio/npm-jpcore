/**
 * Sovereign Shell: routing, state, and Admin layout live in dedicated engine blocks.
 * Enterprise: this file stays as the composition root that wires runtime concerns together.
 */
import React, { useEffect, useMemo, useState } from 'react';
import {
  createBrowserRouter,
  createRoutesFromElements,
  Outlet,
  Route,
  RouterProvider,
  ScrollRestoration,
} from 'react-router-dom';
import { resolveRuntimeConfig } from '../../contract/config-resolver';
import type { JsonPagesConfig } from '../../contract/types-engine';
import { ensureWebMcpRuntime } from '../../webmcp';
import { DefaultNotFound } from '../../lib/DefaultNotFound';
import { ConfigProvider } from '../config/ConfigContext';
import { themeManager } from '../theme/theme-manager';
import { normalizeBasePath } from '../url';
import { IconRegistryContext } from '../../studio/admin/IconRegistryContext';
import { EngineErrorBoundary } from './EngineErrorBoundary';
import { PreviewRoute } from './PreviewRoute';
import { StudioRoute } from './StudioRoute';
import { VisitorRoute } from './VisitorRoute';

import defaultAdminCss from '../../studio/admin/admin-skin.css?inline';

export interface JsonPagesEngineProps {
  config: JsonPagesConfig;
}

const FALLBACK_ADMIN_CSS = `
:root { --background: #0f172a; --foreground: #f1f5f9; }
body { background-color: var(--background); color: var(--foreground); }
`;

/**
 * Data-router layout: ScrollRestoration only works under RouterProvider (not BrowserRouter).
 * Renders the matched route via <Outlet />.
 */
function JsonPagesRouterShell() {
  return (
    <>
      <ScrollRestoration />
      <Outlet />
    </>
  );
}

export function JsonPagesEngine({ config }: JsonPagesEngineProps) {
  const {
    registry = {},
    schemas = {},
    basePath = '/',
    pages: pageRegistry = {},
    siteConfig,
    themeConfig,
    menuConfig,
    refDocuments,
    themeCss,
    addSection: addSectionConfig,
    NotFoundComponent = DefaultNotFound,
  } = config;

  const addableSectionTypes: string[] =
    addSectionConfig?.addableSectionTypes ??
    (Object.keys(schemas).filter((type) => type !== 'header' && type !== 'footer') as string[]);

  const persistence = {
    saveToFile: config.persistence?.saveToFile,
    hotSave: config.persistence?.hotSave,
    coldSave: config.persistence?.coldSave,
    showLocalSave: config.persistence?.showLocalSave ?? true,
    showHotSave: config.persistence?.showHotSave ?? false,
    showColdSave: config.persistence?.showColdSave ?? false,
  };

  const tenantCss = typeof themeCss?.tenant === 'string' ? themeCss.tenant : '';
  const adminCss =
    typeof themeCss?.admin === 'string'
      ? themeCss.admin
      : typeof defaultAdminCss === 'string'
        ? defaultAdminCss
        : FALLBACK_ADMIN_CSS;

  const baseResolvedRuntime = useMemo(
    () =>
      resolveRuntimeConfig({
        pages: pageRegistry,
        siteConfig,
        themeConfig,
        menuConfig,
        refDocuments,
      }),
    [pageRegistry, siteConfig, themeConfig, menuConfig, refDocuments]
  );

  const [isReady, setIsReady] = useState(false);
  const routerBasePath = normalizeBasePath(basePath);

  useEffect(() => {
    try {
      if (baseResolvedRuntime.themeConfig?.tokens) {
        themeManager.setTheme(baseResolvedRuntime.themeConfig);
      }
    } catch (error) {
      console.warn('[JsonPages] setTheme failed', error);
    }

    if (config.webmcp?.enabled) {
      ensureWebMcpRuntime();
    }

    setIsReady(true);
  }, [baseResolvedRuntime.themeConfig, config.webmcp?.enabled]);

  const router = useMemo(() => {
    const routes = createRoutesFromElements(
      <Route element={<JsonPagesRouterShell />}>
        <Route
          path="/"
          element={
            <VisitorRoute
              pageRegistry={pageRegistry}
              siteConfig={siteConfig}
              menuConfig={menuConfig}
              themeConfig={baseResolvedRuntime.themeConfig}
              refDocuments={refDocuments}
              tenantCss={tenantCss}
              adminCss={adminCss}
              NotFoundComponent={NotFoundComponent}
            />
          }
        />
        <Route
          path="/*"
          element={
            <VisitorRoute
              pageRegistry={pageRegistry}
              siteConfig={siteConfig}
              menuConfig={menuConfig}
              themeConfig={baseResolvedRuntime.themeConfig}
              refDocuments={refDocuments}
              tenantCss={tenantCss}
              adminCss={adminCss}
              NotFoundComponent={NotFoundComponent}
            />
          }
        />
        <Route
          path="/admin"
          element={
            <StudioRoute
              pageRegistry={pageRegistry}
              schemas={schemas}
              siteConfig={siteConfig}
              menuConfig={menuConfig}
              themeConfig={baseResolvedRuntime.themeConfig}
              refDocuments={refDocuments}
              tenantCss={tenantCss}
              adminCss={adminCss}
              addSectionConfig={addSectionConfig}
              addableSectionTypes={addableSectionTypes}
              webMcp={config.webmcp}
              saveToFile={persistence.saveToFile}
              hotSave={persistence.hotSave}
              coldSave={persistence.coldSave}
              showLocalSave={persistence.showLocalSave}
              showHotSave={persistence.showHotSave}
              showColdSave={persistence.showColdSave}
            />
          }
        />
        <Route
          path="/admin/*"
          element={
            <StudioRoute
              pageRegistry={pageRegistry}
              schemas={schemas}
              siteConfig={siteConfig}
              menuConfig={menuConfig}
              themeConfig={baseResolvedRuntime.themeConfig}
              refDocuments={refDocuments}
              tenantCss={tenantCss}
              adminCss={adminCss}
              addSectionConfig={addSectionConfig}
              addableSectionTypes={addableSectionTypes}
              webMcp={config.webmcp}
              saveToFile={persistence.saveToFile}
              hotSave={persistence.hotSave}
              coldSave={persistence.coldSave}
              showLocalSave={persistence.showLocalSave}
              showHotSave={persistence.showHotSave}
              showColdSave={persistence.showColdSave}
            />
          }
        />
        <Route
          path="/admin/preview"
          element={<PreviewRoute tenantCss={tenantCss} adminCss={adminCss} />}
        />
        <Route
          path="/admin/preview/*"
          element={<PreviewRoute tenantCss={tenantCss} adminCss={adminCss} />}
        />
        <Route path="*" element={<NotFoundComponent />} />
      </Route>
    );
    return createBrowserRouter(routes, { basename: routerBasePath });
  }, [
    NotFoundComponent,
    addSectionConfig,
    addableSectionTypes,
    adminCss,
    baseResolvedRuntime.themeConfig,
    menuConfig,
    pageRegistry,
    persistence.coldSave,
    persistence.hotSave,
    persistence.saveToFile,
    persistence.showColdSave,
    persistence.showHotSave,
    persistence.showLocalSave,
    refDocuments,
    routerBasePath,
    schemas,
    siteConfig,
    tenantCss,
    config.webmcp,
  ]);

  if (!isReady) {
    return (
      <div
        style={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: '#0f172a',
          color: '#94a3b8',
          fontFamily: 'ui-sans-serif, system-ui, sans-serif',
          fontSize: 14,
        }}
      >
        Loading...
      </div>
    );
  }

  return (
    <EngineErrorBoundary>
      <IconRegistryContext.Provider value={config.iconRegistry ?? {}}>
      <ConfigProvider
        config={{
          registry,
          schemas,
          tenantId: config.tenantId ?? 'default',
          basePath: routerBasePath,
          assets: config.assets,
          overlayDisabledSectionTypes: config.overlayDisabledSectionTypes,
        }}
      >
        <RouterProvider router={router} />
      </ConfigProvider>
      </IconRegistryContext.Provider>
    </EngineErrorBoundary>
  );
}
