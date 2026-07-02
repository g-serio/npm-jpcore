## 3. Tenant Block Protocol (TBP) v1.1

**Objective:** Standardize the capsule structure for tenant section/component types.

### 3.1 The Atomic Capsule Structure

Components are self-contained directories under `src/components/<sectionType>/`:

- `View.tsx` -> pure React component
- `schema.ts` -> Zod schema(s) for the data contract and optionally settings
- `types.ts` -> TypeScript interfaces inferred from the schema
- `index.ts` -> public API re-exporting View, schema(s), and types

`schema.ts` must export at least one data schema for the type.
Data schema should extend `BaseSectionData`.
Array items should extend `BaseArrayItem`.

### 3.2 Shell-Scoped Section Instances

`header` and `footer` are not conceptually reserved types.

They are ordinary tenant section/component types whose instances are declared in `site.json` instead of page JSON.

They therefore share:

- the same component model
- the same schema-driven contract style
- the same compositional principles

They differ only in:

- data placement
- rendering scope

They also participate in two distinct contracts that must not be conflated:

- authored shell config contract in `site.json`, where menu/link ownership is expressed through direct `$ref` binding fields such as `data.menu.$ref`, `data.socialLinks.$ref`, or `data.legalLinks.$ref`
- resolved runtime contract, where those fields are materialized as concrete `MenuItem[]` values for rendering and Inspector editing

### 3.3 Runtime Special Handling

Core may render shell-scoped instances specially in the global shell path.
This is a runtime/layout concern, not a separate ontological category of section type.

**Why it matters:** TBP keeps extension uniform and prevents shell components from becoming a hidden second component system.

---

## 4. Component Implementation Protocol (CIP) v1.7

**Objective:** Ensure system-wide stability, theme portability, and Admin UI integrity.

### 4.1 The Sovereign View Law

Components receive `data` and `settings` and return JSX.
Shell-scoped instances may receive additional resolved props such as resolved menu trees when the shell binding contract requires it.

Views are metadata-blind:

- they do not import Zod schemas
- they do not embed form logic
- they do not become the semantic authority for tenant theme vocabulary

### 4.2 Z-Index Neutrality

Components must not use `z-index > 1` for ordinary section content.
Layout delegation such as sticky or fixed behavior belongs to the renderer/shell contract, not to arbitrary page sections.

Documented exceptions may exist for shell chrome such as header/footer, but they must remain compatible with overlay visibility.

### 4.3 Agnostic Asset Protocol

Use `resolveAssetUrl(path, tenantId)` for all tenant media.
Resolved URLs are published under `/assets/...`.

### 4.4 Local Design Tokens

**Objective:** Standardize how a section consumes tenant theme values without leaking global styling assumptions into section implementation.

#### 4.4.1 Theme Source Of Truth

For themed tenants, `theme.json` is the tenant-level source of truth for theme tokens.

The tenant decides:

- which token groups exist
- which token names exist
- which semantic vocabulary is used
- how those tokens are bridged into semantic CSS and utilities

Core and section Views are read-only consumers of that contract.

#### 4.4.2 Core Theme Transport Rule

`@olonjs/core` is a token transporter/publisher, not a semantic authority.

That means:

- Core reads `theme.json`
- Core recursively flattens discovered token paths
- Core publishes those values as CSS custom properties before section rendering
- Core may expose convenience aliases
- Core must not govern or restrict the tenant semantic vocabulary

If a tenant token tree is flattenable, Core should publish it.

#### 4.4.3 The Required Layered Chain

For any section that controls background, text color, border color, accent color, or radii, the following chain is normative:

1. Tenant theme source of truth in `theme.json`
2. Runtime theme publication through flattened CSS custom properties
3. Tenant semantic bridge in global CSS such as `:root` and `@theme`
4. Section-local scope through `--local-*` variables when the section owns those concerns
5. Rendered utilities/classes consuming the local or tenant semantic layer

Canonical chain:

`theme.json -> published runtime vars -> tenant semantic bridge -> section --local-* -> JSX classes`

#### 4.4.4 Flattening Rule

Normative rule:

`theme.json object path -> kebab-case path segments -> --theme-... CSS variable`

Examples:

- `tokens.colors.primary` -> `--theme-colors-primary`
- `tokens.typography.fontFamily.display` -> `--theme-typography-font-family-display`
- `tokens.typography.tracking.tight` -> `--theme-typography-tracking-tight`
- `tokens.borderRadius.md` -> `--theme-border-radius-md`
- `tokens.spacing.container-max` -> `--theme-spacing-container-max`
- `tokens.modes.light.colors.background` -> `--theme-modes-light-colors-background`

This flattening rule is architectural law and must not be inferred indirectly by agents.

#### 4.4.5 Runtime Theme Publication

Runtime publication is mandatory for themed tenants.

The compliant bridge is a layered architecture typically implemented in tenant `index.css`:

`theme.json -> engine injection -> :root bridge -> @theme bridge -> JSX classes`

Layer roles:

- engine injection publishes flattened `--theme-*` variables
- `:root` bridge maps published runtime variables into tenant semantic names
- `@theme` bridge exposes those names to Tailwind or equivalent utilities
- section-local `--local-*` variables scope owned concerns to a section root

Concrete bridge examples:

Layer 0 - Engine injection:

| JSON path | Injected CSS var |
|---|---|
| `tokens.colors.{name}` | `--theme-colors-{name}` |
| `tokens.typography.fontFamily.{role}` | `--theme-font-{role}` |
| `tokens.typography.scale.{step}` | `--theme-typography-scale-{step}` |
| `tokens.typography.tracking.{name}` | `--theme-typography-tracking-{name}` |
| `tokens.typography.leading.{name}` | `--theme-typography-leading-{name}` |
| `tokens.typography.wordmark.*` | `--theme-typography-wordmark-*` |
| `tokens.borderRadius.{name}` | `--theme-border-radius-{name}` |
| `tokens.spacing.{name}` | `--theme-spacing-{name}` |
| `tokens.zIndex.{name}` | `--theme-z-index-{name}` |
| `tokens.modes.{mode}.colors.{name}` | `--theme-modes-{mode}-colors-{name}` |

Layer 1 - Tenant semantic bridge:

```css
:root {
  --background: var(--theme-colors-background);
  --foreground: var(--theme-colors-foreground);
  --card: var(--theme-colors-card);
  --primary: var(--theme-colors-primary);
  --border: var(--theme-colors-border);

  --font-primary: var(--theme-font-primary);
  --font-display: var(--theme-font-display);

  --theme-container-max: var(--theme-spacing-container-max);
  --z-overlay: var(--theme-z-index-overlay);
}
```

Layer 2 - `@theme` bridge:

```css
@theme {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-primary: var(--primary);
  --color-border: var(--border);

  --font-primary: var(--font-primary);
  --font-display: var(--font-display);

  --radius-md: var(--theme-radius-md);
  --radius-lg: var(--theme-radius-lg);
}
```

Additional modes should override the Layer 1 semantic bridge, for example under `[data-theme=\"light\"]`, while leaving Layer 2 unchanged.

Rule:

- skipping Layer 2 breaks utility resolution
- skipping Layer 1 couples sections to engine-internal naming
- hardcoding values in any bridge layer is non-compliant

#### 4.4.6 Alias Rule

Aliases such as:

- `--theme-font-primary`
- `--theme-font-display`
- `--theme-radius-md`

are conveniences only.

They do not redefine tenant vocabulary ownership and must not be mistaken for the canonical contract.

#### 4.4.7 Tenant Semantic Bridge

The tenant owns the bridge from published runtime vars into:

- `:root` semantic variables
- Tailwind `@theme` variables
- section-local `--local-*` variables
- utility classes

The naming in this bridge is the tenant's sovereign choice.
Core does not impose semantic names such as `foreground`, `card`, or `muted-foreground`.

#### 4.4.8 Local Token Consumption Rule

If a section visually owns background, text, border, accent, or radius concerns, it must not bypass local scoping for those concerns.

Required pattern:

- section root defines `--local-*` variables for owned color/radius concerns
- child utilities consume `var(--local-*)`

Directly using global theme variables throughout JSX for section-owned concerns is non-canonical for a fully themed section.

#### 4.4.9 Typography Rule

Typography follows the same source-of-truth rule, but local scoping is optional unless the section truly remaps typography locally.

Canonical typography chain:

`theme.json -> published runtime vars -> tenant semantic font bridge -> utility or CSS variable -> JSX typography`

#### 4.4.10 Allowed Exceptions

The following are acceptable if documented and intentionally limited:

- tiny decorative one-off values that are not part of the tenant theme contract
- temporary migration shims where the compliant path still exists and is primary
- semantic alias bridges in tenant CSS whose source remains the published theme layer

#### 4.4.11 Non-Compliant Patterns

The following are non-compliant:

- reading `theme.json` directly inside a View
- hardcoding primary themed values in JSX or section-local inline styles
- using `rounded-[7px]`, `bg-blue-500`, `text-zinc-100`, or similar literals as the primary themed contract
- defining `--local-*` at the root and then bypassing them with raw global utilities for the same owned concerns
- treating tenant-specific extension keys as a replacement for the tenant's own primary semantic contract

#### 4.4.12 Practical Interpretation

`--local-*` is not the source of truth.
It is the section-local scoping layer between tenant theme publication and section rendering.

### 4.5 Z-Index & Overlay Governance

Section content roots must remain at `z-index <= 1` so the Studio overlay can remain authoritative.
Shell-scoped instances may use higher values only as documented shell exceptions.

**Why it matters:** View components stay dumb and portable, themed tenants remain reproducible, and Studio overlay behavior remains deterministic.

---