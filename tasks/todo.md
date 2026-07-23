# Todo: Next RSC starter (`@olonjs/next` + `apps/next`)

Spec: `docs/specs/next-rsc-starter.md` · Plan: `docs/plans/next-rsc-starter.md`  
Status: **Implement done** (Tasks 1–11 complete; ADR-0017 Accepted)

## Phase 1: Foundation

- [x] **Task 1:** Scaffold `packages/next` (`@olonjs/next`) with `server`/`client` exports + build
- [x] **Task 2:** Scaffold `apps/next` App Router (layout, public placeholder, Tailwind/theme baseline, scripts)
- [x] **Task 3:** Local host APIs — path-safe save/upload/list in `@olonjs/next/server` + `app/api/*/route.ts`

## Phase 2: Visitor RSC

- [x] **Task 4:** Visitor loaders — load config/pages/collections; resolve page; detect empty
- [x] **Task 5:** Port protocol + data (registry, schemas, ASC, collections, pages, theme bridge)
- [x] **Task 6:** RSC `authors-list` + `books-list` (+ detail if required) with Next routing/params
- [x] **Task 7:** Empty-tenant server UI when page registry empty
- [x] **Task 8:** `form-demo` RSC shell + `FormDemoClient` leaf (scoped forms context)

## Phase 3: Admin + Save2Repo

- [x] **Task 9:** `/admin` client island — `JsonPagesEngine` + protocol + local persistence
- [x] **Task 10:** Save2Repo cold save (env + stream + drawer); **no HotSave**
- [x] **Task 11:** Final smoke vs spec success criteria; ADR-0017 → Accepted; spec/plan status update
