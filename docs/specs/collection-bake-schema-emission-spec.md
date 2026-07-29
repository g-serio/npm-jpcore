# Spec: Collection schema emission at tenant bake (Core)

## Objective

Publish **machine-readable JSON Schema contracts for collection items** at tenant build time, alongside the existing published collection **data** documents.

**Why:** External consumers (olon-platform Collections dashboard, MCP agents, Form Factory–compatible UIs) need the same deterministic contract Studio already gets from tenant Zod (`CollectionRegistry`), without reading TypeScript from GitHub or opening tenant Studio.

**Who:** Platform operators editing tenant collections from olon-platform; agents consuming tenant deploy surfaces.

**What success looks like:**

- After `apps/tenant-alpha` prebuild/bake, each registered collection has a fetchable schema URL on the deployed tenant origin.
- One schema file describes **one item** in that collection (not the full keyed record document).
- Collection **data** remains a single **keyed object** per source (`Record<itemId, Item>`); no per-item JSON URLs.
- **No** per-item JSON URLs are introduced (e.g. `/posts/designing-with-constraints.json` remains **not** part of this contract).

**User stories:**

1. Dashboard loads `collections/posts/posts.json` + `schemas/collections/posts.schema.json` and can build an item editor for any key in the record.
2. Agent discovers item shape from the schema file without scraping HTML or cloning Studio.

---

## ASSUMPTIONS I'M MAKING

1. **Zod remains SOT** for collection item shape — tenant `src/collections/<name>/schema.ts` → `CollectionRegistry` (same as today).
2. **Data document layout is unchanged** — `src/data/collections/{source}/{source}.json` → published as `/collections/{source}/{source}.json` (via `sync-pages-to-public.mjs`).
3. **Collection schemas are published in three places at bake:** `public/` + `dist/` (fetchable on deploy) **and** `dist-ssr/schemas/collections/` (repo/provisioning parity with page contracts). Page page-contract schemas remain `dist-ssr`-only; unchanged.
4. **First implementation target** is `apps/tenant-alpha/scripts/bake.mjs` only. `apps/next`, inkwell, portfolio templates are **not** in v1 scope.
5. **Serialization logic lives in `@olonjs/core`** (new builder + types), tenant bake only orchestrates emission — this is a **Core contract**, not a tenant one-off.
6. **Item schema** is derived from `z.record(z.string(), ItemSchema)` by emitting JSON Schema for `ItemSchema` (the record value type), not the outer record envelope.
7. **ECIP `ui:*` descriptors** in Zod `.describe()` are preserved in emitted JSON Schema (same pipeline as `sectionSchemas` in `buildPageContract`).
8. **Keyed object invariant (v1):** collection data is always `Record<string, Item>`. Every top-level key must equal `item.id`. The contract declares `recordKeyMustMatchItemId: true`; bake **fails** on violation.

→ Correct these assumptions before implementation if any are wrong.

---

## Tech Stack

| Layer | Choice |
|-------|--------|
| Monorepo | npm workspaces (`packages/*`, `apps/*`) |
| Contract / serialization | `@olonjs/core` — extend `packages/core/src/contract/webmcp-contracts.ts` |
| Reference tenant bake | `apps/tenant-alpha/scripts/bake.mjs` (Vite SSG prebuild) |
| Tenant Zod | `zod` ^3.24.x, `CollectionRegistry` |
| Tests | Vitest in `packages/core`; optional gate in `apps/tenant-alpha/scripts/` (mirror `apps/next/scripts/prebuild-bake.test.mjs` pattern) |

Related normative docs (not replaced by this spec):

- JSP collection data paths (`collections/{source}/{source}.json`)
- ECIP `ui:*` vocabulary for Form Factory
- ADR-0002 (parallel schema registries + page contract emission pattern)

This spec is **tenant-runtime bake emission**, not the olon.js.org canonical v1 set (`docs/canonical-schemas-howto.md`).

---

## Commands

```bash
# From repo root
npm run build -w tenant-alpha          # prebuild runs sync + bake
node apps/tenant-alpha/scripts/bake.mjs # bake only (after deps installed)

# Core package
npm run build -w @olonjs/core
npm test -w @olonjs/core

# Full workspace build (when needed)
npm run build:all
```

**Verify emitted artifacts (tenant-alpha):**

```bash
ls apps/tenant-alpha/public/schemas/collections/
ls apps/tenant-alpha/dist/schemas/collections/   # after full build
ls apps/tenant-alpha/dist-ssr/schemas/collections/
```

---

## Project Structure

```
packages/core/src/contract/
  webmcp-contracts.ts     → add buildCollectionContract*, href helpers, types
  types-engine.ts         → reference only (collectionSchemas registry)

apps/tenant-alpha/
  scripts/bake.mjs        → call core builder; write public + dist
  scripts/sync-pages-to-public.mjs  → unchanged (data mirror)
  src/lib/CollectionRegistry.ts     → unchanged (Zod SOT wiring)

docs/specs/
  collection-bake-schema-emission-spec.md   → this file

docs/decisions/
  ADR-XXXX-collection-bake-schema-emission.md → optional follow-up after acceptance
```

---

## Contract (normative)

### Data (existing — not changed)

| Artifact | Source path | Published URL (tenant origin) |
|----------|-------------|-------------------------------|
| Collection document | `src/data/collections/{source}/{source}.json` | `/collections/{source}/{source}.json` |

Shape: **keyed object** — `Record<itemId, Item>`. All items live in one JSON document; items are addressed by object key, not by separate files.

**Invariant (normative):** for every entry `[key, item]` in the collection document, `key === item.id` (string equality). Bake must reject the build if any pair violates this.

### Schema (new)

| Artifact | Emitted at bake | Published URL |
|----------|-----------------|---------------|
| Collection item contract | `public/` + `dist/` + `dist-ssr/schemas/collections/{source}.schema.json` | `/schemas/collections/{source}.schema.json` (deploy); `dist-ssr/…` for provisioning |

**Not in contract:**

- `/posts/designing-with-constraints.json` or any per-item JSON URL
- Per-item schema files

### `OlonJsCollectionContract` (proposed shape)

Parallel to `OlonJsPageContract`:

```json
{
  "version": "1.0.0",
  "kind": "olonjs-collection-contract",
  "source": "posts",
  "dataHref": "/collections/posts/posts.json",
  "contractHref": "/schemas/collections/posts.schema.json",
  "recordKeyMustMatchItemId": true,
  "itemSchema": { "type": "object", "properties": { ... }, "required": [...] }
}
```

- `itemSchema`: JSON Schema for a **single** collection entry (includes `id` via `BaseCollectionItem`, ECIP `ui:*` metadata). Describes the **value** in the keyed object, not the outer record.
- `recordKeyMustMatchItemId`: always `true` in v1. Signals to consumers that collection data is a keyed object and that each key must equal `item.id`.
- `source`: collection registry key (matches directory name under `collections/`).
- `dataHref` / `contractHref`: stable relative paths for consumers.

**Href helper (core):**

```typescript
export function buildCollectionContractHref(source: string): string {
  return `/schemas/collections/${source}.schema.json`;
}
```

**Record key validation (core):**

```typescript
// packages/core — called by tenant bake before emitting contracts
export function assertCollectionRecordKeys(
  source: string,
  collection: Record<string, unknown>,
): void {
  for (const [key, item] of Object.entries(collection)) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throw new Error(`[bake] Collection "${source}": invalid item at key "${key}"`);
    }
    const id = (item as { id?: unknown }).id;
    if (typeof id !== 'string' || id !== key) {
      throw new Error(
        `[bake] Collection "${source}": record key "${key}" must equal item.id (got ${JSON.stringify(id)})`,
      );
    }
  }
}
```

Bake **must** call `assertCollectionRecordKeys` for each `{source}` document before `buildCollectionContract`. Failure aborts prebuild with non-zero exit.

### Discovery (v1 — site manifest index)

`mcp-manifest.json` (`OlonJsSiteManifestIndex`) gains a **`collections`** array in v1.

Extend `buildSiteManifest` input with `collectionSchemas` (registry keys). Each entry:

```json
{
  "source": "posts",
  "dataHref": "/collections/posts/posts.json",
  "contractHref": "/schemas/collections/posts.schema.json"
}
```

Consumers (dashboard, agents) discover collections from `GET /mcp-manifest.json` first; direct path inference remains a fallback only.

---

## Code Style

Follow existing `webmcp-contracts.ts` patterns:

- Pure functions, no React
- `zodToJsonSchema` for field-level emission (reuse internal helper; export builder only)
- `cloneJson` for safe snapshots
- Named exports; no default exports

Example tenant bake call (illustrative):

```javascript
import { webmcp, assertCollectionRecordKeys } from '@olonjs/core';
// webMcpBuildState.collectionSchemas + collections from SSR entry / runtime

for (const [source, zodSchema] of Object.entries(webMcpBuildState.collectionSchemas)) {
  const collection = webMcpBuildState.collections?.[source];
  if (collection && typeof collection === 'object' && !Array.isArray(collection)) {
    assertCollectionRecordKeys(source, collection);
  }
  const contract = webmcp.buildCollectionContract({ source, schema: zodSchema });
  const relativePath = `schemas/collections/${source}.schema.json`;
  await writeJsonTargets(relativePath, contract);
  await writeSsrJson(relativePath, contract);
}
```

- `writeJsonTargets` — deploy surface (`public/` + `dist/`)
- `writeSsrJson` — provisioning/repo surface (`dist-ssr/`), same policy as page contracts

---

## Testing Strategy

| Level | Where | What |
|-------|-------|------|
| Unit | `packages/core` | `buildCollectionContract` → `recordKeyMustMatchItemId: true` always set |
| Unit | `packages/core` | `assertCollectionRecordKeys` throws when `key !== item.id`; passes on valid keyed object |
| Unit | `packages/core` | Reject unknown Zod shapes with explicit error (non-record collection schemas) |
| Integration | `apps/tenant-alpha` | Run `bake.mjs`; contracts exist; `mcp-manifest.json` lists `collections[]` |
| Integration | `apps/tenant-alpha` | Bake fails with clear error if a fixture collection has mismatched key/`id` |
| Manual | Deployed tenant | `curl https://{tenant}/schemas/collections/posts.schema.json` returns contract |

Coverage expectation: core builder fully unit-tested; tenant gate is file-existence + JSON shape smoke test.

---

## Boundaries

### Always

- Emit schemas from tenant Zod at bake; never hand-edit published `*.schema.json` in tenant repos.
- Keep collection **data** and **schema** paths symmetric under `/collections/` and `/schemas/collections/`.
- Implement serialization and validation in `@olonjs/core`; tenant bake stays thin.
- Enforce keyed-object invariant at bake (`assertCollectionRecordKeys`); never emit contracts for invalid collection data.

### Ask first

- Extending `llms.txt` with a Collections section (manifest index covers v1 discovery).
- Changing where **page** schemas are written (`dist-ssr` vs `public/`).
- Porting the same emission to `apps/next` bake or DNA templates.
- Adding new fields to canonical olon.js.org `/schemas/v1/*`.

### Never

- Per-item JSON files or per-item schema URLs.
- Reading collection Zod from GitHub in platform when deploy schema exists (platform concern, but contract assumes deploy-first).
- Breaking `validateCollectionDocuments` / runtime `CollectionRegistry` parsing.

---

## Success Criteria

1. **Core API:** `buildCollectionContract` (+ `buildCollectionContractHref`) exported from `@olonjs/core` (`webmcp` barrel).
2. **Alpha bake:** For every key in `CollectionRegistry`, after `node scripts/bake.mjs`:
   - `public/schemas/collections/{source}.schema.json` exists
   - `dist/schemas/collections/{source}.schema.json` exists (post full build)
   - `dist-ssr/schemas/collections/{source}.schema.json` exists
3. **Site manifest:** `GET /mcp-manifest.json` includes `collections[]` with `source`, `dataHref`, `contractHref` for each registered collection.
4. **Deploy fetch:** `GET /schemas/collections/{source}.schema.json` returns `kind: "olonjs-collection-contract"` with `recordKeyMustMatchItemId: true` and valid `itemSchema`.
5. **Keyed object:** Bake exits non-zero if any `collections/{source}/{source}.json` entry has `key !== item.id`.
6. **Item alignment:** A sample item from `collections/{source}/{source}.json` is structurally described by `itemSchema` (required fields, `ui:*` hints).
7. **No regression:** Existing bake outputs (pages JSON, mcp manifests, `dist-ssr/schemas/*.schema.json` for pages) unchanged.
8. **Tests:** Core unit tests pass; tenant bake gate passes in CI.

---

## Resolved decisions

1. **Site manifest index** — **Yes (v1).** `mcp-manifest.json` exposes `collections: [{ source, dataHref, contractHref }]`.
2. **`dist-ssr` mirror** — **Yes (v1).** Collection contracts are written to `dist-ssr/schemas/collections/` in addition to `public/` + `dist/`.
3. **Keyed object + `recordKeyMustMatchItemId`** — **Yes (v1).** Collection data is a keyed object (`Record<string, Item>`). Contract always includes `recordKeyMustMatchItemId: true`. Bake calls `assertCollectionRecordKeys` and **fails** if any `key !== item.id`.

---

## Implementation phases (for human review — not executed until spec approved)

1. Core: types + `buildCollectionContract` + tests
2. tenant-alpha `bake.mjs`: emission loop + gate test
3. Docs: link from `docs/ARCHITECTURE.md`; optional ADR
4. (Later) Next bake, DNA templates, olon-platform dashboard consumer

---

## References

- `apps/tenant-alpha/scripts/bake.mjs` — page contract → `dist-ssr`; data → `public`+`dist`
- `apps/tenant-alpha/scripts/sync-pages-to-public.mjs` — collection data mirror
- `packages/core/src/contract/webmcp-contracts.ts` — `buildPageContract`, `zodToJsonSchema`
- `packages/core/src/contract/config-resolver.ts` — `validateCollectionDocuments`, collection document aliases
- `docs/decisions/ADR-0002-form-submission-schemas.md` — parallel registry / contract emission pattern
