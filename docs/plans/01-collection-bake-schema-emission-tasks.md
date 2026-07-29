# 01 — Tasks: Collection item schema emission

Plan: [`01-collection-bake-schema-emission-plan.md`](01-collection-bake-schema-emission-plan.md)
Spec: [`../specs/collection-bake-schema-emission-spec.md`](../specs/collection-bake-schema-emission-spec.md)

## Phase 1: Core Foundations

- [ ] **Task 1:** Add collection contract types + href helpers in Core
  - Add `OlonJsCollectionContract` interface + `buildCollectionContractHref(source)` → `/schemas/collections/${source}.schema.json`
  - File: `packages/core/src/contract/webmcp-contracts.ts`
  - Verify: `npm run build -w @olonjs/core`

- [ ] **Task 2:** Implement `assertCollectionRecordKeys` + `buildCollectionContract`
  - Validator: throws if `key !== item.id` for any entry
  - Builder: emits `kind: "olonjs-collection-contract"`, `recordKeyMustMatchItemId: true`, `itemSchema` (single item value from `z.record` value type)
  - Files: `packages/core/src/contract/webmcp-contracts.ts`, new test file
  - Verify: `npm test -w @olonjs/core`

- [ ] **Task 3:** Extend `mcp-manifest.json` with `collections[]`
  - Update `OlonJsSiteManifestIndex` + `BuildSiteManifestInput` + `buildSiteManifest`
  - Each entry: `{ source, dataHref, contractHref }`
  - File: `packages/core/src/contract/webmcp-contracts.ts`
  - Verify: `npm test -w @olonjs/core`, `npm run build -w @olonjs/core`

- [ ] **Task 4:** Export new Core WebMCP symbols
  - Export `buildCollectionContract`, `buildCollectionContractHref`, `assertCollectionRecordKeys`, `OlonJsCollectionContract` from `packages/core/src/webmcp/index.ts`
  - Verify: `npm run build -w @olonjs/core`

### Checkpoint: Core
- [ ] Core build + tests pass, no page contract regression

---

## Phase 2: Tenant-alpha Build Emission

- [ ] **Task 5:** Update `apps/tenant-alpha/scripts/bake.mjs` — emit collection contracts
  - For each `collectionSchemas` entry: validate with `assertCollectionRecordKeys`, build contract, write to `public/` + `dist/` + `dist-ssr/schemas/collections/{source}.schema.json`
  - File: `apps/tenant-alpha/scripts/bake.mjs`
  - Verify: run bake, check file existence

- [ ] **Task 6:** Update `apps/tenant-alpha/scripts/bake.mjs` — manifest generation
  - Pass `collectionSchemas` to `buildSiteManifest`, verify `mcp-manifest.json` includes `collections[]`
  - File: `apps/tenant-alpha/scripts/bake.mjs`
  - Verify: read `public/mcp-manifest.json`

- [ ] **Task 7:** Add tenant bake gate test
  - Assert: schema files exist for `autori` + `libri`, contract shape correct, `mcp-manifest.json` has `collections[]`
  - File: `apps/tenant-alpha/scripts/prebuild-bake-collections.test.mjs` (new)
  - Verify: `node --test apps/tenant-alpha/scripts/prebuild-bake-collections.test.mjs`

### Checkpoint: Tenant
- [ ] `npm run build -w tenant-alpha` passes, artifacts match spec

---

## Phase 3: Docs + Final

- [ ] **Task 8:** Update `docs/ARCHITECTURE.md` with collection contract URLs + keyed-object invariant
  - Verify: manual review

- [ ] **Task 9:** Run full local checks
  - `npm test -w @olonjs/core` + `npm run build -w tenant-alpha`
  - Verify: all green
