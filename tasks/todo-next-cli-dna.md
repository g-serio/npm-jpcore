# Todo: Next CLI DNA + release:enterprise

Plan: `docs/plans/next-cli-dna-release.md`  
Status: **implemented — awaiting dry-run human go for real publish**

## Phase 1: DNA

- [x] **Task 1:** `src2Code.sh` + `dist` on `apps/next` (`--template next`)
  - Acceptance: `package.json` has `dist` / `dist:dna`; encoder present and executable
  - Verify: script runs without error
  - Files: `apps/next/src2Code.sh`, `apps/next/package.json`
  - Scope: S

- [x] **Task 2:** Generate `packages/cli/assets/templates/next/`
  - Acceptance: `src_tenant.sh` + `manifest.json` (`name: next`); DNA includes `app/`, `middleware.ts`, `package.json`
  - Verify: inspect manifest + grep DNA markers
  - Files: `packages/cli/assets/templates/next/**`
  - Scope: S · Depends: 1

- [x] **Task 3:** Extend `dist:dna:all` + `check:templates` for `next`
  - Acceptance: root runs alpha + tenant-next; checker requires `['alpha','next']`
  - Verify: `npm run check:templates`
  - Files: `package.json`, `scripts/check-cli-templates.mjs`
  - Scope: S · Depends: 2

### Checkpoint: DNA

- [x] Both templates pass `check:templates`
- [ ] Human review DNA file list

## Phase 2: CLI UX + scaffold

- [x] **Task 4:** Interactive picker (arrows + Enter) when `--template` absent — labels **`next`** | **`vite`**
  - Acceptance: TUI selectable; maps to DNA ids `next` / `alpha`
  - Verify: manual interactive run
  - Files: `packages/cli/src/index.js` (+ prompt helper if needed)
  - Scope: M · Depends: 2

- [x] **Task 5:** Keep `--template` for agents (`next` | `vite` | `alpha`); skip TUI when set; non-TTY without flag → clear error (or agreed default)
  - Acceptance: `--template next` / `vite` / `alpha` never prompts
  - Verify: scripted non-interactive invoke
  - Files: `packages/cli/src/index.js`
  - Scope: S · Depends: 4

- [x] **Task 6:** Scaffold branches — Next DNA-first (no Vite inject); Vite/alpha path unchanged
  - Acceptance: next → App Router tree; vite/alpha → existing Vite flow
  - Verify: smoke both templates via `--template`
  - Files: `packages/cli/src/index.js`
  - Scope: M · Depends: 2, 5

- [x] **Task 7:** Smoke interactive + `--template` paths
  - Acceptance: both UX paths work; alpha regression OK
  - Verify: manual TUI + `--template next` + `--template vite`
  - Scope: S · Depends: 4, 5, 6

### Checkpoint: CLI

- [x] Maschera next/vite OK
- [x] `--template` agent path OK
- [x] Alpha/Vite regression OK

## Phase 3: Enterprise release

- [x] **Task 8:** Publish `@olonjs/next` in `release.js`
  - Acceptance: build + version bump + publish (dry-run skip) after react/studio, before CLI
  - Verify: dry-run log
  - Files: `scripts/release.js`
  - Scope: M · Depends: 3

- [x] **Task 9:** `stepTenant` for Next (`apps/next` mapping) + pin `@olonjs/next`
  - Acceptance: pins core/react/studio/next; build + dist; path is `apps/next`
  - Verify: dry-run
  - Files: `scripts/release.js`
  - Scope: M · Depends: 3, 8

- [x] **Task 10:** Docs + dry-run checklist (TUI + `--template` for agents)
  - Acceptance: TEMPLATES/CLI/PUBLISHING updated
  - Verify: `npm run release:enterprise -- --dry-run`
  - Files: `docs/TEMPLATES.md`, `docs/CLI.md`, `docs/PUBLISHING.md`
  - Scope: S · Depends: 8, 9

### Checkpoint: Complete

- [ ] Dry-run green
- [ ] Human go for real `release:enterprise`
- [ ] Real publish only on explicit request

**Task 10 verify:** Docs updated; run `npm run release:enterprise -- --dry-run` before real publish (human go).
