# ADR-0017: Next.js binding — RSC visitors + admin client island

## Status

Accepted

## Date

2026-07-22

## Context

OlonJS today ships a Vite-hosted tenant DNA (`apps/tenant-alpha`) that mounts a single client React tree (`JsonPagesEngine` from `@olonjs/react`, Studio via `@olonjs/studio`, routing via `react-router-dom`). Dev host APIs live in a Vite plugin (`configureServer`).

We want a Next.js App Router starter and a published host package `@olonjs/next`. Two competing shapes were considered:

1. **Single client island** — mount the whole Olon app (visitor + admin) as one `'use client'` tree inside Next (parity with Vite SPA).
2. **Split surfaces** — visitors rendered in an RSC-efficient server path; `/admin` (and Studio preview) as a client island only.

A single island is the shortest bridge from Vite, but it is inefficient for public traffic on Next and mixes two different product concerns (static/content delivery vs interactive CMS). The normative product target for the Next starter is therefore the split model.

Constraints that remain true regardless of host:

- `@olonjs/core` stays framework-agnostic.
- `@olonjs/react` is **not** “React/Vite”; Vite is only the package build tool. Runtime peers are React + `react-router-dom`.
- Studio / Form Factory / DnD require a client React tree.
- Tenant section Views today are React components; “RSC-efficient visitors” is not automatic — public Views must be server-compatible (or composed of server shells + small client leaves).

## Decision

1. **Publish `@olonjs/next` as a host binding**, not a second rendering engine. It composes `@olonjs/core` + `@olonjs/react` / `@olonjs/studio`; it does not fork `JsonPagesEngine`.

2. **Normative Next starter shape** (`apps/tenant-next` and future CLI DNA):
   - **Visitors:** RSC-efficient public rendering (Server Components / server loaders for page+config data; minimal client JS on the public path).
   - **Admin:** `'use client'` island for `/admin` and Studio surfaces only.

3. **Package surface (intended):**
   - `@olonjs/next/server` — load/resolve content, visitor render helpers, Route Handler implementations (save/upload/list/WebMCP parity with the Vite dev plugin).
   - `@olonjs/next/client` (or `admin`) — admin island wiring around `@olonjs/react` + `@olonjs/studio`.
   - Optional `withOlon` / docs for `next.config` and `basePath`.

4. **Routing split:**
   - Public routes: Next App Router.
   - Admin island: may keep `react-router-dom` internally (as today) until a deeper Next↔engine routing bridge exists.

5. **View discipline for the Next DNA:** public section capsules used on the visitor path must be RSC-safe (no mandatory client hooks on the server render path). Client-only behavior (forms, lazy totals, etc.) stays in explicit client leaves or admin-only code.

6. **Reject as the published Next starter target:** “whole-app client island” parity with Vite. That pattern may exist only as an internal spike, not as `@olonjs/next`’s documented production shape.

## Alternatives Considered

### A. Whole-app client island (Vite parity in Next)

- Pros: fastest to scaffold; reuses `App.tsx` harness almost unchanged; same empty-tenant / authors-books demo with minimal View changes.
- Cons: visitors download/hydrate CMS-oriented client JS; does not justify a Next-specific package beyond API route shims; dual routers without gaining RSC benefits.
- Rejected as **production starter target** (acceptable only as temporary spike).

### B. Full RSC rewrite of Studio + engine

- Pros: maximum Next-native story.
- Cons: Studio is inherently interactive; reverse-engineering the engine into RSC would break the three-package split and delay shipping indefinitely.
- Rejected.

### C. Static-only visitors (bake/SSG HTML) + admin island, no RSC

- Pros: already partially exists in Vite DNA (`bake.mjs`); very light public path.
- Cons: under-uses App Router; weaker “Next starter” story than RSC-capable server render of the same JSON contract.
- Not rejected forever — SSG remains a valid deploy mode — but the **adapter contract** targets RSC-efficient server render, with static generation as an optimization on top.

### D. Put Next APIs inside `@olonjs/react`

- Pros: one fewer package.
- Cons: couples React bindings to a specific host; violates the core/react/studio host-agnostic layering.
- Rejected — host concerns belong in `@olonjs/next`.

## Consequences

- Implementing `@olonjs/next` and `apps/tenant-next` is a **multi-slice** effort: shared dev-api logic (Vite plugin ↔ Route Handlers), visitor server render path, admin island, then authors/books + empty-tenant demo under View RSC rules.
- Tenant alpha (Vite) remains the reference DNA for the Vite host; Next DNA may diverge where host constraints demand it, but **section/schema/JSON protocol** stays aligned.
- Agents and humans must not treat “mount JsonPagesEngine on every Next page” as the intended architecture.
- Public View non-compliance (client hooks on the visitor path) is a **gate** for the Next template, not a soft warning.
- `react-router-dom` remains a peer of `@olonjs/react` for the admin island until a follow-up ADR supersedes routing.

## References

- Package split: ADR-0016 (three-package split: `@olonjs/core` / `@olonjs/react` / `@olonjs/studio`)
- Vite tenant DNA: `apps/tenant-alpha` (including `scripts/vite/tenantDevApiPlugin.ts`)
- Product target discussion: Next starter = RSC-efficient visitors + admin client island (2026-07-22)
