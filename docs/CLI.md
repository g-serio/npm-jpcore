# CLI

This document defines the current `@olonjs/cli` behavior and contract.

## Package location

- `packages/cli/src/index.js`

## Binary

- command name: `olonjs` (primary), `jsonpages` (compatibility alias)
- entrypoint: `./src/index.js`

## Primary command

```bash
olonjs new tenant <name>
```

Supported options:

- `--template <name>`: choose template for agents/CI (`next` | `vite` | `alpha`); skips interactive picker
- `--script <path>`: override template DNA path directly

## Template selection UX

### Interactive (human, TTY)

When `--template` is **not** provided and stdin/stdout are a TTY, the CLI shows an arrow-key picker (Enter to confirm) with two labels:

- **next** → DNA template `next`
- **vite** → DNA template `alpha`

### Agents / CI (non-interactive)

Pass `--template` explicitly. Accepted values:

| `--template` | DNA id | Stack |
|---|---|---|
| `next` | `next` | Next App Router (DNA-first) |
| `vite` | `alpha` | Vite + React TS |
| `alpha` | `alpha` | Vite + React TS (alias of `vite`) |

When `--template` is set, the TUI is never shown.

### Non-TTY without `--template`

If stdin/stdout are not a TTY and `--template` is missing, the CLI **fails** with a clear error:

```
Non-interactive mode requires --template next|vite|alpha (for agents/CI).
```

## Examples

```bash
# Human: interactive picker (next | vite)
olonjs new tenant my-site

# Agent/CI: Next App Router tenant
olonjs new tenant my-site --template next

# Agent/CI: Vite tenant (same DNA as alpha)
olonjs new tenant my-site --template vite
olonjs new tenant my-site --template alpha

# Override DNA script path directly
olonjs new tenant my-site --script ./custom/src_tenant.sh
```

## Template resolution

Default resolution path:

- `packages/cli/assets/templates/<dnaId>/src_tenant.sh`

Fallback compatibility for `alpha`:

- `packages/cli/assets/src_tenant_alpha.sh`

If template is unknown and `--script` is not provided, CLI exits with a template list.

Implementation: `packages/cli/src/templateChoice.js` maps UI labels and `--template` values to DNA ids.

## Generation pipeline

When running `olonjs new tenant <name>` (or `jsonpages new tenant <name>`), the pipeline branches on DNA id:

### `next` (Next App Router)

1. prepare empty workspace (no `create-vite` / no Vite inject path)
2. project DNA by interpreting shell script (`mkdir -p` and heredoc file blocks) from `templates/next/src_tenant.sh`
3. install dependencies

### `alpha` / `vite` (Vite + React TS)

1. scaffold Vite React TS app (`create vite`)
2. remove boilerplate files
3. inject minimal infra files (`package.json`, `tsconfig.json`, `components.json`)
4. project DNA from `templates/alpha/src_tenant.sh`
5. install dependencies

## Notes

- Template assets are packaged through `packages/cli/package.json` (`files` includes `assets/templates`).
- Template conformance check exists at `npm run check:templates` (requires `alpha` + `next`).
- Regenerate DNA before release: `npm run dist:dna:all`.

## CLI maintenance checklist

Before publishing CLI:

1. `npm run check:templates`
2. `npm run dist:dna:all`
3. `node --check packages/cli/src/index.js`
4. run release flow (`release:enterprise` recommended)
