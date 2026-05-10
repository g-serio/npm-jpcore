# ADR-0008: Performance roadmap from Lighthouse mobile 58 to ≥ 90

## Status

Accepted as roadmap (2026-05-09). Per-phase status:

- **Phase A — Tactical wins on the visitor critical path:** *In flight.* Non-blocking Google Fonts CSS, deep schema imports in `lib/schemas.ts` and `lib/ComponentRegistry.tsx`, GTM deferred to first-interaction-or-10s, and explicit `width`/`height` on shield badges shipped in commit `4ee9d8e` and deployed to `olon.js.org`. Post-deploy Lighthouse measurement is the next gate.
- **Phase B — Studio / runtime decoupling:** *Done.* Implemented per [ADR-0009](./ADR-0009-core-studio-split-via-runtime-subpath.md); `@olonjs/core` v1.1.0 ships dual bundles; tenants migrated; boundary check enforced.
- **Phase C — Polish and budget guards:** *Pending.* Triggered only if Phase A + Phase B together fall short of mobile Performance ≥ 90.

## Date

2026-05-08 (proposal) · 2026-05-09 (acceptance as roadmap; Phase B closed, Phase A in flight)

## Scope

`apps/olonjs.io` tenant first-load performance, with a controlled ripple into `@olonjs/core` for **Phase B only**. Establishes the sequencing and decision boundaries for the work that remains after [ADR-0007](./ADR-0007-section-lazy-load-and-heavy-dep-budget.md) and the four slices (defer GTM, lazy Shiki, lazy below-fold sections, optimize hero image) shipped in the `claude/busy-knuth-3be562` branch.

This ADR does not redo ADR-0007. It picks up where ADR-0007's measurement gate left off and commits to a strategy for closing the remaining gap to a Lighthouse mobile Performance ≥ 90.

## Context

Lighthouse 13.3.0 measurements after the ADR-0007 implementation (run 2026-05-08, throttled mobile, Moto G Power emulation):

| Metric | Baseline | After ADR-0007 implementation | Δ |
|---|---|---|---|
| Performance (mobile) | 42 | **58** | +16 |
| Performance (desktop) | 81 | **83** | +2 |
| LCP (mobile) | 7.3 s | 4.9 s | −2.4 s |
| TBT (mobile) | 1300 ms | 860 ms | −440 ms |
| Speed Index (mobile) | 7.2 s | 4.5 s | −2.7 s |
| CLS | 0 | 0 | — |

The 16-point mobile gain validates the bundle/lazy-loading hypothesis, but mobile is still 32 points short of the 90 target. Lighthouse points at three independent sources for the remaining gap, in decreasing impact order:

1. **Render-blocking `fonts.googleapis.com/css2?…`** — Lighthouse: *Est savings of 1,450 ms on LCP*. The Google Fonts stylesheet is 1.4 KiB but blocks the critical path, costing ~1.5 s on throttled mobile.
2. **Main JS chunk `index-*.js` is still 1,322 KB raw / 395 KB gzipped** — bootup time of ~1.4 s on mobile. The chunk contains the entire `@olonjs/core` package, which bundles **both** the visitor-facing engine **and** the Studio editor. Visitors never use Studio yet pay its cost.
3. **Operational tail** — four oversized PNGs (~57 KB wasted), a 10-minute cache TTL on hashed assets where 1-year `immutable` is appropriate (752 KiB and ~1.5 s LCP saved on repeat view).

These three categories sit at very different levels of architectural impact:

- **Category 1** is a one-line `<link>` change in `index.html` — pure tenant, no Core involvement.
- **Category 2** requires a structural change to `@olonjs/core`: split Studio from the runtime. Public-API visible. Likely a minor version bump.
- **Category 3** is operational config (`vercel.json`, image processing).

ADR-0007 explicitly excluded Category 2 from its scope on the grounds that Core changes deserve their own decision record. This ADR is that record. It also commits to the sequencing of all three categories so the implementation work has a clear order and stop conditions.

The strategy must respect three non-negotiable constraints:

- **Studio must keep working** in `/admin` and `/admin/preview`. Splitting Studio off the visitor path cannot silently degrade the editor experience.
- **`@olonjs/core` is published** to npm and downstream tenants depend on it. Any Core change must preserve the existing `JsonPagesEngine` import surface for tenants that don't opt into the split.
- **Measurement is the gate**. We do not commit to all three categories up front. We ship Phase A, measure, and only invest in Phase B if needed to clear 90. Phase C exists only as a contingent backup.

## Decision

A three-phase roadmap, each phase gated by a Lighthouse rerun before the next phase is approved.

### 1. Phase A — Critical-rendering-path fixes (tenant-only, no Core changes)

Three independent low-risk changes shipped together:

1. **Defer Google Fonts CSS via media-swap** in `apps/olonjs.io/index.html`:
   ```html
   <link rel="preload" as="style" href="…fonts.googleapis.com…" />
   <link rel="stylesheet" href="…fonts.googleapis.com…"
         media="print" onload="this.media='all'" />
   <noscript><link rel="stylesheet" href="…fonts.googleapis.com…" /></noscript>
   ```
   Recovers Lighthouse's stated 1,450 ms LCP saving. Trade-off: brief FOUT on first paint, masked by the existing `font-display: swap` URL parameter.

2. **Resize the four oversized PNGs** flagged by Lighthouse `image-delivery-insight`:
   - `1778141326605-DATACONTRACT.png` 512×512 → 256×256
   - `1778141660323-site_as_holon.png` 512×512 → 256×256
   - `1778141730071-2bgen_1_.png` 512×512 → 384×384
   - `1778098423562-olon-mark-dark-256.png` 256×256 → 96×96 (or switch to the existing `olon-mark-dark-128.png`)

   Reuses the `scripts/optimize-hero.mjs` sharp-based pattern. Adds explicit `width`/`height` to the `<img>` elements to keep CLS at 0.

3. **Cache headers in `apps/olonjs.io/vercel.json`**: 1-year `immutable` for `/assets/*` (content-hashed by Vite, safe), `must-revalidate` for HTML so deploys propagate.

**Stop condition:** if Phase A alone moves mobile to ≥ 90, work is done; promote ADR-0007 and ADR-0008 to `Accepted`. Estimated landing zone after Phase A: mobile 70–80.

### 2. Phase B — Split Studio from `@olonjs/core` (Core change, conditional)

Triggered only if Phase A leaves mobile below 90.

The goal is to remove Studio code from the bundle that visitors download. Studio is the visual editor used in `/admin` and `/admin/preview`; visitors of `/`, `/<slug>` and other content routes never need it but currently pay its full size and parse cost.

**Two-entry-point design** in `@olonjs/core`:

- `@olonjs/core` (existing import path) — full surface including Studio. Tenants that don't change anything keep working.
- `@olonjs/core/runtime` (new import path) — runtime-only export: `JsonPagesEngine`, `useConfig`, asset resolution helpers, schema runtime, no Studio.

The tenant `App.tsx` decides at startup which to load:

```tsx
// Pseudocode
const isStudio = window.location.pathname.startsWith('/admin');
const Engine = isStudio
  ? (await import('@olonjs/core')).JsonPagesEngine        // full
  : (await import('@olonjs/core/runtime')).JsonPagesEngine; // runtime-only
```

The two engines render the same section components. They differ in whether the Studio overlay UI, the working-draft state machine, and the editor primitives are present.

**Acceptance criteria for Phase B:**

- Visitor bundle (initial JS for `/`) drops to ≤ 250 KB gzipped (target; baseline after Phase A is 395 KB).
- Mobile Lighthouse Performance ≥ 90.
- Studio (`/admin`) opens and functions identically to today: section selection, inspector, working draft, save/deploy flow. No regression.
- `@olonjs/core` ships a minor version bump (from 1.0.x to 1.1.x). Existing tenants pinned to the major see no breaking change.

**What we accept:** the package double-export increases `@olonjs/core` build complexity. We accept this because the alternative is a permanent ~150 KB gzipped tax on every visitor of every tenant.

**Stop condition:** if Phase A + B clears 90 mobile, promote ADR-0007/ADR-0008/ADR-0009 (the Studio-split ADR drafted under this Phase) to `Accepted`. Estimated landing zone after A + B: mobile 88–92.

A separate ADR-0009 will be drafted at Phase B start to capture the Core-side technical decisions (export shape, tree-shaking guarantees, build pipeline, migration path for existing tenants). This ADR-0008 commits only to *that the split happens*, not to its exact mechanics.

### 3. Phase C — Optional polish (only if Phase A + B miss 90)

Reserved as fallback. Three independent investigations:

1. **Audit `motion/react`** usage in `premium-hero`, `footer`, `premium-cta`. Either:
   - Replace with CSS `@keyframes` for the 2–3 simple fade/translate animations, eliminating the `motion/react` runtime dependency from the visitor bundle, or
   - Lazy-load `motion/react` inside the View via `React.lazy` if the animations are non-trivial.
2. **Audit `@radix-ui/*` imports** for tree-shaking opportunities. Confirm with the bundle visualizer that we ship only the primitives the tenant actually mounts. Drop any pulled-in by accident.
3. **Subset Google Fonts more aggressively**: load only the weights present above the fold (likely Instrument Sans 400, 600, 700) on first paint, async-load the others.

Phase C is pure tenant work, no Core changes. Each item is independently shippable.

**Stop condition:** Phase C lands only if Phase A + B fails to clear 90 mobile. We expect not to need it.

## Alternatives Considered

### A — Ship everything in one big branch and measure once

- **Pros:** Single PR; one Lighthouse run; faster perceived velocity.
- **Cons:** No way to attribute the gain to individual changes; if mobile lands at, say, 78 instead of 92, we cannot tell whether Phase B is broken, Phase A under-delivered, or the test environment is noisy. Reverting bad work is difficult.
- **Rejected because:** ADR-0007 already proved the value of phase-by-phase measurement (mobile 42 → 58 attributable cleanly to four slices). Same discipline here.

### B — Skip Phase A and go straight to Phase B (Studio split)

- **Pros:** One change, big win, fewer touched files.
- **Cons:** Phase A's 1.45 s of font-related LCP would still bottleneck even after the Studio split. Phase A is cheap (one HTML file + four PNGs + one config file) and may, alone, get us very close to 90. Going straight to Phase B risks doing the harder work without the easy wins and being surprised that we still aren't at 90.
- **Rejected because:** Phase A is cheap insurance and may make Phase B unnecessary. No reason to skip it.

### C — Split Studio purely on the tenant side via dynamic imports, without changing `@olonjs/core`

- **Pros:** No Core change; no version bump; no migration concern.
- **Cons:** Studio is woven into `@olonjs/core` at the module level — its components and hooks are exported from the package and there is no public boundary to lazy-load. We would have to either (a) deep-import internal paths (fragile, breaks the public API), or (b) wrap the entire `@olonjs/core` import in `React.lazy`, which would lazy-load the runtime engine too — defeating the goal.
- **Rejected because:** the split has to happen at the package boundary. Doing it tenant-side requires monkey-patching that would be more brittle than a clean Core release.

### D — Migrate to SSR/SSG to bypass the JS execution problem entirely

- **Pros:** Largest possible LCP improvement; HTML-first rendering eliminates the JS bundle as the LCP gate.
- **Cons:** Months of work; touches the engine deeply; rethinks how Studio interacts with hydrated content; out of scope for a perf project.
- **Rejected because:** disproportionate. Phase B is sufficient to hit 90.

### E — Replace `@olonjs/core` with a thinner runtime entirely (rewrite)

- **Pros:** Could optimize for size from scratch.
- **Cons:** Throws away years of work; unrelated to the perf goal.
- **Rejected:** trivially.

## Consequences

### Positive

- Clear ordered roadmap with measurement gates between phases. Each gate is a real stop point: if mobile reaches 90, work ends; if it doesn't, the next phase has a quantified justification.
- ADR-0007 and ADR-0008 together cover the tenant-only work (Phases 1–4 and Phase A); a future ADR-0009 will isolate the Core-side decisions of Phase B. No mixing of tenant and Core decisions in a single record.
- Stop condition explicitly named: Phase A may be sufficient. We are not pre-committing to a Core change that may not be necessary.

### Negative

- The roadmap binds future work across at least two release boundaries (tenant deploy + Core minor version). Coordinating a Core release while measuring tenant performance adds complexity.
- Phase B requires careful migration management for any downstream tenants of `@olonjs/core` that exist outside this monorepo. The split is additive (`@olonjs/core/runtime` is a new entry, the existing `@olonjs/core` keeps working) but the new entry needs to be documented and supported.
- We accept that Phase C's outcomes are speculative. If Phase A + B somehow miss the target, Phase C is our last lever before considering SSR (which would require a new ADR superseding this one).

### Requirements imposed on other parts of the system

- **Tenant repo (`apps/olonjs.io`)**: ships Phase A immediately (post-greenlight); adopts the new `@olonjs/core/runtime` import after Phase B's Core release.
- **`@olonjs/core`**: gets a Phase B release with the runtime/full split. Public API expanded but not broken. CHANGELOG entry required.
- **Downstream tenants** (other than this one): unaffected unless they opt into the new runtime-only entry. Default behavior of `import { JsonPagesEngine } from '@olonjs/core'` stays unchanged.
- **CI**: `size-limit` budget from ADR-0007 still enforces ≤ 220 KB initial chunk; budget will be tightened after Phase B to reflect the new visitor-only baseline.
- **Specs**: CIP v1.7 prose may be updated to reference the runtime/full split as the canonical pattern for performance-sensitive tenants. Non-blocking.

## Follow-ups

- [ ] Implement Phase A as three slices in `apps/olonjs.io` (current branch). Commits per slice.
- [ ] Capture Lighthouse rerun results in `docs/plans/perf-olonjs-io.md` after Phase A.
- [ ] If mobile < 90 after Phase A, draft ADR-0009 for the Studio-split mechanics in `@olonjs/core` (export shape, tree-shaking strategy, build pipeline, migration guide). Do not start Core implementation before that ADR is `Accepted`.
- [ ] After Phase B (if needed), tighten the `size-limit` budget to reflect the new visitor-only chunk.
- [ ] Phase C is dormant until the Phase A + B measurement gate. Do not pre-implement.

## Open Points

- **Engine module split mechanics** — to be decided in ADR-0009 if Phase B triggers. Candidates: separate package (`@olonjs/core-runtime`), subpath export (`@olonjs/core/runtime`), or build-time conditional exports. Leaning towards a subpath export (`@olonjs/core/runtime`) because it keeps the package count at 1 and lets `package.json`'s `"exports"` field do the work.
- **Tenant App.tsx routing trigger** — pathname-based switch is the simplest, but a build-time flag (e.g. a different bundle entry for `/admin`) is also possible. Defer to ADR-0009.
- **Self-hosted fonts** — Phase A.1 uses media-swap, not self-hosting. If after Phase A + B we still see fonts as a measurable LCP contributor, self-hosting via `@fontsource/*` becomes a small Phase C item or a one-line update to this ADR. We do not pre-commit.

## References

- Lighthouse mobile + desktop reports captured 2026-05-08 (post-Phase-1-4) — see `docs/plans/perf-olonjs-io.md` "Mid-implementation measurement" section.
- [ADR-0007](./ADR-0007-section-lazy-load-and-heavy-dep-budget.md) — section lazy-loading and heavy-dep budget. Phases 1–4 of the implementation plan execute against it.
- `docs/plans/perf-olonjs-io.md` — execution plan; will be updated with Phase A details once this ADR is `Accepted`.
- `apps/olonjs.io/index.html` — target file for Phase A.1.
- `apps/olonjs.io/vercel.json` — target file for Phase A.3.
- `packages/core/src/**` — affected by Phase B (separate ADR-0009 will scope this).
- ADR-0009 (future, conditional) — Core-side mechanics of the Studio split.
