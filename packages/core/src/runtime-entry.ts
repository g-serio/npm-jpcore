/**
 * @olonjs/core/runtime — runtime-only public surface.
 *
 * This entry produces the `dist/olonjs-core-runtime.js` bundle. It
 * exports a strict subset of the full `@olonjs/core` API: enough for a
 * tenant to mount the visitor engine, render pages, read theme tokens,
 * resolve asset URLs, and use the no-op StudioContext. It deliberately
 * does NOT export:
 *   - JsonPagesEngine, StudioRoute, PreviewRoute (full-engine surface)
 *   - AdminSidebar, FormFactory, StudioStage, AddSectionLibrary,
 *     PreviewEntry, InputWidgets, FormFactory (studio admin UI)
 *   - admin-skin.css inline asset
 *
 * The exports are listed explicitly (no `export *`) so the bundle
 * boundary is auditable: anything reachable from this module is in the
 * runtime bundle, anything not listed here is not.
 *
 * See ADR-0009 (D1, D2, D7, D8). Wired into `package.json` via the
 * `"./runtime"` subpath export in Phase 2 / Task 2.3.
 */

// ── Engine ────────────────────────────────────────────────────────
export { OlonJSEngine, type OlonJSEngineProps } from './runtime/engine/OlonJSEngine';

// ── Configuration types ───────────────────────────────────────────
export type { JsonPagesConfig } from './contract/types-engine';

// ── Config context (runtime-side state container) ─────────────────
export {
  ConfigProvider,
  useConfig,
  type ConfigContextValue,
} from './runtime/config/ConfigContext';

// ── Rendering primitives ──────────────────────────────────────────
export { PageRenderer } from './runtime/rendering/PageRenderer';
export { SectionRenderer } from './runtime/rendering/SectionRenderer';

// ── Theme ─────────────────────────────────────────────────────────
export { ThemeLoader, type ThemeLoaderProps } from './runtime/theme/ThemeLoader';
export { themeManager } from './runtime/theme/theme-manager';

// ── URL utilities ─────────────────────────────────────────────────
export { normalizeBasePath, withBasePath } from './runtime/url';

// ── Assets ────────────────────────────────────────────────────────
export { resolveAssetUrl } from './runtime/assets/asset-resolver';

// ── Default 404 ───────────────────────────────────────────────────
export { DefaultNotFound } from './lib/DefaultNotFound';

// ── Studio surface kept in runtime per ADR-0009 D3 ───────────────
// These are the no-op-friendly Studio pieces that even visitor mode
// uses (SectionRenderer reads `useStudio().mode` for IDAC overlay
// gating). They live in studio/ for legacy reasons; conceptually they
// are runtime concerns.
export { StudioProvider, useStudio } from './studio/StudioContext';
export { STUDIO_EVENTS } from './studio/events';

// ── Icon registry ─────────────────────────────────────────────────
export {
  IconRegistryContext,
  useIconRegistry,
  type IconRegistry,
} from './runtime/icons/IconRegistryContext';
