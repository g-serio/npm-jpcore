# ADR-0015: SSR initial-data and hydration handoff contract

## Status

Proposed — pending implementation and verification (2026-06-04)

## Date

2026-06-04

## Scope

The data boundary for the server-side rendering capability introduced by [ADR-0014](./ADR-0014-opt-in-ssr-via-static-router-and-server-subpath.md): who fetches tenant content for the first paint, how it reaches the server render, and how the client rehydrates without mismatch. Affects `@olonjs/core/server`, the tenant client entry, and SSR consumers.

## Context

ADR-0014 adds a server render that takes a resolved `JsonPagesConfig`. In cloud mode a tenant's content lives behind the platform REST endpoint (`GET /api/v1/content`, authenticated by a **server-only** per-tenant Bearer key; it returns `siteConfig`, `pages`, and — already — the public Supabase Realtime creds `supabaseUrl`/`supabaseAnonKey`/`tenantId`). On the client today the engine renders empty and fills `pages`/`siteConfig` from a client-side fetch plus the live Realtime layer. If the server renders before that data exists, SSR emits an empty document — defeating the purpose. So SSR needs the data **at render time on the server**, and the client must hydrate against the **same** data to avoid a mismatch.

Hard constraint: `@olonjs/core` must stay **data-source-agnostic** — it cannot bake in the platform API.

## Decision

1. **The consumer (SSR server / tenant) fetches content; core does not.** `@olonjs/core/server` renders a **fully-resolved `JsonPagesConfig`** passed in by the caller. The tenant's SSR handler fetches `/api/v1/content` server-side with the server-only key and assembles the config.
2. **Serialize initial state into the HTML as `window.__OLON_INITIAL__`** (JSON). The client entry reads it and hydrates with identical `pages`/`siteConfig` → no hydration mismatch.
3. **After hydration, the client owns updates.** The SSR payload is the first-paint snapshot only; the existing client fetch + Supabase Realtime live layer take over unchanged.
4. **Credential boundary.** The Bearer `api_key` is server-only and must never be serialized into `window.__OLON_INITIAL__` or any client bundle; only the already-public anon key reaches the client.

## Alternatives Considered

### A — Core fetches content inside `/server`

- **Cons:** couples core to the platform API shape and auth; breaks data-source agnosticism.
- **Rejected because:** core must not know about `/api/v1/content`.

### B — Server renders empty, client fetches (no handoff)

- **Cons:** empty first paint; defeats SSR for vitals/SEO; double work.
- **Rejected because:** it negates the reason to do SSR.

### C — Embed state only via React context, no serialized global

- **Cons:** hydration still needs the data on the client; without a serialized payload the client must refetch, reintroducing B's flash.
- **Rejected because:** a serialized handoff is the standard, mismatch-free path.

## Consequences

### Positive

- Clean separation: **core renders given data; the consumer owns fetching.** Reusable by any SSR host.
- No hydration mismatch; the live layer is unaffected.

### Negative / costs

- The tenant SSR handler must implement the server-side fetch and inject the global.
- Requires an XSS-safe JSON serialization (escape `<` and `/`) for the inline `<script>`.

### Requirements imposed

- The client entry must read `window.__OLON_INITIAL__` and pass it as initial state to `App` / the engine.
- A security review of the serialized payload (no secrets, escaped output) is required.

## Follow-ups

- [ ] Define the exact `__OLON_INITIAL__` shape (`{ siteConfig, pages, menu }`) and a typed reader.
- [ ] Provide a safe-serialize helper (escape for inline `<script>`).
- [ ] Tenant SSR handler: server fetch of `/api/v1/content` with the server-only key.

## References

- [ADR-0014](./ADR-0014-opt-in-ssr-via-static-router-and-server-subpath.md) — the SSR rendering capability this contract serves.
- Platform endpoint `GET /api/v1/content` — returns `siteConfig`, `pages`, `supabaseUrl`, `supabaseAnonKey`, `tenantId`.
