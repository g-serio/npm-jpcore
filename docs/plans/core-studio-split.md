# Implementation Plan: Split Studio from `@olonjs/core` runtime

Status: **Ready for incremental implementation** — ADR-0009 drafted (Proposed); per-phase greenlight gates as work progresses
Decision records: [ADR-0008](../decisions/ADR-0008-perf-roadmap-to-mobile-90.md) (Phase B trigger), [ADR-0009](../decisions/ADR-0009-core-studio-split-via-runtime-subpath.md) (D1–D8 architectural decisions ratified)
Owner: `@olonjs/core` package maintainer (with tenant smoke-testing in `apps/olonjs.io`).

## Overview

Today `@olonjs/core` ships a single ESM bundle that contains both the **runtime** (the visitor-facing engine: routing, rendering, theme, asset resolution) and the **Studio** (the visual editor: AdminSidebar, FormFactory, StudioStage, etc.). Tenants on the public web pay the full cost on every visit even though Studio is only used in `/admin`.

This plan splits the package so that tenants can opt into a runtime-only build via a new `@olonjs/core/runtime` subpath export. The existing `@olonjs/core` import surface keeps working unchanged — no breaking changes for downstream consumers.

Quantitative target (per ADR-0008): mobile Lighthouse Performance ≥ 90 for `https://olon.js.org`, with the visitor-facing initial JS chunk ≤ 250 KB gzipped (down from 395 KB).

## Discovery summary (from current codebase)

The following is grounded reading, not speculation — needed for sizing the work:

- `packages/core/src/index.ts` already exposes `contract`, `kernel`, `runtime`, `studio`, `webmcp` as conceptual namespaces. The author flagged this as "the future split" in a code comment. The flat re-exports below the namespaced ones are what currently force everything into one bundle.
- Studio source is **~3,870 LOC** under `packages/core/src/studio/` (admin UI 2,113 LOC, plus `orchestration/`, `ui/`, `StudioContext.tsx`, `events.ts`).
- The runtime (`packages/core/src/runtime/`) imports from `studio/` in **5 files**:
  1. `runtime/engine/JsonPagesEngine.tsx` — `IconRegistryContext`, `admin-skin.css?inline`
  2. `runtime/engine/VisitorRoute.tsx` — `StudioProvider` (wraps content in `mode="visitor"`)
  3. `runtime/engine/StudioRoute.tsx` — heavy: `AddSectionLibrary`, `AdminSidebar`, `StudioStage`, `section-ops`, `useStudioPersistence`, `useStudioSelectionState`, `StudioProvider`, `STUDIO_EVENTS`
  4. `runtime/engine/PreviewRoute.tsx` — `PreviewEntry`
  5. `runtime/rendering/SectionRenderer.tsx` — `useStudio` (reads `mode` to gate overlay rendering, per IDAC v1.2)
- The package.json `exports` field has only `"."` and `"./package.json"`. Adding `"./runtime"` is straightforward.
- The build is Vite library mode (`vite build`), single output `dist/olonjs-core.js` + UMD. We need to extend it to produce two outputs.
- Tests use Vitest. There are tests under `studio/admin/FormFactory.nested-array.test.tsx` and a few `route-utils.test.ts`-style tests in `runtime/engine/`. The split must keep these passing.

## Architecture decisions (to be ratified in ADR-0009)

These decisions are presented here as candidates. **ADR-0009 must lock them before Phase 1**.

### D1 — Two distinct bundles, not one bundle with lazy chunks

The split happens at the **package boundary**, not at runtime via dynamic `import()`. The package ships:

- `dist/olonjs-core.js` — full surface (runtime + Studio); imported via `@olonjs/core`. Existing tenants unchanged.
- `dist/olonjs-core-runtime.js` — runtime-only; imported via `@olonjs/core/runtime`. New.

Rationale: a single bundle with `React.lazy(() => import(...studio))` would still ship Studio source (the chunk just loads later). For visitors that never open `/admin`, that means the bytes are downloaded on demand or sit unused. With two bundles, visitors *never* receive Studio code — Vite (the consumer's bundler) chooses the bundle from the import path.

### D2 — Subpath export, single package

We do not split into two npm packages. We add a `package.json` `exports` map:

```json
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

Rationale: keeps versioning, dependencies, and release process unified. Two-package solutions add a coordination problem we don't need.

### D3 — `StudioProvider` and `useStudio` stay in the runtime entry

These are the smallest pieces of Studio (a Context + a hook). They are needed by `SectionRenderer` and `VisitorRoute` even in visitor mode (the provider mounts with `mode="visitor"` so `useStudio()` returns a no-op shape). Keeping them in the runtime bundle costs ~50 lines and avoids a more invasive abstraction (e.g. a "studio adapter" interface).

What stays in **runtime**: `StudioContext.tsx`, `events.ts` (constants), and `IconRegistryContext.tsx` (8 LOC, currently in `studio/admin/` but functionally a runtime concern).

What moves to **studio-only**: `AdminSidebar`, `FormFactory`, `StudioStage`, `AddSectionLibrary`, `PreviewEntry`, `PageSelector`, `InputRegistry`, `admin-skin.css`, the `orchestration/` folder, and the engine routes that mount them.

### D4 — Engine becomes Studio-aware via injection, not direct import

Today `JsonPagesEngine.tsx` directly imports `StudioRoute` and `PreviewRoute`. After the split:

- The full engine (`@olonjs/core`) keeps mounting all routes including admin.
- The runtime engine (`@olonjs/core/runtime`) mounts only the visitor route. The `/admin` and `/admin/preview` paths are simply not registered. If a user navigates to `/admin` in a runtime-only build, they get a 404 (or whatever `DefaultNotFound` produces) — which is correct behavior for a public site that has no editor.

Implementation choice: **two engine files**, sharing 90% via composition, differing in route registration.

```
runtime/engine/
  ├── JsonPagesEngineCore.tsx    (NEW — shared shell, no admin routes)
  ├── JsonPagesEngine.tsx        (existing — wraps Core, adds admin routes)
  └── OlonJSEngine.tsx (NEW — wraps Core, visitor only)
```

`JsonPagesEngineCore` is the composition root. The two siblings differ only in which `<Route>` children they pass.

### D5 — `IconRegistryContext` moves from `studio/admin/` to `runtime/`

This is small (8 LOC) but the engine imports it. The current location is misleading — it's a runtime concern (icons consumed by section schemas), not a Studio one. Move it during Phase 1 to clean up the import direction.

### D6 — Public API contract: additive only

- `@olonjs/core` exports stay byte-for-byte identical. No removal, no renames.
- `@olonjs/core/runtime` exports a strict subset: `OlonJSEngine` (the visitor-only engine; new symbol), `useConfig`, `resolveAssetUrl`, `themeManager`, `STUDIO_EVENTS`, `useStudio`, `StudioProvider`, and runtime types (including `JsonPagesConfig`, **not** renamed).
- `@olonjs/core` ships as `1.1.0` (minor bump): additive subpath export = SemVer minor.

### D7 — Tenant adoption is opt-in

`apps/olonjs.io/src/App.tsx` will import conditionally based on pathname:

```tsx
const isAdminPath = window.location.pathname.startsWith('/admin');
// Vite static-analyzes both branches; bundles both, picks at runtime.
// To get the split we need to use dynamic import:
const enginePromise = isAdminPath
  ? import('@olonjs/core').then(m => m.JsonPagesEngine)
  : import('@olonjs/core/runtime').then(m => m.OlonJSEngine);
```

The tenant uses `React.lazy` or top-level `await` to wire this. **The tenant change is small** (one file, ~15 lines). The Core change is what unlocks the win.

## Task List

### Phase 0 — Pre-flight (decisions and safety net)

#### Task 0.1 — Draft ADR-0009 with the D1-D7 decisions

**Description:** Convert the architecture decisions D1-D7 above into ADR-0009 in `docs/decisions/ADR-0009-...md`. Each decision needs context, alternatives considered, rejected options. Reference ADR-0008 as the trigger.

**Acceptance criteria:**
- [ ] ADR-0009 covers D1-D7 with rationale and at least 2 rejected alternatives per architectural choice
- [ ] Status: `Proposed — pending implementation and verification`
- [ ] Cross-referenced in `docs/decisions/README.md` index
- [ ] Cross-referenced from this plan's preamble (replace "candidates" wording)

**Verification:**
- [ ] User reviews and approves ADR-0009 before Phase 1 starts
- [ ] Status moves to `Accepted` once verified empirically

**Dependencies:** None
**Files:** `docs/decisions/ADR-0009-*.md`, `docs/decisions/README.md`, this plan
**Scope:** S

#### Task 0.2 — Snapshot baseline metrics for regression detection

**Description:** Before any Core change, capture: (1) current `dist/` chunk listing for `apps/olonjs.io` after Phase 1-4 of perf work, (2) current `@olonjs/core` build output sizes, (3) Lighthouse mobile/desktop scores, (4) full test results from `packages/core` and `apps/olonjs.io`.

**Acceptance criteria:**
- [ ] Baseline saved in `docs/plans/core-studio-split-baseline.txt` (or appended to this plan)
- [ ] Includes: `npm test` output for both packages, `dist/` listing with sizes, current Lighthouse JSON

**Verification:**
- [ ] All baseline tests pass before Phase 1 begins (no pre-existing failures contaminate the comparison)

**Dependencies:** None
**Files:** `docs/plans/core-studio-split-baseline.txt`
**Scope:** XS

### Checkpoint: Phase 0 complete
- [ ] ADR-0009 `Accepted` (pending verification)
- [ ] Baseline metrics saved
- [ ] User greenlight for Phase 1

---

### Phase 1 — Source decoupling (no public API change, no build change)

The goal is for `packages/core/src/runtime/` to **stop importing anything from `packages/core/src/studio/admin/`**, while keeping all current behavior. This is the riskiest phase — it touches the engine routing.

#### Task 1.1 — Move `IconRegistryContext` from `studio/admin/` to `runtime/`

**Description:** Per D5, `IconRegistryContext.tsx` is a runtime concern. Move it to `runtime/icons/IconRegistryContext.tsx` (or similar). Update the single importer in `JsonPagesEngine.tsx`. Re-export from the legacy path to preserve backward compatibility for any external code that grabs it (defensive).

**Acceptance criteria:**
- [ ] File physically moved
- [ ] `JsonPagesEngine.tsx` imports the new path
- [ ] Old path still works (re-export shim in `studio/admin/IconRegistryContext.tsx`)
- [ ] All existing tests pass

**Verification:**
- [ ] `cd packages/core && npm run build && npm test` clean
- [ ] `cd apps/olonjs.io && npm run build` clean

**Dependencies:** 0.1, 0.2
**Files:** `packages/core/src/runtime/icons/IconRegistryContext.tsx` (new), `packages/core/src/studio/admin/IconRegistryContext.tsx` (becomes re-export shim), `packages/core/src/runtime/engine/JsonPagesEngine.tsx`
**Scope:** XS

#### Task 1.2 — Inline or relocate `admin-skin.css` import

**Description:** `JsonPagesEngine.tsx` imports `studio/admin/admin-skin.css?inline` as default CSS. This couples the visitor engine to Studio styles. Either: (a) move the file to `runtime/` (if visitor mode actually uses the rules), (b) make the import optional via a config prop, or (c) inject the CSS only in the admin-route branch.

**Acceptance criteria:**
- [ ] Determine via `grep` and DevTools whether visitor mode actually applies any of these rules. If yes: keep inlined but move file path. If no: gate the inline import behind admin route registration.
- [ ] Document the decision inline (one-line comment near the import)
- [ ] No visual regression in visitor mode or admin mode

**Verification:**
- [ ] Manual smoke test: `apps/olonjs.io` home page (visitor) — pixel-compare against baseline
- [ ] Manual smoke test: `/admin` — pixel-compare against baseline

**Dependencies:** 0.1, 0.2
**Files:** `packages/core/src/runtime/engine/JsonPagesEngine.tsx`, possibly `packages/core/src/runtime/admin-skin.css` (new path)
**Scope:** S

#### Task 1.3 — Extract `JsonPagesEngineCore` shared shell

**Description:** Per D4, factor the common shell out of `JsonPagesEngine.tsx`. The new `JsonPagesEngineCore` accepts `<Route>` children as props (or as a render prop) and handles: provider tree (`ConfigProvider`, `IconRegistryContext`, `EngineErrorBoundary`), `themeManager` initialization, `ensureWebMcpRuntime()` boot, the `createBrowserRouter` + `RouterProvider` wiring with `<ScrollRestoration />`. Routes are passed in by the caller.

**Acceptance criteria:**
- [ ] `JsonPagesEngineCore` exists and contains 90%+ of current `JsonPagesEngine` logic
- [ ] Existing `JsonPagesEngine` becomes a thin wrapper that adds admin/preview routes and delegates to `Core`
- [ ] Public API of `JsonPagesEngine` unchanged (same props, same behavior)
- [ ] All existing tests pass

**Verification:**
- [ ] `npm test` clean
- [ ] Manual smoke test of `/`, `/admin`, `/admin/preview` in `apps/olonjs.io` — all routes render identically

**Dependencies:** 1.1, 1.2
**Files:** `packages/core/src/runtime/engine/JsonPagesEngineCore.tsx` (new), `packages/core/src/runtime/engine/JsonPagesEngine.tsx` (refactored)
**Scope:** M

#### Task 1.4 — Create `OlonJSEngine` (visitor-only sibling)

**Description:** New file that mounts only the visitor route via `JsonPagesEngineCore`. Does **not** import any module from `studio/admin/` or `studio/orchestration/`. May import `StudioContext` and `events` (per D3).

**Acceptance criteria:**
- [ ] `OlonJSEngine` exists, accepts the same `JsonPagesConfig` prop
- [ ] When mounted, visitor routes render identically to current `JsonPagesEngine` for non-admin paths
- [ ] Admin paths fall through to `DefaultNotFound`
- [ ] Static analysis: no transitive import reaches `studio/admin/` or `studio/orchestration/` (verified via `madge` or grep)

**Verification:**
- [ ] `madge --circular` and `madge --image` show clean dependency tree from `OlonJSEngine`
- [ ] Build with a temporary tenant entry that uses `OlonJSEngine` and inspect the chunk: studio admin code must NOT be present

**Dependencies:** 1.3
**Files:** `packages/core/src/runtime/engine/OlonJSEngine.tsx` (new)
**Scope:** S

#### Task 1.5 — Add `madge` (or equivalent) dependency check in test

**Description:** Add a test/script that fails CI if any file under `runtime/` (excluding `runtime/engine/JsonPagesEngine.tsx`) imports from `studio/admin/` or `studio/orchestration/`. This locks in the decoupling.

**Acceptance criteria:**
- [ ] `npm test` (or a dedicated script) verifies the import boundary
- [ ] Allowed exceptions documented (e.g. `JsonPagesEngine.tsx` is the integration point and *can* import admin)
- [ ] CI fails on regression

**Verification:**
- [ ] Introduce a temporary bad import; verify CI fails. Revert.

**Dependencies:** 1.4
**Files:** `packages/core/scripts/check-runtime-decoupling.mjs` (new), `packages/core/package.json` (test script)
**Scope:** XS

### Checkpoint: Phase 1 complete (source decoupled, no build change yet)
- [ ] All Phase 1 tasks pass acceptance criteria
- [ ] `@olonjs/core` builds and tests pass
- [ ] `apps/olonjs.io` builds and tests pass; visitor + admin manually verified
- [ ] `madge` shows runtime is decoupled from studio admin

---

### Phase 2 — Build pipeline (two bundles, subpath export)

#### Task 2.1 — Update Vite config to emit two library targets

**Description:** Modify `packages/core/vite.config.ts` to build two ESM outputs: `olonjs-core.js` (full, current behavior) and `olonjs-core-runtime.js` (entry: `src/runtime-entry.ts` — a new file that re-exports only what runtime needs).

**Acceptance criteria:**
- [ ] `npm run build` in `packages/core` produces both files
- [ ] Sizes recorded: full bundle ~current, runtime bundle materially smaller (target: ≤ 60% of full)
- [ ] Both bundles externalize React/ReactDOM/zod/react-router-dom (peer deps), no double-bundling
- [ ] Source maps present for both

**Verification:**
- [ ] `du -h dist/*.js` shows the size delta
- [ ] `grep -c "AdminSidebar\|FormFactory\|StudioStage" dist/olonjs-core-runtime.js` returns 0 (negative confirmation that admin is absent)

**Dependencies:** 1.5
**Files:** `packages/core/vite.config.ts`, `packages/core/src/runtime-entry.ts` (new)
**Scope:** M

#### Task 2.2 — TypeScript declaration emission for both entries

**Description:** `vite-plugin-dts` produces one `dist/index.d.ts`. Configure it (or run a second pass) to also emit `dist/runtime.d.ts` from `src/runtime-entry.ts`. Without this, `import from '@olonjs/core/runtime'` lacks types.

**Acceptance criteria:**
- [ ] `dist/runtime.d.ts` exists and accurately reflects `src/runtime-entry.ts` exports
- [ ] Tenant can `import { OlonJSEngine, type JsonPagesConfig } from '@olonjs/core/runtime'` without `any`

**Verification:**
- [ ] In `apps/olonjs.io`, write a test import of every type from `@olonjs/core/runtime`. `tsc --noEmit` clean.

**Dependencies:** 2.1
**Files:** `packages/core/vite.config.ts` (dts plugin config)
**Scope:** S

#### Task 2.3 — Update `package.json` exports map and version bump

**Description:** Add the `./runtime` subpath export. Bump version `1.0.127 → 1.1.0` (minor: additive). Update `files` if needed.

**Acceptance criteria:**
- [ ] `package.json` `exports` has `"."` and `"./runtime"` keys, both with `types`/`import`/(`require` for `.` only)
- [ ] `npm pack --dry-run` shows both `olonjs-core.js`, `olonjs-core-runtime.js`, `index.d.ts`, `runtime.d.ts` in the tarball
- [ ] Version bumped

**Verification:**
- [ ] `node -e "console.log(require('@olonjs/core/runtime'))"` resolves after `npm install` (or via `yalc` for local development)

**Dependencies:** 2.2
**Files:** `packages/core/package.json`
**Scope:** XS

### Checkpoint: Phase 2 complete (package ships two bundles)
- [ ] Both bundles built and sized
- [ ] Types resolve for both subpaths
- [ ] No external-facing breaking change

---

### Phase 3 — Tenant adoption in `apps/olonjs.io`

#### Task 3.1 — Switch `apps/olonjs.io/src/App.tsx` to conditional engine import

**Description:** Per D7, import `OlonJSEngine` for non-admin paths and `JsonPagesEngine` for admin paths. Use a top-level dynamic decision that Vite can statically split.

**Acceptance criteria:**
- [ ] App.tsx selects the engine based on `window.location.pathname`
- [ ] Both code paths are reachable: visitor and admin
- [ ] Tenant `npm run build` produces a visitor-only main chunk that does NOT contain Studio admin code
- [ ] `grep -c "AdminSidebar\|FormFactory" dist/assets/index-*.js` returns 0 for the visitor entry

**Verification:**
- [ ] `npm run build` in `apps/olonjs.io` succeeds
- [ ] Bundle size of the visitor `index-*.js` chunk is ≤ 250 KB gzipped (target from ADR-0008)
- [ ] Manual smoke test: open `/`, scroll, interact — no console errors
- [ ] Manual smoke test: open `/admin`, full editor must work — no regression vs. baseline

**Dependencies:** 2.3 (and `yalc` link of the new core, until published)
**Files:** `apps/olonjs.io/src/App.tsx`
**Scope:** S

#### Task 3.2 — Tighten the `size-limit` budget for visitor entry

**Description:** Update the `size-limit` config (or equivalent) in `apps/olonjs.io` to set the visitor `index-*.js` budget to 250 KB gzipped (per ADR-0008 D6 target). Keep the admin budget separate (or untracked).

**Acceptance criteria:**
- [ ] `size-limit` runs after build and asserts visitor chunk ≤ 250 KB gz
- [ ] Documented in `apps/olonjs.io/README.md` (if such file exists, otherwise as inline comment)

**Verification:**
- [ ] `npm run size-limit` (or whatever the script is) passes after Task 3.1

**Dependencies:** 3.1
**Files:** `apps/olonjs.io/package.json`, `apps/olonjs.io/.size-limit.json` (or equivalent)
**Scope:** XS

### Checkpoint: Phase 3 complete (tenant uses runtime-only entry)
- [ ] Visitor bundle measurably smaller (≤ 250 KB gz target)
- [ ] Admin bundle works
- [ ] CI budget green

---

### Phase 4 — Verification and release

#### Task 4.1 — Full Lighthouse rerun (mobile + desktop)

**Description:** Deploy the tenant to a Vercel preview URL or staging. Run Lighthouse against both form factors. Compare against the post-Phase-A baseline.

**Acceptance criteria:**
- [ ] Lighthouse mobile Performance ≥ 90 (target from ADR-0008)
- [ ] Lighthouse desktop Performance ≥ 90
- [ ] CLS still 0
- [ ] Numbers recorded in `docs/plans/perf-olonjs-io.md` "Final measurement" section

**Verification:**
- [ ] Reports archived (e.g. `olon-mobile-after-split.report.html`)
- [ ] Comparison table appended to perf plan

**Dependencies:** 3.2
**Files:** `docs/plans/perf-olonjs-io.md`
**Scope:** S (mostly waiting for measurements)

#### Task 4.2 — Studio (admin) regression test

**Description:** Manual end-to-end test of the editor. Open `/admin` for `apps/olonjs.io`, do a representative editor flow: select a section, modify a field via the inspector, drag-reorder, save (Hot Save or Local Save depending on env), verify the change persists. Optional: smoke-test a Studio crash scenario to confirm `EngineErrorBoundary` still works.

**Acceptance criteria:**
- [ ] All editor primitives function: section selection, inspector inputs, add-section library, reorder, save, theme picker, image picker
- [ ] No new console errors
- [ ] Save flow round-trips correctly (Local file, Hot Cloud, or Save2Repo as configured)

**Verification:**
- [ ] Checklist filled out in a comment on the PR or in this plan as completion notes
- [ ] If any regression is found, document it and resolve before promoting ADR-0008/0009 to Accepted

**Dependencies:** 4.1
**Files:** None (test-only)
**Scope:** S

#### Task 4.3 — Release `@olonjs/core@1.1.0`

**Description:** Publish to npm. Update CHANGELOG with the new subpath export and the migration recommendation (visitor-heavy tenants should adopt `@olonjs/core/runtime`).

**Acceptance criteria:**
- [ ] `npm publish --access public` from `packages/core` succeeds
- [ ] `@olonjs/core@1.1.0` is fetchable
- [ ] CHANGELOG entry under `## [1.1.0]` documents the subpath export and how to use it

**Verification:**
- [ ] `npm view @olonjs/core@1.1.0 exports` shows the new map
- [ ] `npm install @olonjs/core@1.1.0` in a scratch project, then `import('@olonjs/core/runtime')` succeeds

**Dependencies:** 4.2
**Files:** `packages/core/package.json`, `packages/core/CHANGELOG.md` (create if absent)
**Scope:** XS

#### Task 4.4 — Promote ADRs to `Accepted`

**Description:** Move ADR-0007, ADR-0008, ADR-0009 from `Proposed` to `Accepted`, with the date of acceptance and a one-line note on the empirical results (e.g. "verified mobile 92 / desktop 96 on 2026-MM-DD").

**Acceptance criteria:**
- [ ] All three ADR statuses updated
- [ ] Index `docs/decisions/README.md` reflects the new statuses

**Verification:**
- [ ] Visual check of the index

**Dependencies:** 4.3
**Files:** `docs/decisions/ADR-0007-*.md`, `docs/decisions/ADR-0008-*.md`, `docs/decisions/ADR-0009-*.md`, `docs/decisions/README.md`
**Scope:** XS

### Checkpoint: Project complete
- [ ] Mobile Lighthouse ≥ 90 verified
- [ ] Desktop Lighthouse ≥ 90 verified
- [ ] Studio editor untouched in functionality
- [ ] `@olonjs/core@1.1.0` released
- [ ] ADRs accepted and indexed

---

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| `SectionRenderer` runtime split breaks IDAC overlay attributes (Studio mode flag misread) | High | Medium | Task 1.4 verifies SectionRenderer keeps `useStudio()` wired through `StudioProvider` even in runtime build. Manual smoke test in 4.2. |
| `admin-skin.css` rules turn out to be needed by visitor mode | Medium | Low | Task 1.2 explicitly checks before deciding. If needed, keep inlined or move file into runtime. |
| Vite double-bundling React or other peer deps inflates the runtime chunk | Medium | Medium | Task 2.1 acceptance: `external` config covers React, ReactDOM, zod, react-router-dom. Verify with bundle visualizer. |
| Tenant App.tsx dynamic-import pattern doesn't actually split (Vite includes both bundles in the visitor entry) | High | Medium | Task 3.1 verifies via `grep` that admin code is absent from visitor chunk. If found present, switch to a build-time flag (separate `index-runtime.html` / `index-admin.html` entries) — costlier but bulletproof. |
| Studio editor regression we don't catch in manual testing | High | Low | Task 4.2 explicit checklist. Roll back the Core split if regression is found and Studio cannot be quickly fixed. |
| Downstream tenants outside this monorepo break | High | Low | D6 commits to additive-only changes. The `@olonjs/core` import surface is byte-identical. |

## Resolved questions (decisions locked, no longer open)

- **Q1 — Naming of the runtime engine.** The runtime-only engine is exported as `OlonJSEngine` from `@olonjs/core/runtime`. The full engine continues to be exported as `JsonPagesEngine` from `@olonjs/core` (no rename, no alias). Different name for different scope; no risk of confusing the two bundles at the import site. `JsonPagesConfig` and `JsonPagesEngineProps` types are **not** renamed (out of scope for this work).
- **Q2 — Tree-shaking vs explicit split.** Explicit split via two physical bundles; no reliance on tree-shaking the published package. Already locked in D1.
- **Q3 — Module formats for `/runtime`.** **ESM only** for `@olonjs/core/runtime`. The main `.` entry continues to ship ESM + CJS for back-compat. The runtime is React component code consumed by modern bundlers (Vite/Webpack 5+); no `require()` use case justifies the extra build target.
- **Q4 — Downstream consumers.** Two known consumers: `apps/tenant-alpha` (the DNA reference tenant — auto-syncs from the `@olonjs/stack` process) and `apps/olonjs.io` (manually updated as part of this work, Task 3.1). No external public consumers to coordinate with. Release process simplified: standard `npm publish` + CHANGELOG update, no public deprecation period needed.

## Parallelization Opportunities

The plan is mostly sequential (each phase depends on the previous), but within phases:

- **Phase 0**: 0.1 and 0.2 are parallel.
- **Phase 1**: 1.1 and 1.2 can run in parallel; 1.3 depends on both; 1.4 depends on 1.3; 1.5 is last.
- **Phase 2**: 2.1 → 2.2 → 2.3 strictly sequential.
- **Phase 3**: 3.1 → 3.2 sequential.
- **Phase 4**: 4.1 → 4.2 → 4.3 → 4.4 sequential (each gates the next).

Total wall-clock estimate (single agent, focused work): **2–3 days** including measurement, manual testing, and ADR-0009 drafting. Phase 1 is the longest (~1 day) because it touches the engine.

## Definition of Done

- ADR-0009 drafted, reviewed, accepted, and referenced from this plan
- All Phase 1–4 tasks acceptance-criteria met
- Mobile Lighthouse Performance ≥ 90 verified empirically on the deployed `apps/olonjs.io`
- `@olonjs/core@1.1.0` published with the subpath export
- ADR-0007, ADR-0008, ADR-0009 statuses moved to `Accepted`
- This plan archived under `docs/plans/perf-olonjs-io.md` "Final measurement" or kept as a sibling reference
