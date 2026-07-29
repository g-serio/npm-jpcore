# 01 — Implementation Plan: Collection item schema emission (tenant bake, Core)

Spec: [`docs/specs/collection-bake-schema-emission-spec.md`](../specs/collection-bake-schema-emission-spec.md)
Repo: `npm-jpcore`
Status: **Plan — awaiting human review**

## Overview

Implement a deterministic, machine-readable JSON Schema contract for **collection item values** emitted by tenants during build time. The platform and agents will be able to fetch:

- Collection data: `GET /collections/{source}/{source}.json`
- Collection item schema contract: `GET /schemas/collections/{source}.schema.json`

Additionally, extend `GET /mcp-manifest.json` to include a `collections[]` index so consumers can discover collection sources without scraping HTML.

## Architecture Decisions

- **Contract shape mirrors pages:** follow `webmcp-contracts.ts` patterns used by `buildPageContract` / `buildSiteManifest`.
- **Keyed record invariant is enforced at bake:** collection JSON is a single keyed record object (`Record<itemId, Item>`). The contract always declares `recordKeyMustMatchItemId: true`, and the bake fails if any `key !== item.id`.
- **Deployment + provisioning surfaces both supported:** collection contracts are written to `public/` + `dist/` (fetchable on deploy) and also mirrored into `dist-ssr/schemas/collections/` (repo/provisioning parity with page contracts).

## Task List

### Phase 1: Core Foundations

- [ ] Task 1: Add collection contract types + href helpers in Core
- [ ] Task 2: Implement `assertCollectionRecordKeys` + `buildCollectionContract`
- [ ] Task 3: Extend `mcp-manifest.json` with `collections[]`
- [ ] Task 4: Export new Core WebMCP symbols

### Checkpoint: Core

- [ ] `npm run build -w @olonjs/core` passes
- [ ] `npm test -w @olonjs/core` passes
- [ ] No existing page contract outputs changed

### Phase 2: Tenant-alpha Build Emission

- [ ] Task 5: Update `apps/tenant-alpha/scripts/bake.mjs` — emit collection contracts
- [ ] Task 6: Update `apps/tenant-alpha/scripts/bake.mjs` — pass `collectionSchemas` to `buildSiteManifest`
- [ ] Task 7: Add tenant bake gate test for collection schema emission

### Checkpoint: Tenant

- [ ] `npm run build -w tenant-alpha` passes
- [ ] Emitted collection schema files + manifest exist and match expected shapes

### Phase 3: Docs + Final Verification

- [ ] Task 8: Update documentation
- [ ] Task 9: Run full local checks

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Incorrect extraction of item value type from Zod `z.record(...)` | Medium | Core unit tests comparing emitted `itemSchema` against fixture |
| Bake fails on collection data not following keyed-object invariant | High | Intentional; clear error message; ensure tenant-alpha data is correct |
| Changing `buildSiteManifest` shape breaks consumers | Medium | Additive only (`collections[]`); backward compatible |

## Open Questions

- `llms.txt` collections section: out of scope v1.
