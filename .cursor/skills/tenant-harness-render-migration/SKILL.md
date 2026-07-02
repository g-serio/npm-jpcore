---
name: tenant-harness-render-migration
description: Migrates OlonJS tenant App.tsx harness from legacy GET /api/v1/content (god object) to dual bootstrap — visitor GET /api/v1/render?path=... (SPP projection) plus admin GET /content via useAdminStudioContent. Use when upgrading hot-save cloud bootstrap, fixing empty menus, Studio stuck on Loading Studio..., or aligning landing harness to multi-route sites (thebrief/gumlon).
---

# Tenant harness: `/content` → `/render` (+ admin `/content`)

Surgical migration for **hot-save cloud mode only**. Do not refactor the whole `App.tsx` into hooks unless explicitly requested.

**Core rule:** `/render` replaces `/content` for the **visitor** only. **Studio `/admin` still needs `/content`** (all pages). Never delete `/content` entirely without adding `useAdminStudioContent`.

## When to migrate

| Symptom | Cause |
|---|---|
| Menu/header empty in prod but OK locally | `menuConfig` stub or store missing `config/menu` |
| Visitor loads all pages at once | Legacy harness uses god-object `/content` for everything |
| `/admin` stuck on `Loading Studio...` | Render bootstrap skipped admin but nothing loads `pages` → `draft` is null in `StudioRoute` |
| Need route-scoped bootstrap + resolved `$ref` | Platform SPP `/render` for visitor |

## Prerequisites (verify before harness work)

1. **Platform store** — `tenant_content_store` has `config/site`, `config/menu`, `page/*` (provision, snapshot, or manual).
2. **Tenant seed** — `menuConfig = menuData as MenuConfig`; `refDocuments` use the same object (never `{ main: [] }` stub).
3. **Header** — schema includes `menu` (`ui:list`); View reads `data.menu` with IDAC attributes.
4. **API smoke test**
   - `GET /api/v1/render?path=/` → `ok`, `page`, `context.siteConfig`, `context.menuConfig`
   - `GET /api/v1/content` → `pages`, `siteConfig` (for admin)

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
           → skip visitor render bootstrap
           → useAdminStudioContent → GET /content (all pages + site)
           → required or Studio shows "Loading Studio..."
```

## Migration workflow (minimal diff)

### Step 1 — Add render client

Create `src/lib/spp/renderClient.ts` (copy from `thebrief` or `gumlon`):

- `fetchRenderProjection(apiBases, apiKey, path, { signal })`
- `normalizeRenderPath`, `isAdminPath`, `resolveRegistrySlugFromRender`
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

### Step 3 — Visitor: replace hot-save `/content` bootstrap

In the hot-save `useEffect` only:

1. If `isAdminPath(pathname)` → set `hasInitialCloudResolved(true)` and **return** (no render fetch)
2. Else `fetchRenderProjection` on `normalizeRenderPath(pathname)`
3. `applyRenderPayload(result)`:
   - `setPages(prev => ({ ...prev, [registrySlug]: result.page }))` — **merge**, not replace
   - `setSiteConfig(result.context.siteConfig)`
   - `setMenuConfig(result.context.menuConfig)`
   - cache: `siteConfig`, `menuConfig`, merged `pages`
4. `patchHistoryNavigation` → re-fetch render on route change
5. Log `boot.spp_render.*` (not `boot.cloud.*`)

### Step 4 — Admin: add `useAdminStudioContent`

Create `src/lib/cloud/useAdminStudioContent.ts` (copy from `thebrief` or `gumlon`).

Wire in `App.tsx` when `isHotSaveMode`:

```typescript
useAdminStudioContent({
  enabled: isHotSaveMode,
  basePath: APP_BASE_PATH,
  apiCandidates: cloudApiCandidates,
  apiKey: CLOUD_API_KEY ?? '',
  setPages,
  setSiteConfig,
  setMenuConfig,  // optional if /content returns menuConfig
  writeCache: writeCachedCloudContent,
});
```

Hook behavior:

- Runs only when `isAdminPath(window.location.pathname)`
- `GET /content` — god object with **all pages** (Studio needs full registry)
- `patchHistoryNavigation` for admin SPA transitions
- **Never** call `/render` from this hook

### Step 5 — Clean up visitor-only dead code

Remove `/content` helpers from the **visitor** bootstrap path only (`ContentResponse`, `extractContentSources` in `App.tsx` if moved to admin hook).

Keep `/content` client code used by `useAdminStudioContent`.

## Payload contracts

### Visitor — `/render`

```typescript
{
  ok: true,
  route: { path, template, params },
  context: { siteConfig, menuConfig },
  page: PageConfig,
  diagnostics: { projectionMode: 'atomic' | 'legacy_fallback', unresolvedRefs: [] }
}
```

| JsonPagesConfig field | Source |
|---|---|
| `pages[slug]` | `result.page` (merged) |
| `siteConfig` | `result.context.siteConfig` |
| `menuConfig` | `result.context.menuConfig` |
| `refDocuments` | `useMemo(menuConfig)` |

### Admin — `/content`

```typescript
{ ok: true, siteConfig, pages: { home: PageConfig, ... } }
```

Studio `draft` requires at least one page in `pages` state. `siteConfig` can come from seed but pages cannot stay `{}` in cloud mode.

## Do not change (scope guard)

- Local dev (`getHydratedData`)
- Save2repo static loader
- `hotSave` POST / `coldSave` / `save-stream`
- Section capsules, `entry-ssg.tsx` (unless SSG uses stale menu stub)
- `@olonjs/core` — tenant-only fix

## Verification

```bash
npm run build
npm run dev   # VITE_OLONJS_CLOUD_URL + VITE_OLONJS_API_KEY
```

| Surface | Network | Expected |
|---|---|---|
| Visitor `/` | `render?path=/` | Menu visible; `boot.spp_render.success` |
| Visitor nav | `render?path=...` | Per-route fetch |
| Admin `/admin` | `content` (not render) | Studio loads; no `Loading Studio...` |
| Admin | no `pages: {}` in React state | `StudioRoute` gets `draft` |

## Reference implementations

| Tenant | Visitor | Admin |
|---|---|---|
| `thebrief` | `useTenantBootstrap` + `lib/spp/renderClient.ts` | `lib/cloud/useAdminStudioContent.ts` |
| `gumlon` | surgical `App.tsx` render branch | `lib/cloud/useAdminStudioContent.ts` |

Read reference code before improvising. Copy `renderClient.ts` and `useAdminStudioContent.ts` verbatim when possible; adapt only the hot-save `useEffect` in `App.tsx`.

## Platform alignment

`provision-stream` / `vercelIntegrationCallback` must bootstrap `menu.json` into the store like `save2edge-snapshot` (`buildTenantContentPayloadFromRepo` in `jsonpages-platform`). Both `/render` and `/content` read from `tenant_content_store`.
