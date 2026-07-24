# Implementation Plan: Next CLI DNA + `release:enterprise`

Parent: ADR-0017 · Next starter (`docs/plans/next-rsc-starter.md`)  
Repo: `npm-jpcore`  
Status: **Implemented — awaiting human dry-run / publish go**  
Checklist: [`tasks/todo-next-cli-dna.md`](../../tasks/todo-next-cli-dna.md)

## Overview

Integrare il tenant Next (`apps/next`, workspace `tenant-next`) nel pipeline DNA/CLI/enterprise già usato da alpha: stesso `src2Code.sh --template next`, asset sotto `packages/cli/assets/templates/next/`, gate `release:enterprise`, publish di `@olonjs/next` + CLI che:

1. **Umano** — `olonjs new tenant <name>` apre una maschera TUI (frecce + Invio) con due opzioni: **next** | **vite**
2. **Agenti / CI** — `--template` resta obbligatorio-friendly e non interattivo

**Non** è un nuovo prodotto: estende il meccanismo esistente. Publish resta `npm run release:enterprise`.

## Architecture Decisions

1. **SOT** — DNA Next da `apps/next` via `src2Code.sh --template next`. Output: `packages/cli/assets/templates/next/{src_tenant.sh,manifest.json}`. DNA Vite resta `alpha` da `tenant-alpha`.
2. **Publish path** — `release:enterprise` → `check:templates` → `dist:dna:all` → `release.js`. Nessun publish parallelo.
3. **`@olonjs/next`** — pubblicato in `release.js` prima del CLI (dopo react/studio), pin su tenant Next prima del `dist`.
4. **CLI UX (confermato)**
   - **Interactive (default se `--template` assente):** prompt frecce con label **`next`** e **`vite`**; Invio conferma.
   - **Non-interactive:** `--template` per agenti/CI. Valori accettati: `next` | `vite` | `alpha` (`vite` e `alpha` → stesso DNA Vite/`alpha`).
   - Mapping UI → DNA: `next` → `templates/next`; `vite`/`alpha` → `templates/alpha`.
5. **CLI scaffold** — branch per stack: Next = DNA-first (no Vite inject); Vite/alpha = path attuale (create vite + inject + DNA), invariato nel comportamento.
6. **App dir vs workspace** — cartella `apps/next`, workspace `tenant-next`. `stepTenant` richiede mapping esplicito → `apps/next`.
7. **Fuori scope** — SSO admin; HotSave Next; rename forzato della cartella app.

## Dependency Graph

```
apps/next dist (src2Code.sh --template next)
        │
        ├── packages/cli/assets/templates/next/
        │
        ├── check:templates (alpha + next)
        ├── dist:dna:all (alpha + tenant-next)
        │
        └── release.js
              ├── … stack → core → studio → react → mcp
              ├── publish @olonjs/next
              ├── stepTenant(alpha)
              ├── stepTenant(next) + pin @olonjs/next  (apps/next map)
              ├── stepCli
              └── compat @jsonpages/*

CLI `olonjs new tenant <name>`
        │
        ├── no --template → TUI: next | vite  (arrows + Enter)
        └── --template next|vite|alpha → skip TUI (agents)
                │
                ├── next  → Next scaffold + DNA templates/next
                └── vite/alpha → Vite scaffold + DNA templates/alpha
```

## Task List

### Phase 1: DNA generation (same mechanism as alpha)

- **Task 1:** Wire `src2Code.sh` + `dist` on `apps/next` (`--template next` + file list Next).
- **Task 2:** Generate DNA once; verify `templates/next/` + manifest.
- **Task 3:** Extend `dist:dna:all` + `check:templates` for `next`.

### Checkpoint: DNA

- [x] `npm run dist -w tenant-next` writes `templates/next/`
- [x] `npm run check:templates` green for `alpha` + `next`
- [ ] Human review DNA file list (no secrets, no `node_modules`)

### Phase 2: CLI UX + Next-aware scaffold

- **Task 4:** Interactive template picker (frecce + Invio) quando manca `--template`; opzioni label **`next`** | **`vite`**.
- **Task 5:** Keep `--template` for agents (`next` | `vite` | `alpha`); resolve to DNA id; skip TUI when flag present (also when stdin non-TTY).
- **Task 6:** Branch scaffold: Next DNA-first (no Vite inject); Vite/alpha path unchanged.
- **Task 7:** Smoke: interactive path (manual) + `olonjs new … --template next` and `--template vite`/`alpha`.

### Checkpoint: CLI

- [x] Senza `--template`: maschera next/vite funzionante
- [x] Con `--template next|vite|alpha`: nessun prompt; scaffold corretto
- [x] Alpha/Vite regression OK

### Phase 3: Enterprise release integration

- **Task 8:** Publish `@olonjs/next` in `release.js` (order + version bump).
- **Task 9:** `stepTenant` for Next with `apps/next` mapping; pin `@olonjs/core|react|studio|next`; `build` + `dist`.
- **Task 10:** Docs (`TEMPLATES.md`, `CLI.md`, `PUBLISHING.md`) — TUI + `--template` for agents + dry-run checklist.

### Checkpoint: Complete

- [x] `npm run release:enterprise -- --dry-run` includes next DNA + `@olonjs/next` + CLI with both templates
- [ ] Human approval before real publish
- [ ] Real `npm run release:enterprise` only when human says so

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `stepTenant("tenant-next")` → `apps/tenant-next` | High | Explicit appDir map |
| TUI breaks CI/agents | High | `--template` skips prompt; non-TTY fallback require flag or default documented |
| DNA file list incomplete | High | Review + smoke scaffold |
| CLI still Vite for next | High | Task 6 before claiming Next works |
| `@olonjs/next` unpublished | High | Task 8 before/with CLI publish |
| Label `vite` vs DNA id `alpha` confusion | Med | Explicit resolve map in CLI + docs |

## Open Questions

Defaults chosen for implementation:

1. **Bootstrap Next:** DNA-first (no create-next-app inject)
2. **First `@olonjs/next` version:** patch from `0.0.1`
3. **Non-TTY without `--template`:** fail with clear message
4. **Real publish:** only after explicit human go (dry-run first)

## Verification (before coding)

- [x] Human approves this plan
- [x] Open questions answered or deferred with defaults above
