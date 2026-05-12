# ADR-0013: Implementation of the v1 canonical JSON Schema set via `npm run bump:all`

**Status:** Accepted
**Date:** 2026-05-12
**Deciders:** Guido Filippo Serio
**Related:** ADR-0003 (JSON Schema as public contract, Zod as internal SOT)

---

## Context

ADR-0003 mandated the v1 canonical contract surface: five JSON Schema artifacts published at `https://olon.js.org/schemas/v1/`. At the time of that ADR only `design.schema.json` was published, hand-authored. The other four (`menu`, `site`, `page`, `tenant`) were defined as Zod-derived but had no concrete generator.

This ADR records the implementation that completes the v1 surface, the conventions adopted in the generator, and the behavioral rules of `zod-to-json-schema` that the Zod source must respect to produce clean output.

## Decision

Three concrete artifacts:

1. **Internal Zod SOT** at `packages/core/src/contract/zod-schemas.ts`. Not re-exported from `@olonjs/core` (ADR-0003 §AD-2).
2. **Generator script** at `scripts/bump-schemas.ts`, invoked via `npm run bump:all`. Run via `tsx`; no core build required.
3. **Four published artifacts** in `apps/olonjs.io/public/schemas/v1/`: `menu.schema.json`, `site.schema.json`, `page.schema.json`, `tenant.schema.json`. The fifth, `design.schema.json`, remains hand-authored per ADR-0003 §AD-5.

The set of 5 schemas published under `/v1/` is now complete.

## Architecture decisions

### AD-1: Envelope is generator-controlled, not Zod-controlled

The generator wraps each Zod-converted body with a fixed envelope: `$schema` (Draft-07), `$id` (`https://olon.js.org/schemas/v1/<name>.schema.json`), `title`, `description`, and `examples`. These five fields are never authored in Zod — they come from the resource entry in `bump-schemas.ts`. This keeps Zod focused on structural shape and `bump-schemas.ts` focused on contract metadata.

### AD-2: Deterministic key ordering with a curated priority

Output uses a fixed priority list (`$schema`, `$id`, `$ref`, `title`, `description`, `type`, `required`, `properties`, …) for high-frequency JSON Schema keywords, then alphabetical for the rest. Goals: readable for humans, stable for git diff, deterministic across runs.

### AD-3: `definitions` are configured per-resource, not per-schema

Each resource declares `definitions: { Name: ZodSchema }`. The lib (`zod-to-json-schema`) extracts those schemas as `#/definitions/Name` and rewrites usages to `$ref`. Registration policy:

- **Always register** schemas that are recursive (`MenuItem`) or used multiple times across the same output file (`Section` in both `site` and `page`).
- **Register for consistency** when a single-use schema appears in multiple files and we want uniform rendering (`SiteIdentity` in both `site` and `tenant` — chosen explicitly, see Option B in the implementation plan).
- **Leave inline** anything else.

### AD-4: Cross-file `$ref` for the tenant manifest

`tenant.schema.json` is a thin wrapper: four of its five top-level properties are cross-file `$ref` to the canonical schemas (`design.schema.json`, `site.schema.json`, `menu.schema.json`, `page.schema.json`). The generator handles this via a `crossRefs: Record<string, string>` map on the resource that post-replaces target dotted-paths with `{ $ref: <relative-url> }` after `zod-to-json-schema` conversion. This is **configuration of emission**, not patching of output: the Zod SOT for the manifest carries placeholder schemas at those paths, and `crossRefs` declares the targets in one place.

### AD-5: Cross-ref placeholder Zod must be required-by-default

Cross-ref placeholders in `TenantManifestSchema` use `z.object({}).passthrough()` (or any non-undefined-accepting type), NOT `z.unknown()`. `z.unknown()` produces non-required fields in JSON Schema output because Zod's `unknown` accepts `undefined`. The generator replaces the placeholder's converted output with the cross-file `$ref` so the placeholder's shape is irrelevant after replacement; only its required-ness matters.

### AD-6: `design.schema.json` stays hand-authored and out of the pipeline

`bump:all` does not touch `design.schema.json`. It remains a hand-authored Draft-07 schema per ADR-0003 §AD-5. The cross-file `$ref` from `tenant.schema.json` points to it by URL; the design schema's `$id` is the contract anchor.

### AD-7: ajv meta-schema validation before write

Every generated body is validated against the Draft-07 meta-schema with `ajv` (in `strict: false` mode) before being written. Failure exits non-zero. This catches structural breakage in the converted output but does NOT verify cross-file `$ref` resolvability — that is a deployment-time concern.

## Gotchas learned

These are behaviors of `zod-to-json-schema` that drive how the Zod SOT must be written. They are not bugs; they are deterministic and reflect the library's identity-based design. They must be respected.

### Gotcha 1: `.optional().describe()` preserves $ref; bare `.describe()` does not

When a Zod schema `S` is registered in `definitions`, the lib emits `$ref: #/definitions/Name` only when it sees `S` by reference identity. `S.optional()` returns a `ZodOptional` that wraps `S`; the lib unwraps it, sees `S`, emits `$ref` cleanly. `S.describe('X')` returns a *clone* of `S` with a new description; the lib does not match the clone against `S`, decomposes the clone inline, and emits per-property `$ref` like `#/definitions/Name/properties/<field>`.

**Implication:** do not chain `.describe()` directly on `definitions`-registered schemas. Place the description on the schema definition itself, or on a wrapping `.optional()`, or on the parent array/object — never on the bare schema at the use site.

### Gotcha 2: `z.unknown()` makes a field non-required

`zod-to-json-schema` treats `z.unknown()` as accepting `undefined`, so the field never lands in the parent's `required` array. For cross-ref placeholders, use `z.object({}).passthrough()` instead.

### Gotcha 3: `$ref` siblings are formally ignored in Draft-07

When `$ref` is used, sibling keywords (`description`, `title`, …) are formally ignored by spec-compliant validators. `header: SectionSchema.optional().describe('X')` emits `{ $ref: …, description: 'X' }`. The description is visible to tools that bend the spec (Apidog, Stoplight, some SDK generators) but invisible to strict validators (ajv with `strict: true`, native JSON Schema engines). For per-usage descriptions of `$ref`'d schemas, accept the sibling-pattern as documentation-only or move the description into the parent schema's prose.

## Consequences

### Positive

- v1 contract surface complete: 5 published schemas, citable, language-agnostic.
- Add-a-schema flow is a small Zod edit plus a small `resources[]` entry — reproducible, documented in `docs/canonical-schemas-howto.md`.
- Manual review gate (ADR-0003 §AD-3) is sufficient because the lib's behavior is deterministic given the gotchas.

### Negative

- The Zod source has subtleties (the three gotchas) that aren't obvious from Zod or JSON Schema specs alone. New contributors must read this ADR and the howto.
- Cross-file `$ref` in `tenant.schema.json` requires consumers to resolve relative URLs against `$id`. Some preview tools (e.g., Apidog) report "Reference not found" because they don't fetch sibling schemas; this is a consumer-tool issue, not a contract issue.

### Neutral

- The `crossRefs` mechanism in the generator is ~20 lines and reusable for any future schema that needs to reference other canonical schemas.
- Output is Draft-07. Migration to Draft 2019-09 / 2020-12 (`$defs` instead of `definitions`) is a future concern, gated on consumer ecosystem maturity.

## Implementation outline (completed)

1. ✅ Added devDeps in root `package.json`: `zod-to-json-schema`, `ajv`, `tsx`.
2. ✅ Added `"bump:all"` script.
3. ✅ Created `packages/core/src/contract/zod-schemas.ts` (internal SOT). Exports: `MenuItemSchema`, `MenuConfigSchema`, `SectionSchema`, `SiteIdentitySchema`, `SiteConfigSchema`, `PageMetaSchema`, `PageContractSchema`, `TenantManifestSchema`.
4. ✅ Created `scripts/bump-schemas.ts`. Pipeline: convert via `zodToJsonSchema` → optional `crossRefs` post-substitution → envelope inject → ajv meta-schema validation → deterministic write.
5. ✅ Published 4 generated artifacts at `apps/olonjs.io/public/schemas/v1/`. `design.schema.json` left untouched.

## Follow-ups

- `--check` mode for `bump:all`: validate actual `.json` data files against the published schemas (ADR-0003 §AD-3 review gate at runtime).
- CI drift guard: workflow that runs `bump:all` and fails if the working tree is dirty.
- Documentation page on `olon.it/resources` linking the 5 canonical schemas with consumer examples.
- ADR-0004 (Python authoring layer via Pydantic) and a future ADR for v2.0 conformance suite remain roadmap as declared in ADR-0003.

## References

- ADR-0003 — JSON Schema as public contract, Zod as internal SOT.
- `packages/core/src/contract/zod-schemas.ts` — internal Zod SOT.
- `scripts/bump-schemas.ts` — generator.
- `apps/olonjs.io/public/schemas/v1/` — published artifacts.
- `docs/canonical-schemas-howto.md` — practical guide for adding/modifying schemas.
- `zod-to-json-schema` — library reference for the Zod → JSON Schema conversion rules.
- JSON Schema Draft-07 specification — section 8.3 (`$ref`), section 9 (`definitions`).
