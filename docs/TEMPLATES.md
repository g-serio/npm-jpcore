# Templates

This document defines multi-template governance for CLI DNA assets.

## Scope

Required templates in current repository:

- `alpha`
- `next`

## Asset layout

Template assets live in:

- `packages/cli/assets/templates/<template>/src_tenant.sh`
- `packages/cli/assets/templates/<template>/manifest.json`

Compatibility copy for `alpha`:

- `packages/cli/assets/src_tenant_alpha.sh`

## Source of truth (SOT)

Template DNA must be generated from source apps:

- `apps/tenant-alpha` → template `alpha`
- `apps/next` (npm workspace `tenant-next`) → template `next`

**Note:** The Next source app lives at `apps/next`, not `apps/tenant-next`. The workspace name (`tenant-next`) differs from the folder name — see `scripts/releaseTenantPaths.js` for the release mapping.

SOT generation command:

```bash
npm run dist:dna:all
```

This delegates to each source app dist script:

- `npm run dist -w tenant-alpha`
- `npm run dist -w tenant-next`

## Conformance

Validate templates with:

```bash
npm run check:templates
```

Current checks (`scripts/check-cli-templates.mjs`):

- required template directories exist (`alpha`, `next`)
- `src_tenant.sh` exists
- `manifest.json` exists
- manifest fields match expected values
- DNA script includes baseline markers

## Manifest contract

Each `manifest.json` must include:

- `name`: template name
- `sourceApp`: source application directory name
- `dnaScript`: `src_tenant.sh`

## Template author workflow

1. edit source app (`apps/tenant-alpha` for Vite/alpha, or `apps/next` for Next)
2. run source app `dist` or root `dist:dna:all`
3. run `npm run check:templates`
4. verify CLI behavior with `--template <name>` (or interactive TUI for humans)

## Add a new template

Minimum steps:

1. create source app `apps/tenant-<name>` (or another folder name — workspace name may differ from folder; see `next` / `tenant-next` → `apps/next`)
2. ensure source app has `dist` script generating template DNA
3. generate template assets under `packages/cli/assets/templates/<name>/`
4. update `scripts/check-cli-templates.mjs` required template list
5. add workspace to root `dist:dna:all` if applicable
6. validate with `npm run check:templates`
7. update docs (`README.md`, `docs/CLI.md`, `docs/TEMPLATES.md`)

## Do and do not

- Do: treat source app as canonical edit target
- Do: regenerate DNA from source app before release
- Do: run conformance checks in CI and pre-release
- Do not: hand-edit generated DNA as primary workflow
