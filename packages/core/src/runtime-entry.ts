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
export type {
  JsonPagesConfig,
  LibraryImageEntry,
  AddSectionConfig,
} from './contract/types-engine';

// ── Config resolution (used by SSG entry) ────────────────────────
export { resolveRuntimeConfig } from './contract/config-resolver';
export { resolvePublicPageDocument } from './runtime/engine/public-page-document';

// ── Utility ──────────────────────────────────────────────────────
// cn() is the className merge helper used by every tenant ui/* component.
// Re-exported here so tenant code can import it from /runtime without
// bringing in the full Studio bundle.
export { cn } from './lib/utils';

// ── Kernel types & registries (augmentable via MTRP) ──────────────
// The tenant's MTRP module augmentation (`declare module
// '@olonjs/core/runtime'`) needs these interfaces to attach to.
// Without this re-export the augmentation has no anchor and
// JsonPagesConfig.PageConfig.sections falls back to FallbackSection.
export type {
  CollectionDocument,
  CollectionItem,
  CollectionItemRegistry,
  CollectionType,
  SectionDataRegistry,
  SectionSettingsRegistry,
  BaseSection,
  SectionType,
  MenuItem,
  PageCollectionBinding,
  PageConfig,
  SiteConfig,
  ThemeConfig,
  MenuConfig,
  ProjectState,
} from './contract/kernel';

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
// `themeManager` (singleton, identity-bearing) and `buildThemeVariableMap`
// (pure function) live in the same source file. ADR-0012 externalizes the
// file as a unit in the full-bundle Vite config, so the runtime bundle must
// re-export every symbol the full bundle's public surface forwards through
// `runtime/theme/index.ts → runtime/index.ts → src/index.ts`.
export { themeManager, buildThemeVariableMap } from './runtime/theme/theme-manager';

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

// ── DNA surface ───────────────────────────────────────────────────
// Tenant-owned framework primitives: deploy steps + types, cloud save
// stream, OlonForms context, base section schemas. Verified not to
// transitively import from studio/admin (only `react` and `zod`).
// These need to be reachable from tenants that adopt @olonjs/core/runtime
// because the tenant App.tsx uses them in both visitor and admin paths
// (forms render in visitor; deploy/save flows are admin-only but their
// constants are statically imported).
export * from './dna';
