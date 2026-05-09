/**
 * OlonJSEngine — runtime-only engine surface.
 *
 * Sibling of `JsonPagesEngine`. Same `JsonPagesConfig` prop shape, same
 * provider tree, same router setup — but mounts only the visitor route.
 * Has zero transitive imports from `studio/admin/` or `studio/orchestration/`,
 * so when this module is the entry point of `@olonjs/core/runtime` (per
 * ADR-0009 D1, D2, D7) the resulting bundle does not contain Studio code.
 *
 * If a user navigates to `/admin` on a deployment built around this
 * engine, the request falls through to `DefaultNotFound` (or the
 * tenant's `NotFoundComponent`). Public sites that don't host an editor
 * should adopt this engine for visitor traffic and fall back to
 * `JsonPagesEngine` only on admin paths (see ADR-0009 D7 + Task 3.1
 * for the tenant adoption pattern).
 *
 * What's deliberately omitted vs. JsonPagesEngine:
 * - No `StudioRoute`, `PreviewRoute` mounting.
 * - No `admin-skin.css?inline` import. The runtime engine passes an
 *   empty string for `adminCss`; routes mounted here only run
 *   `ThemeLoader` in `mode="tenant"`, which ignores `adminCss` (verified
 *   in Task 1.2). The visitor-relevant `[data-radix-portal]` z-index
 *   rule was migrated to the tenant's own index.css.
 *
 * See ADR-0009 and docs/plans/core-studio-split.md (Task 1.4).
 */

import React from 'react';
import { Route } from 'react-router-dom';
import type { JsonPagesConfig } from '../../contract/types-engine';
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
