/**
 * JsonPagesEngine — full engine surface.
 *
 * Mounts visitor + admin + preview routes. The admin route (`StudioRoute`)
 * dynamically imports `@olonjs/studio` — it is the only place in this
 * package that ever references Studio, and only at runtime, only when a
 * consumer actually navigates to `/admin`. Everything else in this file
 * (and in `OlonJSEngine`) never touches Studio, so a visitor-only bundle
 * never fetches it.
 *
 * The actual provider tree, theme bootstrap, and router setup live in
 * `JsonPagesEngineCore`. This file only declares the route tree.
 */

import React from 'react';
import { Route } from 'react-router-dom';
import type { JsonPagesConfig } from '@olonjs/core';
import {
  JsonPagesEngineCore,
  JsonPagesRouterShell,
  type EngineRuntimeContext,
} from './JsonPagesEngineCore';
import { PreviewRoute } from './PreviewRoute';
import { StudioRoute } from './StudioRoute';
import { VisitorRoute } from './VisitorRoute';

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
    collectionSchemas: ctx.collectionSchemas,
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
    collectionSchemas: ctx.collectionSchemas,
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
  return <JsonPagesEngineCore config={config} routesBuilder={buildFullRoutes} />;
}
