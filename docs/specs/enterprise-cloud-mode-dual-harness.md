# Spec: Enterprise Dual Cloud Mode Harness

Status: **Specify done — Plan ready for human review** (`docs/plans/enterprise-cloud-mode-dual-harness.md`)  
Repo: `npm-jpcore`  
Related: tenant DNA harness (`apps/tenant-alpha`), `@olonjs/react`, `@olonjs/core` save stream helpers  
Out of scope: `jsonpages-platform` API changes (unless a contract gap blocks dual mode)

---

## Objective

Make OlonJS tenant **cloud mode enterprise-grade** by providing a **single, shared cloud policy + save harness** that:

1. Treats HotSave and Save2Repo as **dual capabilities** under the same env credentials (`CLOUD_URL` + `API_KEY`), not mutually exclusive modes.
2. Lives in **one place the tenant developer does not touch** — the DNA/`App.tsx` only wires registry/schemas/pages and mounts the engine; cloud policy and save adapters come from the shared package.
3. Keeps local (no-cloud) behavior unchanged.

### User

- Tenant developer scaffolding from `@olonjs/cli` (alpha DNA): sets env vars, does not reimplement bootstrap/save.
- Platform operator: same env contract across all tenants.

### Why now

Today (`apps/tenant-alpha`):

- `isHotSaveMode = isCloudMode && !SAVE2REPO` — Save2Repo **disables** HotSave.
- Studio UI shows either hot or cold, not both.
- Env/policy is read in multiple places (`tenantEnv`, `spp/cloudConfig`, bootstrap, `App.tsx`, forms) with inconsistent semantics (`getSppCloudConfig` turns cloud off when Save2Repo is on).
- ~700-line bootstrap + save wiring is copied into every tenant DNA.

### Success criteria (testable)

- [x] **Barra enterprise (primaria):** policy/boot/save espliciti — matrice in `cloudPolicy` + `CLAUDE.md`; zero mutua esclusione Hot↔Save2Repo (pending human “amazed” review)
- [x] With only `VITE_OLONJS_CLOUD_URL` + `VITE_OLONJS_API_KEY` set: Studio exposes **HotSave**; cold/Save2Repo UI is off; **boot** carica dal cloud live.
- [x] With `URL` + `API_KEY` + `VITE_SAVE2REPO=true`: Studio espone **HotSave e ColdSave**; **boot** carica dai JSON statici (Save2Repo). HotSave non cambia il boot.
- [x] With neither URL nor API key: local save only; boot locale (unchanged).
- [x] All cloud env reads go through **one** module (no ad-hoc `import.meta.env` in forms/Views/App for cloud policy).
- [x] Tenant `App.tsx` does not implement `hotSave` fetch body — `createHotSaveHandler`; cold via DNA `useCloudSave`.
- [x] `getSppCloudConfig` (and equivalents) share the same policy: Save2Repo does **not** mean “cloud disabled” and does **not** disable HotSave.
- [x] `npx tsc` + tenant `npm run build` green for `tenant-alpha`; DNA regenerable via `npm run dist:dna:all`.
- [x] Alias env names (`VITE_JSONPAGES_*`) still work as fallbacks.

---

## Tech Stack

- Monorepo: `npm-jpcore` (npm workspaces)
- Packages: `@olonjs/core` (pure helpers already used: `startCloudSaveStream`, deploy steps), `@olonjs/react` (preferred home for React harness), `@olonjs/studio` (UI flags only via engine config — no platform calls)
- Tenant reference: `apps/tenant-alpha`
- Env: Vite `import.meta.env` (`VITE_*`)
- Existing cloud endpoints (platform, unchanged by this spec unless blocked):
  - Hot: `POST …/hotSave` (Bearer)
  - Cold: SSE / save-stream via `startCloudSaveStream` (already in `@olonjs/core`)
  - Render/bootstrap: SPP `/render` path used by hot bootstrap today

---

## Commands

```bash
# From monorepo root (WSL)
npm run build --workspace=@olonjs/core
npm run build --workspace=@olonjs/react
npm run test --workspace=@olonjs/react
npm run build -w tenant-alpha
npm run dist:dna:all
npm run check:templates
npm run test:boundary
```

Manual matrix (dev):

```bash
# Local
# (no VITE_OLONJS_CLOUD_URL / VITE_OLONJS_API_KEY)
npm run dev -w tenant-alpha
# Expect: showLocalSave only

# Hot only
# VITE_OLONJS_CLOUD_URL=… VITE_OLONJS_API_KEY=… (no VITE_SAVE2REPO)
# Expect: showHotSave true, showColdSave false

# Dual
# + VITE_SAVE2REPO=true
# Expect: showHotSave true AND showColdSave true
```

---

## Project Structure

```
packages/react/src/
  cloud/                         → NEW: single cloud policy + adapters (proposed)
    cloudEnv.ts                  → read/normalize URL, key, flags
    cloudPolicy.ts               → derive isCloud / hot / save2repo / ui flags (dual)
    cloudApi.ts                  → buildApiCandidates, fetch helpers
    createCloudPersistence.ts    → hotSave / coldSave adapters for JsonPagesConfig
    index.ts                     → public exports

apps/tenant-alpha/src/
  lib/tenantEnv.ts               → thin re-export OR delete in favor of @olonjs/react cloud
  lib/spp/cloudConfig.ts         → must call shared policy (no divergent semantics)
  lib/useTenantBootstrap.ts      → consumes shared policy flags (no local mode math)
  App.tsx                        → mounts engine; persistence from createCloudPersistence
  (data/, components/, schemas/) → unchanged tenant domain

docs/specs/enterprise-cloud-mode-dual-harness.md  → this document
docs/plans/enterprise-cloud-mode-dual-harness.md → implementation plan + tasks (single file)
```

Exact file names may shift in the plan; the invariant is **one shared module boundary**.

---

## Code Style

Follow existing `@olonjs/react` / tenant conventions: named exports, no default exports for harness APIs, TypeScript strict, zero platform secrets in source.

```ts
// Good: single policy derivation (dual, not exclusive)
export type CloudPolicy = {
  isCloudMode: boolean;
  hotSaveEnabled: boolean;      // true whenever isCloudMode
  save2RepoEnabled: boolean;    // true when isCloudMode && SAVE2REPO flag
  showLocalSave: boolean;
  showHotSave: boolean;         // === hotSaveEnabled
  showColdSave: boolean;        // === save2RepoEnabled
  apiBases: string[];
  apiKey: string;
  apiUrl: string;
};

// Bad (today): mutual exclusion
// const isHotSaveMode = isCloudMode && !isSave2RepoMode;
```

Env resolution (canonical then alias):

```ts
const apiUrl =
  import.meta.env.VITE_OLONJS_CLOUD_URL?.trim() ||
  import.meta.env.VITE_JSONPAGES_CLOUD_URL?.trim() ||
  '';
```

---

## Testing Strategy

| Level | What | Where |
|---|---|---|
| Unit | Policy matrix: (no env) / (url+key) / (url+key+save2repo) → flags | `packages/react/src/cloud/*.test.ts` |
| Unit | `buildApiCandidates` / URL normalization | same |
| Unit | Save2Repo does not clear `hotSaveEnabled` | same |
| Integration (tenant) | `tsc` + `vite build` after App/bootstrap thin wiring | `apps/tenant-alpha` |
| Manual | Studio UI buttons + one hot save + one cold save stream | `/admin` with real env |
| Regression | Forms/assets/SPP helpers using shared config, not stale `getSppCloudConfig` disable | grep + smoke |

Coverage expectation: policy module 100% of flag combinations; no requirement for e2e suite (none exists today — same constraint as ADR-0016).

---

## Boundaries

**Always**

- Preferire codice che un developer enterprise trova ovvio a colpo d’occhio (nomi espliciti, una sola policy, zero magia).
- Derive Hot/Cold flags from one shared policy module.
- Keep HotSave available whenever cloud credentials are present (also when Save2Repo is on).
- Decide **boot** only from Save2Repo sì/no; never from “HotSave acceso”.
- Preserve local mode when credentials are absent.
- Keep `@olonjs/core` free of Vite/`import.meta.env` (env reading belongs in `@olonjs/react` or a tiny harness helper that accepts injected env).
- Update DNA (`dist:dna:all` + `check:templates`) after tenant wiring changes.
- Document the env matrix in tenant CLAUDE / onboarding once stable.

**Ask first**

- Changing public exports of `@olonjs/react`.
- Moving bootstrap (`useTenantBootstrap`) wholesale into `@olonjs/react` (larger than dual-mode; may be a follow-up).
- Renaming or removing `VITE_SAVE2REPO` / `VITE_JSONPAGES_*` aliases.
- Platform API contract changes in `jsonpages-platform`.
- Publishing / `release:enterprise`.

**Never**

- Commit `.env` or API keys.
- Reintroduce mutual exclusion (`hot = cloud && !save2repo`).
- Leave divergent cloud semantics in `spp/cloudConfig` vs bootstrap.
- Put React/Vite env reads into `@olonjs/core`.
- Require tenant authors to copy-paste save fetch implementations.

---

## Env contract (normative)

| Variable | Role |
|---|---|
| `VITE_OLONJS_CLOUD_URL` (alias `VITE_JSONPAGES_CLOUD_URL`) | Cloud API base |
| `VITE_OLONJS_API_KEY` (alias `VITE_JSONPAGES_API_KEY`) | Bearer credential |
| `VITE_SAVE2REPO` | Se `'true'` **e** ci sono le credenziali cloud → abilita ColdSave **in più** rispetto a HotSave; e decide **anche** il boot (vedi sotto) |

### Boot vs save (norma)

Due cose diverse:

1. **Da dove carichi all’avvio (boot)** — lo decide **solo** Save2Repo:
   - **senza** Save2Repo (ma con URL+key) → boot dal cloud live
   - **con** Save2Repo → boot dai JSON statici del deploy
2. **Cosa puoi salvare in Studio** — con URL+key HotSave è sempre disponibile; con anche Save2Repo hai ColdSave in più. HotSave **non** cambia il boot.

| Credentials | `VITE_SAVE2REPO` | Boot | Local save | HotSave | ColdSave |
|---|---|---|---|---|---|
| absent | any | locale / file | on | off | off |
| present | not `true` | cloud live | off | on | off |
| present | `true` | JSON statici | off | on | on |

---

## Success Criteria

(See Objective checklist above.)

**Criterio primario:** un developer enterprise deve stupirsi della chiarezza e dell’esplicità del codice cloud (policy, boot, save).

Done operativo = policy duale sui save + boot determinato solo da Save2Repo sì/no + modulo shared + DNA thin wiring + build green + Studio mostra entrambi i save quando dual.

---

## Locked decisions (from prior confirmation)

- Criterio di accettazione primario: chiarezza ed esplicità tali da stupire un developer enterprise.
- Dual sui **save**: con `URL+APIKEY`, HotSave resta acceso; `VITE_SAVE2REPO=true` aggiunge ColdSave e **non** spegne Hot.
- Boot: **solo** Save2Repo sì/no (statici vs cloud live). HotSave non influenza il boot.
- Shared harness in `@olonjs/react`; il tenant author setta le env, non riscrive policy/save. `useTenantBootstrap` è DNA (infrastruttura template), non superficie tenant.
- Questo slice: **policy + persistence adapters** in `@olonjs/react`; il DNA bootstrap consuma la policy shared (niente mutua esclusione Hot↔Save2Repo).
- Primo consumer: `tenant-alpha` DNA; altri app dopo che alpha è green.

---

## Out of scope

- Redesigning platform hotSave / save-stream APIs.
- New billing or auth flows.
- Full e2e suite for Studio.
- Vue (or other) harness — React package only for now.
- Moving `useTenantBootstrap` into `@olonjs/react`.
