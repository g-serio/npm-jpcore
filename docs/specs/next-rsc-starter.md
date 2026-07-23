# Spec: Next.js Olon starter (`@olonjs/next` + `apps/next`)

Status: **Implement done — Accepted** (`packages/next`, `apps/next` / `tenant-next`; ADR-0017 Accepted)  
Repo: `npm-jpcore`  
Related: [ADR-0017](../decisions/ADR-0017-next-rsc-visitors-admin-island.md), `@olonjs/core` / `@olonjs/react` / `@olonjs/studio`, Vite reference DNA `apps/tenant-alpha`  
App path: `apps/next` (folder already created; supersedes ADR draft name `tenant-next` for this monorepo app)

---

## Assumptions (correct now or this spec is wrong)

1. **Host split is normative:** visitors = RSC-efficient server path; `/admin` (+ Studio preview) = client island only. Whole-app client island is out of scope for this starter.
2. **Package name:** `packages/next` publishes as `@olonjs/next`.
3. **App name/path:** workspace app lives at `apps/next` (not `apps/tenant-next`).
4. **Demo content parity (protocol):** same autori/libri collections + pages + `empty-tenant` empty-state path as alpha; shell footer as needed for site.json; **`form-demo` in v1** via RSC section shell + **client leaf** for interactive submit (do not mount `OlonFormsContext` on the whole visitor layout).
5. **v1 persistence / cloud:** **Save2Repo (cold save) is a v1 success gate** — Studio can cold-save via the platform save-stream path under the same env credentials model as alpha. **HotSave is a later slice**, not required for v1. Local `save-to-file` remains for non-cloud / local dev.
6. **Stack:** Next.js App Router, React 19 (aligned with monorepo peers), TypeScript, Tailwind 4 in the app (match alpha design tokens / theme chain where practical).
7. **CLI DNA packaging** (`dist:dna` / template for `olonjs new … --template next`): follow-up after the app+package work; not a v1 success gate.

→ If any of these is wrong, say so before Plan.

---

## Objective

Ship a **production-shaped Next starter** for OlonJS that:

1. Lets **visitors** read autori/libri (and home) with **minimal client JS** (RSC / server render of the JSON page contract).
2. Lets **editors** use Studio on `/admin` via a **client island** (`@olonjs/react` + `@olonjs/studio`).
3. Exposes host concerns in **`@olonjs/next`**, not by forking the engine and not by stuffing Next into `@olonjs/react`.
4. Shows **empty tenant** UX when there are no pages (same product idea as alpha’s `EmptyTenantView` / `isTenantEmpty`).
5. Ships **`form-demo`** on the visitor path as **RSC chrome + client leaf** (form state / submit only inside the leaf).

### Users

- Tenant developers evaluating or scaffolding Olon on Next.
- Agents implementing against ADR-0017 without collapsing back to a Vite SPA-in-Next.

### Success looks like

- Public routes render from server without mounting `JsonPagesEngine` for visitors.
- `/admin` mounts the Studio island; local save works; **Save2Repo (cold save) works** when cloud env is configured.
- Authors → books demo works on public routes with Next routing (no `react-router` on the visitor path).
- `form-demo` page works for visitors with only a small client bundle for the form leaf.
- Empty state works when page registry is empty.
- ADR-0017 can move Proposed → Accepted.

---

## Tech Stack

| Layer | Choice |
|-------|--------|
| App | Next.js App Router (`apps/next`) |
| Host package | `@olonjs/next` (`packages/next`) |
| Contract / resolve | `@olonjs/core` |
| Admin island | `@olonjs/react` + `@olonjs/studio` |
| Public UI | Server Components + RSC-safe section Views (client leaves only where required) |
| Styling | Tailwind 4 + theme.json → CSS variable chain (CIP), adapted to Next |
| Data | `src/data/config/*`, `src/data/pages/*`, `src/data/collections/*` (JSP) |

---

## Commands

```bash
# from monorepo root
npm install

# package
npm run build -w @olonjs/next
npm test -w @olonjs/next          # if/when tests exist

# starter app
npm run dev -w next               # or whatever package.json name is set (prefer "next" or "tenant-next" name field — path is apps/next)
npm run build -w next
npm run lint -w next              # if configured

# typecheck
npm exec -w next -- tsc --noEmit
```

Exact workspace package `name` in `apps/next/package.json` may be `next` or `tenant-next`; **path** stays `apps/next`.

---

## Project Structure

```
packages/next/                    → @olonjs/next
  src/
    server/                       → loaders, visitor render helpers, route-handler impls
    client/                       → admin island helpers / re-exports for 'use client'
    index.ts                      → package entry policy (subpath exports preferred)

apps/next/                        → starter kit
  app/
    layout.tsx                    → RSC shell
    [[...slug]]/page.tsx          → public visitor RSC path (or segmented routes)
    admin/[[...slug]]/page.tsx    → client island entry for Studio
    api/
      save-to-file/route.ts
      upload-asset/route.ts
      list-assets/route.ts
      # WebMCP parity endpoints as needed (llms.txt / manifests) — can land in same slice as handlers
  src/
    components/                   → section capsules (RSC-safe on visitor path; form-demo + FormDemoClient leaf)
    lib/                          → protocol only at root (registry, schemas, ASC, collections, icons, utils)
    data/                         → config / pages / collections JSON
  docs/                           → app-local notes if needed; ADR stays in repo docs/decisions
```

Shared extract of Vite `tenantDevApiPlugin` logic into `@olonjs/next/server` is preferred when implementing handlers; Vite DNA can keep a thin wrapper later (not blocking v1 of `apps/next`).

---

## Code Style

Follow Olon tenant protocol (TBP / CIP / IDAC / JSP) as in alpha, with Next-specific rules:

```tsx
// Public section View — RSC-safe (no react-router, no client hooks required)
export function AuthorsListView({ data }: { data: AuthorsListData }) {
  const authors = Object.values(data.items ?? {}).sort((a, b) => a.name.localeCompare(b.name));
  return (
    <main>
      <h1 data-jp-field="title">{data.title}</h1>
      {/* links use href from Next public routes */}
    </main>
  );
}
```

```tsx
// form-demo — RSC View shell + client leaf (normative for interactive sections)
// View.tsx (Server Component): title, description, IDAC attrs; renders <FormDemoClient … />
// FormDemoClient.tsx ('use client'): useFormState / OlonForms provider scoped HERE only
export function FormDemoView({ data }: { data: FormDemoData }) {
  return (
    <main>
      <h1 data-jp-field="title">{data.title}</h1>
      <FormDemoClient formId={data.anchorId ?? 'form-demo'} data={data} />
    </main>
  );
}
```

```tsx
// app/admin/[[...slug]]/page.tsx — island boundary
import { AdminIsland } from '@olonjs/next/client';
// or local wrapper that mounts JsonPagesEngine — must be 'use client' tree
export default function AdminPage() {
  return <AdminIsland /* tenant protocol props */ />;
}
```

Conventions:

- Named exports for capsules; App Router `page.tsx` default export as required by Next.
- Visitor path must not import `@olonjs/studio` or admin-only drawers.
- `books-list` author filter comes from **Next route params / searchParams**, not `useLocation()`.
- Interactive forms: **client leaf only** — never wrap the whole visitor layout in `OlonFormsContext`.
- Theme chain: no branded font fallbacks; missing tokens → warn/skip (same policy as alpha cleanup).

---

## Testing Strategy

| Level | What |
|-------|------|
| Package unit | `@olonjs/next` pure helpers (path safety for save, slug normalize, visitor resolve wiring) via vitest |
| App typecheck | `tsc --noEmit` on `apps/next` |
| Manual / smoke | `npm run dev -w …`: home, `/authors`, books filtered by author, **form-demo submit leaf**, empty state, `/admin` loads Studio, local save round-trip, **cold Save2Repo** when cloud env set |
| Gate | No visitor route imports Studio; public Views have no required client hooks **except explicit `'use client'` leaves**; Save2Repo path wired (HotSave not required) |

Coverage target for v1: pragmatic, not a % gate — critical server helpers tested; UI smoke manual.

---

## Boundaries

**Always**

- Keep visitor render free of `JsonPagesEngine` / Studio.
- Keep section/schema/JSON protocol aligned with alpha where the demo overlaps.
- Scope form interactivity to client leaves (e.g. `form-demo`); do not provider-wrap the entire public tree.
- Path-traverse-safe writes for save/upload (parity with Vite plugin).
- Update ADR-0017 to Accepted only when success criteria below are met.

**Ask first**

- Publishing `@olonjs/next` to npm / stack pin bumps.
- Changing `@olonjs/react` public API to support visitor RSC (prefer adapter-side composition first).
- Adding CLI template / `dist:dna` for Next.
- Adding **HotSave** to `apps/next` / `@olonjs/next` (explicitly post-v1).

**Never**

- Whole-app client island as the documented starter architecture.
- Putting Next Route Handlers inside `@olonjs/react`.
- Committing secrets / `.env` with keys.
- Shipping public Views that hard-depend on `react-router-dom`.
- Mounting `OlonFormsContext` (or equivalent) on the root visitor layout “for convenience”.

---

## Success Criteria

1. `packages/next` builds and exports at least `server` + `client` (or equivalent subpaths named in implementation plan).
2. `apps/next` `dev` + `build` succeed in the monorepo.
3. Visitor: home + authors list + books list (incl. author filter via Next routing) render without loading Studio JS on that navigation.
4. Visitor: **`form-demo`** renders as RSC shell + client leaf; submit/status work without making the whole page a client tree.
5. Empty: zero pages → empty-tenant (or equivalent) server UI, not a blank crash.
6. Admin: `/admin` island loads Studio against the same protocol registries/schemas.
7. Local save: edit in Studio → Route Handler persists JSON under `src/data/**` (or agreed app data root) when not in cloud Save2Repo boot mode.
8. **Save2Repo (cold save):** with cloud URL + API key (+ Save2Repo enabled per alpha env contract), Studio cold-save completes via save-stream (drawer/progress acceptable as admin-island UI).
9. ADR-0017 status → **Accepted**.

---

## Out of scope (v1)

- **HotSave** (add after Save2Repo v1 ships).
- Rewriting `OlonFormsContext` into a non-client abstraction (leaf scoping is the v1 pattern; Server Actions adapter optional later).
- Full WebMCP surface parity (may partially land with handlers; not a ship blocker if core demo works).
- CLI template publication / `dist:dna:all` for Next.
- Replacing admin `react-router-dom` with a full Next routing bridge (follow-up ADR).

---

## Open Questions

_None that block Specify → Plan._ Folder name, split model, package ownership, and v1 demo scope are fixed above. Any correction belongs in Assumptions, not as open debate.
