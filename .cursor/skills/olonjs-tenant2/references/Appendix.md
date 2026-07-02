## Appendix A - Tenant Type & Code-Generation Annex

**Objective:** Make the specification sufficient to generate or audit a full tenant without a reference codebase.

**Status:** Mandatory for code-generation and governance.

Appendix A distinguishes between:

- authored document contracts, formalized by normative companion JSON Schemas
- resolved runtime contracts, consumed by Core and tenant components after document resolution

## A.1 Core-Provided Types

The following are assumed to be exported by Core and consumed by the tenant:

| Type | Description |
|------|-------------|
| `SectionType` | `keyof SectionDataRegistry` after tenant augmentation |
| `Section` | Union of `BaseSection<K>` for all K |
| `BaseSectionSettings` | Optional shared settings type |
| `MenuItem` | Minimum menu node shape such as `{ label: string; href: string }` |
| `AddSectionConfig` | Add-section contract described in ASC |
| `JsonPagesConfig` | Bootstrap contract described in JEB |

## A.2 Tenant-Provided Types

The tenant should define these in a single module such as `src/types.ts`.
That module performs module augmentation for `@olonjs/core` and exports the tenant-facing contract types.

### A.2.1 SectionComponentPropsMap

Maps section type keys to React props.
Shell-scoped instances may have additional resolved props such as materialized menu trees.

Important distinction:

- authored config in `site.json` expresses menu/link usage via direct `$ref` fields in `section.data`
- `data.menu.$ref` is the canonical/default primary navigation binding
- named menu-like fields such as `data.socialLinks.$ref` and `data.legalLinks.$ref` may bind to named branches of `menu.json`
- resolved runtime data passed to the component contains concrete `MenuItem[]` values for those fields
- compatibility runtime props such as `menu?: MenuItem[]` may exist, but they do not define data ownership

Explicit pattern:

```typescript
import type { MenuItem } from '@olonjs/core';

export type SectionComponentPropsMap = {
  header: { data: HeaderData; settings?: HeaderSettings; menu?: MenuItem[] };
  footer: { data: FooterData; settings?: FooterSettings; menu?: MenuItem[] };
  hero: { data: HeroData; settings?: HeroSettings };
};
```

Mapped pattern:

```typescript
export type SectionComponentPropsMap = {
  [K in SectionType]:
    { data: SectionDataRegistry[K]; settings?: K extends keyof SectionSettingsRegistry ? SectionSettingsRegistry[K] : BaseSectionSettings }
};
```

Use an explicit variant when shell-scoped props differ from ordinary page sections.

### A.2.2 ComponentRegistry

The registry object must be typed as:

```typescript
export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = { /* ... */ };
```

Conventional file: `src/lib/ComponentRegistry.tsx`.

### A.2.3 PageConfig

Minimum page shape:

```typescript
export interface PageConfig {
  id?: string;
  slug: string;
  meta?: {
    title?: string;
    description?: string;
  };
  sections: Section[];
}
```

### A.2.4 SiteConfig

`site.json` owns shell structure and shell instance declaration.

Canonical direction for v1.6.1:

- `header` is optional and `footer` is required in `site.json`
- each shell instance must provide `id`, `type`, and `data`
- `data` is tenant-sovereign in shape
- if a shell instance uses a primary navigation menu, it binds to `menu.json` through `data.menu.$ref`
- `data.menu.$ref` may target any named collection in `menu.json`; `main` is conventional, not mandatory
- if a shell instance uses additional menu-like collections, each collection may bind through its own direct data field, for example `data.socialLinks.$ref` or `data.legalLinks.$ref`
- no menu-like data means the corresponding binding field is omitted

Illustrative minimum shape:

```typescript
export interface JsonRef {
  $ref: string;
}

export interface SiteConfig {
  header: {
    id: string;
    type: 'header';
    data: HeaderData & {
      /** Primary resolved navigation binding; may target menu.json#/main or any named collection. */
      menu?: JsonRef;
    };
    settings?: HeaderSettings;
  };
  footer: {
    id: string;
    type: 'footer';
    data: FooterData & {
      /** Optional primary footer navigation binding. */
      menu?: JsonRef;
      /** Optional footer social link collection owned by menu.json. */
      socialLinks?: JsonRef;
      /** Optional footer legal link collection owned by menu.json. */
      legalLinks?: JsonRef;
    };
    settings?: FooterSettings;
  };
}
```

The named footer fields above are illustrative, not reserved by Core. The general rule is that a direct shell data field containing a `$ref` to `menu.json` is a menu-bound field.

Normative companion schema:

- [site.schema.json](/wsl.localhost/Ubuntu/home/dev/npm-jpcore/specs/site.schema.json)

Authored config rule:

- `site.json` stores reference intent in direct shell data binding fields
- `data.menu` is the canonical/default primary menu binding field
- additional menu-like fields may store their own `$ref` bindings, for example `data.socialLinks` and `data.legalLinks`
- `site.json` does not canonically own materialized menu/link arrays referenced from `menu.json`
- the authored JSON contract is formalized by the companion schema above

Studio editing rule:

- if any direct shell data field is a `$ref` to `menu.json`, the editable draft for that field belongs to the referenced menu document branch
- editing the resolved menu/link value must update the referenced `menu.json` branch
- editing the resolved value must not rewrite authored `site.json` to inline the resolved array
- examples: editing `footer.data.socialLinks` bound to `menu.json#/footerSocial` updates `menu.json.footerSocial`; editing `footer.data.legalLinks` bound to `menu.json#/footerLegal` updates `menu.json.footerLegal`

Resolved runtime rule:

- after config resolution, shell components may receive concrete `MenuItem[]` props
- this runtime convenience does not change authorship or source of truth

### A.2.5 MenuConfig

`menu.json` is the source of truth for menu structures.
Named menu collections are allowed.

`main` is a conventional default collection name. It is not mandatory for header navigation. A header may bind to any named collection, for example `menu.json#/headerNav`.

Illustrative minimum shape:

```typescript
export interface MenuConfig {
  main?: MenuItem[];
  [key: string]: MenuItem[] | undefined;
}
```

Runtime may resolve references such as `menu.json#/main`, `menu.json#/headerNav`, `menu.json#/footerSocial`, or `menu.json#/footerLegal` before passing concrete `MenuItem[]` into shell instances or resolved section data.

Normative companion schema:

- [menu.schema.json](/wsl.localhost/Ubuntu/home/dev/npm-jpcore/specs/menu.schema.json)

Authored config rule:

- `menu.json` is the authored menu source of truth
- named menu collections are formalized by the companion schema above
- shell/runtime consumers read materialized menu trees after resolution rather than redefining menu ownership

Studio persistence rule:

- if a shell instance binds a direct data field to `menu.json`, Inspector edits to that resolved field must persist into the referenced branch of `menu.json`
- `data.menu.$ref` is the canonical/default primary menu binding and may target `menu.json#/main`, `menu.json#/headerNav`, `menu.json#/footer`, or any named menu collection
- other direct fields such as `data.socialLinks.$ref` and `data.legalLinks.$ref` may target their own named menu collections
- persistence must not redirect those edits into `site.json`
- the binding field in `site.json` must remain a `$ref` after local save, hot save, cold save, or any Studio persistence channel

### A.2.6 ThemeConfig

`theme.json` is the single source of truth for the visual token contract.

v1.6 rule:

- Core should not define tenant semantic vocabulary
- Core should publish flattenable token paths
- tenant owns semantic interpretation and bridging

Illustrative grouped-open contract:

```typescript
export interface ThemeValueMap {
  [key: string]: string | undefined;
}

export interface ThemeTypography {
  fontFamily?: ThemeValueMap;
  scale?: ThemeValueMap;
  tracking?: ThemeValueMap;
  leading?: ThemeValueMap;
  wordmark?: ThemeValueMap;
  [key: string]: ThemeValueMap | undefined;
}

export interface ThemeModes {
  [mode: string]: {
    colors?: ThemeValueMap;
    [key: string]: ThemeValueMap | undefined;
  } | undefined;
}

export interface ThemeTokens {
  colors?: ThemeValueMap;
  typography?: ThemeTypography;
  borderRadius?: ThemeValueMap;
  spacing?: ThemeValueMap;
  zIndex?: ThemeValueMap;
  modes?: ThemeModes;
  [key: string]: ThemeValueMap | ThemeTypography | ThemeModes | undefined;
}

export interface ThemeConfig {
  name: string;
  tokens: ThemeTokens;
}
```

Practical expectation:

- `tokens.colors`, `tokens.typography`, `tokens.borderRadius`, `tokens.spacing`, `tokens.zIndex`, and `tokens.modes` are canonical groups when present
- each group remains open-map and tenant-sovereign internally
- extra groups are allowed as additive extensions
- tenant naming is sovereign

## A.3 Schema Contract (SECTION_SCHEMAS)

Conventional location: `src/lib/schemas.ts`.

Contract:

- `SECTION_SCHEMAS` is a single object keyed by `SectionType`
- values are Zod schemas for section data
- base fragments such as `BaseSectionData` and `BaseArrayItem` are reused by capsules
- the app passes this aggregate to `JsonPagesEngine` as `config.schemas`

Important distinction:

- `SECTION_SCHEMAS` formalize section data contracts for component/editing/runtime surfaces
- the companion JSON Schemas formalize authored document contracts for `site.json` and `menu.json`
- these contract layers complement each other and must not be conflated

## A.4 File Paths & Data Layout

| Purpose | Path (conventional) | Description |
|---------|---------------------|-------------|
| Site config | `src/data/config/site.json` | `SiteConfig` |
| Menu config | `src/data/config/menu.json` | `MenuConfig` |
| Theme config | `src/data/config/theme.json` | `ThemeConfig` |
| Page data | `src/data/pages/<slug>.json` | `PageConfig` |
| Base schemas | `src/lib/base-schemas.ts` | Base fragments |
| Schema aggregate | `src/lib/schemas.ts` | `SECTION_SCHEMAS` |
| Registry | `src/lib/ComponentRegistry.tsx` | `ComponentRegistry` |
| Add-section config | `src/lib/addSectionConfig.ts` | `AddSectionConfig` |
| Tenant types | `src/types.ts` | augmentation and contract types |
| Bootstrap | `src/App.tsx` | builds `JsonPagesConfig` and renders `JsonPagesEngine` |

## A.5 Integration Checklist

When generating or auditing a tenant, ensure:

1. capsules exist for each section type with `View.tsx`, `schema.ts`, `types.ts`, and `index.ts`
2. base schemas define `BaseSectionData`, `BaseArrayItem`, and optional `BaseSectionSettings`
3. `src/types.ts` performs module augmentation and exports tenant contract types
4. `ComponentRegistry` is typed against `SectionType` and `SectionComponentPropsMap`
5. `SECTION_SCHEMAS` is a single keyed schema aggregate
6. `addSectionConfig` provides addable types, labels, and valid defaults
7. `App.tsx` builds `JsonPagesConfig` with pages, site, theme, menu, registry, schemas, CSS bridge data, and optional `refDocuments`
8. config/page JSON files conform to `SiteConfig`, `MenuConfig`, `ThemeConfig`, and `PageConfig`
9. themed tenants publish runtime theme variables before themed sections render
10. tenant global CSS includes TOCC selectors and semantic/theme bridge rules
11. shell instances consume menu/link data by reference binding rather than canonical local ownership; `data.menu.$ref` is canonical/default, and named fields such as `data.socialLinks.$ref` or `data.legalLinks.$ref` may bind to named `menu.json` branches

## A.6 Path/Nested Strictness Addendum

This addendum preserves prior obligations and adds:

1. `SelectionPathSegment` and `SelectionPath` should be exported for Studio messaging
2. nested targeting uses path segments from root to leaf
3. editable object arrays require stable item identity
4. legacy flat fields are transitional adapters, not the normative nested protocol

## A.7 Local Design Tokens Implementation Addendum

This addendum preserves prior obligations and adds:

1. tenant theme values live in `src/data/config/theme.json`
2. runtime publication is mandatory for themed tenants
3. themed sections scope owned color/radius concerns through `--local-*`
4. section-owned color/radius classes consume the local or tenant semantic layer, not hardcoded literals
5. typography consumes the published semantic font chain
6. migration shims may exist temporarily but are not the primary themed contract

Canonical implementation pattern:

```text
theme.json -> published runtime theme vars -> tenant semantic bridge -> section --local-* -> JSX classes
```

Canonical typography pattern:

```text
theme.json -> published runtime theme vars -> tenant semantic font bridge -> section typography
```

Minimal compliant example:

```tsx
<section
  style={{
    '--local-bg': 'var(--background)',
    '--local-text': 'var(--foreground)',
    '--local-primary': 'var(--primary)',
    '--local-radius-md': 'var(--theme-radius-md)',
  } as React.CSSProperties}
  className="bg-[var(--local-bg)]"
>
  <h2 className="font-display text-[var(--local-text)]">Title</h2>
  <a className="bg-[var(--local-primary)] rounded-[var(--local-radius-md)]">CTA</a>
</section>
```

Deterministic compliance checklist:

1. tenant theme source of truth exists
2. runtime publication exists
3. tenant semantic bridge exists
4. section-local scope exists when the section owns the concern
5. section-owned classes consume local or tenant semantic variables
6. primary themed values are not hardcoded