# @olonjs/stack

**Single source of truth** for OlonJS tenant dependency versions (enterprise stack manifest).

## Purpose

- **Core, React, Studio** (post-ADR-0016 three-package split) each sync their own `peerDependencies` from this manifest via their own `prepack` script.
- **CLI** uses this manifest when projecting a new tenant so `npm install` gets the exact versions defined here.
- No version drift: one file to change when upgrading React, Vite, React Router, etc.

## Peer dependency fields (post-ADR-0016)

`@olonjs/core` is framework-agnostic (zero React, per ADR-0016) — it must **not** peer on `react`/`react-dom`/`react-router-dom`. `@olonjs/react` and `@olonjs/studio` do need those. To keep each package's sync script pulling only what it actually needs:

- `corePeerDependencies` — what `@olonjs/core` syncs (`zod` only).
- `reactBindingPeerDependencies` — the shared React-family peer set synced into both `@olonjs/react` and `@olonjs/studio` (`react`, `react-dom`, `react-router-dom`). `@olonjs/studio` additionally merges in `corePeerDependencies.zod` (its `FormFactory`/`AdminSidebar` introspect tenant Zod schemas directly, per ECIP). `@olonjs/react` additionally preserves its own `@olonjs/studio` optional peer (the ADR-0016 D2 dynamic-import bridge), which is package-specific and not stack-driven.
- `peerDependencies` — the full union, kept for CLI-projected tenant `package.json` files (a tenant app itself needs the whole stack).
- `packages` — the three `@olonjs/*` package versions, coordinated (used to keep `dependencies` and any future CLI dependency-injection logic aligned).

**Do not** point any `@olonjs/core` sync script at the full `peerDependencies` block again — that was a real regression caught during Phase 4 of the package-split plan (it silently reintroduced React into Core's peer contract).

## Workflow

1. **Upgrade stack:** Edit `stack-versions.json` (dependencies, devDependencies, peerDependencies, corePeerDependencies, reactBindingPeerDependencies, packages). Keep these in sync with what Core/React/Studio actually support.
2. **Publish order:** Publish `@olonjs/stack` first, then `@olonjs/core`, then `@olonjs/react` and `@olonjs/studio`, then `@olonjs/cli` (legacy aliases: `@jsonpages/stack`, `@jsonpages/core`, `@jsonpages/cli`).
3. **From repo:** Run `npm install` at monorepo root so workspace deps resolve; then build/publish Core, React, Studio, and CLI as needed.

## Consumers

| Package        | Use |
|----------------|-----|
| @olonjs/core | `prepack` runs `scripts/sync-peers-from-stack.js` → copies `corePeerDependencies` into Core's package.json (zero-React). |
| @olonjs/react | `prepack` runs `scripts/sync-peers-from-stack.js` → copies `reactBindingPeerDependencies` into React's package.json, preserving its own `@olonjs/studio` optional peer. |
| @olonjs/studio | `prepack` runs `scripts/sync-peers-from-stack.js` → copies `reactBindingPeerDependencies` + `zod` (from `corePeerDependencies`) into Studio's package.json. |
| @olonjs/cli  | On `olonjs new tenant <name>` (legacy alias command: `jsonpages new tenant <name>`), the actual tenant `package.json` comes from the DNA script's embedded snapshot of `apps/tenant-alpha`'s own file, not from reading this manifest directly — this manifest is the manual source of truth kept aligned with that snapshot. |

## File layout

- `stack-versions.json` — canonical versions (peerDependencies, corePeerDependencies, reactBindingPeerDependencies, packages, dependencies, devDependencies).
- `index.js` — ESM export for Node (used by Core/React/Studio sync scripts and CLI).
