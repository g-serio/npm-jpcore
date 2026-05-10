
# Onboarding — Governance Path (with CMS) — Full Version

**Target Audience:** Developers handling graphics and data who require the **CMS** (Studio, ICE, Form Factory): in-app authoring, strong typing, content and component governance.

**Spec Reference:** JSONPAGES Architecture Specifications v1.2 (full) + Appendix A — Tenant Type & Code-Generation Annex.

---

## 1. What "Governance" Implies

-   **Types:** Every section type is declared in `SectionDataRegistry` / `SectionSettingsRegistry` (module augmentation) and in `SectionComponentPropsMap`. Registry and config are strictly typed.
-   **Schema:** Every section type has a Zod schema (data, and optionally settings) used by the Form Factory to generate the editor in the Inspector. Schemas are aggregated in `SECTION_SCHEMAS`.
-   **Studio/ICE:** The editor (Inspector) hooks into the DOM via **data-jp-field** and **data-jp-item-id** / **data-jp-item-field**. The selection overlay in the iframe requires the **tenant** to provide the CSS (TOCC).
-   **Add Section:** The tenant exposes **AddSectionConfig** (addable types, labels, default data) so the user can add sections from the library in Studio.
-   **Design Tokens:** Views use CSS variables (`--local-*`) and no "naked" utilities (CIP) for consistency and compatibility with themes and overlays.

**Why they are needed (Summary):** Types and schemas allow the Core and Form Factory to operate without knowing Tenant details; IDAC allows the Inspector to link clicks in the Stage to the active row in the sidebar (including active/inactive opacity); TOCC makes the overlay visible; AddSectionConfig defines the "Add Section" library; tokens and z-index prevent conflicts with the editing UI. For detailed "Whys" for each spec, see spec v1.2 (§1–§10, JAP, Appendix A).

---

## 1.1 The Value of Typing: Governance and CMS UX

Typing (TypeScript types + Zod schemas) serves **two levels**: Governance (Developer/Architecture) and **CMS UX** (Author using Studio). Often only the first is mentioned.

**Governance:** Typed registry, SectionComponentPropsMap, SiteConfig/PageConfig shape, audits, code-generation → consistency across tenants, no drift, safe refactoring, spec-based tooling.

**CMS UX:** The Zod schema drives the **Form Factory** (which widgets to use for each field: text, textarea, select, list, icon-picker, **image-picker**); **data-jp-field** and **data-jp-item-id/field** bind clicks in the Stage to forms in the Inspector; **AddSectionConfig** provides addable types, labels, and defaults. Result for the author: consistent forms, "Add Section" with sensible names and initial data, correct selection (click → right form), validation with clear errors. Without schemas and a typed contract, the Inspector wouldn't know which fields to show or how to validate them. Therefore: for governance, typing guarantees contracts; for **CMS UX**, it defines the **editing experience**. Both must be specified.

---

## 2. Project Structure (Complete)

-   **`src/data/config/site.json`** — SiteConfig (identity, pages[], header block, footer block).
-   **`src/data/config/menu.json`** — MenuConfig (e.g., `main: MenuItem[]`).
-   **`src/data/config/theme.json`** — ThemeConfig (tokens).
-   **`src/data/pages/<slug>.json`** — PageConfig (slug, meta, sections[]). **To create a new page**, simply add a `<slug>.json` file in `src/data/pages/`; the filename slug becomes the page path (e.g., `about-us.json` → `/about-us`).
-   **`src/components/<sectionType>/`** — **Full Capsule:** View.tsx, schema.ts, types.ts, index.ts.
-   **`src/lib/base-schemas.ts`** — BaseSectionData, BaseArrayItem, BaseSectionSettingsSchema.
-   **`src/lib/schemas.ts`** — SECTION_SCHEMAS (aggregate of data schemas per type) + export SectionType.
-   **`src/lib/ComponentRegistry.tsx`** — Typed Registry: `{ [K in SectionType]: React.FC<SectionComponentPropsMap[K]> }`.
-   **`src/lib/addSectionConfig.ts`** — AddSectionConfig (addableSectionTypes, sectionTypeLabels, getDefaultSectionData).
-   **`src/types.ts`** — SectionComponentPropsMap, PageConfig, SiteConfig, MenuConfig, ThemeConfig; **module augmentation** for SectionDataRegistry and SectionSettingsRegistry **on both** `@olonjs/core` **and** `@olonjs/core/runtime` identifiers (see §2.1 below); re-export from `@olonjs/core/runtime` (the `@jsonpages/core` compatibility alias still points at the full package).
-   **`src/App.tsx`** — Bootstrap: config (tenantId, registry, schemas, pages, siteConfig, themeConfig, menuConfig, themeCss, addSection). Mounts `<OlonJSEngine>` for visitor paths and lazy-loads `<JsonPagesEngine>` only on `/admin` paths (see §2.1 below).
-   **Global CSS** — Includes TOCC selectors for overlay (hover/selected/type label).

---

## 2.1 Runtime / Studio Split (ADR-0009)

As of `@olonjs/core` v1.1.0, the package ships **two physical bundles**:

-   **`@olonjs/core/runtime`** — visitor-only subset, ~28 KB gzipped. Includes `OlonJSEngine`, `PageRenderer`, `SectionRenderer`, `ConfigProvider`, `ThemeLoader`, `resolveAssetUrl`, the no-op `StudioProvider`/`useStudio` stubs, and the entire DNA surface (`BaseSectionData`, `CtaSchema`, `DEPLOY_STEPS`, `OlonFormsContext`, etc.).
-   **`@olonjs/core`** — full bundle including everything above **plus** `JsonPagesEngine`, `StudioRoute`, `PreviewRoute`, `AdminSidebar`, `FormFactory`, `StudioStage`, and admin-skin CSS. ~128 KB gzipped.

### What this means for tenant authoring

**Default to `@olonjs/core/runtime`** for every tenant import that participates in the visitor critical path: section schemas, View components, base schema fragments, `cn`, `useConfig`, `resolveAssetUrl`, `STUDIO_EVENTS`, `useStudio`, etc. The runtime bundle exports all of these as a strict subset of the full bundle's surface.

**Use `@olonjs/core`** only inside the lazy admin chunk in `App.tsx` (see canonical pattern below). Importing `JsonPagesEngine` from anywhere else collapses the split and ships the full bundle to every visitor.

### Canonical `App.tsx` pattern

```tsx
import { useEffect, useMemo, useState, Suspense, lazy } from 'react';
import { OlonJSEngine, type JsonPagesConfig } from '@olonjs/core/runtime';

// /admin gate evaluated at module load — Vite splits the chunks statically.
const isAdminPath =
  typeof window !== 'undefined' && window.location.pathname.startsWith('/admin');

const LazyJsonPagesEngine = lazy(() =>
  import('@olonjs/core').then((m) => ({ default: m.JsonPagesEngine })),
);

export default function App() {
  const config: JsonPagesConfig = { /* ... */ };

  return isAdminPath
    ? <Suspense fallback={null}><LazyJsonPagesEngine config={config} /></Suspense>
    : <OlonJSEngine config={config} />;
}
```

### Module augmentation must target both identifiers

TypeScript treats `'@olonjs/core'` and `'@olonjs/core/runtime'` as **distinct module identifiers**. The MTRP augmentation in `types.ts` must therefore declare the registry on both, otherwise `PageConfig.sections` falls back to a generic `FallbackSection` on the runtime side and the tenant loses the typed contract that drives the Form Factory.

```ts
// apps/<tenant>/src/types.ts
declare module '@olonjs/core' {
  export interface SectionDataRegistry { /* tenant types */ }
  export interface SectionSettingsRegistry { /* tenant settings */ }
}

declare module '@olonjs/core/runtime' {
  export interface SectionDataRegistry { /* same tenant types */ }
  export interface SectionSettingsRegistry { /* same tenant settings */ }
}

// IMPORTANT: this is a *value* re-export, not just a type re-export.
// Vite treats `export *` as a runtime dependency edge in its module graph,
// so this anchor decides which physical bundle the tenant entry pulls in.
// Always point it at the runtime subpath; never at '@olonjs/core'.
export * from '@olonjs/core/runtime';
```

### Why this matters for governance

The split is enforced at the bundler level, not by convention. A regression — for example, a tenant component that imports `JsonPagesEngine` directly, or a `lib/schemas.ts` that pulls section barrels containing heavy View dependencies — collapses the runtime bundle back to ~400+ KB on the visitor critical path. Two safeguards:

1.  **Core-side boundary check** (`packages/core/scripts/check-runtime-decoupling.mjs`) prevents `runtime-entry.ts` from importing Studio admin modules. Run via `npm run test:boundary -w @olonjs/core`.
2.  **Tenant-side practice** (this section) — keep `@olonjs/core` imports confined to the lazy admin chunk; use deep schema-only imports (`@/components/<x>/schema` rather than `@/components/<x>`) anywhere a section schema is referenced eagerly, to avoid dragging the View into the visitor entry.

---

## 3. Components (Capsules + IDAC + Tokens)

-   **Capsule:** Every section type has View, schema (Zod), types (inferred), index. The **data** schema extends BaseSectionData; array items extend BaseArrayItem.
-   **View:** Receives `data` and `settings` (and `menu` for header). Does not import Zod. Uses **only** CSS variables for colors/radii (e.g., `bg-[var(--local-bg)]`), root section with `z-index` ≤ 1.
-   **IDAC (ICE):** On every scalar editable field: **`data-jp-field="<fieldKey>"`**. On every editable array item: **`data-jp-item-id="<stableId>"`** and **`data-jp-item-field="<arrayKey>"`**. This allows the Inspector to bind selection and forms to the correct paths.
-   **Schema:** Uses UI vocabulary (ECIP): `.describe('ui:text')`, `ui:textarea`, `ui:select`, `ui:number`, `ui:list`, `ui:icon-picker`, **`ui:image-picker`** (see §3.1). Array of editable objects: every object must have an `id` (BaseArrayItem).

**Why they are needed (Components):** **data-jp-field** and **data-jp-item-*** are needed because the Stage is in an iframe, and the Core needs to know which field/item corresponds to a click without knowing the Tenant's DOM: this allows the sidebar to highlight the active row (even with different opacity for active/inactive), open the form on the right field, and manage lists (reorder, delete). Without IDAC, clicks on the canvas are not reflected in the sidebar. Schemas with `ui:*` and BaseArrayItem are needed by the Form Factory to generate the correct widgets and maintain stable keys (reorder/delete). Tokens and z-index prevent content from covering the overlay. See spec §6 (IDAC), §5 (ECIP), §4 (CIP).

---

## 3.1 Image Picker: Correct Usage in Schema (Example `image-break`)

For **image fields**, the Form Factory exposes the **Image Picker** widget only if the schema is modeled correctly.

### Rule

-   The image field is not a **string** (`z.string()`), but an **object** with at least `url` and, optionally, `alt`.
-   The **schema of this object** (the sub-schema) must be marked with **`.describe('ui:image-picker')`**. The Form Factory recognizes `ui:image-picker` only on **ZodObject** (object schema), not on string fields.

### Example (Capsule `image-break`)

**Schema (`schema.ts`):**

```ts
import { z } from 'zod';
import { BaseSectionData } from '@/lib/base-schemas';

const ImageSelectionSchema = z
  .object({
    url: z.string(),
    alt: z.string().optional(),
  })
  .describe('ui:image-picker');

export const ImageBreakSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  image: ImageSelectionSchema.default({ url: '', alt: '' }),
  caption: z.string().optional().describe('ui:textarea'),
});
```

-   **ImageSelectionSchema** is a `z.object({ url, alt })` with **`.describe('ui:image-picker')`** on the object.
-   The **`image`** field in the section data uses that schema (with default) so the Inspector shows the Image Picker widget for `image`.

**View (`View.tsx`):**

-   For the image `src`: **`resolveAssetUrl(data.image.url, tenantId)`** (multi-tenant and relative paths).
-   On the node representing the image (e.g., the `<img>` or a wrapper): **`data-jp-field="image"`** so the click in Stage binds the Inspector to the `image` field.
-   Other editable fields (caption, label) with **`data-jp-field="caption"`** and **`data-jp-field="label"`** where appropriate.

**Full Reference:** `apps/tenant-alpha/src/components/image-break/` (schema.ts, types.ts, View.tsx, index.ts).

### What to Avoid

-   **Do NOT** use `.describe('ui:image-picker')` on a **string** field (e.g., `imageUrl: z.string().describe('ui:image-picker')`): the Image Picker widget expects an object `{ url, alt? }`.
-   **Do NOT** forget `data-jp-field="image"` on the corresponding node in the DOM, otherwise the Inspector ↔ Stage binding will not work for that field.

---

## 4. Data: Shape and Responsibility

-   **site.json / menu.json / theme.json / pages/*.json** — Exact shape as in Appendix A (SiteConfig, MenuConfig, ThemeConfig, PageConfig). These are the source of truth when the user saves from Studio (Working Draft → persist to these files or API generating them).
-   **Studio** updates the Working Draft; sync with the iframe and "Bake" use the same structure. Therefore, the data you pass to JsonPagesEngine (siteConfig, menuConfig, pages) must be compatible with what the editor modifies.

If data comes from an external CMS, it is up to you to synchronize: e.g., export from Studio → push to CMS, or CMS as source and Studio in read-only; in any case, the **shape** of the pages (sections with id, type, data, settings) remains that of the spec.

---

## 5. Registry, Schemas, Types, AddSection

-   **types.ts:** Single point of **module augmentation** and definition of SectionComponentPropsMap, PageConfig, SiteConfig, MenuConfig, ThemeConfig. Header: `{ data, settings?, menu: MenuItem[] }`; all others: `{ data, settings? }`.
-   **ComponentRegistry:** Every SectionType key has the corresponding component; type: `{ [K in SectionType]: React.FC<SectionComponentPropsMap[K]> }`.
-   **SECTION_SCHEMAS:** Every SectionType key has the **Zod data schema** (same order as registry). Base schemas re-exported from base-schemas.ts.
-   **addSectionConfig:** addableSectionTypes (only types the user can add from the library), sectionTypeLabels, getDefaultSectionData(type) which returns valid `data` for that schema.

**Why they are needed (registry, schemas, types, addSection):** A single point of augmentation (types.ts) and a single SECTION_SCHEMAS avoids duplication and ensures that registry, Form Factory, and config use the same types. AddSectionConfig is the single source of truth for "which sections can be added" and "with what defaults"; without it, the "Add Section" modal would not have valid names or initial data. See spec §9 (ASC), Appendix A.2–A.3.

---

## 6. Overlay and CSS (TOCC)

-   The Core injects the overlay markup (wrapper with `data-section-id`, sibling with `data-jp-section-overlay`). The **tenant** must provide the CSS so that:
    -   `[data-jp-section-overlay]` covers the section, `pointer-events: none`, high z-index (e.g., 9999).
    -   Hover and selected are visible (dashed/solid border, optional tint).
    -   The type label (e.g., `[data-jp-section-overlay] > div`) is positioned and visible on hover/selected.

Without this, the overlay is invisible in the iframe in Studio.

**Why they are needed (TOCC):** The Stage iframe loads only the Tenant's CSS; the Core injects the overlay markup but not the styles. Without TOCC selectors in the tenant CSS, hover/selected borders and type labels are not visible: the author cannot see which section is selected. See spec §7 (TOCC).

---

## 7. Quick Checklist (Graphics and Data Development, with CMS)

| Item | Action |
|------|--------|
| **Layout / Graphics** | View with `--local-*` variables, z-index ≤ 1, no naked utilities. |
| **Data (Shape)** | SiteConfig, MenuConfig, ThemeConfig, PageConfig as in Appendix A; JSON in `data/config` and `data/pages`. |
| **New Page** | Add a `<slug>.json` file in `src/data/pages/` (slug becomes page path). |
| **Capsules** | View + schema (with ui:*) + types + index; data schema extends BaseSectionData; array item with id. |
| **IDAC** | data-jp-field on editable scalar fields; data-jp-item-id and data-jp-item-field on array items. |
| **Image Picker** | Image field = object `{ url, alt? }` with sub-schema `.describe('ui:image-picker')`; View with `resolveAssetUrl` and `data-jp-field="image"`. Example: `image-break`. |
| **types.ts** | SectionComponentPropsMap (header with menu), augmentation, PageConfig, SiteConfig, MenuConfig, ThemeConfig. |
| **Registry** | All types mapped to component; registry type as in Appendix A. |
| **SECTION_SCHEMAS** | One entry per type (data schema); re-export base schemas. |
| **addSectionConfig** | addableSectionTypes, sectionTypeLabels, getDefaultSectionData. |
| **Config** | tenantId, registry, schemas, pages, siteConfig, themeConfig, menuConfig, themeCss, addSection. |
| **TOCC** | CSS overlay for [data-jp-section-overlay], hover, selected, type label. |

---

## 8. Spec References

-   **Architecture and ICE:** §1–§10 (MTRP, JSP, TBP, CIP, ECIP, IDAC, TOCC, BSDS, ASC, JEB).
-   **Types and Code-Generation:** Appendix A (Core types, Tenant types, Schema contract, File paths, Integration checklist).
-   **Admin:** JAP (Studio topology, Working Draft, Bake, overlay, Green Build).

Using this path gives you full **governance**: types, schema, editor, Add Section, and overlay aligned with spec v1.2. For versions with all the "Whys", use the file **JSONPAGES_Specs_v1.2_completo.md**.
