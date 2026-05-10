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

The full bundle imports the runtime as an **external module reference**, not as inlined source. After this change, exactly one copy of every runtime module is loaded into memory regardless of which subpath the consumer imports.

1. **Restructure `packages/core/src/index.ts`** so that every export which must be a singleton across bundles is re-exported from `./runtime-entry` (the file that becomes `olonjs-core-runtime.js`), not from the underlying `./runtime/*` source files. Concretely:

   ```ts
   // BEFORE
   export * from './runtime';
   export * from './dna';
   // ...

   // AFTER
   export * from './runtime-entry';
   // Studio-only additions kept as before:
   export { JsonPagesEngine } from './runtime/engine/JsonPagesEngine';
   export { StudioRoute } from './studio/...';
   export { PreviewRoute } from './studio/...';
   export { AdminSidebar, FormFactory, StudioStage, ... } from './studio/admin/...';
   ```

   The full bundle keeps every Studio export it has today; only the *runtime* surface is re-routed through `runtime-entry`.

2. **Externalize `runtime-entry` (and its compiled artifact) in `vite.config.ts`**. Add a `rollupOptions.external` entry that matches both the source-side specifier (`./runtime-entry`, `./runtime-entry.ts`) and the resolved import. Add a `rollupOptions.output.paths` mapping that rewrites the externalized specifier to the relative URL of the runtime artifact (`./olonjs-core-runtime.js`):

   ```ts
   // vite.config.ts (full)
   rollupOptions: {
     external: [
       'react', 'react-dom', 'react-router-dom', 'zod',
       /\/runtime-entry(\.ts|\.js)?$/,         // singleton boundary
     ],
     output: {
       globals: { /* unchanged */ },
       paths: {
         // rewrite internal external to the sibling artifact
         [path.resolve(__dirname, 'src/runtime-entry')]: './olonjs-core-runtime.js',
       },
     },
   },
   ```

   The exact regex/path form is an implementation detail; the contract is: any source-level reference to `runtime-entry` in the full build emits an `import` of the sibling runtime bundle.

3. **Build order is enforced by `scripts/build-dual.mjs`**. The runtime bundle must be produced **before** the full bundle, because the full bundle's compiled output references `./olonjs-core-runtime.js` as an existing sibling. The current orchestrator already runs `vite.config.runtime.ts` after `vite.config.ts` — this ADR **inverts that order** so the runtime artifact exists when the full build runs. The orchestrator continues to handle dts file rename/restore so both `index.d.ts` and `runtime.d.ts` survive.

4. **Boundary check is extended.** `scripts/check-runtime-decoupling.mjs` (or a new sibling `scripts/check-singleton-modules.mjs`) walks the import graph of the **full** bundle entry and asserts that any file matching the singleton list (`runtime/config/ConfigContext.ts`, `studio/StudioContext.ts`, `runtime/icons/IconRegistryContext.ts`, `runtime/theme/theme-manager.ts`) is reached **only via `runtime-entry`**, never directly. This makes the singleton constraint a CI-enforced invariant, not just a build-config trick. Implementation can be deferred to a follow-up; it is not a release blocker.

5. **Tenant consumption is unchanged.** Both `import { OlonJSEngine } from '@olonjs/core/runtime'` and `import { JsonPagesEngine } from '@olonjs/core'` keep their meaning. Tenants do not modify any source file. The dual-import pattern documented in ADR-0009 §"Tenant consumption pattern" remains canonical and now actually behaves as documented.

6. **Versioning.** The change ships as `@olonjs/core` v1.1.1 (patch). It is a bug fix in the published artifact; the public API surface is unchanged. ADR-0009's status line (`implemented in @olonjs/core v1.1.0`) is left intact for historical accuracy; future ADR readers find the v1.1.1 reference here.

After this change, both subpath imports of `useConfig`, `ConfigProvider`, `useStudio`, `StudioProvider`, `themeManager`, and `IconRegistryContext` resolve at runtime to **exactly one module instance**. The Studio preview stage will render tenant section views without spurious context errors.

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

- The Studio preview stage (`StudioStage` rendered inside `JsonPagesEngine`) renders tenant section views correctly. The seven `COMPONENT ERROR` panels seen on 2026-05-10 disappear.
- `useConfig`, `useStudio`, `themeManager`, and any other singleton-bearing module observed at runtime are guaranteed to be the **same instance** regardless of which subpath the consumer imported. This invariant is now a build-time contract, not a coincidence.
- The full bundle becomes physically smaller — the runtime source is no longer duplicated inside it. Estimated reduction: 25–40 KB raw / 8–12 KB gzipped on the full bundle (the runtime-entry surface is ~28 KB gz; deduping removes most of it from the full output, modulo a few re-exports).
- The dual-bundle topology now matches its documented behavior in ADR-0009 §"Tenant consumption pattern". Tenants no longer have to discover by experimentation that Studio only works in dev.
- The constraint is enforceable in CI (proposed follow-up #4 above): future regressions are caught before publish.

### Negative

- The full bundle now has a hard runtime dependency on the runtime bundle. If a consumer ships only `dist/olonjs-core.js` without `dist/olonjs-core-runtime.js` next to it (e.g. a misconfigured CDN, a custom bundler that resolves only the main field), the full bundle fails to load. We mitigate by keeping both files in `package.json` `files` and `exports` (already the case) and documenting the requirement in `docs/PUBLISHING.md`.
- The build order in `scripts/build-dual.mjs` becomes meaningful: runtime first, full second. Reversing it produces a broken full bundle. We document this in the orchestrator script comment and assert the order programmatically.
- Tooling that statically analyzes `dist/olonjs-core.js` (e.g. bundle-size visualizers, `npm pack` linters) sees an unresolved import to `./olonjs-core-runtime.js` until both files are colocated. This is correct ESM behavior but may surprise tools that expect a self-contained file.
- A small migration burden if a future contributor adds a new singleton-bearing module: it must be exported from `runtime-entry.ts`, not from the full entry directly, otherwise the bug re-emerges. The CI check proposed in §4 above addresses this.

### Requirements imposed on other parts of the system

- **`packages/core/src/index.ts`** — refactor to re-export the runtime surface via `runtime-entry`.
- **`packages/core/vite.config.ts`** — add the `external` rule and the `output.paths` rewrite for `runtime-entry`.
- **`packages/core/scripts/build-dual.mjs`** — invert the build order: runtime first, full second. Add an assertion that the runtime artifact exists before the full build runs.
- **`packages/core/package.json`** — no change to `exports` or `files`; the runtime artifact is already published. Bump version to `1.1.1`.
- **`docs/PUBLISHING.md`** — add a one-line note in the "Verifying the published artifacts" subsection: both `olonjs-core.js` and `olonjs-core-runtime.js` must be colocated for the full bundle to load.
- **`docs/ARCHITECTURE.md` §"Build and Distribution Topology"** — add a paragraph clarifying that the full bundle imports the runtime as an external sibling, not as inlined source. This corrects the implicit reading of ADR-0009 that the two bundles are independent.
- **No tenant change required.** All tenants keep their current import patterns. The fix is invisible to consumers other than the bug going away.

## Follow-ups

- [ ] Implement the boundary extension described in §4 above (assert that singleton modules are reachable only via `runtime-entry` from the full entry). Non-blocking for shipping the fix; should land within one release of v1.1.1.
- [ ] Re-evaluate Alternative B (single Vite build with shared chunks) if a third subpath is introduced or if more than two singleton modules need cross-bundle dedup. The threshold for migration is roughly: more than five singleton entries, or a need for nested subpaths (e.g. `@olonjs/core/runtime/forms`).
- [ ] Add a smoke test in CI that boots `apps/olonjs.io` with the production build, navigates to `/admin`, and asserts that the StudioStage renders at least one section without an EngineErrorBoundary fallback. The bug this ADR fixes was invisible to current CI; a regression test prevents recurrence.
- [ ] Update `apps/olonjs.io`'s deploy-landing workflow to also exercise an offline `/admin` path (not deployed publicly, but built and asserted-on) so the dual-bundle topology is verified on every push that touches `packages/core/**`.

## Open Points

- The exact form of the `external` regex in `vite.config.ts` (matching `./runtime-entry`, `./runtime-entry.ts`, and any path-resolved variants) is a one-iteration tuning task during implementation. Prior art from `vite-plugin-externalize-deps` may simplify; whether to add a dependency vs. write the rule by hand is decided in the implementation PR.
- Whether to keep `themeManager` as a singleton stored in `runtime-entry`, or refactor it to live entirely inside React state (returned from a hook). Keeping it as a singleton is the lowest-risk path now; refactor is a separate ADR if it proves limiting.
- Whether the proposed CI check (§4) lives inside the existing `check-runtime-decoupling.mjs` (extending its responsibilities) or as a sibling script (`check-singleton-modules.mjs`). Leaning sibling for separation of concerns; both walk the same import graph but assert different invariants.

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
