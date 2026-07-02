## 2. JsonPages Site Protocol (JSP) v1.10

**Objective:** Define deterministic content/config topology and the site-level document contract.

### 2.1 The File System Ontology

Every tenant should expose a deterministic content/config silo:

- `src/data/config/site.json`
- `src/data/config/menu.json`
- `src/data/config/theme.json`
- `src/data/pages/**/*.json`

The CLI or projection workflow may use different physical staging paths, but the runtime contract remains that the app receives `siteConfig`, `menuConfig`, `themeConfig`, `pages`, and optional `refDocuments`.

### 2.2 Source Of Truth Separation

The canonical tenant document responsibilities are:

- `site.json` -> site identity, shell structure, shell-scoped section instances, page listing metadata
- `menu.json` -> menu trees and named menu/link collections
- `theme.json` -> theme token source of truth
- `pages/**/*.json` -> page-scoped content sections

### 2.3 Menu Source Of Truth Rule

`menu.json` is the source of truth for menu data.

Shell components may consume menu data.
Shell components must not be treated as the authoritative source of menu structure.

### 2.4 Shell Binding Rule

If a shell component uses menu data, it should bind to `menu.json` through a direct field in `section.data`.

Canonical default rule:

- for a primary shell navigation collection, use `data.menu.$ref`
- the `$ref` may target any named collection in `menu.json`, not only `#/main`
- `main` is a conventional default collection name, not a required header collection name
- for additional menu-like collections, use explicit field names whose schema describes the resolved collection

Examples:

- `site.json -> header.data.menu.$ref -> menu.json#/main`
- `site.json -> header.data.menu.$ref -> menu.json#/headerNav`
- `site.json -> footer.data.socialLinks.$ref -> menu.json#/footerSocial`
- `site.json -> footer.data.legalLinks.$ref -> menu.json#/footerLegal`

### 2.5 Bound External Field Rule

If an authored field contains a `$ref` to an external document, that field is a binding field, not an ownership field.

Canonical consequences:

- the authored document keeps the binding expression
- the referenced document remains the owner of the bound data
- Studio may present the resolved value in Inspector as if it were local
- draft mutation and persistence must target the referenced owner document, not the binding document
- the binding document must not be canonically materialized with the resolved payload during save

Example:

- `site.json -> header.data.menu.$ref -> ../config/menu.json#/main`
- Inspector may render `header.data.menu` as concrete `MenuItem[]`
- edits must update `menu.json.main`
- `site.json` must keep `data.menu.$ref`

The same rule applies to any direct shell data field bound to `menu.json`, not only a field named `menu`.

Examples:

- `site.json -> footer.data.socialLinks.$ref -> menu.json#/footerSocial`
- Inspector may render `footer.data.socialLinks` as concrete `MenuItem[]`
- edits must update `menu.json.footerSocial`
- `site.json` must keep `data.socialLinks.$ref`

- `site.json -> footer.data.legalLinks.$ref -> menu.json#/footerLegal`
- Inspector may render `footer.data.legalLinks` as concrete `MenuItem[]`
- edits must update `menu.json.footerLegal`
- `site.json` must keep `data.legalLinks.$ref`

- no menu-like data -> omit the corresponding binding field
- has menu-like data owned by `menu.json` -> use `$ref`

Resolved Editing Surface Rule: Component Zod schemas (e.g., HeaderSchema or FooterSchema) describe the resolved data surface presented to the Inspector, not the raw authored JSON. If a field like `data.menu`, `data.socialLinks`, or `data.legalLinks` is authored as a `$ref` in `site.json`, the corresponding Zod schema MUST describe the resolved shape (e.g., `z.array(MenuItemSchema)`). The engine handles resolving the `$ref` for the Form Factory and routing the edits back to the referenced document (e.g., `menu.json`).

### 2.5 Deterministic Projection

Tenant generation and scaffolding should preserve deterministic paths for:

- config documents
- page documents
- component capsules
- registries
- schemas

Canonical projection workflow:

1. Infra projection generates the shell files such as `package.json`, `tsconfig.json`, and `vite.config.ts`
2. Source projection reconstructs the tenant DNA under `src/`
3. Dependency resolution pins the expected runtime/build stack for the tenant

The exact tool implementation may evolve, but the projection result must remain deterministic enough that agents and tooling can rediscover the same contract surfaces without heuristic scanning.

**Why it matters:** JSP gives agents and tooling stable paths for discovery, projection, validation, and migration.

---