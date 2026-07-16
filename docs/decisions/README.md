# Architecture Decision Records

This folder captures the *why* behind significant technical decisions in `npm-jpcore` (the OlonJS monorepo). Code shows *what* was built; ADRs explain *why it was built this way* and *what alternatives were considered*.

ADRs are the highest-signal documentation we can leave for future humans and agents working on this codebase.

## When to write an ADR

Write one when:

- Designing or changing a public API of `@olonjs/core` (contracts, manifests, config shape).
- Choosing between competing architectural approaches with meaningful trade-offs.
- Introducing a tenant-facing convention that downstream repos must follow.
- Adding or deprecating a framework, library, or major dependency.
- Making any decision that would be expensive to reverse.

Do **not** write one for trivial refactors, cosmetic changes, or prototypes.

## Conventions

- Filename: `ADR-NNNN-kebab-case-title.md` (4-digit zero-padded, sequential, never renumbered).
- Store in this folder. No subfolders.
- One decision per ADR. If a change bundles several decisions, split them.
- Status lifecycle: `Proposed` → `Accepted` → (`Superseded by ADR-NNNN` | `Deprecated`). Qualifiers are allowed when useful (e.g. `Proposed — pending implementation and verification`).
- **Never delete** an old ADR. When a decision changes, add a new ADR that supersedes it and update the old one's `Status` line only.
- Write in English. Present tense for the decision, past tense for context.

## Template

Copy [`TEMPLATE.md`](./TEMPLATE.md) when starting a new ADR. The minimum sections are:

1. **Status** — one of the values above, plus a date.
2. **Context** — what forces are at play, what constraints, what problem.
3. **Decision** — the chosen approach, stated as a commitment.
4. **Alternatives Considered** — what else we looked at and why we rejected it.
5. **Consequences** — what becomes easier, harder, or required as a result.

Optional: `Follow-ups`, `Open Points`, `Compliance mapping`, `Risk mitigation`, `References`.

## Index

| #    | Title                                                                           | Status                                                | Date       |
| ---- | ------------------------------------------------------------------------------- | ----------------------------------------------------- | ---------- |
| 0001 | [Remove `SiteConfig.pages`](./ADR-0001-remove-siteconfig-pages.md)              | Proposed — pending implementation and verification    | 2026-04-20 |
| 0002 | [Declarative form submission schemas in OlonJS core](./ADR-0002-form-submission-schemas.md) | Accepted                                              | 2026-04-21 |
| 0003 | [JSON Schema as public contract, Zod as internal SOT](./ADR-0003-jsonschema-as-public-contract-zod-as-internal-sot.md) | Accepted | 2026-05-03 |
| 0004 | [Scroll restoration in `JsonPagesEngine`](./ADR-0004-scroll-restoration-in-json-pages-engine.md) | Deprecated — reverted | 2026-05-04 |
| 0005 | [Optional inside-router slot for tenant scroll UX](./ADR-0005-optional-inside-router-slot-for-tenant-scroll-ux.md) | Accepted — pending implementation and verification | 2026-05-04 |
| 0006 | [Data router and `ScrollRestoration` in `JsonPagesEngine`](./ADR-0006-data-router-and-scroll-restoration-in-jsonpagesengine.md) | Proposed — pending implementation, QA, and acceptance | 2026-05-04 |
| 0007 | [Section capsule lazy-loading and heavy-dep budget for tenant apps](./ADR-0007-section-lazy-load-and-heavy-dep-budget.md) | Proposed — pending implementation and verification | 2026-05-08 |
| 0008 | [Performance roadmap from Lighthouse mobile 58 to ≥ 90](./ADR-0008-perf-roadmap-to-mobile-90.md) | Accepted as roadmap — Phase B done; Phase A in flight; Phase C pending measurement | 2026-05-09 |
| 0009 | [Split Studio from `@olonjs/core` runtime via `/runtime` subpath export](./ADR-0009-core-studio-split-via-runtime-subpath.md) | Accepted — implemented in `@olonjs/core` v1.1.0; deployed to `olon.js.org` | 2026-05-09 |
| 0010 | [Replace `motion/react` with CSS animations on the LCP path](./ADR-0010-hero-css-animation-over-motion-on-lcp-path.md) | Proposed — pending implementation and Lighthouse verification | 2026-05-10 |
| 0011 | [Declare `@olonjs/core` as side-effect-free for aggressive tree-shaking](./ADR-0011-olonjs-core-side-effects-false.md) | Accepted — implemented in `@olonjs/core` v1.1.2; predicted bundle-size win measured at 0 KB for `apps/olonjs.io` (see Implementation notes) | 2026-05-10 |
| 0012 | [Externalize the runtime entry from the full bundle to dedupe shared module instances](./ADR-0012-externalize-runtime-from-full-bundle.md) | Accepted — implemented in `@olonjs/core` v1.1.1; Studio renders sections verified | 2026-05-10 |
| 0013 | [Implementation of the v1 canonical JSON Schema set via `npm run bump:all`](./ADR-0013-v1-schemas-implementation.md) | Accepted | 2026-05-12 |
| 0014 | [Opt-in server-side rendering via `createStaticRouter` and a `/server` subpath export](./ADR-0014-opt-in-ssr-via-static-router-and-server-subpath.md) | Proposed — pending implementation and verification | 2026-06-04 |
| 0015 | [SSR initial-data and hydration handoff contract](./ADR-0015-ssr-initial-data-and-hydration-contract.md) | Proposed — pending implementation and verification | 2026-06-04 |
| 0016 | [Split `@olonjs/core` into three packages — `core`, `react`, `studio`](./ADR-0016-core-react-studio-package-split.md) | Proposed | 2026-07-16 |

## For agents

When you are about to make an architectural decision in this repo:

1. Read the index above. If a relevant ADR exists, honor it (or explicitly supersede it with a new one — never silently contradict).
2. If none exists and the decision qualifies, draft a new ADR **before** writing implementation code. The ADR is the first test of whether the design holds up.
3. Do not move an ADR from `Proposed` to `Accepted` without explicit user confirmation.
