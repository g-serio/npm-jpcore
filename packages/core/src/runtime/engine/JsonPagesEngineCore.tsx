/**
 * Engine composition root — internal, never exported from the package.
 *
 * Both `JsonPagesEngine` (full, mounts admin + preview routes) and
 * `OlonJSEngine` (runtime-only, mounts visitor route only) wrap this Core.
 * The Core handles everything route-agnostic: provider tree, theme +
 * webmcp bootstrap, base-path normalization, the `<RouterProvider>` itself.
 *
 * The caller supplies a `routesBuilder(ctx)` callback that receives the
 * resolved runtime context and returns the route tree to mount. This lets
 * the Core stay studio-agnostic — `OlonJSEngine`'s caller never references
 * `studio/admin/` modules, so tree-shaking and the explicit subpath split
 * (per ADR-0009 D1, D4) keep Studio out of the runtime bundle.
 *
 * See ADR-0009 for the architectural decisions, docs/plans/core-studio-split.md
 * for the implementation plan (Task 1.3).
 */

import React, { useEffect, useMemo, useState } from 'react';
import {
  createBrowserRouter,
  createRoutesFromElements,
  Outlet,
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
import { IconRegistryContext } from '../icons/IconRegistryContext';
import { EngineErrorBoundary } from './EngineErrorBoundary';

/**
 * Resolved runtime context handed to the route builder. Anything a route
 * (visitor or studio) might need is exposed here so the caller never has
 * to recompute derived state.
 */
export interface EngineRuntimeContext {
  registry: NonNullable<JsonPagesConfig['registry']>;
  schemas: NonNullable<JsonPagesConfig['schemas']>;
  pageRegistry: NonNullable<JsonPagesConfig['pages']>;
  siteConfig: JsonPagesConfig['siteConfig'];
  menuConfig: JsonPagesConfig['menuConfig'];
  themeConfig: JsonPagesConfig['themeConfig'];
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
  addSectionConfig: JsonPagesConfig['addSection'];
  addableSectionTypes: string[];
  webmcp: JsonPagesConfig['webmcp'];
  persistence: {
    saveToFile: NonNullable<JsonPagesConfig['persistence']>['saveToFile'];
    hotSave: NonNullable<JsonPagesConfig['persistence']>['hotSave'];
    coldSave: NonNullable<JsonPagesConfig['persistence']>['coldSave'];
    showLocalSave: boolean;
    showHotSave: boolean;
    showColdSave: boolean;
  };
  routerBasePath: string;
  tenantCss: string;
  /**
   * The full engine injects the Studio admin skin here; the runtime engine
   * passes an empty string. Routes that only render in tenant/visitor mode
   * (i.e. the `ThemeLoader` with `mode="tenant"`) ignore this value.
   */
  adminCss: string;
  NotFoundComponent: React.ComponentType;
}

export interface JsonPagesEngineCoreProps {
  config: JsonPagesConfig;
  /**
   * Returns the full route tree to mount under the data router. The
   * callback receives the resolved runtime context. The tree is wrapped
   * in the router shell (with `<ScrollRestoration />`) by the Core.
   */
  routesBuilder: (ctx: EngineRuntimeContext) => React.ReactElement;
  /**
   * Studio admin skin CSS injected at startup. The full engine passes the
   * `?inline`-imported admin-skin.css; the runtime engine passes `''` so
   * studio assets stay out of the runtime bundle (ADR-0009 D6).
   */
  adminCss?: string;
}

/**
 * Data-router shell — `<ScrollRestoration />` only works under
 * `<RouterProvider>` (not legacy `<BrowserRouter>`). Renders matched routes
 * via `<Outlet />`.
 */
function JsonPagesRouterShell() {
  return (
    <>
      <ScrollRestoration />
      <Outlet />
    </>
  );
}

export function JsonPagesEngineCore({ config, routesBuilder, adminCss = '' }: JsonPagesEngineCoreProps) {
  const {
    registry = {},
    schemas = {},
    basePath = '/',
    pages: pageRegistry = {},
    siteConfig,
    themeConfig,
    menuConfig,
    collections,
    collectionSchemas,
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

  // tenantCss flows through the engine config (`themeCss.tenant`) and is
  // owned by the consuming tenant. adminCss is supplied by the caller
  // (the full engine wrapper passes the inlined admin-skin.css string;
  // the runtime engine passes '').
  const tenantCss = typeof themeCss?.tenant === 'string' ? themeCss.tenant : '';
  const resolvedAdminCss =
    typeof themeCss?.admin === 'string' ? themeCss.admin : adminCss;

  const baseResolvedRuntime = useMemo(
    () =>
      resolveRuntimeConfig({
        pages: pageRegistry,
        siteConfig,
        themeConfig,
        menuConfig,
        collections,
        collectionSchemas,
        refDocuments,
      }),
    [pageRegistry, siteConfig, themeConfig, menuConfig, collections, collectionSchemas, refDocuments]
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

  const ctx: EngineRuntimeContext = {
    registry,
    schemas,
    pageRegistry,
    siteConfig,
    menuConfig,
    themeConfig: baseResolvedRuntime.themeConfig,
    collections,
    collectionSchemas,
    refDocuments,
    addSectionConfig,
    addableSectionTypes,
    webmcp: config.webmcp,
    persistence,
    routerBasePath,
    tenantCss,
    adminCss: resolvedAdminCss,
    NotFoundComponent,
  };

  const router = useMemo(() => {
    const routes = createRoutesFromElements(routesBuilder(ctx));
    return createBrowserRouter(routes, { basename: routerBasePath });
    // The `ctx` object is recreated each render but its members are
    // stable references derived from `config` props; the routesBuilder
    // is a pure function of those. We re-memo on the same set of
    // dependencies the previous monolithic engine used, plus the
    // builder identity (in practice, the wrapper engines export a
    // module-level constant, so identity is stable).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    NotFoundComponent,
    addSectionConfig,
    addableSectionTypes,
    resolvedAdminCss,
    baseResolvedRuntime.themeConfig,
    menuConfig,
    collections,
    collectionSchemas,
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
    routesBuilder,
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

// Internal export for the wrapper engines that need the same shell name.
// Not exported from the package's public API.
export { JsonPagesRouterShell };
