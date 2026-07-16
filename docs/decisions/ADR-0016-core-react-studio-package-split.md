# ADR-0016: Split `@olonjs/core` into three packages — `core` (pure engine), `react` (rendering bindings), `studio` (editor UI)

## Status

Proposed (2026-07-16)

## Date

2026-07-16

## Scope

`packages/core` public surface. Replaces the single package with three npm workspace packages: `packages/core` (pure TypeScript engine, zero React), `packages/react` (React rendering bindings), `packages/studio` (React + Radix editor UI, depends only on `packages/core`). Radical, versioned breaking change — no back-compat shim for the current flat `@olonjs/core` import surface. Affects `apps/tenant-alpha`, `packages/cli` templates, `packages/stack`. Full file-by-file verified boundary analysis: [`docs/ideas/core-react-studio-package-split.md`](../ideas/core-react-studio-package-split.md).

## Context

`@olonjs/core` today ships as one package with two subpath bundles (`.` full, `./runtime` visitor-only), per [ADR-0009](./ADR-0009-core-studio-split-via-runtime-subpath.md), plus a singleton-externalization mechanism sharing React Context identity across both bundles ([ADR-0012](./ADR-0012-externalize-runtime-from-full-bundle.md)). That split optimizes for one goal: visitor bundle size, with a hard no-breaking-change constraint.

**ADR-0009 already considered and rejected this exact direction** (its "Option C — Studio as a separate side package"), for a reason that was correct at the time: *"breaking change without proportional benefit... the subpath export achieves the same physical separation while preserving back-compat."* That rejection stands for ADR-0009's objective. It does not stand for this ADR's objective, which is different:

- ADR-0009 optimized for **visitor bundle size** under a **no-breaking-change** constraint. A subpath export fully satisfies that.
- This ADR optimizes for **framework-agnosticism and zero-React consumption of the engine contract** — a goal a subpath export cannot satisfy, because `peerDependencies` are declared once per `package.json`. There is no way for `@olonjs/core`'s single manifest to let a Node build script or `jsonpages-platform` install the engine's types/Zod schemas/resolvers without also declaring `react`, `react-dom`, `@radix-ui/*`, and `@dnd-kit/*` as peers. Verified concretely: `apps/tenant-alpha/scripts/bake.mjs` and `generate-llms-txt.mjs` already import `resolvePageMatchFromRegistry`, `resolvePublicPageDocument`, `webmcp` from `'@olonjs/core'` inside plain Node scripts, pulling in the full React/Radix/dnd-kit dependency graph for zero React usage.

Discovery against the current codebase (`packages/core/src/`), verified file-by-file across the whole tree (not inferred from folder names):

- The current domain folders (`contract/`, `runtime/`, `studio/`, `webmcp/`, `dna/`) were drawn along the ADR-0009 bundle-splitting axis (visitor vs. admin), not along a "pure TypeScript vs. React" axis. Both `runtime/` and `studio/` mix pure-TS files with React files: `runtime/assets/asset-resolver.ts`, `runtime/theme/theme-manager.ts`, `runtime/url/base-path.ts`, `runtime/engine/route-utils.ts`, `runtime/engine/public-page-document.ts` are zero-React despite living under `runtime/`; `studio/orchestration/section-ops.ts`, `studio/admin/selection-path.ts`, `studio/events.ts` (`STUDIO_EVENTS`) are zero-React pure logic despite living under `studio/`. `dna/lib/OlonFormsContext.ts` is the inverse false negative: `.ts` extension, but imports `createContext` from React.
- `src/index.ts` already carries a "Conceptual surfaces for the future split" comment above namespace re-exports (`contract`, `kernel`, `runtime`, `studio`, `webmcp`) — the split direction was anticipated in-code, never executed.
- Grepping every import in `studio/` against `runtime/` found exactly 3 friction points that would have blocked "Studio depends only on core" if left unaddressed: (1) `studio/admin/AdminSidebar.tsx` calls `useConfig()` for `schemas`, which `StudioRoute` already receives as its own prop; (2) `studio/admin/IconRegistryContext.tsx` is a re-export shim whose own code comment already says *"kept so existing imports keep working... to remove this shim... deferred: removal is a future major"* — this ADR is that major; (3) `studio/admin/PreviewEntry.tsx` imports `PageRenderer`/`themeManager` because it is the code that renders content **inside** the Stage iframe, not admin chrome.
- `StudioStage.tsx` (the actual Studio-side Stage component) was verified to import neither `PageRenderer` nor any rendering-runtime symbol — it only opens `<iframe src="/admin/preview/:slug">` and exchanges `postMessage`. The React-rendering dependency lives entirely in `PreviewEntry.tsx`, a different file, which the fix above relocates.
- `studio/StudioContext.tsx` (`StudioProvider`/`useStudio`) is used directly by `runtime/rendering/SectionRenderer.tsx`, `runtime/engine/VisitorRoute.tsx`, and `runtime/engine/StudioRoute.tsx` — i.e. required by the rendering pipeline itself (it gates IDAC overlay injection), independent of whether the Studio admin package is even installed. It is a rendering-mode flag, not admin-chrome UI, despite living under `src/studio/` today.
- `runtime/engine/StudioRoute.tsx` (~850 lines) is almost entirely Studio orchestration logic (draft state, collections draft, WebMCP tool wiring, calls into `section-ops`) with zero use of `PageRenderer`/`SectionRenderer`/`ConfigContext` — but it wraps itself in `<ThemeLoader><StudioProvider>`, both `@olonjs/react`-package components.
- Both existing consumers of the engine are inside this monorepo: `apps/tenant-alpha` (reference tenant, no automated e2e — its `tsc && vite build` is the closest thing to an integration test) and `packages/cli`'s generated template (`assets/templates/alpha/src_tenant.sh`), which mirrors tenant-alpha's imports 1:1. No external consumer exists — this is a controlled release, same as ADR-0009's context.

What we do not yet know: whether splitting `theme-manager.ts` into a pure logic half (destined for `@olonjs/core`) and a singleton/publish half (destined for `@olonjs/react`) breaks the ADR-0012 cross-bundle React-identity-sharing mechanism, and whether `@olonjs/react`'s dynamic `import('@olonjs/studio')` behaves as a clean code-split boundary across a real package boundary (ADR-0009's split was intra-package). Both are scoped as pre-implementation spikes in Follow-ups, not open architectural decisions — the boundary and the dependency direction are decided regardless of their outcome; only the exact mechanics of the theme-manager split or the bundler config would need adjusting if a spike surfaces a problem.

## Decision

We commit to eight architectural choices, D1–D8.

### D1 — Three physical npm packages, not subpath exports

Unlike ADR-0009's D2 (single package, subpath exports), this split happens at the **package boundary**: `packages/core`, `packages/react`, `packages/studio`, each with its own `package.json`, `peerDependencies`, `vite.config.ts`, `tsconfig.json`. This is the only structure that lets a consumer install `@olonjs/core` without `react` ever entering its dependency tree.

### D2 — Dependency graph: two independent siblings under `core`, one directional edge between them

```
                    @olonjs/core
                   /            \
        @olonjs/studio      @olonjs/react
                   \            /
                    react → studio
         (one directional edge only, dynamic import)
```

`@olonjs/studio` depends **only** on `@olonjs/core` (plus generic `react`/`react-dom` as peer dependencies — Studio's UI is still built with React + Radix, it just never imports the `@olonjs/react` package). `@olonjs/react` depends on `@olonjs/core` (hard) and does a single dynamic `import('@olonjs/studio')` inside a thin admin-bridge component that composes `<ThemeLoader><StudioProvider mode="studio"><StudioRoute .../></StudioProvider></ThemeLoader>`. `@olonjs/studio` is an optional peer dependency of `@olonjs/react`; a visitor-only/SSG consumer that never renders `/admin` never installs it.

This reverses ADR-0009's rejection of "Studio as a separate side package" (its Option C) precisely because the objective changed: ADR-0009 needed to avoid a breaking change; this ADR explicitly accepts one (D7) in exchange for a capability a subpath structurally cannot provide.

### D3 — Boundary criterion is "does this file import React", not folder location or file extension

The three packages are populated by tracing actual imports, not by moving folders wholesale:

- `@olonjs/core` gets: `contract/*` (kernel, types-engine, config-resolver, zod-schemas, webmcp-contracts), `webmcp/*`, `dna/lib/base-schemas.ts`/`cloudSaveStream.ts`/`deploySteps.ts`/`dna/types/deploy.ts`, `studio/events.ts` (`STUDIO_EVENTS` — shared vocabulary, not Studio-exclusive), `studio/orchestration/section-ops.ts` (pure mutation functions), `studio/admin/selection-path.ts` (pure, same domain as `webmcp`'s `applyValueAtSelectionPath`), the already-zero-React `runtime/` files listed in Context, `theme-manager.ts`'s logic half, and `lib/utils.ts` (`cn` — zero React import, fits the framework-agnostic criterion despite being UI-utility in nature).
- `@olonjs/react` gets: `runtime/engine/*` (`JsonPagesEngineCore`, `OlonJSEngine`, `JsonPagesEngine`, `VisitorRoute`, `EngineErrorBoundary`), `runtime/rendering/*`, `runtime/config/ConfigContext.tsx`, `runtime/icons/IconRegistryContext.tsx`, `runtime/theme/ThemeLoader.tsx` + `theme-manager.ts`'s singleton/publish half, `lib/DefaultNotFound.tsx`, `dna/lib/OlonFormsContext.ts`, plus (corrected from an earlier draft of the underlying idea doc) `studio/StudioContext.tsx` and `studio/admin/PreviewEntry.tsx`, and the admin-bridge component described in D2.
- `@olonjs/studio` gets: `studio/admin/*` (minus `selection-path.ts` and `PreviewEntry.tsx`) with `AdminSidebar` taking `schemas` as an explicit prop (D5), `studio/ui/*`, `studio/orchestration/useStudioPersistence.ts` and `useStudioSelectionState.ts`, and the relocated orchestration body of `StudioRoute.tsx` (D6).

### D4 — `theme-manager.ts` splits into a logic half and a singleton half

The pure token-flatten/read logic moves to `@olonjs/core`. The singleton/publish-to-CSS-DOM mechanism — the part ADR-0012 externalizes for cross-bundle React-identity sharing — stays in `@olonjs/react`. Validated by spike, see Follow-ups.

### D5 — `AdminSidebar` takes `schemas` as an explicit prop; the `IconRegistryContext` re-export shim is deleted

`AdminSidebar.tsx`'s only `@olonjs/react`-package dependency is `const { schemas } = useConfig()`. `StudioRoute` already receives `schemas` as its own prop (`StudioRouteProps.schemas`) — it is threaded through explicitly instead. `studio/admin/IconRegistryContext.tsx` is a re-export shim whose own comment already flags it as deferred cleanup for "a future major" — deleted, not migrated.

### D6 — `StudioRoute.tsx` splits into an orchestration body (moves to `@olonjs/studio`) and a thin bridge (stays in `@olonjs/react`)

The ~850-line orchestration body (draft state, collections draft, WebMCP tool wiring, `section-ops` calls) stops importing `ThemeLoader`/`StudioProvider` itself and relocates to `@olonjs/studio` as `StudioRoute`, receiving `mode="studio"` context from its caller. The `<ThemeLoader><StudioProvider>` wrapping moves to a thin admin-bridge component that stays in `@olonjs/react` and performs the dynamic `import('@olonjs/studio')`. `runtime/engine/PreviewRoute.tsx` needs no cross-package fix at all once `PreviewEntry` and `StudioContext` move to `@olonjs/react` — it becomes a same-package composition with zero dependency on `@olonjs/studio`.

### D7 — No backward-compatibility surface; radical, versioned breaking change

`@olonjs/core`'s current flat re-export surface (`export * from './kernel'`, etc.) is not preserved. Tenants pinned to `@olonjs/core@1.x` keep working untouched on that pinned version — this is accepted as the mechanism that makes the break safe, not a shim. `apps/tenant-alpha` (the only reference/test bed) is fully migrated to the new three-package imports as part of this work; there is no forced upgrade path for other tenants.

### D8 — `@olonjs/studio` never needs a per-framework port

Verified: `StudioStage.tsx` never renders tenant content directly (iframe + `postMessage` only, per TOCC v1.1's "Stage runs in an iframe so tenant CSS does not leak into Admin chrome"), and `FormFactory`/`AdminSidebar` are schema-driven (ECIP) — they introspect Zod `schemas`, never the tenant's actual `View.tsx` components or `ComponentRegistry`. A hypothetical future `@olonjs/vue` rendering binding would reuse `@olonjs/studio` as-is via the same single `import('@olonjs/studio')` edge shown in D2, needing only its own `PreviewEntry`/`PageRenderer` equivalent — never a `@olonjs/studio-vue` port. This is a consequence of D2's graph shape, not a separate mechanism.

## Alternatives Considered

### Option A — Extend ADR-0009's subpath model with a third `./contract` subpath

- **Pros:** No new packages to publish/version; smallest operational change; consistent with the existing pattern.
- **Cons:** `peerDependencies` are declared once per `package.json` — there is no way for a subpath to tell npm "this entry point does not need `react`." Any consumer installing `@olonjs/core` for the `./contract` subpath still gets `react`, `react-dom`, `@radix-ui/*`, `@dnd-kit/*` listed as peers of the package they installed.
- **Rejected because:** it cannot achieve this ADR's core objective (zero-React consumption of the engine), which is the entire reason this ADR exists rather than simply extending ADR-0009.

### Option B — Two packages: `@olonjs/core` (zero-React) and `@olonjs/react` (React runtime + Studio combined)

- **Pros:** Simpler graph (one dependency edge instead of two); fewer packages to coordinate; avoids the `AdminSidebar`/`StudioRoute`/`StudioContext`/`PreviewEntry` reclassification work in D3/D5/D6.
- **Cons:** Ties Studio's dependency footprint to `@olonjs/react`'s (including the ADR-0012 singleton-context mechanism), which is unnecessary — verified that Studio's only real couplings to `@olonjs/react` were three incidental misplacements, not a fundamental need. Forecloses D8's result (Studio reusable, unmodified, by any future rendering binding) since Studio would be permanently bundled with one specific rendering implementation.
- **Rejected because:** the marginal cost of the D3/D5/D6 fixes was small (3 verified friction points, all mechanical) against a real gain (D8).

### Option C — Linear chain `core ← react ← studio`

- **Pros:** Matches the naive assumption that Studio is "built on top of" the rendering runtime; requires no reclassification of `StudioContext.tsx`/`PreviewEntry.tsx`/`StudioRoute.tsx`.
- **Cons:** Verified false against the actual code: `StudioStage.tsx` (Studio's real Stage component) never imports rendering-runtime symbols at all; the only file that did (`PreviewEntry.tsx`) is not admin chrome, it is the renderer-in-an-iframe, and belongs with the rendering binding, not with Studio. Forcing a linear chain would have made every future rendering binding require its own Studio port — the opposite of D8.
- **Rejected because:** it does not match the codebase's actual coupling, and the sibling graph (D2) is strictly better once the actual coupling is traced correctly.

## Consequences

### Positive

- The engine (`@olonjs/core`) becomes installable and usable — types, Zod schemas, config resolver, pure orchestration, WebMCP contracts — by plain Node build scripts (`apps/tenant-alpha/scripts/bake.mjs`, `generate-llms-txt.mjs`) and by `jsonpages-platform` without pulling in React, Radix, or dnd-kit.
- `@olonjs/core`'s test suite for pure logic no longer needs `jsdom`/React Testing Library.
- A future second rendering binding (Vue or otherwise) is a real, costed option, not aspirational: it reuses `@olonjs/core` and `@olonjs/studio` unmodified (D8), implementing only its own rendering layer.
- The dependency graph now matches the actual verified coupling in the code, closing a gap between `.cursor/rules/core-engine.mdc`'s prior (now-corrected) documentation and reality.

### Negative

- Three packages to version, publish, and keep coordinated instead of one — `packages/stack`'s `stack-versions.json` must evolve from pinning one `@olonjs/core` version to pinning three.
- `apps/tenant-alpha` and `packages/cli`'s generated template require a real, one-time import migration — every `import ... from '@olonjs/core'` in ~14,000 lines of template source is affected. No compat shim absorbs this.
- `test:boundary` (`check-runtime-decoupling.mjs`, `check-singleton-modules.mjs`) currently does intra-package static analysis; it must evolve into a cross-package dependency-graph check or lose its enforcement value.
- The `theme-manager.ts` split (D4) carries residual, not-yet-validated risk against the ADR-0012 singleton-identity mechanism.

### Requirements imposed on other parts of the system

- **`packages/cli`**: template generation (`src2Code.sh`, `check-cli-templates.mjs`) regenerates against the new three-package import shape.
- **`apps/tenant-alpha`**: full migration to the new imports; remains the only integration test (`tsc && vite build`) since no automated e2e suite exists.
- **`packages/stack`**: `stack-versions.json` pins three coordinated versions instead of one.
- **Specs (`specs/olonjsSpecs_V_1_6_1.md` §10, JEB)**: currently assumes a single-package bootstrap contract. Needs a future revision noting the three-package surface. Non-blocking — can land as a subsequent spec patch after implementation, mirroring how ADR-0009 treated its own spec update as a non-blocking follow-up.

## Follow-ups

- [ ] Write the implementation plan (Phase 2 of spec-driven-development) covering the file moves, package scaffolding, and migration order.
- [ ] Spike: confirm the `theme-manager.ts` logic/singleton split (D4) does not break ADR-0012's cross-bundle React-identity-sharing mechanism.
- [ ] Spike: confirm `@olonjs/react`'s dynamic `import('@olonjs/studio')` works as a clean cross-package Vite code-split boundary (ADR-0009's split was intra-package; this is a new mechanism).
- [ ] Evolve `test:boundary` from intra-package static analysis to a cross-package dependency-graph check (e.g. `madge`/`depcheck` across workspace packages) enforcing D2's graph.
- [ ] Evolve `packages/stack/stack-versions.json` to pin three coordinated package versions.
- [ ] Update `specs/olonjsSpecs_V_1_6_1.md` §10 (JEB) to describe the three-package bootstrap contract.
- [ ] Audit the full `studio/admin/*` + `studio/ui/*` surface (not just the 3 friction points found) for any remaining hidden coupling to rendering-runtime output (e.g. drag-and-drop previews, image-picker thumbnails) before declaring D2's graph fully verified.

## Open Points

None. All decision-level questions (package naming, dependency direction, `theme-manager`/`StudioRoute`/`StudioContext` classification, `cn()` placement, back-compat posture) were resolved during ideation — see [`docs/ideas/core-react-studio-package-split.md`](../ideas/core-react-studio-package-split.md) for the full trace. Remaining items are implementation-detail follow-ups above, consistent with ADR-0009's own precedent that detail-level decisions do not require ADR-level resolution.

## References

- [ADR-0009](./ADR-0009-core-studio-split-via-runtime-subpath.md) — the direct predecessor; this ADR reverses its Option C rejection under a different objective.
- [ADR-0012](./ADR-0012-externalize-runtime-from-full-bundle.md) — the singleton-externalization mechanism at risk during the `theme-manager.ts` split (D4).
- [`docs/ideas/core-react-studio-package-split.md`](../ideas/core-react-studio-package-split.md) — full file-by-file verified boundary analysis this ADR formalizes.
- `.cursor/rules/core-engine.mdc` — updated in this same work session to reflect the current (pre-split) real file structure.
- `specs/olonjsSpecs_V_1_6_1.md` §10 (JEB) — bootstrap contract to be revised downstream, non-blocking.
- `apps/tenant-alpha/scripts/bake.mjs`, `generate-llms-txt.mjs` — the concrete Node-script evidence motivating D1.
- `packages/core/src/studio/admin/StudioStage.tsx`, `PreviewEntry.tsx`, `StudioContext.tsx`, `AdminSidebar.tsx`, `runtime/engine/StudioRoute.tsx` — the files whose exact import graph was traced to produce D2/D3/D5/D6.
