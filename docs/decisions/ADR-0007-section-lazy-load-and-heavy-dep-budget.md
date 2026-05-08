# ADR-0007: Section capsule lazy-loading and heavy-dependency budget for tenant apps

## Status

Proposed — pending implementation, performance verification, and maintainer acceptance (2026-05-08)

## Date

2026-05-08

## Scope

Tenant runtime bundle of OlonJS apps (immediate target: `apps/olonjs.io`). Conventions added on top of CIP v1.7 (Component Implementation Protocol) and TBP v1.1 (Tenant Block Protocol). No change to the public surface of `@olonjs/core`.

## Context

Lighthouse on `https://olon.js.org` (2026-05-08, Lighthouse 13.3.0) reports a **mobile Performance score of 42** (target: 90+) with **LCP 7.3s**, **TBT 1300ms**, **TTI 10.5s**. Desktop is 81 with LCP 2.4s and TBT 80ms. CLS is 0 on both. Server response time is 80–190ms (not the bottleneck).

The mobile collapse is dominated by JavaScript execution, not network or images:

- `index-CDTUJmai.js` — **1,348 KB raw / 392 KB gzipped**, **44% (591 KB) unused** on first load. Three long tasks of 483 / 362 / 330 ms attributed to this file.
- `wasm-CG6Dc4jp.js` — **608 KB raw / 229 KB gzipped**, 0% unused. Identified as the Shiki + Oniguruma WASM runtime, pulled in synchronously by `code-block/View.tsx` (`import { codeToHtml } from "shiki"`).
- Shiki language grammars (`typescript-*.js` 177 KB, `tsx-*.js` 171 KB) are eagerly fetched.
- Google Tag Manager (`gtag/js`) — **463 KB raw / 157 KB gzipped**, 42% unused, contributes 2 long tasks of 103–115ms.
- Section components (`premium-hero`, `content-7`, `scroll-accordion`, `code-block`, `sticky-section`) are statically imported by `ComponentRegistry.tsx` and end up in the initial chunk regardless of whether they are above the fold.
- The hero raster (`plug-graded-square.jpg`, 203 KB) arrives late on mobile because the main thread is busy parsing the JS above. It is the most likely LCP element.

The architectural cause is structural, not incidental:

- **CIP v1.7** does not currently constrain how heavy a section's import graph may be, nor how it must lazy-load runtime-only dependencies (highlighters, animation libraries, rich-text editors).
- **TBP v1.1** describes a Section Capsule's *shape* (`View.tsx` + `schema.ts` + `types.ts` + `index.ts`) but is silent on how the capsule should be *loaded*.
- `ComponentRegistry.tsx` exposes section components as eager references, so Vite has no signal to split them.

The downstream consequence is that every tenant built on the reference template inherits this profile: a single ~1.3 MB JS chunk that ships every Section View, its animation/highlighting deps, and the editor surface, even on cold-cache mobile visits to a content page.

This ADR establishes the conventions needed to make tenant bundles structurally fast by default. It does **not** mandate a specific implementation in `@olonjs/core`; the engine already accepts whatever React component the tenant places in `ComponentRegistry`, including ones produced by `React.lazy`.

## Decision

We add three conventions to the tenant build contract. They apply to `apps/olonjs.io` immediately and to any future tenant scaffolded from the alpha template.

### 1. Section Views are lazy-loadable

Every entry in `ComponentRegistry` MAY be a `React.lazy(() => import('@/components/<name>'))` reference instead of a static import. Sections that are not guaranteed above-the-fold on at least one published page MUST be lazy. The engine renders sections inside its existing Suspense-friendly tree; tenants render a `<Suspense fallback={…}>` boundary around the section list (or use the engine's existing skeleton), so streaming a missing chunk does not break hydration.

Concretely for olon.js.org: only `header`, `footer`, and `premium-hero` remain eager. `content-7`, `scroll-accordion`, `code-block`, `sticky-section`, and any section type whose schema imports a heavy library become lazy.

### 2. Heavy runtime dependencies are loaded on demand inside the View

A View MUST NOT statically import any of the following library categories at module top-level:

- Syntax highlighting engines and grammars (`shiki`, `@shikijs/*`, `highlight.js`, `prismjs`).
- Rich-text editors (`@tiptap/*`, `prosemirror-*`, `slate`, `lexical`).
- Markdown renderers and their plugin chains when used only inside specific sections (`react-markdown` + `remark-*` + `rehype-*`).
- Animation libraries above the smallest tier (`motion/react` for non-trivial animation graphs).

The View imports these inside an effect or via `React.lazy`/`import()` and renders a non-blocking placeholder (raw `<pre>` for code, plain prose for markdown, static element for animation) until the chunk resolves. The placeholder MUST preserve layout dimensions to keep CLS at 0.

For Shiki specifically: the View calls `getSingletonHighlighter({ langs: [...explicit subset...] })` inside `useEffect`, never `codeToHtml` at module scope. The language list is the smallest set actually used by the tenant content.

### 3. Third-party analytics scripts are deferred past first interaction

The tenant `index.html` MUST NOT execute analytics scripts (Google Tag Manager, Plausible's auto-loader, Hotjar, etc.) during initial HTML parsing. Loading happens after `load` or via `requestIdleCallback`, optionally gated on user interaction. The `gtag('config', …)` call moves to that deferred loader.

This is a tenant-level convention; `@olonjs/core` neither knows nor cares about analytics.

### 4. Performance budget enforced in CI

The tenant repo adds a budget check (`size-limit` or equivalent) that fails CI when the initial JS chunk exceeds **220 KB gzipped** or when total transferred JS on the published home page exceeds **500 KB gzipped**. The exact tool is an implementation detail; the budget is the contract.

## Alternatives Considered

### A — Optimize images only, leave JS as is

- **Pros:** Smallest change; zero risk of breaking section rendering.
- **Cons:** The Lighthouse data shows the LCP is gated on main-thread availability, not network. Even reducing the hero raster to AVIF leaves TBT at ~1.3s and TTI at ~10s on mobile. Score would improve marginally (estimated 42 → ~55), well below the 90+ target.
- **Rejected because:** evidence-driven — the bottleneck is JS execution, not byte weight of images.

### B — Move to SSR / SSG with hydration

- **Pros:** Largest possible LCP improvement; HTML-first rendering bypasses the JS parsing cost for first paint.
- **Cons:** Requires a runtime change in `@olonjs/core` (SSR build, hydration markers) and rethinking the Studio editor surface. Months of work; cross-cuts ADR-0006 (data router migration) and the Studio architecture.
- **Rejected because:** out of scope and disproportionate to the current need. We can reach 90+ with code-splitting alone.

### C — Replace Shiki with a smaller highlighter (e.g. `lowlight`/`highlight.js` subset, or server-precomputed HTML)

- **Pros:** Permanent removal of the WASM payload; no runtime highlight cost.
- **Cons:** Lower output fidelity; would still leave the rest of the JS bundle problem (591 KB of unused code in the main chunk) untouched.
- **Rejected as a primary fix, kept as a follow-up:** lazy-loading Shiki removes it from the critical path with no quality loss. If, after lazy-loading, the deferred WASM payload still degrades INP when a user scrolls to the code block, we revisit with a precompute approach. This becomes a follow-up, not a blocker.

### D — Inline-defer GTM via `<script defer>` only

- **Pros:** Trivial change.
- **Cons:** `defer` still blocks the browser idle window during initial render and runs before `DOMContentLoaded`. Lighthouse still attributes long tasks to it.
- **Rejected because:** `requestIdleCallback`/post-`load` loading is just as easy and removes the script from the first-render budget entirely.

## Consequences

### Positive

- Mobile Performance score expected to clear 90 with the three conventions applied to `apps/olonjs.io`. Modeled gains: removing Shiki + grammars + WASM from the initial chunk eliminates ≥1 MB of raw JS and the 330–483ms long tasks. Deferring GTM removes the 103–115ms long tasks. Lazy-loading below-fold sections cuts the 591 KB unused JS in `index-*.js`.
- Future tenants scaffolded from the alpha template inherit a fast-by-default profile.
- The contract is explicit: a reviewer can reject a PR that statically imports Shiki at module top-level, citing this ADR.

### Negative

- Slightly more boilerplate per Section View that uses a heavy library: the import moves into an effect, with a placeholder render path.
- Suspense boundaries become part of the tenant's mental model. The error-boundary story for "chunk failed to load" must be handled (we already have `EngineErrorBoundary`; tenants need an explicit retry UX for chunk loads).
- Studio (the editor surface) must continue to load the heavy editor stack eagerly when in edit mode. We accept that Studio is *not* subject to the same budget as the public runtime; this ADR's budget targets the visitor-facing first load.

### Requirements imposed on other parts of the system

- **Tenant repos** following the alpha template MUST update `ComponentRegistry.tsx` to use `React.lazy` for non-critical sections.
- **Tenant `index.html`** MUST move analytics initialization out of synchronous head execution.
- **CI** in tenant repos MUST run the budget check on PR.
- **`@olonjs/core`**: no required changes. The engine already tolerates lazy components in `ComponentRegistry`. We may, in a follow-up, ship a documentation update in the CIP spec citing this ADR as the canonical guidance.

## Follow-ups

- [ ] Draft an implementation plan in `docs/plans/perf-olonjs-io.md` that executes against this ADR and includes exit measurements.
- [ ] Update CIP v1.7 prose (`specs/olonjsSpecs_V_1_6.md`) to reference this ADR under "View component rules" — non-blocking but should land in v1.7-patch.
- [ ] Decide whether `@olonjs/core` should ship a `<LazySectionFallback />` component to reduce per-tenant boilerplate. Defer until two tenants have implemented the convention by hand.
- [ ] Re-evaluate option C (precomputed Shiki HTML at build time) once lazy-loading is deployed and we have INP measurements for the code-block-in-viewport case.

## Open Points

- Exact tooling for the CI budget check (`size-limit` vs. `bundlesize` vs. Lighthouse CI assertions). Leaning `size-limit` for the initial-chunk budget plus `lhci` for the holistic Performance score gate, but the implementation plan will choose.
- Whether to include `react-markdown` + plugins in the heavy-deps list for olon.js.org specifically. It is currently used in section views; whether it's worth lazy-loading depends on bundle-visualizer output during implementation.

## References

- Lighthouse reports captured 2026-05-08: `olon-mobile.report.html`, `olon-desktop.report.html` (local).
- `apps/olonjs.io/src/components/code-block/View.tsx` — Shiki entry point that drives the WASM and grammar payloads.
- `apps/olonjs.io/src/lib/ComponentRegistry.tsx` — eager section registry; primary refactor target.
- `apps/olonjs.io/index.html` — synchronous GTM script; refactor target.
- CIP v1.7, TBP v1.1 — protocols this ADR extends conventionally.
- ADR-0006 — concurrent router migration; this ADR is independent and can land before, after, or alongside it.
