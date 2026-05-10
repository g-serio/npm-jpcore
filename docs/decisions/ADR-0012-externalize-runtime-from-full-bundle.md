# ADR-0012: Externalize the runtime entry from the full bundle to dedupe shared module instances

## Status

Accepted — implemented in `@olonjs/core` v1.1.1; Studio renders all tenant sections verified 2026-05-10 (`apps/olonjs.io` `/admin`, dev build against `localhost:5173`).

## Date

2026-05-10

## Scope

The build configuration of `@olonjs/core` (`packages/core/vite.config.ts`, `packages/core/vite.config.runtime.ts`, `packages/core/scripts/build-dual.mjs`, and the surface of `packages/core/src/index.ts`). Affects every consumer that loads both subpath exports (`@olonjs/core` and `@olonjs/core/runtime`) at runtime — primarily tenants that mount Studio (`/admin`) under the architecture established in ADR-0009.

This ADR **amends** ADR-0009. It does not supersede it. The dual-bundle topology and the visitor/Studio split remain the right design; a missing build constraint must be added so the topology behaves as designed.

## Context

ADR-0009 split `@olonjs/core` into two physical bundles:

- `dist/olonjs-core.js` — full bundle (visitor runtime + Studio admin), entry `src/index.ts`.
- `dist/olonjs-core-runtime.js` — visitor-only bundle, entry `src/runtime-entry.ts`.

Both bundles are produced by `scripts/build-dual.mjs`, which runs two **independent Vite library builds** sequentially (`vite.config.ts`, then `vite.config.runtime.ts`). Each Vite build externalizes only the peer dependencies (`react`, `react-dom`, `react-router-dom`, `zod`); every other source file in `packages/core/src/` is inlined into whatever bundle reaches it through its entry's import graph.

`src/index.ts` (the full entry) does this:

```ts
export * from './kernel';
export * from './studio/events';
export * from './lib/utils';
export * from './runtime';   // ← inlines the entire runtime tree
export * from './dna';
```

`src/runtime-entry.ts` (the runtime entry) imports the same files:

```ts
export { OlonJSEngine } from './runtime/engine/OlonJSEngine';
export { ConfigProvider, useConfig, ... } from './runtime/config/ConfigContext';
export { StudioProvider, useStudio } from './studio/StudioContext';
export { themeManager } from './runtime/theme/theme-manager';
// ...
```

Because the two Vite builds are independent and neither marks the other's source as external, **every shared file is compiled twice — once into each bundle**. For pure functions, types, and stateless React components this is wasteful but harmless. For modules that hold **identity** at runtime, it is a correctness bug:

- `runtime/config/ConfigContext.ts` calls `React.createContext()` — once per bundle → two distinct context objects.
- `studio/StudioContext.ts` does the same.
- `runtime/icons/IconRegistryContext.ts` does the same.
- `runtime/theme/theme-manager.ts` exports a singleton — duplicated → two registries diverging in state.
- Any class instance held at module scope (none currently, but possible) would also be duplicated.

### Symptom (observed 2026-05-10)

When a tenant follows the canonical pattern from ADR-0009 §"Tenant consumption pattern":

```tsx
import { OlonJSEngine } from '@olonjs/core/runtime';
const LazyJsonPagesEngine = lazy(() =>
  import('@olonjs/core').then((m) => ({ default: m.JsonPagesEngine })),
);
```

…and the user navigates to `/admin`, both bundles end up in memory simultaneously. The full bundle's `JsonPagesEngine` mounts `ConfigProvider` from the **full bundle's** `ConfigContext` instance. The tenant's section views (`HeaderView`, `PremiumHeroView`, `FooterView`, etc.) call `useConfig()` imported from `@olonjs/core/runtime` — i.e. they read from the **runtime bundle's** `ConfigContext` instance. Different React context objects → consumer reads `undefined` → the runtime helper throws `useConfig must be used within ConfigProvider`.

The captured browser console (2026-05-10, `localhost:5173/admin` against `apps/olonjs.io`) shows seven identical crashes, one per registered section, with the diagnostic stack:

```
Error: useConfig must be used within ConfigProvider
    er olonjs-core-runtime.js:551          ← thrown from /runtime instance
    HeaderView View.tsx:90
    ...
    Cf  olonjs-core.js:4109                ← provider/error-boundary live in /full instance
```

The colocation of `olonjs-core-runtime.js` and `olonjs-core.js` in the same stack is the proof of two-instance loading.

### Why this was not caught before

ADR-0009 was marked Accepted on 2026-05-09 with the justification *"implemented in @olonjs/core v1.1.0; deployed to olon.js.org"*. The deployed acceptance covers **visitor-only** behavior:

- `apps/olonjs.io/scripts/bake.mjs` produces SSG output that mounts only `OlonJSEngine` from `@olonjs/core/runtime`. The full bundle is never loaded during the bake; `/admin` is not part of the production build.
- `.github/workflows/deploy-landing.yml` exercises the same path and pushes to `gh-pages`. It does not exercise `/admin` either.
- Local Studio (`/admin`) is exercised in dev mode, but the dev server uses Vite's source-level resolution, which **does not reproduce the dual-bundle topology**. In dev, a single source tree is served; both `import` paths resolve to the same `ConfigContext.ts` source file, so `createContext()` runs once. The bug only manifests against the *built* artifacts.

The CI-enforced boundary check (`packages/core/scripts/check-runtime-decoupling.mjs`) walks the import graph from `src/runtime-entry.ts` to forbid Studio admin code reaching the visitor bundle. It is purely a directional check — it does not verify singleton invariants on the modules that *are* meant to be shared. The boundary check is correct in scope; the gap is in the build configuration, not the linter.

In short: ADR-0009 set the right architectural direction, the visitor side was verified, and the Studio side appears to never have been smoke-tested against the production build of `@olonjs/core`. ADR-0012 closes that gap.

## Decision

The full bundle imports the runtime as an **external module reference at the file granularity**, not as inlined source. After this change, exactly one copy of every singleton-bearing runtime module is loaded into memory regardless of which subpath the consumer imports.

The implementation has four moving parts. The proposal originally enumerated six (§1–§6); during implementation §1 was narrowed to a one-line addition and §3 was dropped entirely — both reasons documented under "Implementation notes" below.

1. **Externalize the four singleton-bearing source files in `packages/core/vite.config.ts`** and rewrite their emitted import path to the sibling runtime artifact. The implemented form:

   ```ts
   // vite.config.ts (full bundle)
   const SINGLETON_RUNTIME_MODULES = [
     /[/\\]runtime[/\\]config[/\\]ConfigContext(\.tsx?)?$/,
     /[/\\]studio[/\\]StudioContext(\.tsx?)?$/,
     /[/\\]runtime[/\\]theme[/\\]theme-manager(\.tsx?)?$/,
     /[/\\]runtime[/\\]icons[/\\]IconRegistryContext(\.tsx?)?$/,
   ];

   const isSingletonRuntimeModule = (id: string): boolean =>
     SINGLETON_RUNTIME_MODULES.some((re) => re.test(id));

   build: {
     emptyOutDir: false,                 // see point 4 below
     rollupOptions: {
       external: (id) =>
         PEER_DEPS.includes(id) || isSingletonRuntimeModule(id),
       output: {
         globals: { /* unchanged */ },
         paths: (id) =>
           isSingletonRuntimeModule(id)
             ? './olonjs-core-runtime.js'
             : id,
       },
     },
   },
   ```

   The full bundle's compiled ESM output emits `import { ConfigProvider, useConfig, ... } from "./olonjs-core-runtime.js"` (12 such import sites confirmed in v1.1.1 dist). The UMD/CJS output emits the equivalent `require("./olonjs-core-runtime.js")` (5 sites). Both consumers (ESM and CJS) resolve the runtime sibling and share its module instance.

2. **Add `buildThemeVariableMap` to the runtime-entry surface (`packages/core/src/runtime-entry.ts`)**. Rollup externalizes at file granularity, not symbol granularity: when `runtime/theme/theme-manager.ts` is externalized, every symbol re-exported by the full bundle's public surface from that file must be available on the runtime artifact. `themeManager` (singleton) was already exported by `runtime-entry.ts`; `buildThemeVariableMap` (a pure function in the same source file, re-exported by `runtime/theme/index.ts → runtime/index.ts → src/index.ts`) was not, and the full build failed to load with `SyntaxError: ... does not provide an export named 'buildThemeVariableMap'`. The fix is one re-export line. No restructuring of `src/index.ts` is required — the audit during implementation showed every symbol the full bundle's import graph expects from the externalized files (`useConfig`, `ConfigProvider`, `useStudio`, `StudioProvider`, `themeManager`, `buildThemeVariableMap`, `IconRegistryContext`, `useIconRegistry`) is now exported by `runtime-entry.ts`.

3. **Boundary check extension is deferred to a follow-up**, not blocking this fix. A future iteration of `scripts/check-runtime-decoupling.mjs` (or a sibling `scripts/check-singleton-modules.mjs`) should walk the import graph of the full entry and assert that any file matching `SINGLETON_RUNTIME_MODULES` is reached only via the externalize boundary, never inlined into the full bundle. The current safeguard is the regex list above plus the `output.paths` rewrite — both colocated in `vite.config.ts` and visible to reviewers.

4. **`packages/core/scripts/build-dual.mjs` keeps its original build order (full first, then runtime)** and `vite.config.ts` adds `build.emptyOutDir: false`. The original ADR draft proposed inverting the order so the runtime artifact would exist on disk before the full build runs; in practice this is not necessary because the externalize is resolved at *consumer load time*, not at the full bundle's compile time. The full build emits a textual `import "./olonjs-core-runtime.js"` regardless of whether the file currently exists; Rollup does not verify external paths. What inverting the order *did* break was `vite-plugin-dts`'s rolled-up declarations: when the runtime build ran first and wrote `dist/index.d.ts`, the subsequent full build's api-extractor pass produced `index.d.ts` containing 60+ types with `_2` suffix duplicates (`JsonPagesConfig` and `JsonPagesConfig_2`, `ProjectState_2`, `FallbackSection_2`, etc.). Tenant TypeScript compilation broke with `Type 'JsonPagesConfig' is not assignable to type 'JsonPagesConfig_2'` at every call site that crossed the boundary. Reverting to the original full-first order eliminates the duplication. The orchestrator already cleans `dist/` once at step 0; both Vite configs declare `emptyOutDir: false` so neither build wipes the other's artifacts.

5. **Tenant consumption is unchanged.** Both `import { OlonJSEngine } from '@olonjs/core/runtime'` and `import { JsonPagesEngine } from '@olonjs/core'` keep their meaning. Tenants do not modify any source file. The dual-import pattern documented in ADR-0009 §"Tenant consumption pattern" remains canonical and now actually behaves as documented — Studio's `<ConfigProvider>`, `<StudioProvider>`, and `<IconRegistryContext.Provider>` instances reference the same React Context objects the tenant section views consume via `useConfig`, `useStudio`, `useIconRegistry`.

6. **Versioning.** The change ships as `@olonjs/core` v1.1.1 (patch). It is a bug fix in the published artifact; the public API surface is unchanged. ADR-0009's status line (`implemented in @olonjs/core v1.1.0`) is left intact for historical accuracy; future ADR readers find the v1.1.1 reference here.

After this change, the symbols in both subpath public surfaces resolve to literally the same JavaScript reference at runtime. Verified 2026-05-10 in a Node ESM probe loading both `dist/olonjs-core.js` and `dist/olonjs-core-runtime.js`:

| Symbol | Same reference? |
|---|---|
| `useConfig` | ✓ |
| `ConfigProvider` | ✓ |
| `useStudio` | ✓ |
| `StudioProvider` | ✓ |
| `themeManager` | ✓ |
| `IconRegistryContext` | n/a — internal only, full bundle does not re-export it; the import-graph dedup is verified by inspecting the emitted `import { IconRegistryContext } from "./olonjs-core-runtime.js"` in `dist/olonjs-core.js` |

The Studio preview stage in `apps/olonjs.io` `/admin` renders all 7 tenant sections without `useConfig must be used within ConfigProvider` errors (verified 2026-05-10).

## Alternatives Considered

### B — Single Vite build with two entry points and shared chunks

Replace `vite.config.ts` and `vite.config.runtime.ts` with a single config that declares both entries via `rollupOptions.input: { full: 'src/index.ts', runtime: 'src/runtime-entry.ts' }`, and let Rollup automatically extract a shared chunk for code reachable from both.

- **Pros:** Most idiomatic Rollup-native solution; automatic dedup without manual `external` lists; future singleton modules require no config change.
- **Cons:** Requires migrating away from Vite `lib` mode (which assumes a single library entry) toward `build.rollupOptions.input` directly. Output naming, dts generation, and the existing `scripts/build-dual.mjs` orchestrator all need to be rewritten. The shared chunk emitted by Rollup gets a content-hashed name that must be referenced from both entries — tenants currently consume named files (`olonjs-core.js`, `olonjs-core-runtime.js`); any rename breaks the `package.json` `exports` map and every tenant's import resolver cache.
- **Rejected because:** disproportionate to the bug. Fix A is a few lines of config; this is a build system migration. Worth revisiting in a future ADR if more singleton modules are added or if a third subpath emerges (e.g. ADR-0011 follow-up suggested a `@olonjs/core/dna` subpath as Option C, which was rejected then for the same disproportion reason).

### C — Hoist singleton instances onto `globalThis`

Modify each singleton-creating file to read/write its instance from `globalThis.__OLONJS__.contexts.config` (or similar). The full and runtime bundles each look the same key up; the first to import wins, the second observes the existing instance.

- **Pros:** Zero build config change. Self-contained inside the source files that own the singletons.
- **Cons:** Adds runtime indirection on every read of `useContext`. Pollutes a global namespace controlled by no specification. Breaks if a tenant or extension defines a conflicting `__OLONJS__` key. Hostile to tree-shaking. Hard to reason about — context identity is now dependent on import order across bundles, not on module identity.
- **Rejected because:** workaround, not a fix. The bug is architectural (two Vite builds → two module instances); the right level to address it is the build config, not application code. Also crosses a layer: contexts should not know they may be cross-bundle deduped.

### D — Revert ADR-0009 to a single bundle

Drop `vite.config.runtime.ts` and ship `@olonjs/core` as one bundle again. Tenants that want runtime-only loading rely on Rollup's tree-shaking + `sideEffects: false` (per ADR-0011) to drop Studio admin from their chunk.

- **Pros:** Eliminates the entire class of dual-bundle bugs by construction.
- **Cons:** Loses the explicit runtime/Studio boundary that ADR-0009 negotiated, including the CI-enforced check (`check-runtime-decoupling.mjs`). Tree-shaking is best-effort; a single careless `export * from './studio/admin'` in `runtime-entry.ts` re-introduces 100+ KB of editor code on the visitor critical path with no diagnostic. Also throws away the verified ~28 KB-gz visitor budget shipped in v1.1.0.
- **Rejected because:** the dual-bundle topology earned its keep — visitor budget verified, boundary CI-enforced, ADR-0008 perf roadmap depends on it. Throwing it away to fix a dedup bug is a much larger architectural regression than the bug we are fixing.

### E — Document the Studio-vs-runtime mismatch as a known limitation; tell tenants to import only from `@olonjs/core` when mounting Studio

Update ADR-0009 to say "Tenants that mount Studio MUST import all section-side hooks (`useConfig`, `useStudio`, etc.) from `@olonjs/core`, not from `@olonjs/core/runtime`." This collapses the import graph back to a single bundle on `/admin` routes.

- **Pros:** Zero code change in `@olonjs/core`. Documentation-only.
- **Cons:** Pushes the complexity onto every tenant. The conditional-import pattern (`from '@olonjs/core/runtime'` for visitor, `from '@olonjs/core'` for Studio sections) is unworkable — section views are shared between visitor and Studio routes; they cannot have two different import sources for the same hook. Effectively this means tenants always import from `@olonjs/core`, which collapses the visitor budget back to the pre-ADR-0009 size.
- **Rejected because:** equivalent to D in outcome (no runtime budget win) but with worse ergonomics for tenants and no CI enforcement.

## Consequences

### Positive

- The Studio preview stage (`StudioStage` rendered inside `JsonPagesEngine`) renders tenant section views correctly. The seven `COMPONENT ERROR` panels seen on 2026-05-10 are gone — verified empirically against `apps/olonjs.io` `/admin`.
- `useConfig`, `useStudio`, `themeManager`, and the other singleton-bearing modules observed at runtime are guaranteed to be the **same instance** regardless of which subpath the consumer imported. This invariant is now a build-time contract enforced by the externalize rule, not a coincidence of bundling.
- The full bundle becomes substantially smaller. **Measured: 815 KB raw / 229 KB gzipped → 532 KB raw / 127 KB gzipped (−283 KB raw / −102 KB gzipped, ≈ 45 % reduction).** The savings come from no longer duplicating the runtime source into the full output: `ConfigContext`, `StudioContext`, `theme-manager`, `IconRegistryContext`, plus the React rendering primitives those files transitively depend on.
- The dual-bundle topology now matches its documented behavior in ADR-0009 §"Tenant consumption pattern". Tenants no longer discover by experimentation that Studio only works in dev mode.
- The constraint is enforceable in CI (follow-up #4 below): future regressions can be caught before publish.

### Negative

- The full bundle now has a hard runtime dependency on the runtime bundle. If a consumer ships only `dist/olonjs-core.js` without `dist/olonjs-core-runtime.js` next to it (e.g. a misconfigured CDN, a custom bundler that resolves only the main field), the full bundle fails to load. Mitigation: both files remain in `package.json` `files` and `exports` (already the case); a one-line note belongs in `docs/PUBLISHING.md` (follow-up #2 below).
- Tooling that statically analyzes `dist/olonjs-core.js` (e.g. bundle-size visualizers, `npm pack` linters) sees an unresolved import to `./olonjs-core-runtime.js` until both files are colocated. This is correct ESM behavior but may surprise tools that expect a self-contained file.
- A small migration burden if a future contributor adds a new singleton-bearing module: it must be added to `SINGLETON_RUNTIME_MODULES` in `vite.config.ts` AND re-exported from `runtime-entry.ts`, otherwise the bug re-emerges silently. The CI check proposed in follow-up #4 below would catch this; until it lands, code review is the only safeguard.
- The UMD output triggers eight Rollup warnings of the form `No name was provided for external module ".../ConfigContext.tsx" in "output.globals" – guessing "ConfigContext_tsx"`. The UMD wrapper falls back to `require()` for CJS consumers (which works correctly) and to a generated global name for IIFE consumers (which is unused — no published consumer of `@olonjs/core` uses the package via `<script>` tag). The warnings are noise and could be silenced by adding entries to `output.globals`, but doing so without a real consumer would just make the noise quieter at the cost of a misleading global. Left as is.

### Implementation notes

Three discoveries during implementation that future maintainers should be aware of:

1. **`vite-plugin-dts` is order-sensitive.** Inverting the build order (runtime first) causes api-extractor's rolled-up `index.d.ts` to contain 60+ duplicate-suffixed types (`JsonPagesConfig_2`, `ProjectState_2`, `FallbackSection_2`, …) which cascade into tenant TypeScript errors at every assignment that crosses the runtime/full boundary. The behavior is reproducible with the runtime build emitting `dist/index.d.ts` first and the full build's api-extractor pass running second; reversing the order eliminates the duplication. Treat this as an empirical invariant of the current dts plugin version (`vite-plugin-dts` 4.x); revisit if the plugin changes its rollup model.

2. **Rollup externalizes at file granularity, not symbol granularity.** When `runtime/theme/theme-manager.ts` is externalized to dedupe `themeManager` (a singleton), the pure function `buildThemeVariableMap` in the same file *also* becomes external. The full bundle's public surface re-exports `buildThemeVariableMap` (through `runtime/theme/index.ts → runtime/index.ts → src/index.ts`), so it must be available on the runtime artifact. Solution: re-export it from `runtime-entry.ts`. Generalization: any externalized file's full set of consumer-facing symbols must be on the runtime entry's surface, even if some are pure functions that don't strictly need deduping.

3. **`IconRegistryContext` is a special case.** It is not exported by the full bundle's public surface (`fullBundle.IconRegistryContext === undefined`); it is only reachable via the runtime subpath. The dedup still works internally: when Studio admin's source code (e.g. `JsonPagesEngineCore.tsx`) does `import { IconRegistryContext } from '../../runtime/icons/IconRegistryContext'`, the externalize rule rewrites the emitted import to `import { IconRegistryContext } from './olonjs-core-runtime.js'`, so Studio's `<IconRegistryContext.Provider>` and the tenant View's `useIconRegistry()` hook share the same context object. The Node ESM probe in §6 above shows `IconRegistryContext` does not match across `fullBundle` and `runtimeBundle` exports, but that is a public-surface artefact — the import-graph dedup is verified separately by grepping the dist for the externalized import.

### Requirements imposed on other parts of the system

- **`packages/core/src/index.ts`** — refactor to re-export the runtime surface via `runtime-entry`.
- **`packages/core/vite.config.ts`** — add the `external` rule and the `output.paths` rewrite for `runtime-entry`.
- **`packages/core/scripts/build-dual.mjs`** — invert the build order: runtime first, full second. Add an assertion that the runtime artifact exists before the full build runs.
- **`packages/core/package.json`** — no change to `exports` or `files`; the runtime artifact is already published. Bump version to `1.1.1`.
- **`docs/PUBLISHING.md`** — add a one-line note in the "Verifying the published artifacts" subsection: both `olonjs-core.js` and `olonjs-core-runtime.js` must be colocated for the full bundle to load.
- **`docs/ARCHITECTURE.md` §"Build and Distribution Topology"** — add a paragraph clarifying that the full bundle imports the runtime as an external sibling, not as inlined source. This corrects the implicit reading of ADR-0009 that the two bundles are independent.
- **No tenant change required.** All tenants keep their current import patterns. The fix is invisible to consumers other than the bug going away.

## Follow-ups

- [ ] Implement the boundary extension described in §3 above (assert that singleton modules are reachable from the full entry only via the externalize boundary). Non-blocking for shipping v1.1.1; should land within one release. Leaning toward a sibling script `scripts/check-singleton-modules.mjs` rather than extending `check-runtime-decoupling.mjs` — both walk the same import graph but assert different invariants.
- [ ] Add a one-line `sideEffects`-style note to `docs/PUBLISHING.md` under the "Verifying the published artifacts" subsection: both `olonjs-core.js` and `olonjs-core-runtime.js` must be colocated for the full bundle to load.
- [ ] Update `docs/ARCHITECTURE.md` §"Build and Distribution Topology" with a paragraph clarifying that the full bundle imports the runtime as an external sibling, not as inlined source. Corrects the implicit reading of ADR-0009 that the two bundles are independent.
- [ ] Add a smoke test in CI that boots `apps/olonjs.io` with the production build, navigates to `/admin`, and asserts that the StudioStage renders at least one section without an `EngineErrorBoundary` fallback. The bug this ADR fixes was invisible to current CI; a regression test prevents recurrence.
- [ ] Update `apps/olonjs.io`'s `deploy-landing.yml` workflow to also exercise an offline `/admin` path (built but not deployed) so the dual-bundle topology is verified on every push that touches `packages/core/**`.
- [ ] Re-evaluate Alternative B (single Vite build with shared chunks) if a third subpath is introduced or if more than four singleton entries accumulate. The threshold for migration is roughly: more than seven singleton entries in `SINGLETON_RUNTIME_MODULES`, a need for nested subpaths (e.g. `@olonjs/core/runtime/forms`), or a future Rollup version that fixes the order-sensitive dts rollup behavior in `vite-plugin-dts` (which would unblock Alternative B's natural ordering).
- [ ] Silence the eight UMD `output.globals` warnings if and when a real `<script>`-tag consumer of `@olonjs/core` emerges. Until then the warnings are correct (UMD does not have a sensible global name for an externalized internal module) and the noise is acceptable.

## Open Points

- Whether to keep `themeManager` as a singleton stored in `runtime-entry`, or refactor it to live entirely inside React state (returned from a hook). Keeping it as a singleton is the lowest-risk path now; refactor is a separate ADR if it proves limiting.
- Whether the four singleton files listed in `SINGLETON_RUNTIME_MODULES` are exhaustive. The 2026-05-10 audit was empirical (`grep` for `createContext` and module-scope identity sources reachable from `runtime-entry.ts`); if a future contributor adds a context or singleton elsewhere in `runtime/` or `studio/` shared paths, it would need to be added to the list. The follow-up #1 boundary check is the durable safeguard.

## References

- ADR-0009 — original split decision; this ADR amends, does not supersede.
- ADR-0011 — `sideEffects: false` for tree-shaking; orthogonal to this ADR but related (both shape what reaches tenant bundles).
- `packages/core/src/index.ts` — full entry that currently barrel-re-exports `./runtime`.
- `packages/core/src/runtime-entry.ts` — runtime entry (106 lines) that this ADR promotes to the singleton boundary.
- `packages/core/vite.config.ts` — full bundle build config; primary refactor target.
- `packages/core/vite.config.runtime.ts` — runtime bundle build config; unchanged by this ADR but documented for completeness.
- `packages/core/scripts/build-dual.mjs` — orchestrator; build order needs to invert.
- `packages/core/scripts/check-runtime-decoupling.mjs` — existing boundary check; complemented by the singleton check proposed in §4.
- Browser console capture 2026-05-10 (`localhost:5173/admin`, dev build of `apps/olonjs.io`) — diagnostic stack showing simultaneous loading of `olonjs-core.js:4109` and `olonjs-core-runtime.js:551`.
- [Rollup `output.paths` documentation](https://rollupjs.org/configuration-options/#output-paths).
- [Vite library mode + multiple entries](https://vite.dev/guide/build.html#library-mode).
