# ADR-0011: Declare `@olonjs/core` as side-effect-free for aggressive tree-shaking

## Status

Accepted — implemented in `@olonjs/core` v1.1.2; bundle-size win for `apps/olonjs.io` measured at **0 KB** (unexpected; see Implementation notes for the root cause). The flag is still architecturally correct and benefits future tenants with different consumption profiles. (2026-05-10)

## Date

2026-05-10

## Scope

The published `@olonjs/core` npm package (`packages/core/package.json`). Affects every tenant that consumes the package via either subpath export (`@olonjs/core` and `@olonjs/core/runtime`). No source-code change to engine logic; the change is to the package contract that bundlers read.

## Context

ADR-0009 split `@olonjs/core` into two physical bundles (`olonjs-core.js` full, `olonjs-core-runtime.js` visitor-only) gated by Node `exports` subpath conditions. The `/runtime` subpath was deliberately scoped to ~28 KB gzipped, with a CI-enforced boundary check (`packages/core/scripts/check-runtime-decoupling.mjs`) preventing regression.

Despite that split, the 2026-05-09 Lighthouse bundle audit on `apps/olonjs.io` shows the tenant's main visitor chunk still carries **~260 KB raw / ~32 % unused code** out of an 815 KB raw / 231 KB gz total. Inspection of the import graph from `runtime-entry.ts` (106 lines, audited 2026-05-10) confirms the entry surface is appropriate — every named export is actually consumed by at least one of `apps/olonjs.io` or `apps/tenant-alpha` (see Audit findings below). The waste is therefore not in *what is exported* but in *what Rollup pulls transitively* because it cannot prove modules are pure.

The root cause is that `packages/core/package.json` does not declare a `sideEffects` field. Per the [Webpack/Rollup convention](https://webpack.js.org/guides/tree-shaking/#mark-the-file-as-side-effect-free) — also honored by Vite 6's underlying Rollup — the absence of this field forces bundlers into the conservative mode: every module reachable from a barrel re-export (such as `runtime-entry.ts`'s `export * from './dna'`) is assumed to have side effects on import and is preserved in the output even when none of its named exports are consumed.

The opposite default (`"sideEffects": false`) tells the bundler that importing any module from this package has no observable effect beyond the named exports the consumer actually references. Rollup is then free to drop entire transitive subgraphs.

### Audit findings (2026-05-10)

The following was verified before drafting this decision, to confirm the package is genuinely safe to flag:

1. **No global CSS imports.** `grep -rn "^import .*\.css" packages/core/src/` returns no matches. The `admin-skin.css` that previously lived here was migrated to the tenant's `index.css` per ADR-0009 D6 / Task 1.2, leaving the runtime path CSS-free.
2. **No top-level mutations.** `runtime/theme/theme-manager.ts` exposes a singleton but initializes it lazily on first call, not at import time. `runtime/icons/IconRegistryContext.ts` is a pure React context factory.
3. **No polyfills or `window.*` writes at module scope.** The studio surface kept in the runtime per ADR-0009 D3 (`StudioContext`, `events`) only registers DOM listeners inside React components, never at module top-level.
4. **DNA barrel is pure.** `packages/core/src/dna/index.ts` re-exports `base-schemas` (Zod schema declarations), `cloudSaveStream` (function declarations), `deploySteps` (constant array), `OlonFormsContext` (React context factory), and `types/deploy` (types only). Every sub-module is a pure declaration body.
5. **No top-level `console.*`, `addEventListener`, or `Date.now()`** in any file reachable from `runtime-entry.ts`.

The full bundle entry (`src/index.ts` for the main `@olonjs/core` export) reaches into `studio/admin/*` and the form-factory chain. Those files were also spot-checked: the heavy modules (`AdminSidebar`, `FormFactory`, `StudioStage`) are React component declarations, and the orchestration entry points wire side effects only inside hooks / effects, never at module scope.

### Why the runtime-entry surface is not the lever

A common alternative would be to prune `runtime-entry.ts` exports. The audit makes it clear this would not help:

| Export | Consumer (verified) |
|---|---|
| `OlonJSEngine` | `apps/olonjs.io/src/App.tsx` |
| `JsonPagesConfig`, `LibraryImageEntry`, `AddSectionConfig` | `apps/olonjs.io/src/App.tsx`, `apps/olonjs.io/src/lib/addSectionConfig.ts` |
| `resolveRuntimeConfig` | `apps/olonjs.io/src/entry-ssg.tsx` |
| `cn` | 30+ tenant UI primitives |
| Kernel types (`PageConfig`, `SiteConfig`, `ThemeConfig`, `MenuConfig`, `MenuItem`, `BaseSection`, `SectionType`, `ProjectState`) | `apps/olonjs.io/src/types.ts` (re-export pivot) |
| `ConfigProvider`, `useConfig` | `apps/olonjs.io/src/entry-ssg.tsx`, `apps/olonjs.io/src/components/tiptap/View.tsx` |
| `PageRenderer`, `SectionRenderer` | `apps/olonjs.io/src/entry-ssg.tsx` |
| `ThemeLoader`, `themeManager` | engine internals (eager) |
| `normalizeBasePath`, `withBasePath` | `apps/olonjs.io/src/App.tsx` |
| `resolveAssetUrl` | several tenant Views |
| `DefaultNotFound` | engine internals |
| `StudioProvider`, `useStudio`, `STUDIO_EVENTS` | tenant section views (`tiptap`) and `App.tsx` |
| `IconRegistryContext`, `useIconRegistry` | engine internals |
| DNA: `BaseSectionData`, `BaseArrayItem`, `CtaSchema`, `ImageSelectionSchema`, `WithFormRecipient`, `useFormState`, `OlonFormsContext`, `DEPLOY_STEPS`, `startCloudSaveStream`, `DeployPhase`, `StepId`, `StepState`, `DeployStep`, `FormState` | tenant schemas, `App.tsx`, `save-drawer/*` |

Pruning is therefore a non-option. The `sideEffects: false` flag is the correct lever.

## Decision

`packages/core/package.json` declares the package as side-effect-free.

1. **Add `"sideEffects": false`.** Place it alphabetically near the existing top-level fields, between `"main"` and `"exports"`. The field is read by Rollup, Webpack, esbuild, and Vite during tenant builds and unlocks transitive dead-code elimination across the `export * from './dna'` barrel and any other barrel currently in the tree.

2. **No source-code change.** The audit above confirms zero genuine side effects in the import graph reachable from either subpath entry. Should a future audit surface a side-effect file (e.g. a future global CSS asset), switch to the array form `"sideEffects": ["dist/**/*.css", "<specific path>"]` rather than reverting to `false`-absent.

3. **Boundary check remains the publish gate.** `npm run test:boundary -w @olonjs/core` continues to walk the import graph from `src/runtime-entry.ts` and fails on regressions into `studio/admin/*` or `studio/orchestration/*`. The new `sideEffects: false` flag does not weaken that gate; it operates orthogonally (one is build-time correctness, the other is import-graph compliance).

4. **Tenant rebuild verifies the flag is observed by Vite/Rollup.** The proposal predicted a ≥ 100 KB raw / ≥ 30 KB gzipped main-chunk drop on `apps/olonjs.io`, with an expected Lighthouse delta of LCP −500 ms / TBT −100 ms / +5–8 points. Empirical measurement (2026-05-10, full rebuild before-and-after) showed **0 KB delta on the tenant main chunk**. The flag is still observed by the bundler and is correct as a description of the package's properties; the tenant just doesn't have any unused-DNA surface to recover. Root cause analysis is documented in Implementation notes below.

5. **No version bump strategy yet.** This is a metadata-only change. Per semver convention it could be argued as patch (no behavioral change) or minor (bundle output changes for downstream consumers). Decision deferred to the release flow described in `docs/PUBLISHING.md`; default leaning is patch unless tenant CI surfaces an unexpected break.

## Alternatives Considered

### A — Leave `sideEffects` unset, rely on per-module pure annotations

- **Pros:** No package contract change; tenants that misuse `@olonjs/core` are not affected.
- **Cons:** `/*#__PURE__*/` annotations only help expression-level DCE, not module-level pruning. They do not address the barrel re-export issue (`export * from './dna'`), which is where the unused code originates. The 260 KB unused JS measurement remains.
- **Rejected because:** the data shows the dominant cost is module-level retention, not expression-level. `sideEffects: false` is the correct granularity.

### B — Switch barrels to explicit re-exports (drop `export * from './dna'`)

- **Pros:** Bundler-friendly without any `sideEffects` declaration; works for older Rollup versions.
- **Cons:** Requires maintaining an explicit list of every DNA export in `runtime-entry.ts` (currently ~14 names); every new DNA primitive becomes a two-place edit. The DNA module specifically is designed to be a barrel so framework primitives can be added without touching the entry. Modern Rollup (Vite 6) tree-shakes barrels correctly *if and only if* `sideEffects: false` is declared.
- **Rejected because:** higher maintenance cost for the same outcome. The barrel is a feature, not an accident.

### C — Split `@olonjs/core/dna` into a third subpath export

- **Pros:** Tenants that don't need DNA (none currently, but conceivable) skip the import entirely.
- **Cons:** Adds a third bundle to the dual-bundle architecture established in ADR-0009. Requires updating `vite.config.runtime.ts`, `scripts/build-dual.mjs`, and the tenant import surface. Three-way module augmentation in tenant `types.ts` (currently two-way per ADR-0009).
- **Rejected because:** disproportionate. The DNA surface is small enough that `sideEffects: false` plus tree-shaking achieves the same effective outcome with no architectural cost.

### D — Per-file `"sideEffects"` array

- **Pros:** Most conservative — explicitly lists which files have side effects.
- **Cons:** Requires maintenance every time a file is added; easy to forget and silently lose tree-shaking opportunities. The audit shows zero side-effect files exist today.
- **Rejected because:** if zero files have side effects, `false` is correct and lower-maintenance. Switch to the array form *only if* a future audit surfaces a genuine side-effect file.

### E — Use Vite's `optimizeDeps` config in tenant repos

- **Pros:** Tenant-controlled; no package contract change.
- **Cons:** `optimizeDeps` controls dev-mode pre-bundling, not production tree-shaking. Wrong tool for this problem. Also pushes the responsibility to every tenant rather than declaring it once at the package level.
- **Rejected because:** category error — tenant config cannot tell Rollup that a third-party module is pure if the package itself has not declared so.

## Consequences

### Positive

- The package contract is now correct: `sideEffects: false` accurately describes the package's properties (verified by the audit in §Audit findings, re-verified at implementation time). Bundlers consuming `@olonjs/core` no longer have to assume conservative semantics.
- Future tenants with **different consumption profiles** benefit automatically. A hypothetical tenant that imports only `useFormState` from DNA (and not the rest) will now drop the unused DNA modules — under the old metadata, the entire `./dna` barrel would have been retained. No documentation is required for that tenant to opt in.
- Any future contributor adding a side-effect file (e.g. a global CSS import, a top-level `window` mutation) will produce a tenant-side regression that surfaces during smoke tests, rather than silently shipping dead-code retention forever. The ADR's audit checklist is the durable reference for what the flag promises.

### Neutral / Empirically zero

- **No measurable bundle-size delta for `apps/olonjs.io`** (the only tenant in this monorepo as of 2026-05-10). The expected ≥ 100 KB raw drop did not materialize. See Implementation notes for the root cause.
- **No Lighthouse delta** on the visitor critical path for this tenant. The +5–8 points predicted by §Decision §4 must be sought elsewhere on the ADR-0008 perf roadmap.

### Negative

- Strict obligation on `@olonjs/core` maintainers: no module reachable from either subpath entry may introduce a top-level side effect without simultaneously updating `sideEffects` to the array form. Violating this contract silently breaks tenants in subtle ways (missing global CSS, missing event listener, missing polyfill).
- The boundary check (`test:boundary`) does not cover side-effect detection. We accept this gap and rely on code review + the audit checklist (recorded above) at PR time. A follow-up may extend the boundary script to grep for top-level CSS imports and `addEventListener` calls.
- If an external consumer was unknowingly relying on a side effect (e.g. importing the package for its CSS-injection behavior), they will silently lose that effect after upgrade. We do not believe such a consumer exists — admin-skin.css migration in ADR-0009 D6 already broke any such reliance — but this is a theoretical risk worth acknowledging in release notes.

### Implementation notes

The proposal predicted a ≥ 100 KB raw / ≥ 30 KB gzipped reduction on `apps/olonjs.io`'s main visitor chunk. Empirical measurement (full rebuild before and after the flag, no other changes between runs):

| Metric | Before flag | After flag | Delta |
|---|---|---|---|
| Tenant main chunk raw | 815.03 KB | 815.03 KB | **0** |
| Tenant main chunk gz | 229.84 KB | 229.84 KB | **0** |
| `olonjs-core-runtime.js` | 127.94 KB / 28.50 gz | 127.94 KB / 28.50 gz | 0 |

**Root cause: `apps/olonjs.io` already consumes the full barrel surface of `@olonjs/core`.** The `runtime-entry.ts` exports are mostly explicit named re-exports — already tree-shakable without `sideEffects: false` because each `export { Foo } from './path'` is a unique edge Rollup can drop independently. Only one barrel exists: `export * from './dna'`. That barrel re-exports five sub-modules:

```
./lib/base-schemas      → consumed by every tenant section schema
./lib/cloudSaveStream   → consumed by App.tsx
./lib/deploySteps       → consumed by App.tsx + save-drawer
./lib/OlonFormsContext  → consumed by App.tsx
./types/deploy          → consumed by App.tsx + save-drawer
```

`apps/olonjs.io` consumes all five. There is therefore no DNA module that the flag could newly drop — the barrel was already producing the same set of bytes as fully tree-shaken explicit re-exports.

The "260 KB unused JS" measurement from the 2026-05-09 Lighthouse audit, which originally motivated this ADR's predicted size win, must come from sources OUTSIDE `@olonjs/core`. Likely candidates (not yet attributed):

- Tenant-internal components with unused exports across `apps/olonjs.io/src/components/`.
- Third-party libraries pulled by tenant code: `motion/react`, `@radix-ui/*`, `lucide-react`, `react-router-dom`, `@tiptap/*`.
- Studio admin code that's reachable from the tenant build despite ADR-0009's split (would surface in `/admin` chunks, not the visitor critical path — needs verification).

The flag's correctness is independent of this measurement: it accurately describes what the package does (or doesn't do) on import. Future tenants with leaner consumption profiles will benefit. For `apps/olonjs.io` specifically, further Lighthouse gains require attacking the actual unused-JS sources listed above — a separate analysis that ADR-0008 §Phase C should pick up.

**Lesson for future ADRs:** when predicting a bundle-size win, attribute the unused JS to a specific source before declaring the lever. The 2026-05-09 audit reported 260 KB unused without breaking it down by package; this ADR assumed the bulk was inside `@olonjs/core`. The assumption was wrong. A `dist/stats.html` or `rollup-plugin-visualizer` snapshot would have caught it.

### Requirements imposed on other parts of the system

- **`packages/core/package.json`** — gains the `"sideEffects": false` field.
- **`packages/core/CONTRIBUTING.md` (does not yet exist; see Follow-ups)** — should document the side-effect-free contract once first contributor onboarding requires it.
- **No tenant change required.** Tenants rebuild against the new package version and inherit the smaller chunk automatically. Existing `import` statements continue to work unchanged.
- **`docs/PUBLISHING.md`** — should reference this ADR in the verification section ("After `npm publish`, sanity-check…") so future reviewers know to spot-check the `sideEffects` field has not been accidentally dropped.

## Follow-ups

- [x] Implementation: add `"sideEffects": false` to `packages/core/package.json` (landed in v1.1.2, 2026-05-10).
- [ ] Extend the boundary checks (likely as a sibling to `check-singleton-modules.mjs` introduced by ADR-0012) to flag top-level CSS imports, top-level `addEventListener`, and top-level mutations in any file reachable from either entry. Non-blocking; current audit was manual and remains the contract.
- [ ] Add a one-line `sideEffects` reference to `docs/PUBLISHING.md` under the "Verifying the published artifacts" subsection (so reviewers spot-check the field hasn't been accidentally dropped during release).
- [ ] **Attribute the 260 KB unused JS by source.** Run `rollup-plugin-visualizer` (or equivalent) on the `apps/olonjs.io` production build and capture `dist/stats.html`. Then identify which packages contribute most to the unused-JS surface — likely `motion/react`, `@radix-ui/*`, `lucide-react`, or tenant-internal components. The ADR-0008 §Phase C interventions should target whichever surfaces are largest. This work was the missing prerequisite to ADR-0011's now-invalidated size prediction; capture it explicitly before drafting the next size-related ADR.
- [ ] Reconsider option B (explicit barrel) if tenant builds ever target a Rollup version older than the one Vite 6 ships with, e.g. for SSR adapters that pin older Rollup.

## Open Points

- Whether the change warrants a minor or patch version bump on `@olonjs/core`. Leaning patch (no behavior change, only bundle output change) but deferring to the release operator.
- Whether ADR-0009's CI-enforced boundary check should grow to cover side-effect detection in the same script, or be split into a sibling check (`check-side-effects.mjs`). Leaning sibling for separation of concerns; non-blocking.

## References

- ADR-0007 §4 — performance budget that this ADR helps satisfy.
- ADR-0008 — mobile-90 perf roadmap; this ADR is a Phase B-class intervention.
- ADR-0009 — `@olonjs/core` runtime/Studio split; defines the boundary check that this ADR runs orthogonally to.
- `packages/core/src/runtime-entry.ts` — audited entry surface (106 lines, 2026-05-10).
- `packages/core/src/dna/index.ts` — barrel re-export that benefits most directly from `sideEffects: false`.
- `packages/core/scripts/check-runtime-decoupling.mjs` — boundary check that remains the publish gate.
- Lighthouse mobile report 2026-05-09 — baseline (231 KB gz main chunk, 32 % unused).
- [Webpack tree-shaking docs — sideEffects field](https://webpack.js.org/guides/tree-shaking/#mark-the-file-as-side-effect-free).
- [Rollup tree-shaking and package.json conventions](https://rollupjs.org/configuration-options/#treeshake).
