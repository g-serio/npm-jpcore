# ADR-0009: Split Studio from `@olonjs/core` runtime via `/runtime` subpath export

## Status

Accepted (2026-05-09) — implemented in `@olonjs/core` v1.1.0. Both bundles publish via `npm run build -w @olonjs/core` (`scripts/build-dual.mjs`). Tenants `apps/olonjs.io` and `apps/tenant-alpha` migrated to `@olonjs/core/runtime` for the visitor path with `JsonPagesEngine` lazy-loaded on `/admin`. Boundary check (`packages/core/scripts/check-runtime-decoupling.mjs`) enforced via `npm run test:boundary`. Production deploy of `apps/olonjs.io` confirms the decoupled artifacts on `gh-pages`.

## Date

2026-05-08 (proposal) · 2026-05-09 (acceptance)

## Scope

`@olonjs/core` package public surface. Adds an additive `@olonjs/core/runtime` subpath export that ships a runtime-only bundle (no Studio admin UI). The existing `@olonjs/core` import surface stays byte-for-byte unchanged. Triggered by [ADR-0008](./ADR-0008-perf-roadmap-to-mobile-90.md) Phase B; implementation is tracked in [docs/plans/core-studio-split.md](../plans/core-studio-split.md).

This ADR locks the architectural decisions D1–D8. The implementation plan executes against them.

## Context

After [ADR-0007](./ADR-0007-section-lazy-load-and-heavy-dep-budget.md)'s tenant-only interventions and Phase A of ADR-0008 (font media-swap, image resize, cache headers), the visitor-facing bundle of `apps/olonjs.io` is expected to land at ~395 KB gzipped, dominated by `@olonjs/core` itself. Inside that package, the **Studio editor** (~3,870 LOC under `packages/core/src/studio/`) is unconditionally bundled even though visitors never use it — Studio is the visual editor that runs at `/admin` and `/admin/preview`.

Discovery against the current codebase (`packages/core/src/`):

- `index.ts` already exposes `runtime`, `studio`, `kernel`, `webmcp`, `contract` as conceptual namespaces; an inline comment flags this as "the future split". Today the same file then re-exports everything flat for legacy compatibility, forcing one bundle.
- The engine in `runtime/engine/JsonPagesEngine.tsx` imports from `studio/admin/` directly: `IconRegistryContext`, `admin-skin.css?inline`, plus three studio-only routes (`StudioRoute`, `PreviewRoute`, plus `StudioProvider` from `VisitorRoute`). `runtime/rendering/SectionRenderer.tsx` imports `useStudio` to gate the IDAC overlay.
- `package.json` `exports` has only `"."` and `"./package.json"`. Adding `"./runtime"` is straightforward.
- Build is Vite library mode producing a single `dist/olonjs-core.js`. Two-target build is supported by Vite's `build.lib.entry` array.

Two known consumers exist, both inside this monorepo:

- `apps/tenant-alpha` — DNA reference tenant; auto-syncs from the `@olonjs/stack` process. Continues to import `JsonPagesEngine` from `@olonjs/core` (full bundle). Zero migration impact.
- `apps/olonjs.io` — public marketing site. Manually updated as part of this work to import `OlonJSEngine` from `@olonjs/core/runtime` for visitor paths and `JsonPagesEngine` from `@olonjs/core` for `/admin` paths.

No external consumers exist — this is a controlled release.

The non-negotiable constraints:

1. **No breaking change** on `@olonjs/core` (`.`) imports. tenant-alpha must keep working without code edits.
2. **Studio functionality is preserved** identically. Inspector, drag-reorder, save flows (Local / Hot Cloud / Save2Repo) must round-trip without regression.
3. **The split must be physical**, not an after-bundle dynamic split — the visitor bundle should not contain Studio source, even as a lazily-loaded chunk.

## Decision

We commit to eight architectural choices, D1–D8.

### D1 — Two distinct bundles, not one bundle with lazy chunks

The split happens at the **package boundary**. The package ships:

- `dist/olonjs-core.js` — full surface (runtime + Studio); imported via `@olonjs/core`. Existing tenants unchanged.
- `dist/olonjs-core-runtime.js` — runtime-only; imported via `@olonjs/core/runtime`. New.

A consumer's bundler resolves the import path to the corresponding bundle. Visitors of `apps/olonjs.io` never receive a single byte of Studio source, not even as a deferred chunk.

### D2 — Subpath export, single package (not two npm packages)

We do not publish `@olonjs/core-runtime` as a separate npm package. We add a `package.json` `exports` map:

```jsonc
{
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/olonjs-core.js",
      "require": "./dist/olonjs-core.umd.cjs"
    },
    "./runtime": {
      "types": "./dist/runtime.d.ts",
      "import": "./dist/olonjs-core-runtime.js"
    },
    "./package.json": "./package.json"
  }
}
```

Single source repository, single version, single CI. The tradeoff (slightly more complex `vite.config.ts`) is a one-time cost.

### D3 — `StudioContext`, `useStudio`, `StudioProvider`, `events.ts` and `IconRegistryContext` stay in the runtime entry

These are the smallest pieces of "Studio" surface:

- `StudioContext.tsx` (with `useStudio` and `StudioProvider`) — runs in **visitor** mode too, mounted by `VisitorRoute` so `useStudio()` returns a no-op shape outside `/admin`. Removing it would require restructuring `SectionRenderer`'s overlay logic.
- `events.ts` — exports `STUDIO_EVENTS` constants. Used by both visitor and admin code paths.
- `IconRegistryContext.tsx` — currently lives at `studio/admin/IconRegistryContext.tsx` (8 LOC). Functionally a runtime concern (icons consumed by section schemas at render time, not just by the editor). Moves to `runtime/icons/` per D5.

These pieces stay in **both** bundles. They total ~150 LOC and are cheap.

### D4 — Three engine entry points, factored around a shared `JsonPagesEngineCore`

```
runtime/engine/
  ├── JsonPagesEngineCore.tsx    NEW — shared composition root; provider tree,
  │                                    router setup, theme bootstrap. Routes
  │                                    are passed in by the caller as <Route>
  │                                    children.
  ├── JsonPagesEngine.tsx        REFACTORED — wraps Core, mounts visitor +
  │                                    admin + preview routes. Public symbol
  │                                    name unchanged (back-compat).
  └── OlonJSEngine.tsx           NEW — wraps Core, mounts visitor route only.
                                       Has zero transitive imports from
                                       studio/admin/ or studio/orchestration/.
```

`JsonPagesEngineCore` is internal and never exported.
`JsonPagesEngine` is the existing public symbol from `@olonjs/core` — kept identical in name and signature.
`OlonJSEngine` is the new public symbol from `@olonjs/core/runtime`.

Both public engines accept the same `JsonPagesConfig` prop. They differ only in which routes they register. If a visitor navigates to `/admin` on a runtime-only build, the request falls through to `DefaultNotFound` — correct behavior for a public site that has no editor.

### D5 — `IconRegistryContext` relocates from `studio/admin/` to `runtime/icons/`

`IconRegistryContext.tsx` (8 LOC) is misplaced. The engine imports it directly; it has no Studio dependencies. Moving it cleans the import graph so `runtime/` no longer reaches into `studio/admin/`.

A re-export shim is left at the old path so any external consumer that imports the symbol directly continues to work. The shim is removed in a future major version.

### D6 — `admin-skin.css` stays in `studio/admin/`; runtime never imports it

The Studio admin skin (current path: `packages/core/src/studio/admin/admin-skin.css`) is a Studio asset. Today `JsonPagesEngine.tsx` imports it as `?inline` and injects it as a `<style>` tag at startup, regardless of route — even visitors get the CSS string in their HTML.

After the split:

- The CSS file location is unchanged (stays in `studio/admin/`).
- The full engine (`JsonPagesEngine`) keeps the inline import and injection — admin users get the skin as today.
- The runtime engine (`OlonJSEngine`) does not import the CSS at all. Visitors get no admin-skin CSS in the document. If any visitor-mode element relied on these rules, the relevant rules are migrated to `runtime/`-owned styles or to the tenant's own `index.css` during Task 1.2 of the plan.

This is the cleanest boundary: Studio assets live with Studio code.

### D7 — Public API contract: additive only

`@olonjs/core` exports stay byte-for-byte identical. No removal, no renames. `JsonPagesEngine`, `JsonPagesConfig`, `JsonPagesEngineProps`, all existing namespace exports — unchanged.

`@olonjs/core/runtime` exports a strict subset, all already-existing symbols re-grouped, **plus** the new `OlonJSEngine`:

- `OlonJSEngine` (new function)
- `useConfig`, `ConfigProvider`, `type ConfigContextValue`
- `resolveAssetUrl`, `themeManager`
- `STUDIO_EVENTS`, `useStudio`, `StudioProvider`
- `JsonPagesConfig`, `JsonPagesEngineProps` (types — not renamed)
- `DefaultNotFound`, `normalizeBasePath`, `withBasePath`

`@olonjs/core` ships as **`1.1.0`** — additive subpath export = SemVer minor.

### D8 — ESM-only for `@olonjs/core/runtime`; `@olonjs/core` keeps ESM + CJS

The runtime entry is consumed exclusively by modern bundlers (Vite, Webpack 5+, esbuild) that resolve ESM natively. There is no `require()` use case for React component code. Skipping the CJS/UMD build target for `/runtime` simplifies the Vite config and reduces the package tarball size.

The main `.` entry continues to ship both ESM and CJS for back-compat with existing consumers and for tooling that hits `require.resolve('@olonjs/core')`.

## Alternatives Considered

### A — Single bundle with `React.lazy(() => import('@olonjs/core/studio'))` at the engine level

- **Pros:** No build pipeline change; single output file; tenants don't need to learn a new import path.
- **Cons:** Studio source still lives in the package and in the consumer's `node_modules`. Vite would chunk it during the consumer's build, so the visitor's first paint wouldn't pay for it — but the bytes still ship to the user's machine on demand if they navigate to `/admin`. More importantly: Studio code remains in the tenant's `node_modules` and may be picked up by any tool that scans the package (typecheck, lint, security audit) regardless of whether the visitor build references it. The split is only conceptual, not physical.
- **Rejected because:** the goal is a physical removal of Studio bytes from visitor builds. Lazy chunks defer the cost; they do not eliminate it.

### B — Two separate npm packages: `@olonjs/core` + `@olonjs/core-runtime`

- **Pros:** Maximum isolation; each package versions independently; consumers can pin runtime to a different release than full.
- **Cons:** Two packages to publish, version-bump, and CHANGELOG. Two `peerDependencies` lists to keep in sync. Two TypeScript build outputs in two directories. The version drift between the packages becomes a hazard (e.g. `@olonjs/core@1.2` + `@olonjs/core-runtime@1.1` shipped together is a class of bugs we don't want). For two known consumers in one monorepo this is overkill.
- **Rejected because:** the win (independent versioning) does not justify the operational cost. A single package with a subpath export gives us the bundle separation we need without the multi-package burden.

### C — Studio as a separate side package (`@olonjs/studio`) consumed only by tenants that want editing

- **Pros:** Cleanest mental model — runtime is the default, Studio is opt-in at the package level.
- **Cons:** Requires separating the source code into two packages (large refactor), coordinating Cross-package types, and changes the import patterns of every existing tenant including tenant-alpha (`import { AdminSidebar } from '@olonjs/studio'` instead of `from '@olonjs/core'`). Breaking change. tenant-alpha would need an update synced through the DNA process; olonjs.io would need code edits. Much more work for the same end state.
- **Rejected because:** breaking change without proportional benefit. The subpath export achieves the same physical separation while preserving back-compat.

### D — Build-time tree-shaking via `sideEffects: false` and let consumer's bundler eliminate Studio

- **Pros:** No `vite.config.ts` change; no new export entry; theoretically Vite/Webpack should drop Studio when the tenant doesn't import any Studio symbol.
- **Cons:** Tree-shaking across published packages is historically unreliable. CSS imports (`?inline`), context creation, and side-effecting top-level code in Studio modules typically defeat tree-shaking. Vite emits a single `olonjs-core.js` from the package's library build; any subsequent tree-shake by the tenant is best-effort. Empirically the visitor bundle for `apps/olonjs.io` today is 395 KB gzipped — tree-shaking is clearly not eliminating Studio.
- **Rejected because:** unreliable in practice. The only reliable way to keep bytes out of the visitor bundle is to ship them in a separate physical bundle that the visitor build does not import.

### E — SSR/SSG migration that bypasses the JS bundle problem entirely

- **Pros:** HTML-first rendering eliminates the JS bundle as the LCP gate; potentially largest possible win.
- **Cons:** Months of work; touches the engine deeply; rethinks Studio hydration; out of scope of a focused perf project.
- **Rejected because:** disproportionate. The subpath split is sufficient to clear 90 mobile per ADR-0008's modeling.

## Consequences

### Positive

- Visitor bundle of `apps/olonjs.io` drops to a target ≤ 250 KB gzipped (from ~395 KB).
- Mobile Lighthouse Performance expected to clear 90 (combined with ADR-0008 Phase A wins).
- `@olonjs/core` public API stays byte-identical for tenant-alpha and any external consumer that doesn't opt into the new entry. Zero forced migration.
- `runtime/` becomes formally decoupled from `studio/admin/` at the source level — verified by a CI check (`madge` boundary script). Future refactors of Studio cannot accidentally pull Studio into the visitor path.
- The package gains a clean architectural boundary that makes future evolution easier (e.g. shipping a third entry like `@olonjs/core/agent` for AI-only consumers).

### Negative

- Slightly more complex `vite.config.ts` (two `build.lib.entry` targets, dts plugin called twice or once with multi-entry config).
- Slightly larger published tarball (two JS files instead of one), but still tiny in absolute terms (the runtime bundle is much smaller than the full bundle, and the full bundle is essentially the same size as today).
- Tenants now have two import paths to choose between. Documentation must clarify when to use which. Default recommendation: visitor-heavy public sites use `@olonjs/core/runtime`; sites that mount `/admin` on the same bundle entry use `@olonjs/core`.
- The `JsonPagesEngineCore` extraction (D4) creates a third internal engine file. Maintenance of three closely-related files is a small ongoing cost. Mitigation: `JsonPagesEngineCore` carries ~90% of the logic; the two siblings are thin shells.

### Requirements imposed on other parts of the system

- **`packages/core` build pipeline**: extended to two output files. Must externalize React, ReactDOM, zod, react-router-dom (peer deps) consistently across both bundles.
- **`packages/core` types**: `vite-plugin-dts` (or post-build script) must produce `dist/runtime.d.ts` for the new entry alongside `dist/index.d.ts` for the existing entry.
- **CI for `packages/core`**: gains a new check that fails if any file under `runtime/` (excluding the explicit integration point `JsonPagesEngine.tsx`) imports from `studio/admin/` or `studio/orchestration/`. Implemented via `madge` or a small custom script.
- **Tenant `apps/olonjs.io`**: switches `App.tsx` to import `OlonJSEngine` from `@olonjs/core/runtime` for visitor paths, `JsonPagesEngine` from `@olonjs/core` for admin paths. Changes the `size-limit` budget on the visitor entry to `≤ 250 KB gzipped`.
- **Tenant `apps/tenant-alpha`**: no code change required. Auto-update through the DNA process picks up `1.1.0`. Smoke-tested as part of release verification.
- **Specs (`specs/olonjsSpecs_V_1_6.md`)**: should mention the runtime/full split as the canonical pattern for performance-sensitive tenants. Non-blocking; can land in a v1.7-patch revision after this work ships.

## Follow-ups

- [ ] Implementation execution: see [docs/plans/core-studio-split.md](../plans/core-studio-split.md) for the 14-task breakdown across Phases 0–4.
- [ ] After Phase 4 verification, promote ADR-0007, ADR-0008, ADR-0009 from `Proposed` to `Accepted`. Record empirical Lighthouse scores in each ADR's status note.
- [ ] If any visitor-mode CSS rule turns out to live in `admin-skin.css` (Task 1.2 investigation), migrate the affected rules to a runtime-owned stylesheet or to the tenant's `index.css` before the runtime engine ships. Document the migration inline.
- [ ] Consider adding a `@olonjs/core/agent` subpath export in a future ADR — same pattern, optimized for Web MCP–only consumers (no DOM rendering at all). Dormant until use case appears.
- [x] **Document the optimization activation pattern as a tenant-zone guide** (added 2026-05-10, refined to opt-in framing). The ADR's §"Tenant consumption pattern" originally showed only the `App.tsx` lazy gate, which can read as the entire integration. Activating an existing tenant (`radice.olon.it`, 2026-05-10) made it concrete that the lazy split is one piece of a multi-file mechanism. When a tenant chooses to opt in to the split (visitor lean + Studio admin lazy), three pieces align together: (a) the `App.tsx` lazy gate; (b) dual `declare module` augmentation in `types.ts` plus `export * from '@olonjs/core/runtime'`; (c) every other tenant source file imports statically from `@olonjs/core/runtime`. The opt-in framing matters: a tenant that doesn't need the visitor optimization can keep the pre-split layout and pay ~100 KB gz extra on the visitor — nothing breaks. What does break the optimization, when chosen, is a single residual static `from '@olonjs/core'` anywhere in the tenant graph: Vite's static edge wins over the dynamic `lazy()` edge and the full bundle is inlined into the visitor main chunk. This is a mechanical consequence of how Rollup builds chunk graphs, not a project rule. Tenant-zone guide with the reasoning, the activation pattern, and the smoke tests now lives in [`apps/tenant-alpha/CLAUDE.md`](../../apps/tenant-alpha/CLAUDE.md).

## Open Points

- None at the time of writing. Q1–Q4 from the implementation plan have been resolved (see plan's "Resolved questions" section). Remaining detail-level decisions (e.g. exact location of `IconRegistryContext`, precise dts emission strategy) are scoped to individual implementation tasks and do not require ADR-level resolution.

## References

- [ADR-0007](./ADR-0007-section-lazy-load-and-heavy-dep-budget.md) — section lazy-loading; this ADR extends the bundle-budget contract to the package-internal level.
- [ADR-0008](./ADR-0008-perf-roadmap-to-mobile-90.md) — performance roadmap; this ADR is the formal commitment to its Phase B.
- [docs/plans/core-studio-split.md](../plans/core-studio-split.md) — implementation plan executing against this ADR.
- `packages/core/src/index.ts` — current flat re-exports (legacy compat) plus pre-existing namespace exports flagged for "the future split".
- `packages/core/src/runtime/engine/JsonPagesEngine.tsx` — the engine refactored in Task 1.3 of the plan.
- `packages/core/src/studio/` — Studio source, untouched in physical location.
- `apps/olonjs.io/src/App.tsx` — tenant integration point updated in Task 3.1 of the plan.
