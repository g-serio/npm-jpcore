# Architecture

This document defines the current architecture of `npm-jpcore`.

## Monorepo layout

- `packages/core` -> `@olonjs/core`
- `packages/cli` -> `@olonjs/cli`
- `packages/stack` -> `@olonjs/stack`
- `apps/tenant-alpha` -> template source app (`alpha`)

Root workspace config is in `package.json` (`workspaces: ["packages/*", "apps/*"]`).

## Package responsibilities

## `@olonjs/stack`

- version manifest package
- consumed by other packages to keep dependency policy aligned

## `@olonjs/core`

- runtime engine and Studio editor surface, shipped as a single npm package with two physical bundles (see [Build and Distribution Topology](#build-and-distribution-topology) below)
- consumed by generated tenants and bound by [ADR-0009](./decisions/ADR-0009-core-studio-split-via-runtime-subpath.md)
- public API surface lives at two import specifiers:
  - `@olonjs/core` — full bundle including Studio admin, FormFactory, AdminSidebar, StudioStage; size ~128 KB gzipped
  - `@olonjs/core/runtime` — visitor-only subset (engine, rendering, theme, DNA); size ~28 KB gzipped
- a CI-enforced boundary check (`packages/core/scripts/check-runtime-decoupling.mjs`) prevents the runtime bundle from regressing into Studio admin imports

## `@olonjs/cli`

- scaffolds new tenants
- resolves DNA from template assets
- command surface: `olonjs new tenant <name> [--template <name>] [--script <path>]` (`jsonpages` alias supported)

## Template architecture

DNA templates are packaged under:

- `packages/cli/assets/templates/alpha/`

Each template contains:

- `src_tenant.sh`
- `manifest.json`

Backward compatibility path still exists for `alpha`:

- `packages/cli/assets/src_tenant_alpha.sh`

## Source of truth model

Template DNA must originate from source apps:

- `apps/tenant-alpha` => `alpha`

Manual edits directly in template DNA files are not the preferred workflow.

## Operational flows

## Local development

- `npm run dev` -> `tenant-alpha`

## DNA regeneration

- `npm run dist:dna:all`
- delegates to each source app `dist` script

## Template conformance

- `npm run check:templates`
- validates template presence and manifest consistency

## Release

Two distinct flows; see [PUBLISHING.md](./PUBLISHING.md) for the operational details:

- `npm run release` -> legacy npm release flow (`@olonjs/stack`, `@olonjs/core`, `@olonjs/cli`, `@jsonpages/*` bridges)
- `npm run release:enterprise` -> gated npm release (`check:templates`, `dist:dna:all`, then legacy)
- `olon.js.org` site -> deployed automatically to `gh-pages` by `.github/workflows/deploy-landing.yml` on every push to `main` whose change set touches `apps/olonjs.io/**`, `packages/core/**`, or the workflow itself. No manual deploy command. The site builds `@olonjs/core` from the monorepo workspace, not from the npm registry, so it tracks the latest committed source independently of npm publish cadence.

## Build and Distribution Topology

`@olonjs/core` ships **one npm package with two physical bundles**, gated by Node `exports` subpath conditions. This is the implementation of [ADR-0009](./decisions/ADR-0009-core-studio-split-via-runtime-subpath.md).

### Package layout

```
@olonjs/core (single package, single version)
└── dist/
    ├── olonjs-core.js              full bundle (ESM)   — runtime + Studio admin
    ├── olonjs-core.umd.cjs         full bundle (UMD)   — Node interop
    ├── olonjs-core-runtime.js      runtime bundle (ESM) — visitor subset
    ├── index.d.ts                  full types
    └── runtime.d.ts                runtime-only types
```

### Subpath exports

`packages/core/package.json` declares two import specifiers:

```json
"exports": {
  ".":         { "types": "./dist/index.d.ts",   "import": "./dist/olonjs-core.js",         "require": "./dist/olonjs-core.umd.cjs" },
  "./runtime": { "types": "./dist/runtime.d.ts", "import": "./dist/olonjs-core-runtime.js" }
}
```

The runtime subpath is ESM-only by design (no Node CJS consumer needs the runtime bundle). The full bundle keeps UMD/CJS parity for backwards compatibility.

### Tenant consumption pattern

Tenants import the runtime engine statically and the full Studio engine as a `React.lazy` chunk gated on `/admin`. This keeps the visitor critical path free of editor code while preserving a single binary for tenants that mount Studio:

```tsx
// apps/<tenant>/src/App.tsx
import { OlonJSEngine } from '@olonjs/core/runtime';

const isAdminPath =
  typeof window !== 'undefined' && window.location.pathname.startsWith('/admin');

const LazyJsonPagesEngine = lazy(() =>
  import('@olonjs/core').then((m) => ({ default: m.JsonPagesEngine })),
);

return isAdminPath
  ? <Suspense fallback={null}><LazyJsonPagesEngine config={config} /></Suspense>
  : <OlonJSEngine config={config} />;
```

Vite/Rollup observe the two specifiers as distinct dependency edges and emit two output chunks: the visitor entry includes only `olonjs-core-runtime.js`; the admin chunk that includes `olonjs-core.js` is fetched on demand.

### Cross-bundle singleton identity (ADR-0012)

The full bundle does NOT inline the runtime source. Instead, `packages/core/vite.config.ts` externalizes four singleton-bearing files (`runtime/config/ConfigContext.tsx`, `studio/StudioContext.tsx`, `runtime/theme/theme-manager.ts`, `runtime/icons/IconRegistryContext.tsx`) and rewrites their emitted imports to `./olonjs-core-runtime.js`. At consumer load time, both `import { useConfig } from '@olonjs/core'` (full path) and `import { useConfig } from '@olonjs/core/runtime'` (runtime path) resolve to the same module instance — the runtime artifact loaded once, shared by both subpath consumers.

Without this externalize boundary, each Vite build inlines its own copy of every shared file, producing two distinct `React.createContext()` instances at runtime. When Studio's `<ConfigProvider>` (from the full bundle) wraps tenant section views (which read `useConfig()` from the runtime bundle), the consumer reads from a different context than the provider populates, throwing `useConfig must be used within ConfigProvider`. This was the symptom that forced ADR-0012; see that ADR for the full diagnosis and the externalize ruleset.

The colocation requirement that follows from this design — both `olonjs-core.js` and `olonjs-core-runtime.js` must sit side-by-side in any deployment of `@olonjs/core` — is documented in [PUBLISHING.md §"Colocation requirement"](./PUBLISHING.md#colocation-requirement-adr-0012).

### Composition root

`OlonJSEngine` and `JsonPagesEngine` are sibling thin wrappers around `JsonPagesEngineCore` (`packages/core/src/runtime/engine/JsonPagesEngineCore.tsx`). Each invokes the core with a different `routesBuilder`:

- `OlonJSEngine` → `buildRuntimeRoutes` (visitor routes only)
- `JsonPagesEngine` → builder that mounts visitor routes plus `/admin` (StudioRoute) and `/preview` (PreviewRoute)

This avoids code duplication and keeps the engine boot sequence (config resolution, theme loading, error boundaries, head sync) authored once.

### Module augmentation note

The MTRP module augmentation (`SectionDataRegistry`, `SectionSettingsRegistry`) must target **both** import specifiers in tenant `types.ts`, because TypeScript treats `'@olonjs/core'` and `'@olonjs/core/runtime'` as distinct module identifiers. See [ADR-0009](./decisions/ADR-0009-core-studio-split-via-runtime-subpath.md) for the rationale and the canonical pattern.

### Boundary enforcement

`packages/core/scripts/check-runtime-decoupling.mjs` is a static analyzer that walks the import graph from `src/runtime-entry.ts` and fails if any reachable file imports from `src/studio/admin/` or `src/studio/orchestration/`. Allowed integration points are the three documented edges (`JsonPagesEngine`, `StudioRoute`, `PreviewRoute`). Run via:

```bash
npm run test:boundary -w @olonjs/core
```

The check is part of `npm run test:all` and is intended to be wired into CI before publish.

## Constraints and caveats

- On Windows UNC paths (`\\wsl.localhost\...`), npm/cmd invocation may fail; prefer WSL shell for release operations.
- `scripts/release.js` currently updates only `tenant-alpha` dependency pin during publish flow.
- `scripts/release-enterprise.js` adds pre-flight template governance but delegates to legacy release script.
- Both bundles must be rebuilt together. `npm run build -w @olonjs/core` invokes `scripts/build-dual.mjs` which runs `vite.config.ts` and `vite.config.runtime.ts` in sequence and stitches the dts outputs. Do not invoke either Vite config standalone — the runtime build sets `emptyOutDir: false` to preserve the full build's artifacts and depends on the orchestrator for ordering.
