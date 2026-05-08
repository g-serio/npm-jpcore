# Implementation Plan: Performance optimization for `apps/olonjs.io`

Status: **Ready for incremental implementation** — pending user greenlight on each phase
Decision record: [ADR-0007](../decisions/ADR-0007-section-lazy-load-and-heavy-dep-budget.md)
Owner: tenant runtime (`apps/olonjs.io`)
Out of scope: changes to `@olonjs/core` public API; SSR/SSG migration; redesign of Studio bundle.

## Goal

Move `https://olon.js.org` Lighthouse Performance score from **42 mobile / 81 desktop** to **≥ 90 on both**, without changing visible UX, without breaking the Studio editor experience, and without modifying the `@olonjs/core` public surface.

## Baseline (2026-05-08, Lighthouse 13.3.0)

| Metric | Mobile | Desktop |
|---|---|---|
| Performance score | 42 | 81 |
| FCP | 2.1s | 1.3s |
| **LCP** | **7.3s** 🔴 | 2.4s ⚠️ |
| **TBT** | **1300ms** 🔴 | 80ms ✅ |
| Speed Index | 7.2s | 1.8s |
| CLS | 0 ✅ | 0 ✅ |
| TTI | 10.5s | 2.4s |
| Server response | 80ms | 190ms |

Top weighed assets on first load (both form factors):

| Asset | Raw | Gzipped | Unused |
|---|---|---|---|
| `index-CDTUJmai.js` | 1,348 KB | 392 KB | 591 KB (44%) |
| `wasm-CG6Dc4jp.js` (Shiki/Oniguruma) | 608 KB | 229 KB | 0% |
| `googletagmanager.com/gtag/js` | 463 KB | 157 KB | 195 KB (42%) |
| `plug-graded-square.jpg` (likely LCP) | 203 KB | 203 KB | — |
| `typescript-*.js` (Shiki grammar) | 177 KB | 17 KB | 0% |
| `tsx-*.js` (Shiki grammar) | 171 KB | 17 KB | 0% |

Long tasks attributed to `index-CDTUJmai.js` on mobile: 483ms, 362ms, 330ms.

## Architectural decisions (executed against)

All in [ADR-0007](../decisions/ADR-0007-section-lazy-load-and-heavy-dep-budget.md). Do not re-litigate. Summary:

1. Section Views are lazy-loadable; only above-fold sections stay eager.
2. Heavy runtime deps (Shiki, Tiptap, big motion graphs, markdown plugin chains) load on-demand inside the View.
3. Analytics deferred past first interaction.
4. CI budget: initial JS chunk ≤ 220 KB gzipped, total JS on home page ≤ 500 KB gzipped.

## Non-goals

- No changes to `@olonjs/core` source. The engine already supports lazy section components.
- No SSR/SSG. Out of scope (would justify a separate ADR).
- No redesign of the Studio editor bundle. Studio keeps its current eager loading; the budget targets the visitor-facing public runtime.
- No image art-direction pipeline yet. Hero image optimization is in scope (single asset), but a generic responsive-image component is deferred to a follow-up plan.

## Execution phases

Each phase is independently shippable. Each ends with a measurement step that gates the next phase. **Stop and report numbers after every phase before moving on.**

---

### Phase 0 — Measurement infrastructure

**Why:** ADR-0007 demands evidence-driven verification. Build the measurement pipeline first so each subsequent phase can prove its impact.

**Tasks**

1. Add `bundle-visualizer` script: `npm run build && npx vite-bundle-visualizer` (no permanent dep — invoked ad-hoc).
2. Add `size-limit` (or equivalent) with config asserting:
   - `dist/assets/index-*.js` ≤ 220 KB gzipped (will start failing — that's the point)
   - Sum of initial chunks loaded on `/` ≤ 280 KB gzipped
3. Document the manual Lighthouse check in `apps/olonjs.io/README.md`: command, target form factor, target score.
4. Capture the current `dist/` listing with sizes as a baseline file (e.g. `apps/olonjs.io/perf-baseline.txt`, gitignored or committed depending on preference) for diffing against future builds.

**Acceptance criteria**

- `npm run build && size-limit` runs and reports current sizes (failing the assertion is OK, expected).
- Bundle visualizer produces a treemap that confirms the Shiki/grammar/wasm split visible in Lighthouse.
- Baseline sizes recorded.

**Exit measurement:** baseline `dist/` chunk listing committed. No score change expected.

---

### Phase 1 — Defer Google Tag Manager

**Why:** Smallest, lowest-risk change. Removes 103–115ms long tasks and 463 KB raw / 157 KB gzipped from the critical path. Touches only `index.html`. Reversible in one commit.

**Tasks**

1. Remove the synchronous `<script async src="…gtag/js…">` and inline `gtag('config', …)` call from the `<head>` of `apps/olonjs.io/index.html`.
2. Add a deferred loader that:
   - Listens for `load` event (or `requestIdleCallback`).
   - Injects the GTM script tag.
   - Runs `gtag('js', new Date())` and `gtag('config', 'G-HZ9XVH9GK1')` after the script loads.
   - Respects `Do Not Track` if currently respected (audit current behavior; if not currently respected, no change).
3. Verify `dataLayer` initialization happens before the deferred script runs (initialize `window.dataLayer = []` synchronously, only the GTM payload is deferred).
4. Manual smoke test in browser DevTools: confirm GTM events still fire after page idle (e.g. page_view).

**Acceptance criteria**

- GTM no longer appears in the initial Network "blocking before load" group.
- `gtag` events still fire (check Network for `collect?…` requests).
- No regression in analytics dashboard delivery (measurable next day; not a CI gate).

**Exit measurement:** rerun Lighthouse mobile. Expected: TBT drops by 100–200ms; score moves from 42 → ~50–55.

---

### Phase 2 — Lazy-load Shiki and its grammars

**Why:** Largest single win. Removes ~960 KB raw / ~265 KB gzipped of JS+WASM from the critical path (`wasm-*.js` 608 KB + `typescript-*.js` 177 KB + `tsx-*.js` 171 KB + Shiki core in `index-*.js`). Eliminates the 483/362/330 ms long tasks tied to Shiki initialization.

**Tasks**

1. Refactor `apps/olonjs.io/src/components/code-block/View.tsx`:
   - Remove top-level `import { codeToHtml, type BundledLanguage, type CodeOptionsMultipleThemes } from "shiki"`.
   - Type imports stay as `import type { … }` (zero runtime cost).
   - Inside the component:
     - Initial render returns a non-highlighted `<pre><code>` with the raw code (preserves layout and content for SEO/non-JS readers).
     - `useEffect` calls `import('shiki')` then `getSingletonHighlighter({ langs, themes })` with an explicit, narrow `langs` array (audit content for actual languages used; likely `ts`, `tsx`, `json`, `bash`).
     - On highlighter ready, replaces the `<pre>` content with the highlighted HTML (via `dangerouslySetInnerHTML` as today, on the same node so layout doesn't shift).
   - Keep CLS at 0: ensure the placeholder `<pre>` has the same `font-family`, `font-size`, `line-height`, and `padding` as the highlighted output.
2. Audit `apps/olonjs.io/public/pages/*.json` and any markdown source for the actual set of code-block languages in use. Constrain Shiki's `langs` to that subset. Default themes (`github-light`, `github-dark`) likely stay.
3. If a `code-block` instance appears above the fold on any page, mark that page in this plan and decide whether to keep it eager-highlighted (acceptable trade-off if rare). For olon.js.org home, code-block is below the fold (verify against `home.json`).
4. Verify Vite splits Shiki + grammars into a separate chunk (visible in `dist/` listing and bundle visualizer).

**Acceptance criteria**

- Initial bundle no longer contains Shiki core, grammars, or oniguruma WASM.
- Network panel on first page load: no request to `wasm-*.js` or grammar chunks until scrolled to a code block.
- Code blocks render readable text immediately (placeholder), then upgrade to syntax-highlighted output.
- No CLS introduced (verify with Lighthouse — target stays at 0).

**Exit measurement:** rerun Lighthouse mobile. Expected: LCP improves materially (mobile target < 4s); TBT drops below 600ms; score moves to ~70–80.

---

### Phase 3 — Lazy-load below-fold Section Views

**Why:** Cuts the 591 KB of unused JS in `index-*.js` by removing eagerly-imported sections that are below the fold.

**Tasks**

1. Audit which sections render above the fold on home: `header`, `premium-hero`, possibly the start of `content-7`. Treat anything else as below-fold.
2. Refactor `apps/olonjs.io/src/lib/ComponentRegistry.tsx`:
   - For each section type that is not guaranteed above-the-fold across pages, replace the static import with `React.lazy(() => import('@/components/<name>'))`.
   - Stay eager: `header`, `footer`, `premium-hero`.
3. Ensure the engine renders sections inside a Suspense boundary. If the engine already provides one (verify in `JsonPagesEngine`), no tenant change needed. Otherwise, wrap the section list in `App.tsx` or the page renderer with `<Suspense fallback={<Skeleton />}>`.
4. For each lazy section, decide on the placeholder height/dimension to preserve CLS. The simplest is a fixed-`min-height` skeleton matching the section's typical viewport footprint.
5. Verify that `motion/react` does not get pulled into the initial chunk. If it does (because `premium-hero` uses it), accept it (premium-hero stays eager). If `footer`'s use of motion ends up in initial, audit whether the footer animation is essential or can become a CSS keyframe; this is an optional optimization within this phase.

**Acceptance criteria**

- `index-*.js` shrinks meaningfully (target: -40% raw size or better).
- Network panel: section chunks load as the user scrolls down (verify with throttled mobile profile).
- No visible jank on scroll due to chunk-load delay (loaded chunks should be small enough to land in <100ms on 4G).
- No CLS regression.

**Exit measurement:** rerun Lighthouse mobile. Expected: TBT < 200ms, score ≥ 85. Likely already ≥ 90 mobile if Phase 2 cleared most of the long tasks.

---

### Phase 4 — Optimize the LCP image and preload it

**Why:** Once JS is out of the way, the LCP element (likely `plug-graded-square.jpg`, 203 KB) is the next bottleneck. Single asset; targeted intervention.

**Tasks**

1. Identify the actual LCP element via Lighthouse "Largest Contentful Paint element" diagnostic on a fresh run after Phase 3.
2. Generate optimized variants of the LCP image with `sharp` (one-off script, no permanent build hook in this plan):
   - AVIF at 1×, 2× target widths.
   - WebP at 1×, 2× as fallback.
   - Keep the current JPG as final fallback.
3. Update the View that renders the hero (`premium-hero/View.tsx`) to emit a `<picture>` element with `srcset` + `sizes` + `width` + `height` + `fetchpriority="high"` + `decoding="async"` + `loading="eager"`.
4. Add `<link rel="preload" as="image" imagesrcset="…" imagesizes="…" fetchpriority="high">` for the LCP image in `index.html`. Pick a single resolution to preload (the most likely mobile width); browsers will discount the preload if the picked source doesn't match.
5. Verify the existing `<link rel="preload" as="image" href="/assets/images/1778098423562-olon-mark-dark-256.png">` for the logo is still useful or can be dropped (logo is small; preload may be net-neutral).

**Acceptance criteria**

- LCP image transferred size drops by ≥ 60% (target: < 80 KB on mobile).
- Lighthouse "Properly size images" and "Serve images in next-gen formats" no longer fire on the hero.
- LCP < 2.5s on mobile.

**Exit measurement:** rerun Lighthouse mobile and desktop. Target: both ≥ 90.

---

### Phase 5 — CI budget guardrail

**Why:** Prevent regression. ADR-0007 §4 mandates this.

**Tasks**

1. Wire `size-limit` into the tenant's lint/test pipeline (whichever pre-commit / CI surface exists). Make it bloccante on PR.
2. Document the budget in `apps/olonjs.io/README.md` with a one-paragraph note pointing to ADR-0007.
3. (Optional) Add a Lighthouse-CI step that asserts mobile Performance ≥ 90 on a deployed preview URL. This is heavier; only add if the deployment story supports preview URLs cheaply.

**Acceptance criteria**

- A PR that increases `dist/assets/index-*.js` past the budget fails CI.
- Documentation in `apps/olonjs.io/README.md` references ADR-0007 and explains how to query current budget status.

**Exit measurement:** none. This phase locks in the previous phases.

---

## Risks and mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Lazy-loaded Shiki shows ugly unstyled `<pre>` for hundreds of ms | Medium | Style the placeholder to match the highlighted output's typography; the upgrade should be visually smooth. Test on slow 4G. |
| Lazy-loaded sections cause visible loading skeletons that feel worse than eager rendering | Medium | Keep section chunks small (each Section View should be < 30 KB gzipped). On 4G this lands in <150ms; below the threshold for perceptible jank during scroll. If a chunk grows past 30 KB, audit deps. |
| Removing GTM from synchronous `<head>` breaks attribution for short bounces | Low | Page-view fires after `load` — for sessions that bounce in <500ms we lose the event. Acceptable: those sessions aren't useful for analytics anyway, and Lighthouse-driven users aren't real traffic. |
| `React.lazy` chunk-load failures are not currently retried by the tenant | Medium | The engine has `EngineErrorBoundary`; verify it covers chunk-load errors. If not, add a tenant-level retry via dynamic import resolution wrapper. Track as a follow-up; not a blocker for Phase 3. |
| Studio (edit mode) breaks because we lazy-loaded sections it expects to be present synchronously | Low | Studio renders the same `ComponentRegistry`; React.lazy works inside Studio too. Verify by entering Studio after Phase 3 and confirming sections still render in the Stage. |

## Verification matrix

After each phase:

- [ ] `npm run build` succeeds.
- [ ] `npm run preview` and a manual smoke test of `/` confirms no visual regression.
- [ ] Lighthouse mobile rerun captures the new metrics; numbers logged in this plan or a linked artifact.
- [ ] Studio (edit mode) opens and renders all sections.
- [ ] No console errors on first load or on scroll-triggered chunk loads.

## Definition of done

- Mobile Performance ≥ 90 on `https://olon.js.org/`.
- Desktop Performance ≥ 90 on `https://olon.js.org/`.
- CLS remains 0.
- `size-limit` budget enforced in CI.
- ADR-0007 status moved from `Proposed` to `Accepted` (only with explicit user confirmation).
- Update CIP v1.7 prose in `specs/olonjsSpecs_V_1_6.md` to reference ADR-0007 (follow-up, optional, not blocking the score target).

## Open questions for the user before starting Phase 1

1. Confirm we proceed phase-by-phase with a measurement gate between phases (recommended), vs. landing all phases in one branch and measuring once at the end.
2. Confirm CI integration: which CI surface should `size-limit` plug into? GitHub Actions? Vercel preview check? Local pre-push only?
3. Confirm the analytics-deferral approach: do we keep GTM, or is this a moment to consider a lighter analytics tool (e.g. Plausible)? If keeping GTM, deferring is straightforward; switching tools is a separate decision and out of scope here.
