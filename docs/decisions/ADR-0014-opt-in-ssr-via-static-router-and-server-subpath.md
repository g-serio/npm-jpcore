# ADR-0014: Opt-in server-side rendering for `@olonjs/core` via `createStaticRouter` and a `/server` subpath export

## Status

Proposed — pending implementation and verification (2026-06-04)

## Date

2026-06-04

## Scope

`@olonjs/core` — the engine composition (`JsonPagesEngineCore`, per [ADR-0009](./ADR-0009-core-studio-split-via-runtime-subpath.md) D4), `react-router-dom` server APIs, and the package's public export surface. Adds an additive `@olonjs/core/server` subpath that renders a `JsonPagesConfig` to an HTML string on the server. Client rendering is unchanged.

## Context

Tenants ship as client-rendered Vite SPAs. The engine mounts a **data router** built with `createBrowserRouter` + `<RouterProvider>` and `<ScrollRestoration>` ([ADR-0006](./ADR-0006-data-router-and-scroll-restoration-in-jsonpagesengine.md)). The first paint is therefore gated on downloading and executing the JS bundle, then — in cloud mode — fetching content client-side. For content/marketing tenants this hurts the loading Core Web Vitals (LCP/FCP), and crawlers/social previews see an empty document.

`createBrowserRouter` is a **browser** router: it reads `window.history`/`window.location` and cannot run under Node. A grep of the published `1.1.7` bundles (`dist/olonjs-core.js`, `dist/olonjs-core-runtime.js`) confirms both use `createBrowserRouter` + `RouterProvider`, and that the package ships **no** `react-dom/server` path. Consequently a tenant **cannot** server-render its pages today: pages render through the engine, and the engine is browser-only. True SSR is therefore a `@olonjs/core` capability, not something a tenant can add on its own.

[ADR-0009](./ADR-0009-core-studio-split-via-runtime-subpath.md) already established the architecture this builds on: additive **subpath exports** (`/runtime`), a shared internal `JsonPagesEngineCore` composition root that takes its router/routes as input (D4), dual-target Vite builds (`scripts/build-dual.mjs`), ESM-only subpaths (D8), externalized peer deps, and a CI boundary check. ADR-0009 explicitly anticipated a future third entry ("e.g. `@olonjs/core/agent`") and listed full SSR as out of scope **for that perf project** — not rejected on its merits.

## Decision

1. **Add a server render path using React Router's static APIs.** Reuse `JsonPagesEngineCore`; on the server, build the router with `createStaticHandler` + `createStaticRouter` and render via `<StaticRouterProvider>` with `react-dom/server`. The **client path is unchanged**: `createBrowserRouter` + `<ScrollRestoration>` per ADR-0006 (scroll restoration is a client concern that runs after hydration).
2. **Expose it behind an additive `@olonjs/core/server` subpath export**, mirroring ADR-0009's `/runtime` pattern: single package, single version, ESM-only, a third `build.lib.entry` target producing `dist/olonjs-core-server.js` + `dist/server.d.ts`. The entry exports a render function taking a fully-resolved `JsonPagesConfig` + the request URL, returning `{ html, head }`.
3. **Additive and non-breaking.** `.` and `/runtime` stay byte-for-byte identical. Ships as a **minor** version. SSR is **opt-in per tenant**; tenants that do not import `/server` keep CSR with zero change.
4. **New contract: sections must be SSR-safe.** No `window`/`document`/`localStorage` at module scope or during render — only inside effects/handlers (guard with `typeof window !== 'undefined'`). This becomes part of the tenant section contract once a tenant opts into SSR.

## Alternatives Considered

### A — Shim `window`/`history` on the server to force `createBrowserRouter`

- **Pros:** No core change; render the existing client tree as-is.
- **Cons:** The data `createBrowserRouter` is not designed for server rendering; React Router provides `createStaticRouter`/`createStaticHandler` precisely because the browser router's loader/history model does not run correctly under `renderToString`. Leads to hydration mismatches and fragile globals.
- **Rejected because:** it fakes the environment instead of using the supported SSR API; unreliable and unmaintainable.

### B — Migrate the engine to a meta-framework (Next.js / Remix)

- **Pros:** SSR + routing handled by the framework.
- **Cons:** Discards the Vite library-bundle architecture, the `/runtime` + Studio split (ADR-0009), and the `JsonPagesEngine`/`JsonPagesConfig` public contract; forces every tenant to migrate. Months of work, breaking.
- **Rejected because:** disproportionate and breaks the established package architecture.

### C — No core change; headless prerender on the tenant only

- **Pros:** Stays 100% on the tenant; produces content-in-HTML for vitals/SEO.
- **Cons:** A build/deploy **snapshot** (SSG-family), not per-request rendering; staleness corrected only by the client live layer after hydration. Does not deliver per-request freshness.
- **Rejected as the core decision** — kept on record as the only no-core fallback if SSR in core is declined.

### D — Separate `@olonjs/core-server` npm package

- **Pros:** Independent versioning.
- **Cons:** Same drawbacks ADR-0009 rejected in its Alternative B (version drift, double publish/CI for one monorepo).
- **Rejected because:** the subpath export gives the same separation without the multi-package cost.

## Consequences

### Positive

- Tenants can server-render: content in the first byte → better LCP/FCP and crawler/social parity.
- Realizes the "third entry" pattern ADR-0009 anticipated; the architecture generalizes cleanly.
- Client behavior (data router, scroll restoration, Studio) is untouched.

### Negative / costs

- `vite.config` + `build-dual.mjs` gain a third target; `dts` emits a third file.
- A new SSR-safe constraint on sections; a non-SSR-safe section breaks SSR for tenants that opt in.
- SSR tenants deploy as a server (e.g. a Vercel function) rather than pure static — per-request compute and a TTFB cost.

### Requirements imposed

- `JsonPagesEngineCore` must accept an injected router/handler so the server entry can supply a static router without duplicating the composition.
- The boundary CI (`check-runtime-decoupling.mjs`) extends to keep `/server` free of Studio imports.
- The initial-data / hydration contract is specified separately in **[ADR-0015](./ADR-0015-ssr-initial-data-and-hydration-contract.md)**.
- New tenants are **unaffected** until the template/provisioning opts in (a separate, later phase).

## Follow-ups

- [ ] Confirm the locked `react-router-dom` version exposes `createStaticHandler` / `createStaticRouter` / `StaticRouterProvider` (v6.4+ data APIs).
- [ ] Spike: render `JsonPagesEngineCore` with a static router for one known slug; assert no `window` access at render.
- [ ] Extend `build-dual.mjs` + dts emission for the third entry; extend the boundary check.
- [ ] Write the implementation spec for this ADR (in `npm-jpcore`) before code.

## References

- [ADR-0006](./ADR-0006-data-router-and-scroll-restoration-in-jsonpagesengine.md) — the data/browser router this keeps on the client.
- [ADR-0009](./ADR-0009-core-studio-split-via-runtime-subpath.md) — the subpath-export + `JsonPagesEngineCore` pattern this extends.
- [ADR-0011](./ADR-0011-olonjs-core-side-effects-false.md), [ADR-0012](./ADR-0012-externalize-runtime-from-full-bundle.md) — side-effects + externalization posture the server entry must respect.
- [ADR-0015](./ADR-0015-ssr-initial-data-and-hydration-contract.md) — the data/hydration contract for this capability.
- `packages/core/src/runtime/engine/JsonPagesEngineCore.tsx`, `packages/core/scripts/build-dual.mjs`.
- React Router: static-router / `createStaticHandler` SSR documentation.
