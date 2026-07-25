# 001 — Next prebuild: bake agentic + robots/sitemap/llms

Repo: `npm-jpcore`  
Scope: `apps/next` DNA  
Parent: public JSON parity ([`docs/plans/next-public-page-json.md`](../plans/next-public-page-json.md))  
Todo: [`001-next-prebuild-agentic-assets.todo.md`](./001-next-prebuild-agentic-assets.todo.md)  
Status: **Done — Task 5 wired; prebuild + next build green**

## Overview

Allineare il `prebuild` di `apps/next` alla superfice agentic di `tenant-alpha` (`robots`, `sitemap`, `llms`, manifest/contracts WebMCP), **senza** portare lo SSG Vite.

Alpha oggi:

```text
prebuild = sync-pages-to-public && generate-llms-txt && bake && sitemap && robots
verify:webmcp = webmcp-feature-check (fuori prebuild)
```

`bake.mjs` alpha fa due cose diverse:

1. **SSG Vite** — client build + SSR `entry-ssg` + HTML in `dist/` (**non portabile** su Next)
2. **Artifact agentic** — `mcp-manifest.json`, page manifests, contracts/schemas, pages risolte, `llms.txt`, `config/site.json` via `@olonjs/core` `webmcp.*`

Su Next: **un unico script `scripts/bake.mjs`** che fa solo (2).

## Architecture Decisions (locked)

1. **Nome: `bake.mjs`** — un solo script, stesso nome di alpha. Header: no Vite / no HTML SSG.
2. **No Vite bake on Next** — nessun `vite.build`, nessun `entry-ssg`, nessun HTML in `dist/`.
3. **Bake = artifact agentic only** — fs load + `SECTION_SCHEMAS` + `resolvePublicPageDocument` / `buildPageContract` / `buildPageManifest` / `buildSiteManifest` / `buildLlmsTxt`.
4. **Schemas raggiungibili: `public/schemas/`** — serviti staticamente (`/schemas/{slug}.schema.json`). Non `dist-ssr` (irraggiungibile senza rewrite). Differenza consapevole vs alpha.
5. **`generate-llms-txt.mjs`** — come alpha: in prebuild prima del bake; bake può sovrascrivere `llms.txt` con schemas ricchi.
6. **Port default** robots/sitemap: `http://localhost:3000`.
7. **`webmcp-feature-check.mjs`** — `"verify:webmcp"`; **non** in `prebuild`.
8. **`dist` DNA** — includere i nuovi script sotto `scripts/`.

## Dependency Graph

```
src/data/** (pages, collections, config)
        │
        ├── sync-pages-to-public.mjs
        ├── generate-llms-txt.mjs
        └── bake.mjs  →  public/ (mcp-manifest, manifests, schemas/, pages, llms, config)
                  │
                  ├── sitemap.mjs
                  └── robots.mjs

verify:webmcp ──► webmcp-feature-check.mjs
```

## Target prebuild

```json
"prebuild": "node scripts/sync-pages-to-public.mjs && node scripts/generate-llms-txt.mjs && node scripts/bake.mjs && node scripts/sitemap.mjs && node scripts/robots.mjs",
"verify:webmcp": "node scripts/webmcp-feature-check.mjs"
```

## Task List

### Phase 1: Drop-in scripts

- [x] Task 1: Port `robots.mjs` + `sitemap.mjs` (port 3000)
- [x] Task 2: Port `generate-llms-txt.mjs`
- [x] Task 3: Port `webmcp-feature-check.mjs` + `verify:webmcp`

### Checkpoint: Phase 1
- [x] Script isolati ok

### Phase 2: Bake + wire

- [x] Task 4: `scripts/bake.mjs` (artifact only → `public/` incl. `public/schemas/`)
- [x] Task 5: Wire `prebuild` + `dist` DNA

### Checkpoint: Complete
- [x] `npm run prebuild` produce sync + llms + bake artifacts + sitemap + robots
- [x] `next build` ok
- [x] Review umano

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Copiare bake Vite per errore | High | Header + review; opzionale assert no `vite` in test |
| Import TS schemas da `.mjs` | Med | `tsx` o loader allineato a `@/` |
| Feature-check senza Playwright | Low | Solo verify script |
| Bake sovrascrive pages sync con resolved | Med | Parity alpha; accettare |

## Out of scope

- Porting SSG HTML bake / `entry-ssg`
- Cloud blob rewrite `/schemas/*`
- Propagazione prebuild nei generator Inkwell/SA (follow-up DNA release)
