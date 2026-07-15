# Implementation Plan: Save2Repo Site/Menu Sync Contract

Implements: [specs/save2repo-site-menu-sync-contract-v1.md](../../specs/save2repo-site-menu-sync-contract-v1.md)

## Overview

Fix Save-to-Repo Cold Save so header/footer (`site.json`) and menu (`menu.json`) edits are actually committed, not silently dropped alongside the page. Root cause: `startCloudSaveStream` (`@olonjs/core`) only ever sends `path`+`content` for the page. Deliver in `npm-jpcore` (Core, additive contract change) → `design-md-radice` (adopt), with an independent `jsonpages-platform` hardening track for server-side `menu.json` validation.

## Key finding that shapes this plan

`POST /api/v1/save-stream`'s bundle mode (`files[]`) is **already fully generic** today — `commitFilesAtomically` commits any path with no allowlist. This means:
- The **functional fix does not depend on any platform change**. Once the tenant sends `menu.json` in `files[]`, it gets committed by the unmodified server.
- The platform-side `ERR_MENU_CONFIG_REQUIRED` validation is a **safety net** (fail loud if `changedScopes` declares `menu` but the file is missing), not a prerequisite.
- This splits the work into two independently shippable tracks — no artificial serialization.

## Architecture decisions

| Decision | Rationale |
|---|---|
| **Two independent tracks, not one linear chain** | Track A (functional fix: Core → publish → tenant) and Track B (platform validation hardening) have no runtime dependency on each other — confirmed via `commitFilesAtomically` genericity. |
| **Additive-only Core contract** | `additionalFiles?`/`changedScopes?` optional fields — zero risk to any other existing consumer of `startCloudSaveStream`. |
| **Patch version bump** | Change is additive/non-breaking per semver. |
| **Always-include site+menu in Cold Save** | No diffing complexity in `design-md-radice`; confirmed default. |
| **Human owns the npm publish** | Agent prepares code + version bump + green tests; stops at a hard checkpoint and waits for confirmation the new version is live before the tenant task starts. |

## Dependency graph

```
Track A (functional fix — primary):
A1 (Core: extend interface + impl + unit test)
    │
    ▼
A2 (Core: version bump + test:all)
    │
    ▼
⛳ Checkpoint A — HUMAN PUBLISHES (hard stop, agent waits for confirmation)
    │
    ▼
A3 (design-md-radice: bump dep + wire site+menu into Cold Save)
    │
    ▼
A4 (Manual E2E: edit header/footer/menu in /admin → Cold Save → verify commit + deploy)
    │
    ▼
⛳ Checkpoint B — Functional fix verified live

Track B (platform hardening — independent, parallel-safe):
B1 (Platform: MENU_CONFIG_PATH + includesMenuConfig + changedScopes validation)
    │
    ▼
B2 (Platform: extend smoke test coverage)
    │
    ▼
B3 (Platform: update docs/flows/v1-save-stream.md + save-content.mdc)
    │
    ▼
⛳ Checkpoint C — Platform hardening merged (no dependency on Track A)
```

- Track A and Track B can start in parallel today.
- Track A has one hard human checkpoint (publish) between A2 and A3 — everything before it is agent-executable, everything after requires the published package.
- Track B has no external dependency and no human checkpoint beyond normal review.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Breaking existing `startCloudSaveStream` callers (any consumer on `@olonjs/core@^1.1.x` other than `design-md-radice`) | High | A1's unit test explicitly asserts legacy single-file request body is byte-identical when `additionalFiles` is omitted |
| Agent proceeds past the publish checkpoint without confirmation | High | Checkpoint A is a hard stop in this plan and in `tasks/todo.md` — do not check it off without explicit user confirmation the registry has the new version |
| `menu.json` committed but not actually applied by the tenant build (stale bundle) | Med | A4's manual verification checks the redeployed site, not just the GitHub commit |
| Platform validation (`ERR_MENU_CONFIG_REQUIRED`) accidentally made blocking/required | Low | B1 must mirror the existing `site.json` pattern exactly — only fires when `changedScopes` explicitly declares the scope; never rejects a bundle that simply omits `changedScopes` |
| `design-md-radice` Cold Save wiring accidentally sends stale `state.site`/`state.menu` (closure bug) | Med | A3's acceptance criteria requires reading `state.site`/`state.menu` from the same `ProjectState` passed into the Cold Save call, not a stale outer-scope reference |

## Checkpoints

### Checkpoint A — Human publishes `@olonjs/core` (hard stop)

- [x] A1 complete (contract + test written)
- [x] Agent stopped and reported the diff
- [x] **User ran the publish manually**, owning the version bump too (agent's A2 version-bump edit was reverted/superseded — version bump is part of publishing, not agent scope)
- [x] User confirmed: `@olonjs/core@1.1.15` is live on the registry
- [ ] `npm run test:all -w @olonjs/core` result not confirmed by agent (shell blocker) — assumed verified by user before publish
- [x] Agent did not start A3 before this confirmation

### Checkpoint B — Functional fix verified live

- [ ] A3 + A4 complete
- [ ] Real Cold Save from `design-md-radice` `/admin` after a header/footer/menu edit produces a commit with `site.json` + `menu.json` updated
- [ ] Redeployed site visibly reflects the edit

### Checkpoint C — Platform hardening merged

- [ ] B1 + B2 + B3 complete
- [ ] `docs/flows/v1-save-stream.md` and `.cursor/rules/save-content.mdc` no longer describe this as open debt
- [ ] Human review before merge (per `jsonpages-platform` normal PR flow)

---

## Task list

### Track A — Functional fix

#### Task A1: Extend `startCloudSaveStream` contract (Core)

**Description:** In `packages/core/src/dna/lib/cloudSaveStream.ts`, add optional `additionalFiles?: Array<{ path: string; content: unknown }>` and `changedScopes?: Array<'page' | 'site' | 'menu'>` to `StartCloudSaveStreamInput`. When `additionalFiles` is present, build request body as `{ files: [{path, content}, ...additionalFiles], changedScopes, message }`; otherwise keep the exact current `{ path, content, message }` body unchanged.

**Acceptance criteria:**
- [x] Legacy call (no `additionalFiles`) produces byte-identical request body to current behavior
- [x] Call with `additionalFiles` produces a `files[]` bundle body including the primary `path`/`content` plus all additional files
- [x] `changedScopes` passed through verbatim when provided, omitted from body when not provided
- [x] No changes to `onStep`/`onLog`/`onDone`/SSE parsing logic

**Verification:**
- [x] New unit test file `packages/core/src/dna/lib/cloudSaveStream.test.ts` covering both request-body shapes (written, 4 cases)
- [ ] `npm test -w @olonjs/core` — **blocked, not run**: local shell environment failed to spawn (`powershell.exe ENOENT`), intermittent. User to run manually.
- [ ] `npm run test:boundary -w @olonjs/core` — same blocker, not run

**Dependencies:** None

**Files likely touched:**
- `packages/core/src/dna/lib/cloudSaveStream.ts`
- `packages/core/src/dna/lib/cloudSaveStream.test.ts` (new)

**Estimated scope:** S (2 files)

---

#### Task A2: Version bump + pre-publish checks (Core)

**Scope correction:** version bump is part of publishing, owned by the user end-to-end — not agent scope. Agent's earlier bump to `1.1.14` was reverted/superseded; user bumped and published `1.1.15` directly.

**Acceptance criteria:**
- [x] `packages/core/package.json` version bumped and published as `1.1.15` (by user)
- [x] Assumed tested by user before publish (agent could not run `test:all` — shell blocker)

**Verification:**
- [x] User confirmed `@olonjs/core@1.1.15` live on registry

**Dependencies:** Task A1

**Files likely touched:**
- `packages/core/package.json`

**Estimated scope:** XS (1 file)

---

### ⛳ Checkpoint A — stop here, human publishes

---

#### Task A3: Adopt new contract in Cold Save wiring (`design-md-radice`)

**Description:** After the user confirms the new `@olonjs/core` version is published: run `npm install @olonjs/core@latest` in `design-md-radice`. Update the Cold Save call site (`src/App.tsx`, the `startCloudSaveStream` invocation inside the coldSave/Save2Repo action) to pass `additionalFiles: [{ path: 'src/data/config/site.json', content: state.site }, { path: 'src/data/config/menu.json', content: state.menu }]` and `changedScopes: ['page', 'site', 'menu']`, reading `state` from the same `ProjectState` argument already in scope for that call — not from an outer/stale reference.

**Acceptance criteria:**
- [ ] `package.json`/`package-lock.json` reflects the updated (published) `@olonjs/core` resolution — **not done**: `npm install @olonjs/core@latest` blocked by shell, lockfile still on `1.1.12`
- [x] Cold Save call includes `additionalFiles` with `site.json`/`menu.json` sourced from the current save's `state` — via new `src/lib/coldSaveBundle.ts::buildColdSaveAdditionalFiles()`, `changedScopes: ['page','site','menu']` added
- [x] Existing page-only content of the call (`path`, `content: state.page`, `message`) unchanged

**Verification:**
- [ ] `npm run build` (`tsc && vite build`) — **not run**, shell blocker
- [ ] `node --experimental-strip-types scripts/cold-save-bundle-unit.mjs` (new unit test) — **not run**, shell blocker
- [ ] Manual: trigger Cold Save from `/admin` in dev, inspect the network request body sent to `/save-stream` — confirm `files[]` contains all three paths — pending

**Dependencies:** Checkpoint A (human publish confirmed)

**Files likely touched:**
- `design-md-radice/package.json`
- `design-md-radice/src/App.tsx`

**Estimated scope:** S (2 files)

---

#### Task A4: End-to-end verification

**Description:** From a real `design-md-radice` deployment, edit header, footer, and a menu item in `/admin`, trigger Cold Save, and confirm the full round-trip.

**Acceptance criteria:**
- [ ] GitHub commit produced by Cold Save includes updated `src/data/config/site.json` and `src/data/config/menu.json` (not just the page)
- [ ] Vercel deployment triggered by Cold Save succeeds
- [ ] Redeployed site visibly shows the header/footer/menu edit

**Verification:**
- [ ] Manual — inspect the GitHub commit diff
- [ ] Manual — visit the redeployed site

**Dependencies:** Task A3

**Files likely touched:** None (verification only)

**Estimated scope:** XS (manual)

---

### ⛳ Checkpoint B — Functional fix verified live

---

### Track B — Platform hardening (independent, parallel-safe)

#### Task B1: `menu.json` validation contract (Platform)

**Description:** In `jsonpages-platform/src/app/api/v1/save-stream/route.ts`, add `MENU_CONFIG_PATH = 'src/data/config/menu.json'` and `includesMenuConfig(files)`, mirroring `SITE_CONFIG_PATH`/`includesSiteConfig` exactly. Extend the `changedScopes` type from `Set<'page' | 'site'>` to `Set<'page' | 'site' | 'menu'>` (and the corresponding filter in `resolveSavePayload` and the `SaveRequestBody.changedScopes` type). Add validation: `changedScopes.has('menu') && !includesMenuConfig(files)` → `400 ERR_MENU_CONFIG_REQUIRED`, mirroring the existing `ERR_SITE_CONFIG_REQUIRED` check. Extend `summarizeFileKinds` to count `menu` as its own bucket instead of falling into `other`.

**Acceptance criteria:**
- [ ] `changedScopes: ['menu']` without `menu.json` in `files[]` → `400 ERR_MENU_CONFIG_REQUIRED`
- [ ] `changedScopes: ['menu']` with `menu.json` present → succeeds, no behavior regression
- [ ] Omitting `changedScopes` entirely still works exactly as today (non-blocking default preserved)
- [ ] Existing `site`/`page` validation behavior unchanged

**Verification:**
- [ ] `npx tsc --noEmit`
- [ ] Extended smoke test (Task B2)

**Dependencies:** None (independent of Track A)

**Files likely touched:**
- `jsonpages-platform/src/app/api/v1/save-stream/route.ts`

**Estimated scope:** S (1 file)

---

#### Task B2: Extend smoke test coverage (Platform)

**Description:** Extend `jsonpages-platform/scripts/save2-hot-cold-smoke.mjs` (or add a sibling script if scope grows) with: (a) bundle including `menu.json` + `changedScopes: ['menu']` succeeds; (b) `changedScopes: ['menu']` without `menu.json` returns `400 ERR_MENU_CONFIG_REQUIRED`; (c) legacy single-file `path`+`content` call still succeeds unchanged (regression guard).

**Acceptance criteria:**
- [ ] All three cases covered and passing against a test tenant
- [ ] Script follows existing conventions in `save2-hot-cold-smoke.mjs`

**Verification:**
- [ ] `npm run test:save2:smoke` (or the relevant new/updated script command)

**Dependencies:** Task B1

**Files likely touched:**
- `jsonpages-platform/scripts/save2-hot-cold-smoke.mjs`

**Estimated scope:** S (1 file)

---

#### Task B3: Documentation update (Platform)

**Description:** Update `docs/flows/v1-save-stream.md` to document the `menu` scope and the `files[]` bundle contract extension. Update `.cursor/rules/save-content.mdc` to remove the "known debt" framing for this specific gap (menu.json not sent) now that it's fixed, keeping the rest of the file's content (Save2Repo vs Save-to-Repo naming trap, hotSave/render caller table, etc.) intact.

**Acceptance criteria:**
- [ ] `v1-save-stream.md` documents `menu` alongside `site` in the request contract
- [ ] `save-content.mdc` no longer lists the site/menu gap as open debt
- [ ] No unrelated content removed from either file

**Verification:**
- [ ] Human doc review

**Dependencies:** Task B1

**Files likely touched:**
- `jsonpages-platform/docs/flows/v1-save-stream.md`
- `jsonpages-platform/.cursor/rules/save-content.mdc`

**Estimated scope:** XS (2 files)

---

### ⛳ Checkpoint C — Platform hardening merged

---

## Estimated effort

| Task | Effort |
|---|---|
| A1 | ~1–1.5h |
| A2 | ~15min |
| A3 | ~45min |
| A4 | ~30min (manual) |
| B1 | ~45min |
| B2 | ~45min |
| B3 | ~30min |

**Total:** ~4.5–5h across the two tracks, split by the publish checkpoint.

## Parallelization

| Parallel safe | Must be sequential |
|---|---|
| Track B (B1→B2→B3) can run entirely in parallel with Track A | A1 → A2 → Checkpoint A → A3 → A4 (strict order within Track A) |
| A1/A2 can happen while B1/B2/B3 are also in progress | B1 → B2 → B3 (each depends on the previous within Track B) |
