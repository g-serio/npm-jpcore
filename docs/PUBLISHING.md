# Publishing and Release

This document is the operational source of truth for two distinct publishing flows in this monorepo:

1. **npm package publishing** — `@olonjs/stack`, `@olonjs/core`, `@olonjs/cli`, plus compatibility bridges under `@jsonpages/*`. Manual, gated, runs from a developer machine.
2. **`olon.js.org` site deploy** — the marketing site lives at `apps/olonjs.io/` and ships to `gh-pages` automatically on every push to `main`. No manual step.

The two flows are independent. A new `@olonjs/core` version can be published to npm without redeploying the site, and the site can redeploy without bumping any package version.

## Scope

- Standard flow: `npm run release`
- Enterprise-gated flow: `npm run release:enterprise`
- DNA governance (`alpha` + `next`)
- `olon.js.org` deploy (`gh-pages` via GitHub Actions)

## Prerequisites

- npm account with publish rights on `@olonjs`
- `NPM_TOKEN` available in environment or root `.env`
- root `.npmrc` configured for npm registry auth
- dependencies installed from monorepo root

Example `.env`:

```bash
NPM_TOKEN=npm_xxx
```

## Package publish order

Always publish in this order (see `scripts/release.js`):

1. `@olonjs/stack`
2. `@olonjs/core`
3. `@olonjs/studio`
4. `@olonjs/react`
5. `@olonjs/mcp`
6. `@olonjs/next`
7. `tenant-alpha` — pin `@olonjs/core`, `@olonjs/react`, `@olonjs/studio`; build + `dist` (regenerates alpha DNA)
8. `tenant-next` (`apps/next`) — pin `@olonjs/core`, `@olonjs/react`, `@olonjs/studio`, `@olonjs/next`; build + `dist` (regenerates next DNA)
9. `@olonjs/cli`
10. compatibility bridges (`@jsonpages/stack`, `@jsonpages/core`, `@jsonpages/cli`)

Reason:

- `core` aligns dependency contracts using stack manifest
- `studio` / `react` / `mcp` follow the ADR-0016 dependency graph
- `@olonjs/next` must publish before tenant-next pins it and before CLI packages both DNA templates
- both tenant workspaces regenerate DNA (`dist`) with pinned versions before CLI publish
- `cli` must package DNA generated from both source apps using the new versions
- compatibility bridges must point to freshly published `@olonjs/*` versions

## `@olonjs/core` dual-bundle build

As of v1.1.0 (see [ADR-0009](./decisions/ADR-0009-core-studio-split-via-runtime-subpath.md)), `@olonjs/core` ships two physical bundles in a single package:

- `dist/olonjs-core.js` — full bundle (runtime + Studio admin), imported via `from '@olonjs/core'`
- `dist/olonjs-core-runtime.js` — runtime-only bundle (visitor subset), imported via `from '@olonjs/core/runtime'`

### Build commands

| Command | Effect |
|---|---|
| `npm run build -w @olonjs/core` | Full dual build via `scripts/build-dual.mjs`. **Use this.** Runs both Vite configs and stitches dts outputs. |
| `npm run build:full -w @olonjs/core` | Full bundle only. Used internally by the orchestrator. |
| `npm run build:runtime -w @olonjs/core` | Runtime bundle only. Used internally by the orchestrator. Sets `emptyOutDir: false` and depends on a pre-existing full build. |

Do not invoke `build:full` or `build:runtime` directly during a release — the orchestrator handles dts file rename/restore so both `index.d.ts` and `runtime.d.ts` survive.

### Pre-publish gate

Before publishing `@olonjs/core`, the boundary check must pass. It enforces that `src/runtime-entry.ts` and its import graph never reach into `src/studio/admin/` or `src/studio/orchestration/`:

```bash
npm run test:boundary -w @olonjs/core   # decoupling check (~1s)
npm run test:all     -w @olonjs/core    # boundary + vitest unit tests
```

A failing boundary check is a **publish blocker**: it means a recent change has put Studio admin code on the visitor critical path, defeating the purpose of [ADR-0009](./decisions/ADR-0009-core-studio-split-via-runtime-subpath.md).

### Verifying the published artifacts

After `npm publish`, sanity-check that both bundles are in the tarball and decoupled:

```bash
npm pack @olonjs/core
tar -tzf olonjs-core-*.tgz | grep -E 'dist/(olonjs-core|runtime)'
# Expected output:
#   package/dist/olonjs-core.js
#   package/dist/olonjs-core-runtime.js
#   package/dist/olonjs-core.umd.cjs
#   package/dist/index.d.ts
#   package/dist/runtime.d.ts

# Confirm runtime bundle has zero Studio admin symbols:
node -e "const c=require('fs').readFileSync('node_modules/@olonjs/core/dist/olonjs-core-runtime.js','utf8'); console.log(['AdminSidebar','FormFactory','StudioStage'].map(s=>[s,(c.match(new RegExp(s,'g'))||[]).length]))"
# Expected: all counts = 0

# Confirm the full bundle imports the runtime sibling artifact (ADR-0012):
node -e "const c=require('fs').readFileSync('node_modules/@olonjs/core/dist/olonjs-core.js','utf8'); console.log('runtime imports:', (c.match(/olonjs-core-runtime\.js/g) || []).length)"
# Expected: ≥ 1 (typically ~12 in v1.1.1)
```

### Colocation requirement (ADR-0012)

As of v1.1.1, `dist/olonjs-core.js` (and its UMD sibling) contain explicit `import "./olonjs-core-runtime.js"` references for the four singleton-bearing modules (`ConfigContext`, `StudioContext`, `theme-manager`, `IconRegistryContext`). The runtime artifact MUST sit next to the full artifact in `dist/` for the package to load. This is already guaranteed by `package.json` `files: ["dist"]` and the `exports` map; the warning here is for any tooling that copies a subset of files (custom CDN setups, partial mirrors, certain bundle-size analyzers). If you see `ERR_MODULE_NOT_FOUND: olonjs-core-runtime.js` after install, the cause is colocation, not the package itself.

## Release scripts

### `npm run release`

Executes legacy release pipeline in `scripts/release.js`.

Current behavior includes:

- build all workspaces
- patch version + publish `stack`
- build, patch version + publish `core`
- build, patch version + publish `studio`
- build, patch version + publish `react`
- build, patch version + publish `mcp`
- build, patch version + publish `@olonjs/next`
- update `tenant-alpha` pins; build + `dist` (alpha DNA)
- update `tenant-next` (`apps/next`) pins; build + `dist` (next DNA)
- build, patch version + publish `cli`
- sync bridge dependencies and publish `@jsonpages/*` compatibility packages

### `npm run release:enterprise`

Executes `scripts/release-enterprise.js`:

1. `npm run check:templates` (requires `alpha` + `next` template assets)
2. `npm run dist:dna:all` (runs `tenant-alpha` and `tenant-next` / `apps/next` dist)
3. delegates to `node scripts/release.js` (full order: stack → core → studio → react → mcp → next → tenant-alpha → tenant-next → cli → compat)

Use this for gated releases when template governance must be enforced before publish.

## DNA governance

### Source of truth

- `apps/tenant-alpha` is SoT for template `alpha`
- `apps/next` (workspace `tenant-next`) is SoT for template `next`

### Dist command

Root DNA generation:

```bash
npm run dist:dna:all
```

This runs both workspaces:

- `npm run dist -w tenant-alpha`
- `npm run dist -w tenant-next` (`apps/next`)

### Template conformance

Validate required template assets:

```bash
npm run check:templates
```

Validation checks:

- required template directories exist
- `src_tenant.sh` exists per required template
- `manifest.json` exists and is consistent
- DNA script contains baseline safety/content markers

## Dry-run checklist

Run from repository root before any real publish. Real publish only after explicit human approval.

1. **Template conformance**

   ```bash
   npm run check:templates
   ```

   Expect: `alpha` + `next` template assets valid.

2. **Regenerate DNA**

   ```bash
   npm run dist:dna:all
   ```

   Runs `tenant-alpha` and `tenant-next` (`apps/next`) dist scripts.

3. **Release dry-run**

   ```bash
   npm run release:enterprise -- --dry-run
   ```

   Or: `npm run release -- --dry-run`

   Expect logs for `@olonjs/next`, `tenant-next` (`apps/next`), and both DNA dist steps. No `npm publish` calls.

   Optional if git tree is dirty: add `--skip-git-check`.

4. **Revert version bumps**

   Dry-run patches `package.json` versions locally. Revert before committing unrelated work:

   ```bash
   git checkout -- .
   ```

   Or restore only bumped `package.json` files under root, `apps/*/`, and `packages/*/`.

5. **Real publish (human go only)**

   ```bash
   npm run release:enterprise
   ```

   Do not run without explicit approval after dry-run review.
## Recommended release procedure

Complete the [Dry-run checklist](#dry-run-checklist) first. Run from repository root.

1. Validate workspace state

```bash
npm install
npm run build:all
```

2. Validate templates and regenerate DNA

```bash
npm run check:templates
npm run dist:dna:all
```

3. Dry-run release

```bash
npm run release -- --dry-run
```

4. Execute enterprise release

```bash
npm run release:enterprise
```

## `olon.js.org` site deploy (gh-pages)

The marketing site at https://olon.js.org is served from the `gh-pages` branch of this repo and rebuilt automatically by `.github/workflows/deploy-landing.yml`. There is no manual deploy script and no `gh-pages` package dependency — the GitHub Action does all the work.

### Trigger

The workflow runs on every push to `main` whose change set touches one of:

- `apps/olonjs.io/**`
- `packages/core/**`
- `.github/workflows/deploy-landing.yml`

Pushes that only touch `docs/`, `packages/cli/`, `packages/stack/`, or `apps/tenant-alpha/` do **not** trigger a redeploy. This is intentional — keeps the site stable when only ADRs or templates change.

### Pipeline steps

`.github/workflows/deploy-landing.yml`:

1. `actions/checkout@v4` — full repo checkout.
2. `actions/setup-node@v4` (Node 20, npm cache).
3. `npm install` from monorepo root (workspaces resolve `@olonjs/core` from `packages/core/`).
4. `cd packages/core && npm run build` — produces both bundles (`olonjs-core.js` + `olonjs-core-runtime.js`) via `scripts/build-dual.mjs`. Required because the tenant build imports from `@olonjs/core` and `@olonjs/core/runtime` and the in-monorepo workspace symlink resolves to `packages/core/dist/`.
5. `node apps/olonjs.io/scripts/bake.mjs` — runs the OlonJS SSG bake:
   - Builds the client bundle (`apps/olonjs.io/dist/`).
   - Builds an SSR entry bundle (`apps/olonjs.io/dist-ssr/`).
   - Discovers all page slugs from `apps/olonjs.io/src/data/pages/*.json`.
   - Renders each slug via SSR and writes `dist/<slug>/index.html` plus the WebMCP page contracts and manifests.
6. `JamesIves/github-pages-deploy-action@v4` — pushes `apps/olonjs.io/dist/` to the `gh-pages` branch with `clean: true`. GitHub Pages serves it at `olon.js.org` (CNAME).

### Developer workflow

The expected day-to-day flow for any change that should appear on `olon.js.org`:

```bash
# 1. Make changes in apps/olonjs.io/ or packages/core/
git checkout -b my-change
# … edit …

# 2. Verify locally (no deploy yet)
npm run build -w @olonjs/core         # if core changed
npm run build -w olonjs-landing        # tenant build = same as CI step 5 minus SSG

# 3. Commit and push the branch
git add <files>
git commit -m "…"
git push origin my-change

# 4. Open a PR to main, get review, merge

# 5. After merge, watch the workflow:
#    https://github.com/olonjs/core/actions/workflows/deploy-landing.yml
#    Typical run: 2-3 minutes from push to gh-pages update.

# 6. Verify the deploy:
#    - Hard reload https://olon.js.org
#    - Optionally re-run Lighthouse if perf-sensitive change
```

### Hot-fix flow (skip the PR)

If you push directly to `main` (allowed for repo owners), the workflow triggers the same way. Use sparingly — there is no preview environment.

### What if the workflow fails

`deploy-landing.yml` has no rollback step. A failed deploy leaves the previous `gh-pages` commit live. Common failure modes:

| Symptom | Likely cause | Fix |
|---|---|---|
| `Cannot find module '@olonjs/core/runtime'` | Step 4 didn't produce `dist/runtime.d.ts` (legacy single-bundle build invoked) | Verify `packages/core/package.json` `build` script points at `scripts/build-dual.mjs`, not raw `vite build` |
| `npm error EISDIR symlink … node_modules/@olonjs/…` | npm workspaces collision on a stale symlink | Add a `rm -rf node_modules` step before install in the workflow, or use `npm ci` |
| `bake.mjs: Cannot find page <slug>` | A page JSON was renamed but the menu/site reference wasn't updated | Sync the rename in `src/data/config/site.json` and `menu.json` |
| Action succeeds but `olon.js.org` 404s | DNS / CNAME issue, not the build | Check `apps/olonjs.io/public/CNAME` and the GitHub Pages settings |

The Lighthouse audit assets occasionally end up on disk during local runs (`C:\Users\…\AppData\Local\lighthouse.*\Singleton*`). These are Chromium temp dirs and **must not** be committed — confirm `.gitignore` covers `lighthouse.*` at the repo root before pushing.

### Relationship to npm package publishing

The site deploy reads `@olonjs/core` from the monorepo workspace, **not** from the npm registry. Publishing a new `@olonjs/core` version to npm therefore does not affect `olon.js.org` until a separate commit lands that touches `apps/olonjs.io/**` or `packages/core/**`. Conversely, `olon.js.org` always tracks the latest committed `packages/core/`, even if no npm version has been published with those changes yet.

This means:

- A perf fix in `apps/olonjs.io/` is live on `olon.js.org` ~3 minutes after merging to `main`. No npm publish required.
- A breaking change in `packages/core/` is **live on `olon.js.org` ~3 minutes after merging to `main`** (because the workflow rebuilds core from source). External tenants on the published npm version are **unaffected** until you `npm run release`.

The boundary check (`npm run test:boundary -w @olonjs/core`) should ideally be wired into the deploy-landing workflow as a pre-build gate, but currently runs only in the standalone npm release flow.

## Windows note

If npm commands fail under UNC paths (`\\wsl.localhost\...`), use WSL shell to run release commands.

## Troubleshooting

- `Error: Unknown template ...` in CLI
  - Check `packages/cli/assets/templates/<template>/src_tenant.sh`
  - Run `npm run dist:dna:all`
- Template conformance failure
  - Run `npm run check:templates` and fix missing assets/manifests
- npm auth errors during publish
  - Verify `NPM_TOKEN`, `.npmrc`, and npm org permissions
- Release succeeds but new tenants are stale
- Ensure `dist:dna:all` ran before publishing `@olonjs/cli`

## Related docs

- `docs/ARCHITECTURE.md`
- `docs/CLI.md`
- `docs/TEMPLATES.md`
- `docs/README.md`
