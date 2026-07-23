# Implementation Plan: Next.js Olon starter (`@olonjs/next` + `apps/next`)

Spec: [`docs/specs/next-rsc-starter.md`](../specs/next-rsc-starter.md)  
ADR: [`docs/decisions/ADR-0017-next-rsc-visitors-admin-island.md`](../decisions/ADR-0017-next-rsc-visitors-admin-island.md)  
Repo: `npm-jpcore`  
Status: **Implement done — awaiting final human review**  
Checklist: [`tasks/todo.md`](../../tasks/todo.md)

## Overview

Build a Next App Router starter that keeps **visitors on an RSC-efficient path** and confines Studio to an **`/admin` client island**, with host logic in **`@olonjs/next`**. v1 demo: autori/libri, empty-tenant, form-demo (RSC shell + client leaf), local save handlers, and **Save2Repo cold save** (HotSave later).

## Architecture Decisions

1. **Two surfaces, one protocol** — Same JSP JSON + TBP capsules as alpha; different host mount (Next routes vs Vite SPA).
2. **`@olonjs/next` owns host** — `server` (loaders, route-handler impls, visitor render helpers) + `client` (admin island wiring). No Next code in `@olonjs/react`.
3. **Visitor never mounts `JsonPagesEngine`** — resolve page via `@olonjs/core`, render section Views as RSC (client leaves only where required).
4. **Admin keeps react-router inside the island** until a later ADR; public routing is Next only.
5. **Forms = leaf, not layout provider** — `FormDemoClient` scopes `OlonFormsContext` / `useFormState`.
6. **Save2Repo is v1 gate; HotSave is not** — cold stream + drawer in admin island; local `save-to-file` for non-cloud.
7. **App path `apps/next`** — workspace package name may be `next` or `tenant-next`; path fixed.

## Dependency Graph

```
packages/next scaffold (exports server/client)
        │
        ├── safe FS helpers + Route Handler impls (save/upload/list)
        │
        ├── visitor loaders (pages/config/collections resolve)
        │         │
        │         └── apps/next App Router public pages (RSC)
        │                   │
        │                   ├── protocol port (registry/schemas/data)
        │                   ├── authors/books/empty Views (RSC-safe)
        │                   └── form-demo View + FormDemoClient leaf
        │
        └── client AdminIsland
                  │
                  ├── wire JsonPagesEngine + local persistence
                  └── Save2Repo coldSave + drawer (no HotSave)
```

## Task List (phases)

### Phase 1: Foundation

- **Task 1:** Scaffold `packages/next` (`@olonjs/next`) with `server` / `client` subpath exports, build, workspace wiring.
- **Task 2:** Scaffold `apps/next` Next App Router app (layout, placeholder public page, Tailwind/theme baseline, workspace scripts). Depends on T1 for package alias if used.
- **Task 3:** Port/implement path-safe save + upload + list helpers in `@olonjs/next/server` + thin `app/api/*/route.ts` wrappers. Unit tests for path safety.

### Checkpoint: Foundation

- [ ] `@olonjs/next` builds
- [ ] `apps/next` `dev`/`build` run
- [ ] POST save-to-file / upload / list respond in local dev
- [ ] Human review before visitor/admin features

### Phase 2: Visitor RSC core

- **Task 4:** Visitor content loader (read JSON, resolve page via `@olonjs/core`, empty vs page).
- **Task 5:** Port protocol surface: `ComponentRegistry`, `schemas`, `addSectionConfig`, `CollectionRegistry`, collections/pages/config JSON (home, authors, books, form page as needed), theme bridge.
- **Task 6:** RSC-safe `authors-list` + `books-list` (+ `book-detail` if in alpha demo) with Next `href` / params (no `react-router` on visitor).
- **Task 7:** Empty-tenant server UI when no pages.
- **Task 8:** `form-demo` RSC View + `FormDemoClient` leaf (scoped forms context).

### Checkpoint: Visitor

- [ ] Home / authors / books (author filter) work without Studio in the visitor bundle
- [ ] Empty state works
- [ ] form-demo submit leaf works; layout is not `'use client'`
- [ ] `tsc` clean for app

### Phase 3: Admin + Save2Repo

- **Task 9:** `/admin` client island mounting `JsonPagesEngine` with tenant protocol + local persistence flags.
- **Task 10:** Save2Repo cold save wiring (env policy aligned with alpha cold path; drawer UI lazy/acceptable) — **no HotSave**.
- **Task 11:** Smoke matrix + mark ADR-0017 Accepted; update spec status to implement-done / accepted.

### Checkpoint: Complete

- [ ] All spec success criteria 1–9 met
- [ ] HotSave still absent by design
- [ ] Ready for human review / merge

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Section Views pull client-only APIs (router, hooks) | High | Port Views deliberately; gate: no `react-router` on visitor; strip/`useMemo` only where needed |
| Admin island + Next dual routing confusion | Med | Document: public = Next; admin = RR inside island |
| Save2Repo env/boot parity with alpha subtle | High | Reuse `@olonjs/react` cloud policy / cold patterns; mirror alpha contracts, skip HotSave adapter wiring |
| Theme/CSS chain awkward under Next | Med | Start with alpha `theme.json` + CSS vars; iterate |
| Scope creep (WebMCP, CLI DNA, HotSave) | Med | Enforce out-of-scope list |

## Open Questions

_None blocking Plan → Implement._ Corrections go into the spec assumptions first.

## Verification (before coding)

- [ ] Spec assumptions (incl. Save2Repo gate, form-demo leaf) still approved
- [ ] This plan reviewed
- [ ] `tasks/todo.md` ordered and sized S/M
