# Spec: Save2Repo Site/Menu Sync Contract (v1)

## Assumptions I'm Making
1. Scope is exactly 3 repos: `npm-jpcore` (root cause fix + publish), `design-md-radice` (adopter tenant), `jsonpages-platform` (server contract). No other tenant is touched in this spec.
2. Fix lands in the shared `@olonjs/core` package (`packages/core/src/dna/lib/cloudSaveStream.ts`), not as a tenant-local fork — per team decision in this session (root cause > per-tenant patch).
3. `design-md-radice` consumes `@olonjs/core` from the public npm registry (`"^1.1.12"`, currently resolves to published `1.1.13`) — a real `npm publish` (patch bump) is required before the tenant can pick up the fix; this is not a yalc/workspace-linked dev loop.
   - **Publish ownership:** the user runs the actual publish (`npm run release:enterprise` or manual `npm publish`) themselves — not part of my execution scope. My scope stops at: code change + version bump proposal + local `test:all` passing. I do not run the publish command.
4. Backward compatibility is mandatory: the change to `startCloudSaveStream` must be additive-only so any existing consumer that only passes `path` + `content` keeps working unchanged after the bump.
5. Server-side `menu.json` gets a dedicated contract mirroring the existing `site.json` one (`includesSiteConfig` / `changedScopes`), not silent generic-file handling.
6. `design-md-radice`'s Save2Repo (cold save) action always includes `site.json` + `menu.json` in the bundle on every save — no client-side diffing against last-synced state. Confirmed.
7. This spec does not touch `POST /api/v1/hotSave` or `POST /api/v1/render` — those already carry `siteConfig`/`menuConfig` correctly. Scope is exclusively the Save-to-Repo write path (`save-stream`).

## Objective

Today, a tenant in Save-to-Repo mode (`VITE_SAVE2REPO=true`) who edits the header, footer, or menu in Studio and clicks "Cold Save" only gets the current page committed to their GitHub repo. `config/site.json` (header/footer) and `config/menu.json` are silently dropped — the published site keeps stale site/menu content indefinitely, with no error surfaced to the editor.

User goal: editing site-wide config (header, footer, menu) in Studio and publishing via Save-to-Repo must actually publish those changes.

Success means:
- `startCloudSaveStream` (Core) can carry `site` and `menu` payloads alongside `page`, without breaking existing single-file callers.
- `POST /api/v1/save-stream` (platform) validates and commits `menu.json` with the same rigor it already applies to `site.json`.
- `design-md-radice`'s Cold Save action sends page + site + menu on every save, and a live Cold Save round-trip reflects header/footer/menu edits in the deployed site.

## Tech Stack

| Repo | Role | Stack |
|---|---|---|
| `npm-jpcore` | Root cause fix, `@olonjs/core` publish | TypeScript strict, Vite 6 dual build, Vitest 3 |
| `design-md-radice` | Adopter tenant (Save-to-Repo mode) | Vite 6, React 19, `@olonjs/core@^1.1.12` |
| `jsonpages-platform` | Server contract (`save-stream` route) | Next.js 16 App Router, TypeScript, Supabase, Octokit, Vercel API |

## Commands

**`npm-jpcore` (Core):**
- Build core: `npm run build -w @olonjs/core`
- Core tests: `npm test -w @olonjs/core`
- Boundary checks: `npm run test:boundary -w @olonjs/core`
- Full core checks: `npm run test:all -w @olonjs/core`
- Publish (after version bump in `packages/core/package.json`): `npm run release:enterprise` — **run manually by the user, not executed by the agent**

**`design-md-radice` (tenant):**
- Install updated dependency: `npm install @olonjs/core@latest`
- Dev: `npm run dev`
- Build: `npm run build` (`tsc && vite build`)

**`jsonpages-platform` (platform):**
- Dev: `npm run dev`
- Build: `npm run build`
- Lint: `npm run lint`
- Existing related smoke test (pattern to extend): `npm run test:save2:smoke` (`scripts/save2-hot-cold-smoke.mjs`)

## Project Structure

| File | Repo | Change |
|---|---|---|
| `packages/core/src/dna/lib/cloudSaveStream.ts` | `npm-jpcore` | Extend `StartCloudSaveStreamInput` to accept optional `additionalFiles` + `changedScopes`; build bundle body when present, else legacy single-file body (unchanged path) |
| `packages/core/package.json` | `npm-jpcore` | Version bump (patch) for publish |
| `src/app/api/v1/save-stream/route.ts` | `jsonpages-platform` | Add `MENU_CONFIG_PATH`, `includesMenuConfig()`, extend `changedScopes` type to include `'menu'`, add `ERR_MENU_CONFIG_REQUIRED` validation, extend `summarizeFileKinds` |
| `docs/flows/v1-save-stream.md` | `jsonpages-platform` | Document the `menu` scope + `files[]` bundle contract |
| `.cursor/rules/save-content.mdc` | `jsonpages-platform` | Update save-stream section once implemented (currently describes the gap as known debt) |
| `src/App.tsx` (coldSave wiring) | `design-md-radice` | Pass `state.site` + `state.menu` as `additionalFiles` to `startCloudSaveStream` |
| `package.json` | `design-md-radice` | Bump `@olonjs/core` if a minor is chosen instead of patch (not expected — `^1.1.12` already covers a patch bump) |

## Code Style

Match existing patterns exactly — do not introduce a new abstraction where one already exists.

Core, extending the existing single-purpose interface (additive, optional fields only):

```ts
interface StartCloudSaveStreamInput {
  apiBaseUrl: string;
  apiKey: string;
  path: string;
  content: unknown;
  message?: string;
  /** Additional repo files committed atomically alongside the primary path/content (e.g. site.json, menu.json). */
  additionalFiles?: Array<{ path: string; content: unknown }>;
  /** Declares which global scopes changed, mirroring the server's ERR_*_CONFIG_REQUIRED validation. */
  changedScopes?: Array<'page' | 'site' | 'menu'>;
  signal?: AbortSignal;
  onStep: (event: SaveStreamStepEvent) => void;
  onLog?: (event: SaveStreamLogEvent) => void;
  onDone: (event: SaveStreamDoneEvent) => void;
}
```

Server, mirroring the existing `SITE_CONFIG_PATH` / `includesSiteConfig` pair exactly:

```ts
const MENU_CONFIG_PATH = 'src/data/config/menu.json';

function includesMenuConfig(files: SaveFileInput[]): boolean {
  return files.some((file) => file.path.toLowerCase() === MENU_CONFIG_PATH);
}
```

Conventions:
- No new save path, no new route — extend the existing `save-stream` bundle contract that already exists for `site.json`.
- Keep `path`/`content` (legacy single-file mode) working byte-for-byte as today when `additionalFiles` is omitted.
- `changedScopes` values are additive to the existing `Set<'page' | 'site'>` — becomes `Set<'page' | 'site' | 'menu'>`.

## Testing Strategy

- **Core (`npm-jpcore`):** unit test for `startCloudSaveStream` request-body construction — assert legacy single-file body when `additionalFiles` is omitted (regression guard), and assert `files[]` bundle body (page + site + menu) when `additionalFiles` is provided. Run via `npm test -w @olonjs/core`.
- **Platform (`jsonpages-platform`):** extend or add a script alongside `scripts/save2-hot-cold-smoke.mjs` covering: (a) `files[]` bundle with `menu.json` + `changedScopes: ['menu']` succeeds and commits menu; (b) `changedScopes: ['menu']` without `menu.json` in `files[]` returns `400 ERR_MENU_CONFIG_REQUIRED`; (c) existing legacy `path`+`content` single-file call still succeeds unchanged (regression guard).
- **End-to-end (`design-md-radice`):** manual verification gate — edit header/footer/menu in `/admin`, trigger Cold Save, confirm the resulting GitHub commit contains updated `config/site.json` and `config/menu.json`, and the redeployed site reflects the change.
- No test framework changes; follow existing per-repo conventions (Vitest for core, Node smoke scripts for platform).

## Boundaries

- **Always:**
  - Preserve exact legacy behavior of `startCloudSaveStream` when called with only `path`/`content` (no `additionalFiles`).
  - Mirror the existing `site.json` validation pattern for `menu.json` — do not invent a different validation shape.
  - Version-bump `packages/core/package.json` (patch) before publish; never publish without a version bump.
  - Leave the actual `npm publish`/`release:enterprise` execution to the user — agent prepares the bump and passing tests, does not run the publish step.
  - Update `docs/flows/v1-save-stream.md` and `.cursor/rules/save-content.mdc` in the same change that ships the server-side fix (both currently describe this exact gap as known debt).
- **Ask first:**
  - Any change to `@olonjs/core`'s public export surface beyond the additive `StartCloudSaveStreamInput` fields.
  - Choosing diff-and-include-only-if-changed over always-include for `design-md-radice`'s Cold Save wiring (see Open Questions).
- **Never:**
  - Touch `POST /api/v1/hotSave` or `POST /api/v1/render` in this change — they are not part of the reported debt.
  - Modify any tenant other than `design-md-radice` in this change.
  - Touch `packages/cli/assets/templates/alpha/` — not needed (see Open Question #1, resolved).

## Proposed Contract

**Request body sent to `POST /api/v1/save-stream` (bundle mode, extended):**

```json
{
  "files": [
    { "path": "src/data/pages/home.json", "content": { "...page" } },
    { "path": "src/data/config/site.json", "content": { "...site, header, footer" } },
    { "path": "src/data/config/menu.json", "content": { "...menu" } }
  ],
  "changedScopes": ["page", "site", "menu"],
  "message": "Content update for home via Visual Editor"
}
```

Server validation rules (extending existing `site.json` rule):
1. `changedScopes.has('site')` requires `src/data/config/site.json` present in `files[]` → else `400 ERR_SITE_CONFIG_REQUIRED` (existing, unchanged).
2. `changedScopes.has('menu')` requires `src/data/config/menu.json` present in `files[]` → else `400 ERR_MENU_CONFIG_REQUIRED` (new).
3. `files[]` without matching `changedScopes` entries is still accepted as today (no over-strict rejection) — `changedScopes` only gates the "declared but missing" error case, exactly mirroring current `site` behavior.

## Implementation Plan (High Level)

1. **`npm-jpcore`:** extend `StartCloudSaveStreamInput` + request-body builder in `packages/core/src/dna/lib/cloudSaveStream.ts` (additive, backward-compatible). Add unit test. No DNA template regen needed (resolved — see Open Question #1).
2. **`npm-jpcore`:** bump `packages/core/package.json` patch version, run `npm run test:all -w @olonjs/core` (agent-owned). **Handoff point:** user runs the actual publish (`npm run release:enterprise` or manual `npm publish`) — agent stops here and waits for confirmation the new version is live on the registry before step 4.
3. **`jsonpages-platform`:** add `MENU_CONFIG_PATH`/`includesMenuConfig`, extend `changedScopes` type and validation, extend `summarizeFileKinds`, in `src/app/api/v1/save-stream/route.ts`. Extend smoke test coverage. Update `docs/flows/v1-save-stream.md` and `.cursor/rules/save-content.mdc`.
4. **`design-md-radice`:** `npm install @olonjs/core@latest` (patch resolves within existing `^1.1.12`). Update the Cold Save call site in `src/App.tsx` to pass `additionalFiles: [{ path: 'src/data/config/site.json', content: state.site }, { path: 'src/data/config/menu.json', content: state.menu }]` and `changedScopes: ['page', 'site', 'menu']`.
5. **Verification:** run platform smoke test, then manual end-to-end Cold Save from `design-md-radice` `/admin` with a real header/footer/menu edit; confirm GitHub commit + redeployed site.

## Success Criteria

1. `npm test -w @olonjs/core` passes, including new coverage for legacy vs. bundle request-body construction.
2. `POST /api/v1/save-stream` rejects `changedScopes: ['menu']` without `menu.json` in `files[]` with `400 ERR_MENU_CONFIG_REQUIRED`.
3. A Cold Save from `design-md-radice` `/admin` after editing header, footer, and a menu item results in a single GitHub commit containing updated `src/data/pages/*.json`, `src/data/config/site.json`, and `src/data/config/menu.json`.
4. The redeployed `design-md-radice` site (post-Cold-Save) visibly reflects the header/footer/menu edit.
5. `docs/flows/v1-save-stream.md` and `.cursor/rules/save-content.mdc` no longer describe this as open debt.

## Open Questions

None. All resolved:
- DNA template regen: not needed (`apps/tenant-alpha` imports from the published package, same as `design-md-radice`).
- Cold Save always includes `site`+`menu` (Assumption 6, confirmed).
- Version bump: patch (`1.1.13` → `1.1.14`).
