# Implementation Plan: Next public page JSON at runtime (Local / Static / Live)

Parent: [`docs/plans/next-rsc-starter.md`](./next-rsc-starter.md) · Spec: [`docs/specs/next-rsc-starter.md`](../specs/next-rsc-starter.md) · ADR-0017  
Repo: `npm-jpcore`  
Status: **Implement complete — awaiting human review**  
Checklist: [`tasks/todo-page-json.md`](../../tasks/todo-page-json.md)

## Overview

Ripristinare su Next la parity Vite di `GET /{slug}.json` (e opzionale `GET /pages/{slug}.json`): **nessun file pubblico obbligatorio** — un Route Handler (o rewrite → handler) costruisce l’oggetto a runtime da Local / Static / Live, fa resolve come il plugin Vite, risponde `NextResponse.json(page)`.

Fuori scope di questo piano: WebMCP (`/mcp-manifest.json`, `/llms.txt`, schemas) salvo se cade gratis; HotSave.

## Architecture Decisions

1. **Un contratto URL, tre fonti** — stesso path pubblico; `bootSource` / cloud policy sceglie Local | Static | Live (allineato alpha: Save2Repo → static boot; cloud senza Save2Repo → live; no creds → local).
2. **Logica in `@olonjs/next/server`** — `resolvePublicPageJson({ slug, source })` puro/testabile; l’app Next solo wiring (rewrite + thin `route.ts`).
3. **Resolve = core** — riusare `resolvePublicPageDocument` (+ slice filter parity Vite `applyDevSliceFilters` se ancora rilevante per route dinamiche).
4. **Niente file in `public/` per servire** — Local legge `src/data`; Static/Live fetch o loader cloud; risposta sempre runtime.
5. **Conflict con `[[...slug]]`** — `home.json` non deve essere catturato come pagina HTML. Preferire:
   - `middleware` / `next.config` rewrite: `/:slug.json` → `/api/public-page/:slug`, **oppure**
   - route dedicata `app/[...jsonPath]/route.ts` con guard `.json`  
   Decisione implementativa: **rewrite → `app/api/public-page/[...slug]/route.ts`** (chiaro, non combatte l’RSC catch-all).

## Dependency Graph

```
cloudPolicy / bootSource (già Next env)
        │
        ├── content source adapters
        │     ├── local: getFilePages + site bundle
        │     ├── static: load published JSON (URLs/paths TBD from alpha static boot)
        │     └── live: fetch cloud content (parity alpha live)
        │
        └── resolvePublicPageJson (core resolve + slice filter)
                  │
                  └── Next rewrite + Route Handler → NextResponse.json
```

## Task List

### Phase 1: Contract + Local

- **Task A:** `resolvePublicPageJson` in `@olonjs/next/server` + unit tests (slug normalize, 404, local happy path with fixture pages).
- **Task B:** Port/adapt `applyDevSliceFilters` (or shared helper) for dynamic route params.
- **Task C:** Route Handler `GET /api/public-page/[...slug]` + `next.config` rewrites so `GET /home.json` e `GET /pages/home.json` hit the handler.
- **Task D:** Wire Local source only; smoke `curl localhost:3000/home.json`.

### Checkpoint: Local parity

- [x] `/home.json` e `/pages/home.json` → 200 JSON resolved
- [x] slug sconosciuto → 404 JSON `{ error }`
- [x] HTML visitor routes invariate
- [x] Tests package green

### Phase 2: Static + Live

- **Task E:** Static source adapter (Save2Repo boot) — load pages/config da published URLs/paths (mirror alpha `bootStatic` / staticContent).
- **Task F:** Live source adapter — load da cloud API (mirror alpha live content client, read-only for this endpoint).
- **Task G:** Handler sceglie source da `cloudPolicy.bootSource` (o equivalente Next); smoke matrix Local / Static / Live.

### Checkpoint: Complete

- [x] Tre mode documentati + smoke (Local curl; Static/Live unit matrix)
- [x] Nessun file `public/**/*.json` richiesto per servire
- [ ] Human review

## Mode matrix (Task G)

| `cloudPolicy.bootSource` | Env (Next) | Bundle loader |
|---|---|---|
| `local` | no cloud URL+key | `loadLocalPublicPageBundle` — `src/data/**` |
| `static` | URL+key + `NEXT_PUBLIC_SAVE2REPO=true` (or `NEXT_PUBLIC_OLONJS_SAVE2REPO`) | `loadStaticPublicPageBundle` — fetch `{origin}/config/site.json` + `/pages/{slug}.json` |
| `live` | URL+key, Save2Repo off | `loadLivePublicPageBundle` — `GET {api}/render?path=…` |

Handler: `apps/next/app/api/public-page/[...slug]/route.ts` via `loadPublicPageBundleForRequest`.
Rewrites (inline in `next.config.ts`): `/*.json` and `/pages/*.json` → that API.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Catch-all RSC mangia `*.json` | High | Rewrite esplicito prima del page match |
| Static/Live URL shape diverso da alpha | Med | Copiare contratti da `bootStatic` / cloud client alpha; non inventare |
| Slice filter divergenza | Med | Port testuale da Vite plugin + test su `libri/[slug]` |
| Scope creep MCP | Low | Esplicitamente out of scope salvo follow-up |

## Open Questions

_None blocking._ Se Static published base URL non è ancora nel tenant Next, Task E usa lo stesso env/path pattern di alpha Save2Repo static boot.

## Verification (before coding)

- [ ] Human approves this plan
- [ ] `tasks/todo-page-json.md` accepted
