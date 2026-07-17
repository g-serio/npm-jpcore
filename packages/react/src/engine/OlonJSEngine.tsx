/**
 * OlonJSEngine — visitor-only engine surface.
 *
 * Sibling of `JsonPagesEngine`. Same `JsonPagesConfig` prop shape, same
 * provider tree, same router setup — but mounts only the visitor route.
 * Has zero import of `@olonjs/studio` (not even dynamically), so a
 * consumer that only ever renders `OlonJSEngine` never fetches Studio
 * code, regardless of route.
 *
 * If a user navigates to `/admin` on a deployment built around this
 * engine, the request falls through to `DefaultNotFound` (or the
 * tenant's `NotFoundComponent`). Public sites that don't host an editor
 * should adopt this engine for visitor traffic and fall back to
 * `JsonPagesEngine` only on admin paths.
 */

import React from 'react';
import { Route } from 'react-router-dom';
import type { JsonPagesConfig } from '@olonjs/core';
import {
  JsonPagesEngineCore,
  JsonPagesRouterShell,
  type EngineRuntimeContext,
} from './JsonPagesEngineCore';
import { VisitorRoute } from './VisitorRoute';

export interface OlonJSEngineProps {
  config: JsonPagesConfig;
}

function buildRuntimeRoutes(ctx: EngineRuntimeContext) {
  const visitorProps = {
    pageRegistry: ctx.pageRegistry,
    siteConfig: ctx.siteConfig,
    menuConfig: ctx.menuConfig,
    themeConfig: ctx.themeConfig,
    collections: ctx.collections,
    collectionSchemas: ctx.collectionSchemas,
    refDocuments: ctx.refDocuments,
    tenantCss: ctx.tenantCss,
    adminCss: ctx.adminCss, // empty string at the Core level for runtime; ignored by ThemeLoader in tenant mode
    NotFoundComponent: ctx.NotFoundComponent,
  };

  return (
    <Route element={<JsonPagesRouterShell />}>
      <Route path="/" element={<VisitorRoute {...visitorProps} />} />
      <Route path="/*" element={<VisitorRoute {...visitorProps} />} />
      <Route path="*" element={<ctx.NotFoundComponent />} />
    </Route>
  );
}

export function OlonJSEngine({ config }: OlonJSEngineProps) {
  // adminCss is intentionally omitted (defaults to '' in the Core).
  return <JsonPagesEngineCore config={config} routesBuilder={buildRuntimeRoutes} />;
}
