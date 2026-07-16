# Collection Protocol (COP) v1.1

## Status

Accepted.

This document supersedes `specs/COP_v1.0.md` for the implemented Collection Protocol surface. COP v1.1 keeps the architectural model from v1.0 and makes the runtime, Studio, WebMCP, Form Factory, and public document behavior explicit.

## Objective

COP defines structured entity collections that exist independently of pages and are consumed by tenant capsules through bound external references.

A collection is not owned by the section that renders it. A collection has its own data document, schema contract, edit path, validation boundary, and public resolution semantics.

The invariant is:

```text
Collection JSON + Collection Schema -> validated collection document -> $ref resolution -> section props
```

No invalid, schema-less, or raw pre-parse collection data may enter Core `$ref` resolution.

---

## 1. Architectural Principles

### 1.1 Ownership

Collections own entity data. Capsules consume entity data.

A capsule such as `books-list`, `product-grid`, or `book-detail` may render collection entities, but it is not the semantic authority for those entities.

### 1.2 Dual Topology

Collection data and collection contract must remain separate.

Data lives under:

```text
src/data/collections/{source}/{source}.json
```

Contract lives under:

```text
src/collections/{source}/
  schema.ts
  types.ts
  index.ts
```

This mirrors the wider OlonJS separation between authored JSON data and TypeScript/Zod contracts.

### 1.3 Fail-Fast Validation

Collection validation is fail-fast at the Core resolver boundary.

The Core resolver must validate each active `collections[source]` against `collectionSchemas[source]` before registering that collection as a resolvable document.

Invalid data must fail resolution. Missing schemas must fail resolution. Core must not skip invalid collections, warn-only, preserve raw data, or fall back to unresolved `$ref` behavior.

### 1.4 Parsed Output Authority

The parsed output of the collection schema is the only collection document that enters the resolver.

This matters for Zod behavior such as:

- defaults
- stripping unknown object keys
- coercion
- transforms
- refinements

The same parsed entity must be used for both regular collection document refs and `collection:current`.

---

## 2. Collection Document Shape

A collection document is a keyed JSON object:

```json
{
  "dune": {
    "id": "dune",
    "title": "Dune",
    "author": "Frank Herbert"
  },
  "neuromancer": {
    "id": "neuromancer",
    "title": "Neuromancer",
    "author": "William Gibson"
  }
}
```

It is explicitly not a JSON array.

The keys are stable entity identifiers. Each entity must include an `id` field.

The canonical invariant is:

```text
collectionKey === entity.id
```

Core currently relies on the entity `id` for routing, React keys, Studio addressing, and agent mutation targets. Tenants should keep key and `id` aligned. A future strict validator may enforce equality.

---

## 3. Collection Contract

Each collection exports an entity schema and a collection document schema.

Example:

```typescript
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const BookSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  author: z.string().describe('ui:text'),
  year: z.number().describe('ui:number'),
  summary: z.string().describe('ui:textarea'),
});

export const BooksCollectionSchema = z.record(z.string(), BookSchema);
```

### 3.1 Required Files

```text
src/collections/{source}/schema.ts
src/collections/{source}/types.ts
src/collections/{source}/index.ts
```

`schema.ts` exports:

- an entity schema, e.g. `BookSchema`
- a collection schema, e.g. `BooksCollectionSchema`

`types.ts` exports types inferred from those schemas.

`index.ts` re-exports schemas and types.

### 3.2 BaseCollectionItem

Every entity schema must extend `BaseCollectionItem`.

Canonical shape:

```typescript
export const BaseCollectionItem = z.object({
  id: z.string(),
});
```

Current public import path in tenant code is:

```typescript
import { BaseCollectionItem } from '@olonjs/core';
```

`BaseCollectionItem` is a pure Zod schema fragment and stays in `@olonjs/core` regardless of which rendering package (`@olonjs/react`) or editor package (`@olonjs/studio`) the tenant also depends on — there is no subpath or build-time split to reason about for this import (the pre-ADR-0016 `@olonjs/core/runtime` subpath split has been superseded by the three-package split; see ADR-0016).

---

## 4. CollectionRegistry

Tenants register collection document schemas in `src/lib/CollectionRegistry.ts`.

Example:

```typescript
import { BooksCollectionSchema } from '@/collections/books';

export const CollectionRegistry = {
  books: BooksCollectionSchema,
} as const;

export type CollectionType = keyof typeof CollectionRegistry;
```

`CollectionRegistry` is passed to Core as `JsonPagesConfig.collectionSchemas`.

For every active entry in `collections`, there must be a matching entry in `collectionSchemas`.

```typescript
const config = {
  collections: {
    books: booksData,
  },
  collectionSchemas: CollectionRegistry,
};
```

Missing schema policy:

```text
collections[source] present && !collectionSchemas[source] -> throw
```

---

## 5. Engine Bootstrap Contract

`JsonPagesConfig` includes both data and schema registries:

```typescript
export interface JsonPagesConfig {
  collections?: Record<string, Record<string, unknown>>;
  collectionSchemas?: Record<string, { parse(value: unknown): unknown }>;
}
```

Core treats `collectionSchemas` as schema-like objects. They are usually Zod schemas, but Core only requires a `parse(value)` method.

### 5.1 Resolver Input

`resolveRuntimeConfig(...)` accepts:

- pages
- site config
- theme config
- menu config
- collections
- collection schemas
- optional collection context
- ref documents

The resolver validates `collections` before registering them in its internal document map.

### 5.2 Resolver Output

`resolveRuntimeConfig(...)` returns:

- resolved pages
- resolved site config
- resolved theme config
- resolved menu config
- validated collection documents
- validated/rebased collection context

The returned `collections` are parsed schema output.

The returned `collectionContext.currentItem` is also parsed schema output.

---

## 6. Validation Semantics

Validation happens at the Core resolver boundary:

```text
JsonPagesConfig.collections
  -> validateCollectionDocuments(collections, collectionSchemas)
  -> validated collections
  -> buildDocuments(...)
  -> $ref resolution
```

### 6.1 Valid Collection

If `collectionSchemas[source].parse(collections[source])` succeeds, the parsed output is registered as:

```text
collections/{source}/{source}.json
src/data/collections/{source}/{source}.json
```

Both aliases point to the parsed document.

### 6.2 Missing Schema

If a collection source has no matching schema, Core throws an explicit error naming the source.

Example:

```text
[JsonPages] Missing collection schema for "books".
```

### 6.3 Invalid Collection

If parsing fails, Core throws an explicit error naming the source.

Example:

```text
[JsonPages] Invalid collection "books": ...
```

### 6.4 No Silent Fallbacks

Core must not:

- register raw invalid collection data
- skip invalid collection documents
- warn and continue
- preserve unresolved `$ref` as a recovery path for invalid collection data
- resolve `collection:current` from raw data when parsed data exists

---

## 7. Collection References

### 7.1 Document Reference

A section may bind a field to a full collection document.

Example:

```json
{
  "id": "books-list",
  "type": "books-list",
  "data": {
    "title": "Books",
    "items": { "$ref": "../collections/books/books.json" }
  }
}
```

At runtime the section receives the parsed collection document:

```typescript
{
  title: 'Books',
  items: {
    dune: { id: 'dune', title: 'Dune', author: 'Frank Herbert' }
  }
}
```

The authored page keeps the `$ref`.

### 7.2 collection:current

`collection:current` is a reserved `$ref` target for dynamic collection routes.

Example:

```json
{
  "id": "book-detail",
  "type": "book-detail",
  "data": {
    "item": { "$ref": "collection:current" }
  }
}
```

`collection:current` resolves to the active route entity selected by the page `collection` binding.

The entity must come from the parsed collection document, not the raw bootstrap collection object.

This is mandatory. A schema default, strip, coercion, or transform must produce identical entity data for:

- `../collections/{source}/{source}.json#/id`
- `collection:current`

---

## 8. Dynamic Route Binding

A dynamic collection page declares `collection` on the page document.

Example:

```json
{
  "id": "book-detail-page",
  "slug": "books/[slug]",
  "collection": {
    "source": "books",
    "paramKey": "slug"
  },
  "sections": [
    {
      "id": "book-detail",
      "type": "book-detail",
      "data": {
        "item": { "$ref": "collection:current" }
      }
    }
  ]
}
```

The engine:

1. matches the route against the page registry
2. reads `params[paramKey]`
3. validates the collection source
4. rebases `collectionContext.currentItem` to the parsed collection item
5. resolves `collection:current`
6. passes parsed item props to the consuming capsule

If the route param is missing or no item exists after validation, collection context is `null` and `collection:current` remains unresolved through the normal unresolved-ref behavior.

---

## 9. Consuming Capsules

Capsules consume collection data through section fields marked with `ui:collection-ref`.

Example list schema:

```typescript
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { BookSchema } from '@/collections/books';

export const BooksListSchema = BaseSectionData.extend({
  title: z.string().describe('ui:text'),
  items: z.record(z.string(), BookSchema).describe('ui:collection-ref'),
});
```

Example detail schema:

```typescript
import { BaseSectionData } from '@olonjs/core';
import { BookSchema } from '@/collections/books';

export const BookDetailSchema = BaseSectionData.extend({
  item: BookSchema.describe('ui:collection-ref'),
});
```

### 9.1 Schema Authority

The collection schema remains the semantic authority for entity shape.

The section schema may import and reuse the entity schema to make the Form Factory and inspector understand the resolved field shape. This reuse does not transfer ownership of the entity contract to the section.

The section owns editorial fields around the collection binding, such as:

- title
- eyebrow
- description
- page size
- back label

The collection owns entity fields, such as:

- book title
- author
- year
- summary

---

## 10. Form Factory Contract

`ui:collection-ref` tells Studio that the field is externally owned by a collection document.

The Form Factory must:

- render the resolved field value for editing
- preserve the authored `$ref` in the page document
- allow nested entity field edits based on the resolved Zod schema
- identify record items by stable item id
- route changes back through collection draft rebasing

For a record collection field, Form Factory uses the record value schema to render each item.

For a single entity field, Form Factory uses the entity object schema.

The page field remains a binding. The collection document receives the mutation.

---

## 11. Studio Draft Contract

Studio keeps three relevant drafts:

- page draft
- site/menu draft
- collections draft

When an editor changes a collection-bound field:

1. Studio receives resolved section data from the stage or inspector.
2. Studio locates authored `$ref` bindings in the original section data.
3. Studio restores the authored `$ref` into the page draft.
4. Studio writes the edited entity or collection data into `collectionsDraft`.
5. Studio validates `collectionsDraft` with `collectionSchemas`.
6. Studio accepts the state only if validation succeeds.

Invalid collection draft edits must be rejected before becoming saved source of truth.

### 11.1 Authored Ref Preservation

If authored data contains:

```json
{
  "item": { "$ref": "collection:current" }
}
```

then the page draft must keep:

```json
{
  "item": { "$ref": "collection:current" }
}
```

The edited entity is written into the active collection draft.

### 11.2 Collection Document Ref Preservation

If authored data contains:

```json
{
  "items": { "$ref": "../collections/books/books.json" }
}
```

then the page draft must keep that `$ref`, and the edited record is written into `collectionsDraft.books`.

### 11.3 Save Contract

Before local save, hot save, or cold save, Studio must build a project state that includes validated collection documents.

Saved `ProjectState.collections` must contain parsed schema output, not raw unresolved edits.

---

## 12. WebMCP Contract

WebMCP update tools may mutate section fields that resolve from collection bindings.

The same rules as Studio apply:

- schema-parse section payload first
- preserve authored `$ref` fields in the page document
- write collection entity edits into `collectionsDraft`
- validate the resulting collection draft
- reject invalid updates

A WebMCP mutation must not make the page JSON own collection entity data.

WebMCP save must persist only valid collection drafts.

---

## 13. Public Document and SSG Contract

Public page documents and static build output must use the same resolution semantics as runtime.

`resolvePublicPageDocument(...)` must:

- accept `collections`
- accept `collectionSchemas`
- validate collections through the Core resolver
- resolve page `$ref` fields against parsed collection documents
- return `collectionContext` rebased to parsed collection data

The tenant bake pipeline must pass `collectionSchemas` when generating:

- resolved public `pages/*.json`
- page contracts
- page manifests
- MCP manifests
- SSG HTML

If a collection is invalid during SSG, the build must fail. A tenant with invalid collection data must not produce public agent contracts.

---

## 14. Public Agent Contract

Resolved public JSON exported for agents should match runtime section props.

If visitor runtime resolves:

```typescript
section.data.items
```

from a parsed collection document, then public `pages/{slug}.json` must contain the same resolved value.

This keeps browser rendering, WebMCP resource reads, public manifests, and agent contracts coherent.

---

## 15. Error Policy

COP validation errors are contract errors.

Errors should name the collection source.

Acceptable:

```text
[JsonPages] Invalid collection "books": ...
```

Acceptable:

```text
[JsonPages] Missing collection schema for "books".
```

Not acceptable:

```text
[JsonPages] Unresolved $ref ../collections/books/books.json
```

when the real cause is invalid collection data.

---

## 16. Runtime Surfaces

The COP implementation spans these runtime surfaces:

### 16.1 Core Contract Resolver

Owns:

- collection validation
- document alias registration
- `$ref` resolution
- `collection:current`
- parsed collection context rebasing

### 16.2 Visitor Route

Owns:

- route match
- collection context candidate construction
- passing `collections` and `collectionSchemas` into Core resolution

### 16.3 Studio Route

Owns:

- collections draft state
- applying collection-bound edits
- preserving authored refs
- rejecting invalid drafts
- passing collection schemas into persistence

### 16.4 Public Page Document

Owns:

- public page resolution for build and agent resources
- returning parsed collection context

### 16.5 Tenant Runtime

Owns:

- importing collection JSON
- importing `CollectionRegistry`
- passing both into engine config and build state

---

## 17. Compliance Checklist

A tenant with COP is compliant when:

1. Each collection has data at `src/data/collections/{source}/{source}.json`.
2. Each collection has contract files under `src/collections/{source}/`.
3. Every entity schema extends `BaseCollectionItem`.
4. Every collection exports both entity schema and collection document schema.
5. `src/lib/CollectionRegistry.ts` registers every active collection.
6. Engine config passes both `collections` and `collectionSchemas`.
7. Every `collections[source]` has a matching `collectionSchemas[source]`.
8. Collection documents are keyed objects, not arrays.
9. Page documents bind collection fields with `$ref`.
10. Dynamic collection pages declare `collection.source` and `collection.paramKey`.
11. `collection:current` resolves from parsed collection data.
12. Section schemas mark resolved collection fields with `ui:collection-ref`.
13. Studio preserves authored `$ref` fields after edits.
14. Studio writes entity edits into collection drafts.
15. Studio and WebMCP reject invalid collection drafts.
16. SSG/public document generation passes collection schemas.
17. Public JSON and visitor runtime resolve the same collection data.

---

## 18. Non-Goals

COP v1.1 does not define:

- database-backed collections
- remote collection fetching
- pagination protocols for very large collections
- collection-level access control
- relation joins between multiple collection sources
- automatic enforcement that record key equals entity `id`
- a generic collection CRUD UI outside the existing Studio inspector flow

These can be layered later, but they must preserve the same validation and ownership boundaries.

---

## 19. Implementation Notes

The current implementation exposes these key functions:

- `validateCollectionDocuments(...)`
- `resolveCollectionContext(...)`
- `resolveRuntimeConfig(...)`
- `applyCollectionRefBindingsToDraft(...)`
- `resolvePublicPageDocument(...)`

The important ordering is:

```text
resolveCollectionContext(raw candidate)
resolveRuntimeConfig(...)
  validateCollectionDocuments(...)
  rebaseCollectionContext(parsed collections)
  buildDocuments(parsed collections)
  resolveDocument(..., parsed collectionContext)
```

`resolveCollectionContext(...)` may initially locate a candidate using raw collections, because route matching needs to know whether an item id exists. `resolveRuntimeConfig(...)` is responsible for rebasing that context to parsed data before `$ref` resolution.

---

## 20. Regression Scenarios

COP implementations must guard these scenarios:

### 20.1 Missing Schema

Input:

```typescript
collections = { books: {} };
collectionSchemas = {};
```

Expected result:

```text
throw [JsonPages] Missing collection schema for "books".
```

### 20.2 Invalid Collection

Input item lacks a required schema field.

Expected result:

```text
throw [JsonPages] Invalid collection "books"
```

### 20.3 Parsed collection:current

Input raw item:

```json
{
  "id": "dune",
  "title": "Dune",
  "draftOnly": true
}
```

Schema:

```typescript
z.object({
  id: z.string(),
  title: z.string(),
  author: z.string().default('Unknown'),
})
```

Expected resolved `collection:current`:

```json
{
  "id": "dune",
  "title": "Dune",
  "author": "Unknown"
}
```

No `draftOnly` field should survive unless the schema permits it.

### 20.4 Studio Edit Preservation

Authored page field:

```json
{
  "item": { "$ref": "collection:current" }
}
```

After editing the item title, the page field remains the same `$ref`, and `collectionsDraft[source][id]` receives the edited entity.

---

## 21. Glossary

**Collection source**  
The stable key for a collection, e.g. `books` or `libri`.

**Collection document**  
The keyed JSON object containing all entities for a source.

**Entity**  
One item inside a collection document.

**Collection schema**  
The Zod/schema-like parser for the full collection document.

**Entity schema**  
The Zod/schema-like parser for one collection item.

**CollectionRegistry**  
Tenant aggregate that maps source keys to collection schemas.

**collection:current**  
Reserved `$ref` target that resolves to the active entity for a dynamic route.

**collectionsDraft**  
Studio's mutable copy of collection documents during editing.

**Authored ref**  
The original `$ref` object stored in page JSON. Studio must preserve it during collection-bound edits.
