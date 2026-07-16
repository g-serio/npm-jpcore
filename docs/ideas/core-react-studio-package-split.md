# Core/React/Studio Package Split — Framework-Agnostic Engine

> Status: Idea, not yet implemented — ready for planning/spike.
> Supersedes: nothing. This is independent of `dna-boundary-tenant-core-shim.md` / `dna-boundary-resume-here.md`, which should not be used as input or precedent for this plan.

## Problem Statement

How might we split `packages/core` so that its pure TypeScript engine (MTRP types, Zod contracts, config resolver, pure orchestration logic) is fully decoupled from React, and its Studio editor UI is decoupled from the visitor rendering path — so that non-React consumers can depend on the engine alone, and OlonJS's "deterministic contract" positioning is backed by an architecture that isn't hard-wired to one UI framework, opening a real (not aspirational-only) path to future framework bindings?

## Recommended Direction

**Corrected graph (superseding an earlier draft of this doc that assumed a linear `core ← react ← studio` chain):**

```
                    @olonjs/core
                   /            \
        @olonjs/studio      @olonjs/react
                   \            /
                    react → studio
         (one directional edge only, dynamic import)
```

`@olonjs/studio` depends **only** on `@olonjs/core` (types, `STUDIO_EVENTS`, `section-ops`, `selection-path`, `webmcp`) plus generic `react`/`react-dom` as peer dependencies (Studio's UI is still built with React + Radix, it just never imports the `@olonjs/react` package). It never imports `PageRenderer`, `SectionRenderer`, `ConfigContext`, `ThemeLoader`, `theme-manager`, or `IconRegistryContext`.

`@olonjs/react` depends on `@olonjs/core` (hard), and additionally does a **single dynamic `import()` of `@olonjs/studio`** inside a thin admin bridge component that composes `<ThemeLoader><StudioProvider mode="studio"><StudioRoute .../></StudioProvider></ThemeLoader>` (mirrors today's ADR-0009 lazy-load-on-`/admin` pattern, but now crossing a real package boundary instead of an internal bundle split). `@olonjs/studio` is an optional peer dependency of `@olonjs/react`: a visitor-only/SSG consumer that never renders `/admin` never installs it.

### Stronger result: `@olonjs/studio` never needs a per-framework port at all

`@olonjs/studio` stays written in React **permanently** — a future `@olonjs/vue` would reuse it as-is via the same single dynamic-import edge (`vue → studio`), not require a `@olonjs/studio-vue` port. Verified reasons:

- `StudioStage.tsx` never renders tenant page content itself — it opens `<iframe src="/admin/preview/:slug">` and talks only `postMessage` (plain JSON), per TOCC v1.1 ("Stage runs in an iframe so tenant CSS does not leak into Admin chrome").
- `FormFactory`/`AdminSidebar` are schema-driven (ECIP): they build forms by introspecting Zod `schemas`, never by importing the tenant's actual `View.tsx` components or `ComponentRegistry`. Studio has no idea whether the tenant renders with React or Vue.
- The only things crossing the iframe boundary are `STUDIO_EVENTS` (already in `@olonjs/core`) and IDAC DOM attributes (`data-jp-*`, `data-section-id`) — both framework-agnostic by construction (IDAC v1.2 is just HTML attributes).
- What *is* framework-specific, and does need a per-binding implementation, is only the content that runs **inside** the preview iframe — `PreviewEntry` + `PageRenderer` in `@olonjs/react` today, and a `VuePreviewEntry` + Vue-equivalent renderer inside a hypothetical `@olonjs/vue` tomorrow. That code belongs to the rendering binding, not to Studio.

Net effect: this graph generalizes to any number of framework bindings without ever touching `@olonjs/studio` again — each new binding package only needs its own rendering implementation plus the same one `import('@olonjs/studio')` edge. `@olonjs/studio` and `@olonjs/core` are independent siblings; only rendering-binding packages (`@olonjs/react`, future `@olonjs/vue`, ...) need to know Studio exists, and none of them need to reimplement it.

### Verified friction points and their fix (grep across all of `studio/` for `runtime/` imports found exactly 3 hits — no others)

| File | Problem found | Fix |
|---|---|---|
| `studio/admin/AdminSidebar.tsx` | `const { schemas } = useConfig()` — the only `@olonjs/react`-package import in the entire admin UI | Mechanical: `StudioRoute` already receives `schemas` as its own prop (`StudioRouteProps.schemas`) — thread it through as an explicit `<AdminSidebar schemas={schemas} .../>` prop instead. |
| `studio/admin/IconRegistryContext.tsx` | Re-export shim of `runtime/icons/IconRegistryContext`, **already documented in its own code comment** as deferred cleanup: *"kept so existing imports keep working... to remove this shim... (deferred: removal is a future major)"* | Delete the shim. This split *is* that future major. |
| `studio/admin/PreviewEntry.tsx` | Imports `PageRenderer` + `themeManager` (both `runtime/`) because it's the code that runs **inside the Stage iframe** and must actually render the page | Move this file to `@olonjs/react` entirely — it is the React-specific implementation of "render the editable preview surface," not admin chrome. A future Vue binding would need its own equivalent, not a shared one. |
| `studio/StudioContext.tsx` (`StudioProvider`/`useStudio`) | Used by `runtime/rendering/SectionRenderer.tsx`, `runtime/engine/VisitorRoute.tsx`, `runtime/engine/StudioRoute.tsx` — i.e. needed by the rendering pipeline itself, independent of whether the Studio admin package is even installed | Move to `@olonjs/react`. It is a rendering-mode flag (decides IDAC overlay injection), not admin-chrome UI, despite living under `src/studio/` today. |
| `runtime/engine/StudioRoute.tsx` (850 lines, today wraps itself in `<ThemeLoader><StudioProvider>`) | The bulk of this file is pure Studio orchestration (draft state, collections draft, WebMCP tool wiring, calls into `section-ops`) with zero use of `PageRenderer`/`SectionRenderer`/`ConfigContext` — but it self-wraps in two `@olonjs/react` components | Split: the orchestration body moves into `@olonjs/studio` as `StudioRoute` (receives `mode="studio"` context from outside, does not import `ThemeLoader`/`StudioProvider` itself). The `<ThemeLoader><StudioProvider>` wrapping moves up into a thin bridge component that stays in `@olonjs/react` and does the dynamic `import('@olonjs/studio')`. |

`runtime/engine/PreviewRoute.tsx` needs no cross-package fix at all once `PreviewEntry` and `StudioContext` move to `@olonjs/react` — it becomes a same-package composition (`ThemeLoader` + `PreviewEntry`, both in react), with no dependency on `@olonjs/studio`.

### Verified package boundary (grounded in current file-level imports, not guessed)

| Goes to `@olonjs/core` | Why |
|---|---|
| `contract/*` (kernel, types-engine, config-resolver, zod-schemas, webmcp-contracts) | Already zero-React today. |
| `webmcp/*` (contracts + bridge) | `webmcp-bridge.ts` registers tools on a DOM-like object, zero React import. |
| `dna/lib/base-schemas.ts`, `cloudSaveStream.ts`, `deploySteps.ts`, `dna/types/deploy.ts` | Pure TS, zero React. |
| `studio/events.ts` (`STUDIO_EVENTS`) | Pure string-constant vocabulary shared by both `@olonjs/react` (Stage/visitor side emits/listens `STAGE_READY`, `SECTION_SELECT`) and `@olonjs/studio` (`UPDATE_DRAFTS`, `SYNC_SELECTION`). Must not live only in studio or react would need to depend on studio for a dictionary of strings. |
| `studio/orchestration/section-ops.ts` | Verified: `reorderPageSections`/`appendDraftSection` are pure functions, import only `contract/kernel` types. No React, no DOM, no "editor" concept — reusable by WebMCP tools, Node scripts, or a future non-React binding. |
| `studio/admin/selection-path.ts` | Verified pure (only imports `SelectionPath` type from contract). Same domain as `applyValueAtSelectionPath` already in `webmcp` — path resolution belongs at the engine layer, not the admin-UI layer. |
| `runtime/assets/asset-resolver.ts`, `runtime/url/base-path.ts`, `runtime/engine/route-utils.ts`, `runtime/engine/public-page-document.ts` | Verified zero-React pure TS despite living under `runtime/` today. |
| `runtime/theme/theme-manager.ts` — **logic half only** | Token-flatten/read logic is pure; split out from the singleton/publish half. |
| `lib/utils.ts` (`cn`) | `clsx` + `tailwind-merge`, zero React import — fits the "framework-agnostic, zero-React" criterion even though it's UI-utility in nature. |

| Goes to `@olonjs/react` | Why |
|---|---|
| `runtime/engine/*` (`JsonPagesEngineCore`, `OlonJSEngine`, `JsonPagesEngine` thin wrapper, `VisitorRoute`, `EngineErrorBoundary`) | React composition root. |
| `runtime/rendering/*` (`PageRenderer`, `SectionRenderer`, `useDocumentMeta`) | React components/hooks. |
| `runtime/config/ConfigContext.tsx`, `runtime/icons/IconRegistryContext.tsx` | React Context — framework-specific by construction. |
| `runtime/theme/ThemeLoader.tsx` + theme-manager **singleton/publish half** | React wrapper + the ADR-0012 cross-bundle identity-sharing concern. |
| `lib/DefaultNotFound.tsx` | React component. |
| `dna/lib/OlonFormsContext.ts` | Verified: despite `.ts` extension, imports `createContext` from React — false negative caught during exploration. |
| `studio/StudioContext.tsx` (`StudioProvider`/`useStudio`) | Corrected: needed directly by `SectionRenderer`/`VisitorRoute`/the admin bridge — a rendering-mode flag, not admin-chrome UI. |
| `studio/admin/PreviewEntry.tsx` | Corrected: needs `PageRenderer`/`themeManager` to actually render the editable preview surface inside the Stage iframe. |
| A new thin **admin bridge** component (composes `<ThemeLoader><StudioProvider mode="studio">` + dynamic `import('@olonjs/studio')` to mount `StudioRoute`) | This is the *only* place `@olonjs/react` reaches into `@olonjs/studio`, and only via dynamic import. |
| `runtime/engine/PreviewRoute.tsx` | Unchanged composition (`ThemeLoader` + `PreviewEntry`), now fully intra-package — no dependency on `@olonjs/studio` at all. |

| Goes to `@olonjs/studio` | Why |
|---|---|
| `studio/admin/*` (minus `selection-path.ts` and `PreviewEntry.tsx`) — `AdminSidebar` (now takes `schemas` as a prop instead of `useConfig()`), `FormFactory`, `InputRegistry`, `StudioStage`, `AddSectionLibrary`, `PageSelector`, `image-picker/*` | Editor UI, Radix-dependent, depends only on `@olonjs/core` after the `AdminSidebar` prop fix. |
| `studio/ui/*` | Radix primitives used only by the editor chrome. |
| `studio/orchestration/useStudioPersistence.ts`, `useStudioSelectionState.ts` | Verified: both import `useCallback`/`useState` from React (generic peer dep, not the `@olonjs/react` package) — hooks, Studio-only state. |
| `runtime/engine/StudioRoute.tsx` **orchestration body** (relocated) | Corrected: ~850 lines are pure Studio orchestration (draft state, collections draft, WebMCP tool wiring, `section-ops` calls) with zero use of `PageRenderer`/`SectionRenderer`/`ConfigContext`. It stops importing `ThemeLoader`/`StudioProvider` itself — that wrapping moves to the `@olonjs/react` admin bridge — so it becomes a component that depends only on `@olonjs/core` and its own sibling Studio components. |

## Key Assumptions to Validate

- [ ] Splitting `theme-manager.ts` (logic in core, singleton/publish in react) does not break the ADR-0012 cross-bundle React-identity-sharing mechanism — spike a minimal repro before committing.
- [ ] Promoting `section-ops.ts` and `STUDIO_EVENTS` into `@olonjs/core` doesn't leak Studio-specific vocabulary into a package meant to be UI-agnostic — audit that nothing in core's public surface assumes a specific editor UI exists.
- [ ] `@olonjs/react`'s dynamic `import('@olonjs/studio')` works cleanly as a **cross-package** code-split boundary in Vite (today's split is intra-package/intra-bundle only) — needs a build spike, not just an assumption.
- [ ] `apps/tenant-alpha` (the only reference/test bed for the engine) can be fully migrated to the new three-package imports and still produce a green `tsc && vite build` — this is the actual integration test since there is no automated e2e suite.
- [ ] Old tenants pinned to the current `@olonjs/core@1.x` genuinely keep working untouched — confirm nothing in `packages/cli` or `jsonpages-platform` provisioning assumes a single always-current `@olonjs/core` version per tenant.
- [ ] `@olonjs/studio`'s isolation from the rendering framework is total, not partial — audit the *entire* `studio/admin/*` + `studio/ui/*` surface (not just the 3 friction points already found) for any remaining assumption about React-rendered tenant content (e.g. drag-and-drop reorder previews, image-picker thumbnails) that might silently require `@olonjs/react` beyond the already-identified `PreviewEntry`/`StudioContext` moves.

## MVP Scope

**In:**
1. Reorganize `packages/core/src/` into the three boundaries above (file moves, no behavior change yet).
2. Split `packages/core` into three real npm workspace packages: `packages/core`, `packages/react`, `packages/studio`, each with its own `package.json`, `vite.config.ts`, `tsconfig.json`.
3. Wire the dependency graph (`core` ← `react`, `core` ← `studio` as independent siblings, plus `react`'s single dynamic `import('@olonjs/studio')` inside its admin bridge — never the reverse).
4. Migrate `apps/tenant-alpha` to the new import paths (radical break, no compat layer) and get a green build.
5. Update `packages/cli` template generation (`src2Code.sh` / `check-cli-templates.mjs`) to reflect three dependency blocks instead of one.
6. Port existing `vitest` suites to run against the correct new package (pure-logic tests move with their file to `@olonjs/core`).

**Out of MVP (see Not Doing):**
- Any second UI-framework binding.
- Backward-compat shims for the old flat `@olonjs/core` import surface.
- Resolving the CLI's downstream `manifest.json` implications beyond making `check:templates` pass.

## Not Doing (and Why)

- **Building `@olonjs/vue` or any other framework binding now** — the goal of this split is to prove the boundary is real and correctly drawn, not to ship a second framework. A future binding is the validation of this architecture, not part of its MVP.
- **Backward-compat re-exports from `@olonjs/core` for the old flat surface** — explicitly confirmed as unnecessary: this is a radical, versioned break; tenants pinned to the old version keep working as-is.
- **Reusing or extending the `dna-boundary-tenant-core-shim.md` / `dna-boundary-resume-here.md` plan** — explicitly out of scope per your direction. Any future DNA-lib promotion work should be re-scoped against this new three-package boundary, not against the old single-package assumption those docs were written for.
- **Merging/deduplicating `webmcp`'s `applyValueAtSelectionPath` with the promoted `selection-path.ts`** — real follow-up, but not a blocker for landing the package split.

## Open Questions

- ~~Should `@olonjs/studio`'s Stage import `@olonjs/react`'s `PageRenderer` directly?~~ **Resolved by code inspection**: `StudioStage.tsx` never imports `PageRenderer` — it only opens an `<iframe src="/admin/preview/:slug">` and talks `postMessage`. Only `PreviewEntry.tsx` (the code that runs *inside* that iframe) needs `PageRenderer`, and it moves to `@olonjs/react`. No ambiguity remains.
- Naming: keep `@olonjs/core` as the name for the now-pure engine (semantic breaking change even if the package name is unchanged), or rename the pure engine (e.g. `@olonjs/engine`) and mint a fresh `@olonjs/core` meta-package that just re-exports `react` + `studio` for convenience installs?
- Does `test:boundary` tooling (`check-runtime-decoupling.mjs`, `check-singleton-modules.mjs`) get replaced by real package-level dependency-graph checks (e.g. `depcheck`/`madge` across workspace packages) instead of intra-package import-graph static analysis?
- How does `packages/stack`'s `stack-versions.json` (currently pinning a single `@olonjs/core` version) evolve to pin three coordinated versions?
