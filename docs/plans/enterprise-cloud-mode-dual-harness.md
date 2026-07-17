# Implementation Plan: Enterprise Dual Cloud Mode Harness

Spec: [`docs/specs/enterprise-cloud-mode-dual-harness.md`](../specs/enterprise-cloud-mode-dual-harness.md)  
Repo: `npm-jpcore`  
Status: **Checkpoint C** — implement done pending human clarity + manual matrix

Primary bar: codice cloud chiaro ed esplicito abbastanza da stupire un developer enterprise.

## Overview

Introdurre in `@olonjs/react` un unico modulo cloud (policy + API helpers + adapter HotSave) che renda espliciti boot e save: **boot = solo Save2Repo sì/no**; **HotSave resta acceso con le credenziali anche se Save2Repo è on**. Il DNA (`useTenantBootstrap`, `App.tsx`, `cloudConfig`) consuma quella policy e smette di fare mutua esclusione.

## Architecture Decisions

1. **Policy pura + env iniettabile** — `resolveCloudPolicy(input)` non legge `import.meta.env` direttamente; `readCloudEnvFromVite()` fornisce l’input. Testabili senza Vite.
2. **Nomi espliciti** — `hotSaveEnabled`, `save2RepoEnabled`, `bootSource: 'local' | 'live' | 'static'`. Eliminare `hot = cloud && !save2repo`.
3. **Boot vs save separati nel tipo** — `bootSource` distinto dai flag UI save.
4. **HotSave adapter in `@olonjs/react`** — costruisce `persistence.hotSave` + flag show*. Cold stream/drawer resta DNA (`useCloudSave`); i flag vengono dalla policy.
5. **DNA bootstrap resta DNA** — usa `bootSource` (`static` / `live` / `local`); non si sposta in `@olonjs/react`.
6. **Una sola lettura env** — forms, assets, `getSppCloudConfig` passano dalla policy shared.

## Dependency Graph

```
resolveCloudPolicy (pure) + tests
        │
        ├── readCloudEnvFromVite / buildApiCandidates
        │
        ├── export @olonjs/react cloud/*
        │
        ├── DNA: tenantEnv + spp/cloudConfig → policy
        │         │
        │         └── useTenantBootstrap usa bootSource (no mutual exclusion)
        │
        └── App.tsx: show* flags + hotSave da adapter; coldSave resta useCloudSave
                  │
                  └── forms / assets → policy
                            │
                            └── dist:dna:all + check:templates + clarity pass
```

---

## Task List

### Phase A — Foundation

#### Task 1: `resolveCloudPolicy` + tests

**Description:** Tipo esplicito + funzione pura con matrice boot/save.

**Acceptance criteria:**
- [x] `bootSource: 'local' | 'live' | 'static'`, `hotSaveEnabled`, `save2RepoEnabled`, show*
- [x] Matrice: no cred → local; cred → live + hot; cred+SAVE2REPO → static + hot + cold
- [x] Save2Repo **non** spegne `hotSaveEnabled`
- [x] Env iniettata; commento breve boot-vs-save sul tipo

**Verification:** `npm test --workspace=@olonjs/react` — 5/5 passed (2026-07-17)  
**Dependencies:** None  
**Files:** `packages/react/src/cloud/cloudPolicy.ts`, `cloudPolicy.test.ts`  
**Scope:** S

#### Task 2: Env reader + API helpers + export

**Description:** Vite env + `buildApiCandidates` + barrel export.

**Acceptance criteria:**
- [x] Alias OLONJS/JSONPAGES
- [x] Export da `@olonjs/react`
- [x] Zero `import.meta.env` dentro `resolveCloudPolicy` (e dentro `readCloudEnvFromVite`: riceve `env` dal caller)

**Verification:** shell agent flaky — user to confirm:
`cd packages/react && . ~/.nvm/nvm.sh && npx vitest run && npx vite build`  
**Dependencies:** Task 1  
**Files:** `cloudEnv.ts`, `cloudApi.ts`, `cloud/index.ts`, `packages/react/src/index.ts`  
**Scope:** S

### Checkpoint A
- [x] Tests + build `@olonjs/react` green (user confirmed 2026-07-17)
- [x] Policy file ovvio a colpo d’occhio

---

### Phase B — DNA wiring

#### Task 3: Bootstrap + cloudConfig + tenantEnv → policy

**Acceptance criteria:**
- [x] Niente `isHotSaveMode = isCloudMode && !SAVE2REPO`
- [x] Boot solo da `bootSource`
- [x] `getSppCloudConfig`: credentials ⇒ cloud usable; Save2Repo ≠ “cloud off”
- [x] `tenantEnv` thin wrapper / re-export

**Verification:** `npm run build -w tenant-alpha`; grep anti-mutua-esclusione  
**Dependencies:** Task 2  
**Files:** `useTenantBootstrap.ts`, `spp/cloudConfig.ts`, `tenantEnv.ts`  
**Scope:** M


#### Task 4: App persistence — flags dual + hotSave adapter

**Acceptance criteria:**
- [x] show* dalla policy (`cloudPolicy.show*` diretti; rimosso pass-through `persistenceUiFlags`)
- [x] Corpo `hotSave` non inline in `App.tsx` (`createHotSaveHandler`)
- [x] `coldSave` via `useCloudSave` DNA; flag cold dalla policy

**Verification:** `npm test -w @olonjs/react` + `npm run build -w tenant-alpha`  
**Dependencies:** Task 3  
**Files:** `createHotSaveHandler.ts`, `cloud/index.ts`, `App.tsx`  
**Scope:** M

### Checkpoint B
- [ ] Tenant build green
- [ ] Grep: zero mutua esclusione Hot↔Save2Repo

---

### Phase C — Consolidate + DNA ship

#### Task 5: Forms / assets → policy unica

**Acceptance criteria:**
- [x] Niente `import.meta.env` cloud ad-hoc fuori dal modulo cloud (salvo re-export / SSR)
- [x] `useOlonForms`, `useFormSubmit`, `useAssetsManifest`, form-demo allineati

**Verification:** ripgrep env cloud in `apps/tenant-alpha/src` → solo `tenantEnv` (+ SSR in cloudConfig)  
**Dependencies:** Task 2 (dopo Task 4 in pratica)  
**Files:** `useOlonForms.ts`, `useFormSubmit.ts`, `useAssetsManifest.ts`, `form-demo/View.tsx`  
**Scope:** M

#### Task 6: DNA regen + nota env + clarity pass

**Acceptance criteria:**
- [x] `npm run dist:dna:all` (exit 0)
- [x] `npm run check:templates` — OK
- [x] Nota breve matrice env in `apps/tenant-alpha/CLAUDE.md`
- [x] Clarity: rimossi alias `isHotSaveMode` / `isSave2RepoMode`; App usa `bootSource`

**Verification:** comandi sopra  
**Dependencies:** Task 4, Task 5  
**Files:** DNA via dist, `CLAUDE.md`, `App.tsx`, `useTenantBootstrap.ts`  
**Scope:** S

### Checkpoint C — Complete
- [ ] Spec checklist + criterio primario (review umana: “amazed by clarity”)
- [ ] Manual: Local / Hot-only / Dual
- [ ] Human approve → Implement done / publish when asked

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Cold in DNA sembra incompleto | Med | Spec/plan: Hot shared; Cold UI DNA; flag dalla policy |
| Ri-introduzione `hot && !save2repo` | High | Test + grep Checkpoint B |
| `getSppCloudConfig` spegne cloud con Save2Repo | High | Task 3 |
| Platform rifiuta hotSave su tenant Save2Repo | Med | Smoke; se fallisce → platform |

## Out of this plan

- Spostare `useTenantBootstrap` in `@olonjs/react`
- Cambiare API platform
- Migrare altri tenant (dopo alpha green)

**Do not start Implement until this plan is approved.**
