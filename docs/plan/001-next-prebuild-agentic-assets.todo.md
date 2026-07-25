# Todo — 001 Next prebuild agentic assets

Plan: [`001-next-prebuild-agentic-assets.md`](./001-next-prebuild-agentic-assets.md)

## Phase 1 — Drop-in

- [x] **Task 1:** Port `robots.mjs` + `sitemap.mjs` → `apps/next/scripts/` (baseUrl default `:3000`)
  - AC: `node scripts/robots.mjs` / `sitemap.mjs` scrivono `public/robots.txt` e `public/sitemap.xml`
  - Verify: file esistono; sitemap elenca slug da `src/data/pages`
  - Scope: S · Deps: none
  - Done: `34df343`

- [x] **Task 2:** Port `generate-llms-txt.mjs` → `apps/next/scripts/`
  - AC: scrive `public/llms.txt` da pages + site.json via `@olonjs/core` webmcp
  - Verify: `node scripts/generate-llms-txt.mjs`
  - Scope: S · Deps: none
  - Done: `56b3e82`

- [x] **Task 3:** Port `webmcp-feature-check.mjs` + `"verify:webmcp"` in `package.json`
  - AC: usa `document.modelContextTesting` (no navigator fallback); non in prebuild
  - Verify: script parte / fallisce chiaro senza server (comportamento atteso)
  - Scope: S · Deps: none
  - Done: `168e895`

### Checkpoint Phase 1
- [x] Tre script + verify ok in isolamento

## Phase 2 — Bake + wire

- [x] **Task 4:** `scripts/bake.mjs` Next = **solo** artifact agentic (no Vite/SSG)
  - AC: scrive sotto `public/`: mcp-manifest, page manifests, **`public/schemas/`** (raggiungibili), pages risolte, llms.txt, config/site.json
  - AC: nessun import `vite`; nessun HTML bake
  - Verify: run script; `GET`-equivalente path files esistono sotto public/
  - Scope: M · Deps: Task 2 (llms overlap ok)
  - Done: `299605b`

- [x] **Task 5:** Wire `package.json` prebuild (+ `dist` include scripts) come alpha order
  - AC: `prebuild` = sync && generate-llms-txt && bake && sitemap && robots
  - Verify: `npm run prebuild` poi `npm run build` in `apps/next`
  - Scope: S · Deps: Task 1–4
  - Done: `33e5f25`

### Checkpoint Complete
- [x] prebuild + next build verdi
- [x] Human review / commit
