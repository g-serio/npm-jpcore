---
name: tenant-harness-render-migration
description: Migrates OlonJS tenant App.tsx harness from legacy GET /api/v1/content (god object) to SPP GET /api/v1/render?path=... — visitor single-path render plus admin render fan-out via useAdminStudioContent. Use when upgrading hot-save cloud bootstrap, fixing empty menus, Studio stuck on Loading Studio..., or aligning landing harness to multi-route sites (thebrief/gumlon/design-md-radice).
---

# Tenant harness: `/content` → `/render` (visitor + admin fan-out)

Surgical migration for **hot-save cloud mode only**. Do not refactor the whole `App.tsx` into hooks unless explicitly requested.

**Core rule:** Both **visitor** and **Studio `/admin`** use `GET /render`. Visitor: one path per navigation. Admin: **fan-out** — one `/render` call per static page slug from `filePages` manifest. Do **not** use `GET /content` for admin bootstrap (no `menuConfig` in that response).

## When to migrate

| Symptom | Cause |
|---|---|
| Menu/header empty in prod but OK locally | Admin still on `/content` or `menuConfig` stub; visitor-only render |
| Visitor loads all pages at once | Legacy harness uses god-object `/content` for everything |
| `/admin` stuck on `Loading Studio...` | Nothing loads `pages` → `draft` is null in `StudioRoute` |
| Menu edits not visible after hot save reload | Admin bootstrap never reads `context.menuConfig` from render |
| Need route-scoped bootstrap + resolved `$ref` | Platform SPP `/render` |

## Prerequisites (verify before harness work)

1. **Platform store** — `tenant_content_store` has `config/site`, `config/menu`, `page/*` (provision, snapshot, or manual).
2. **Tenant seed** — `menuConfig = menuData as MenuConfig`; `refDocuments` use the same object (never `{ main: [] }` stub).
3. **Header** — schema includes `menu` (`ui:list`); View reads `data.menu` with IDAC attributes.
4. **API smoke test**
   - `GET /api/v1/render?path=/` → `ok`, `page`, `context.siteConfig`, `context.menuConfig`

If store lacks menu, fix platform/tenant data first — harness alone will not fix empty nav.

## Dual bootstrap decision tree

```
isCloudMode (VITE_OLONJS_* env)?
├─ NO  → getHydratedData / file-backed — do not touch
└─ YES
   ├─ VITE_SAVE2REPO=true → static /config/site.json + /pages/*.json — do not touch
   └─ hot-save (default)
      ├─ visitor (not /admin*)
      │    → GET /render?path={normalizeRenderPath(pathname)}
      │    → merge single page + context into engine state
      └─ /admin*
           → skip visitor single-path bootstrap
           → useAdminStudioContent → GET /render for **active admin page only**
           → on page change in inspector (URL `/admin/{slug}`) → another GET /render
           → page list in Studio from `filePages` stubs; cloud content merged per slug
```

## Migration workflow (minimal diff)

### Step 1 — Add render client

Create `src/lib/spp/renderClient.ts` (copy from `design-md-radice`, `thebrief`, or `gumlon`):

- `fetchRenderProjection(apiBases, apiKey, path, { signal })`
- `normalizeRenderPath`, `isAdminPath`, `resolveRegistrySlugFromRender`
- `registrySlugToRenderPath`, `listAdminRenderPaths` (admin fan-out)
- `patchHistoryNavigation` for visitor SPA navigation

Request: `GET {apiBase}/render?path=/` with `Authorization: Bearer {apiKey}`.

### Step 2 — Menu state (not static const)

```typescript
const menuConfigSeed = menuData as unknown as MenuConfig;
const [menuConfig, setMenuConfig] = useState<MenuConfig>(menuConfigSeed);
const engineRefDocuments = useMemo(() => ({
  'menu.json': menuConfig,
  'config/menu.json': menuConfig,
  'src/data/config/menu.json': menuConfig,
}), [menuConfig]);
```

Pass `menuConfig` + `refDocuments: engineRefDocuments` to `JsonPagesConfig`.

### Step 3 — Visitor: single-path render bootstrap

In the hot-save `useEffect` only:

1. If `isAdminPath(pathname)` → **return** early (admin hook owns bootstrap; `hasInitialCloudResolved` via `onBootstrapResolved`)
2. Else `fetchRenderProjection` on `normalizeRenderPath(pathname)`
3. `applyRenderPayload(result)`:
   - `setPages(prev => ({ ...prev, [registrySlug]: result.page }))` — **merge**, not replace
   - `setSiteConfig(result.context.siteConfig)`
   - `setMenuConfig(result.context.menuConfig)`
   - cache: `siteConfig`, `menuConfig`, merged `pages`
4. `patchHistoryNavigation` → re-fetch render on route change
5. Log `boot.spp_render.*` (not `boot.cloud.*`)

### Step 4 — Admin: lazy `/render` via `useAdminStudioContent`

Create `src/lib/cloud/useAdminStudioContent.ts` (reference: `design-md-radice`).

Seed cloud `pages` with **stubs** from `filePages` (empty `sections`) so Studio page selector lists all slugs without loading every page.

Wire in `App.tsx` when `isHotSaveMode`:

```typescript
useAdminStudioContent({
  enabled: isHotSaveMode,
  basePath: APP_BASE_PATH,
  apiCandidates: cloudApiCandidates,
  apiKey: CLOUD_API_KEY ?? '',
  setPages,
  setSiteConfig,
  setMenuConfig,
  readCache: readCloudCache,
  writeCache: writeCachedCloudContent,
  onBootstrapResolved: () => setHasInitialCloudResolved(true),
});
```

Hook behavior:

- Runs only when `isAdminPath(window.location.pathname)`
- **One** `fetchRenderProjection` for the slug implied by the current `/admin` URL
- `patchHistoryNavigation` → refetch when inspector navigates to another page (`/admin/menu`, etc.)
- `context.siteConfig` + `context.menuConfig` from that render response
- **Never** fan-out all pages; **never** call `GET /content`

### Step 5 — Clean up dead `/content` code

Remove `/content` helpers from tenant harness (`fetchLegacyCloudContentPayload`, `ContentResponse`, etc.).

## Payload contracts

### Visitor + Admin — `/render`

```typescript
{
  ok: true,
  route: { path, template, params },
  context: { siteConfig, menuConfig },
  page: PageConfig,
  diagnostics: { projectionMode: 'atomic' | 'legacy_fallback', unresolvedRefs: [] }
}
```

| JsonPagesConfig field | Visitor source | Admin source |
|---|---|---|
| `pages[slug]` | `result.page` (merge per nav) | each fan-out `result.page` (merge all) |
| `siteConfig` | `result.context.siteConfig` | first ok `context.siteConfig` |
| `menuConfig` | `result.context.menuConfig` | first ok `context.menuConfig` |
| `refDocuments` | `useMemo(menuConfig)` | same |

Studio `draft` requires at least one page in `pages` state.

## Dynamic routes

Slugs containing `[` (e.g. `libri/[slug]`) are **excluded** from admin fan-out path list. Studio still needs template page in registry — handle separately if tenant has dynamic routes.

## Do not change (scope guard)

- Local dev (`getHydratedData`)
- Save2repo static loader
- `hotSave` POST / `coldSave` / `save-stream`
- Section capsules, `entry-ssg.tsx` (unless SSG uses stale menu stub)
- `@olonjs/core` — tenant-only fix

## Verification

```bash
npm run test:admin-render-paths
npm run build
npm run dev   # VITE_OLONJS_CLOUD_URL + VITE_OLONJS_API_KEY
```

| Surface | Network | Expected |
|---|---|---|
| Visitor `/` | `render?path=/` | Menu visible; `boot.spp_render.success` |
| Visitor nav | `render?path=...` | Per-route fetch |
| Admin `/admin` | `render?path=...` (one per active page) | Zero `content`; refetch on page change |
| Admin menu | from `context.menuConfig` | Not local `menu.json` seed after cloud load |

## Reference implementations

| Tenant | Visitor | Admin |
|---|---|---|
| `design-md-radice` | `App.tsx` render branch | `lib/cloud/useAdminStudioContent.ts` (render fan-out) |
| `thebrief` | `useTenantBootstrap` + `lib/spp/renderClient.ts` | legacy `/content` — migrate to fan-out |
| `gumlon` | surgical `App.tsx` render branch | legacy `/content` — migrate to fan-out |

Read `design-md-radice` for the current fan-out pattern before improvising.

## Platform alignment

`provision-stream` / snapshot must bootstrap `menu.json` into the store. `/render` reads from `tenant_content_store` with resolved `context.menuConfig`. `GET /content` remains on platform for legacy clients but **tenants should not use it** for Studio bootstrap.
