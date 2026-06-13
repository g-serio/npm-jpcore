/**
 * JsonPagesEngine — full engine surface.
 *
 * Mounts visitor + admin + preview routes. Imports admin-skin.css and
 * the studio routes (StudioRoute, PreviewRoute), so this engine pulls
 * Studio code into the bundle of any consumer that imports it.
 *
 * For visitor-only deployments, prefer `OlonJSEngine` from
 * `@olonjs/core/runtime` (ADR-0009 D7). That sibling never references
 * studio admin modules; the package-level export split keeps Studio
 * out of the runtime bundle entirely.
 *
 * The actual provider tree, theme bootstrap, and router setup live in
 * `JsonPagesEngineCore`. This file only declares the route tree.
 */

import React from 'react';
import { Route } from 'react-router-dom';
import type { JsonPagesConfig } from '../../contract/types-engine';
import {
  JsonPagesEngineCore,
  JsonPagesRouterShell,
  type EngineRuntimeContext,
} from './JsonPagesEngineCore';
import { PreviewRoute } from './PreviewRoute';
import { StudioRoute } from './StudioRoute';
import { VisitorRoute } from './VisitorRoute';

import defaultAdminCss from '../../studio/admin/admin-skin.css?inline';

const FALLBACK_ADMIN_CSS = `
:root { --background: #0f172a; --foreground: #f1f5f9; }
body { background-color: var(--background); color: var(--foreground); }
`;

export interface JsonPagesEngineProps {
  config: JsonPagesConfig;
}

function buildFullRoutes(ctx: EngineRuntimeContext) {
  const visitorProps = {
    pageRegistry: ctx.pageRegistry,
    siteConfig: ctx.siteConfig,
    menuConfig: ctx.menuConfig,
    themeConfig: ctx.themeConfig,
    collections: ctx.collections,
    refDocuments: ctx.refDocuments,
    tenantCss: ctx.tenantCss,
    adminCss: ctx.adminCss,
    NotFoundComponent: ctx.NotFoundComponent,
  };

  const studioProps = {
    pageRegistry: ctx.pageRegistry,
    schemas: ctx.schemas,
    siteConfig: ctx.siteConfig,
    menuConfig: ctx.menuConfig,
    themeConfig: ctx.themeConfig,
    collections: ctx.collections,
    refDocuments: ctx.refDocuments,
    tenantCss: ctx.tenantCss,
    adminCss: ctx.adminCss,
    addSectionConfig: ctx.addSectionConfig,
    addableSectionTypes: ctx.addableSectionTypes,
    webMcp: ctx.webmcp,
    saveToFile: ctx.persistence.saveToFile,
    hotSave: ctx.persistence.hotSave,
    coldSave: ctx.persistence.coldSave,
    showLocalSave: ctx.persistence.showLocalSave,
    showHotSave: ctx.persistence.showHotSave,
    showColdSave: ctx.persistence.showColdSave,
  };

  return (
    <Route element={<JsonPagesRouterShell />}>
      <Route path="/" element={<VisitorRoute {...visitorProps} />} />
      <Route path="/*" element={<VisitorRoute {...visitorProps} />} />
      <Route path="/admin" element={<StudioRoute {...studioProps} />} />
      <Route path="/admin/*" element={<StudioRoute {...studioProps} />} />
      <Route
        path="/admin/preview"
        element={<PreviewRoute tenantCss={ctx.tenantCss} adminCss={ctx.adminCss} />}
      />
      <Route
        path="/admin/preview/*"
        element={<PreviewRoute tenantCss={ctx.tenantCss} adminCss={ctx.adminCss} />}
      />
      <Route path="*" element={<ctx.NotFoundComponent />} />
    </Route>
  );
}

export function JsonPagesEngine({ config }: JsonPagesEngineProps) {
  const adminCss =
    typeof defaultAdminCss === 'string' ? defaultAdminCss : FALLBACK_ADMIN_CSS;
  return (
    <JsonPagesEngineCore
      config={config}
      adminCss={adminCss}
      routesBuilder={buildFullRoutes}
    />
  );
}
