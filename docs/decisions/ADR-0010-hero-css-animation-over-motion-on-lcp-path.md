# ADR-0010: Replace `motion/react` with CSS animations on the LCP path

## Status

Proposed — pending implementation and Lighthouse verification (2026-05-10)

## Date

2026-05-10

## Scope

The visitor-facing hero of `apps/olonjs.io` (`premium-hero/View.tsx`) and any future tenant section that owns the LCP element. No change to `@olonjs/core`. Other tenant sections that use `motion/react` below the fold (`header`, `footer`, `premium-cta`) are explicitly out of scope.

## Context

ADR-0008 set a target of mobile Lighthouse Performance ≥ 90. The 2026-05-09 baseline run on `https://olon.js.org/` reports **mobile 67 / desktop 95** (Lighthouse 13.3.0, Moto G Power emulation, 4G throttle). The mobile gap is overwhelmingly driven by **LCP 3881 ms with 3718 ms (≈ 96 %) attributed to *element render delay***, not network or server time:

- The LCP element is the hero `H1` inside `TwoToneHeading`, currently wrapped by a `motion.div` chain authored in `apps/olonjs.io/src/components/premium-hero/View.tsx`.
- The element only renders once `motion/react` has parsed, the `useReducedMotion()` hook has resolved, and the `fadeUpVariants` spring transition has begun. Under 4× CPU throttling this is consistently 2.5–3.0 s on the test device.
- Two long tasks of 374 ms each in the main bundle (React render passes that include motion's variant resolution) confirm the JS execution cost is on the critical path.

Inspection of `premium-hero/View.tsx` (276 lines, last read 2026-05-10) shows seven motion-animated elements: the ambient gradient (simple opacity 0→1 over 2 s), a badges container, the heading wrapper that owns the LCP H1, the subtitle paragraph, the CTAs row, the social-proof block, and per-avatar staggered entries. All seven use the same `fadeUpVariants` profile (opacity + 16 px translateY, spring duration 0.65 s, bounce 0.1) with custom delays of 0 / 0.22 / 0.34 / 0.5 / 0.56 + i × 0.05 s.

Architecturally, this is a misuse of `motion/react`: the animation graph is trivial (linear opacity/translate), there is no interactive state, no gesture, no layout animation — none of the features that justify the library's runtime cost. The same visual output can be produced by raw CSS keyframes with `animation-delay` for staggering, at zero JS cost on the LCP path.

Removing motion from the hero does not require touching the rest of the tenant. The same library is also used in `header/View.tsx`, `footer/View.tsx`, and `premium-cta/View.tsx`, but:

- `header` and `footer` motion is below the fold for the LCP measurement and contributes to TBT, not LCP.
- `premium-cta` is already lazy-loaded via section-level code splitting per ADR-0007 conventions.

A broader removal of `motion/react` from the entire site is a separate decision that should be re-evaluated after this ADR ships and the post-fix Lighthouse delta is measured. CIP v1.7 already discourages heavy animation libraries in capsules; ADR-0007 §2 lists `motion/react` for non-trivial graphs as a heavy dependency that must be lazy. This ADR is consistent with that direction but does not yet generalize it.

## Decision

The hero capsule replaces `motion/react` with native CSS keyframe animations. Specifically:

1. **Hero animations move to `apps/olonjs.io/src/index.css`.** Two `@keyframes` are defined in the existing utilities layer: `jp-fade-up` (opacity 0 → 1 with 16 px y-translate over 0.65 s) and `jp-fade-in` (opacity-only, 2 s, for the ambient gradient). A single utility class `.jp-anim-fade-up` wires the keyframe with `animation-fill-mode: both` so the pre-animation state is `opacity: 0` without flicker.

2. **`prefers-reduced-motion` is honored at the CSS layer, not in JS.** The keyframe rules are wrapped in `@media (prefers-reduced-motion: no-preference) { … }`. Reduced-motion users render the static end state immediately with zero JS gating. The `useReducedMotion()` hook is removed from the View.

3. **Stagger is expressed through `animation-delay`.** Each motion element becomes a plain `<div>` / `<p>` / `<span>` with `className="jp-anim-fade-up"` and inline `style={{ animationDelay: '<n>s' }}`. The avatar list uses `style={{ animationDelay: \`${0.56 + i * 0.05}s\` }}` per child — the same delay schedule as the previous spring chain.

4. **The hero View imports nothing from `motion/react`.** After this change, `grep -r "motion/react" apps/olonjs.io/src/components/premium-hero/` returns no matches.

5. **No new abstraction is introduced.** We do not author a `<FadeUp>` wrapper component, because that would re-introduce a JS layer on the LCP path. The hero is a one-off LCP-critical surface; raw CSS classes are the right abstraction level.

The LCP element identity is preserved (the H1 inside `TwoToneHeading` remains the same DOM node), but it is no longer gated by JS execution. Expected delta from the audit: **LCP −2.5 s, TBT −100 ms, Lighthouse mobile +12–15 points**, bringing the score into the 79–82 band before Intervention 2 (ADR-0011) is applied.

## Alternatives Considered

### A — Tune the existing motion configuration (smaller variant graph, layout="position", reduced spring)

- **Pros:** Smallest diff. Keeps the existing API surface inside the View.
- **Cons:** `motion/react` itself remains on the critical path; the import cost (~30 KB gz) and the React render-pass overhead do not go away. Even with a stripped variant graph, hydration must complete before the H1 renders, which is the dominant cost.
- **Rejected because:** the data shows the cost is the library being on the critical path at all, not the specific configuration. Tuning yields diminishing returns; removal yields the full delta.

### B — Author a shared `<FadeUp>` component used by hero, header, footer, premium-cta

- **Pros:** Reusable; consistent animation language across the tenant.
- **Cons:** Re-introduces a JS layer on the LCP path. If the component is `lazy`, it cannot animate the LCP element (which must render on first paint). If it is eager, we have rebuilt motion's render gate in tenant code.
- **Rejected because:** the LCP path must be JS-free. A reusable component for non-LCP sections is a fine future improvement but does not belong in this ADR.

### C — Drop hero animations entirely (static render, no fade)

- **Pros:** Maximum LCP win; zero JS, zero CSS animation cost.
- **Cons:** Visible regression in perceived polish on the marketing site. The fade-up is a deliberate brand cue.
- **Rejected because:** the CSS-only path delivers the same LCP win while preserving the visual intent. Removing the animation outright is unnecessary.

### D — Server-side render the hero with no client animation, then enhance after hydration

- **Pros:** True HTML-first paint.
- **Cons:** Requires SSR plumbing in `@olonjs/core`. The site already runs through the SSG bake (`apps/olonjs.io/scripts/bake.mjs`), but the bake renders the React tree to static HTML — the post-hydration animation re-flickers unless coordinated. ADR-0006 (data-router migration) and a broader SSR/hydration story are prerequisites.
- **Rejected as scope:** disproportionate to the goal. The CSS-only path achieves the same LCP outcome with a one-file change.

### E — Keep motion but lazy-load it via dynamic import inside `useEffect`

- **Pros:** Removes motion from the initial chunk.
- **Cons:** The hero still cannot animate until the chunk loads, which means either (i) a flash from static to animated (UX regression), or (ii) the H1 is hidden until the chunk arrives (LCP regression). Both are worse than the CSS-only path.
- **Rejected because:** the CSS-only path solves both problems simultaneously.

## Consequences

### Positive

- The LCP element renders on first paint with no JS gating. Expected mobile LCP improvement: −2.5 s. Expected Lighthouse mobile gain: +12–15 points.
- Reduced-motion users get a zero-cost, zero-flicker render via the media query — strictly better than the previous JS-resolved fallback.
- The hero capsule no longer imports `motion/react`. If the rest of the site eventually drops motion (ADR follow-up), the per-route bundle for the home page is already free of it.
- The pattern (`@keyframes` + `animation-delay` for stagger + `prefers-reduced-motion` media query) is reusable by any future LCP-owning section without authoring a new component.

### Negative

- A second animation idiom (CSS keyframes for hero, `motion/react` elsewhere) coexists in the tenant until a future ADR generalizes the move. This is a temporary inconsistency, accepted because the hero's LCP role makes it special.
- CSS animations cannot replicate spring physics exactly. The chosen `cubic-bezier` curve (to be tuned during Task 1.2 of the implementation plan) is an approximation. Acceptance is "feels equivalent within ~50 ms," not pixel-perfect.
- Per-avatar staggering uses inline `style={{ animationDelay }}` rather than a class, which is slightly less idiomatic for Tailwind-based codebases but unavoidable for dynamic delay values.

### Requirements imposed on other parts of the system

- **`apps/olonjs.io/src/index.css`** gains the `jp-fade-up` / `jp-fade-in` keyframes and the `.jp-anim-fade-up` utility. They live in the existing `@layer utilities` block, near the pre-existing `@keyframes fadeInUp`.
- **`apps/olonjs.io/src/components/premium-hero/View.tsx`** drops the `motion/react` import, the `Variants` type, the `fadeUpVariants` constant, the `useReducedMotion()` hook call, and replaces all seven `motion.*` elements with plain DOM elements + CSS class.
- **No change to `@olonjs/core`.**
- **No change to `package.json`.** `motion` remains a tenant dependency until the broader migration in a follow-up ADR removes it from the other capsules.

## Follow-ups

- [ ] After Lighthouse re-measure, decide whether to extend the same pattern to `header`, `footer`, and `premium-cta` in a separate ADR. Trigger condition: combined post-fix score still < 90 *and* `motion/react` is the next-largest contributor to TBT.
- [ ] Once two or more capsules use the CSS-keyframe pattern, consider promoting `.jp-anim-fade-up` to a documented tenant utility in `index.css` with usage notes.
- [ ] Update ADR-0008 status section after the post-fix Lighthouse run lands (Task 3.2 in the implementation plan).

## Open Points

- The exact `cubic-bezier` curve that best approximates the previous `spring(0.65, bounce: 0.1)` will be tuned during Task 1.2. Leaning toward `cubic-bezier(0.16, 1, 0.3, 1)` (ease-out-quint) as a starting point.
- Whether `prefers-reduced-motion: reduce` should also disable the ambient gradient fade. Current decision: yes, both keyframes wrapped in the same media query, for consistency. Re-evaluate if reduced-motion users report perceived "abruptness."

## References

- ADR-0007 §2 — heavy-dependency budget that lists `motion/react` for non-trivial graphs.
- ADR-0008 — mobile-90 perf roadmap; this ADR is a Phase A-class intervention.
- ADR-0009 — Studio split via `/runtime` subpath; shapes the boundary check that this ADR does not violate (no Studio admin import added).
- `apps/olonjs.io/src/components/premium-hero/View.tsx` — primary refactor target (276 lines as of 2026-05-10).
- `apps/olonjs.io/src/index.css` — keyframe injection site (existing utilities layer at line ~821 already hosts `@keyframes fadeInUp` precedent).
- Lighthouse mobile report 2026-05-09 — baseline (score 67, LCP 3881 ms, TBT 842 ms).
- CIP v1.7 — Component Implementation Protocol; this ADR aligns with its "View must not gate first paint on heavy JS" principle without amending the spec.
