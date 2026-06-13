## 11. Collection Protocol (COP) v1.0

**Objective:** Define the architecture for structured entity collections — products, posts, recipes, and any other domain-specific data sets — that exist independently of pages and are consumed by capsules as bound external references.

---

### 11.1 Motivation

The existing JSP/TBP architecture assumes a direct ownership relationship between a page document and its section data. This model is sufficient for editorial content where the data *is* the page.

Collections invert this relationship. A collection is a set of typed entities that:

- exist independently of any page
- may be consumed by multiple capsules across multiple pages
- are not owned by the capsule that renders them
- require their own schema contract separate from any consuming section

This distinction is architectural, not incidental. A `ProductGrid` capsule does not own the shape of a `Product`. It consumes it.

---

### 11.2 The Dual Topology Rule

Collections maintain a strict separation between data and contract, consistent with the existing JSP file system ontology.

**Data lives under `src/data/`:**

```
src/data/collections/{slug}/
└── {slug}.json
```

**Contract lives under `src/collections/`:**

```
src/collections/{slug}/
├── schema.ts
├── types.ts
└── index.ts
```

This mirrors the existing separation between `src/data/pages/` (data) and `src/components/` (contract), and must not be collapsed.

---

### 11.3 Collection Document Shape

A collection document is a JSON object whose keys are entity identifiers and whose values are entity instances.

It is explicitly **not** a JSON array.

```json
{
  "espresso": {
    "id": "espresso",
    "name": "Espresso",
    "price": "3.50",
    "category": "coffee"
  },
  "cappuccino": {
    "id": "cappuccino",
    "name": "Cappuccino",
    "price": "4.50",
    "category": "coffee"
  }
}
```

Using a keyed object rather than an array provides:

- O(1) lookup by identifier without scanning
- stable keys for `$ref` fragment addressing
- natural alignment with the `refDocuments` resolution model already defined in JEB §10.3

---

### 11.4 Collection Contract Structure

Each collection under `src/collections/{slug}/` exports exactly three artefacts.

**`schema.ts`** — the Zod schema for a single entity:

```typescript
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core/kernel';

export const ProductSchema = BaseCollectionItem.extend({
  name:        z.string().describe('ui:text'),
  price:       z.string().describe('ui:text'),
  category:    z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  image:       ImageSelectionSchema.optional(),
});

export const ProductsCollectionSchema = z.record(z.string(), ProductSchema);
```

Two schemas are always present:
- the **entity schema** for a single item
- the **collection schema** (`z.record`) for the full document

**`types.ts`** — types derived from schema:

```typescript
import { z } from 'zod';
import { ProductSchema, ProductsCollectionSchema } from './schema';

export type Product = z.infer<typeof ProductSchema>;
export type ProductsCollection = z.infer<typeof ProductsCollectionSchema>;
```

**`index.ts`** — public barrel export:

```typescript
export { ProductSchema, ProductsCollectionSchema } from './schema';
export type { Product, ProductsCollection } from './types';
```

No `View.tsx` exists in a collection. Collections do not render. Rendering is the exclusive responsibility of the capsules that consume them.

---

### 11.5 BaseCollectionItem

Every collection entity schema must extend `BaseCollectionItem`, provided by `@olonjs/core/kernel`.

`BaseCollectionItem` is a distinct base from `BaseSectionData` and `BaseArrayItem`. It is not interchangeable with either.

Canonical Zod:

```typescript
export const BaseCollectionItem = z.object({
  id: z.string(),
});
```

`id` is required and non-optional in collection entities. It serves as the stable key for `$ref` fragment addressing, registry lookup, and dynamic route resolution.

---

### 11.6 CollectionRegistry

Collections are registered in a single aggregate at `src/lib/CollectionRegistry.ts`, analogous to `SECTION_SCHEMAS` for sections.

```typescript
import { ProductsCollectionSchema } from '@/collections/products';
import { PostsCollectionSchema }    from '@/collections/posts';

export const CollectionRegistry = {
  products: ProductsCollectionSchema,
  posts:    PostsCollectionSchema,
} as const;

export type CollectionType = keyof typeof CollectionRegistry;
```

The engine uses `CollectionRegistry` to:

- validate a collection document at the Core resolver boundary, before any `$ref` resolution
- expose collection schemas to the Form Factory for editing
- resolve `CollectionType` keys in page and site bindings

Every active `collections[source]` entry must have a matching
`collectionSchemas[source]` entry. A missing schema is a contract error, not an
implicit opt-out.

---

### 11.7 Binding Rule

A capsule that consumes a collection binds to it via `$ref` in the page section data, following the Bound External Field Rule established in JSP §2.5.

Example page section:

```json
{
  "type": "product-grid",
  "data": {
    "title": "Our Menu",
    "items": { "$ref": "../collections/products/products.json" }
  }
}
```

Canonical consequences:

- the page document keeps the binding expression
- `products.json` remains the owner of the collection data
- the engine resolves the `$ref` before passing props to the capsule
- the capsule `View.tsx` receives concrete typed entities, not a `$ref` object
- Studio must persist entity edits into `products.json`, not into the page document

---

### 11.8 Capsule Consumption Contract

A capsule that consumes a collection imports entity types from `src/collections/{slug}`, not from its own `schema.ts`.

The capsule `schema.ts` describes only the editorial fields the section owns. The collection binding field is typed as the resolved entity array or map.

```typescript
// src/components/product-grid/schema.ts
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core/runtime';

export const ProductGridSchema = BaseSectionData.extend({
  title:       z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  // items is a binding field — shape owned by the collection schema
  items:       z.array(z.any()).describe('ui:collection-ref'),
});
```

```typescript
// src/components/product-grid/types.ts
import { z } from 'zod';
import { ProductGridSchema } from './schema';
import type { Product } from '@/collections/products';

export type ProductGridData = Omit<z.infer<typeof ProductGridSchema>, 'items'> & {
  items: Product[];
};
```

The resolved `items` prop received by `View.tsx` is `Product[]`. The capsule never imports `ProductSchema` directly into its own schema definition.

---

### 11.9 Dynamic Route Binding

When a collection requires individual entity pages (`/products/espresso`), the page document uses a route template declaration.

This extends the JSP `PageConfig` with an optional `collection` binding:

```typescript
export interface PageConfig {
  id?:        string;
  slug:       string;
  meta?:      { title?: string; description?: string };
  sections:   Section[];
  collection?: {
    source: string;          // CollectionType key, e.g. "products"
    paramKey: string;        // URL segment name, e.g. "slug"
  };
}
```

Example `pages/product-detail.json`:

```json
{
  "slug": "products/[slug]",
  "collection": {
    "source": "products",
    "paramKey": "slug"
  },
  "sections": [
    {
      "type": "product-detail",
      "data": {
        "item": { "$ref": "collection:current" }
      }
    }
  ]
}
```

`collection:current` is a reserved `$ref` scheme resolved by the engine to the entity whose `id` matches the active URL parameter.

The engine:

1. matches the URL segment to an entity `id` in the registered collection
2. resolves `collection:current` to that entity
3. passes the resolved entity as props to the consuming capsule

---

### 11.10 JEB Integration

`JsonPagesConfig` is extended with `collections` and `collectionSchemas` fields:

```typescript
export interface JsonPagesConfig {
  // ... existing fields ...
  collections?: Record<string, unknown>;
  collectionSchemas?: Record<string, { parse(value: unknown): unknown }>;
}
```

`collections` provides the resolved collection documents at bootstrap, analogous to `refDocuments`. `collectionSchemas` provides the matching collection document schemas, keyed by the same source names.

The Core resolver validates each `collections[source]` entry against `collectionSchemas[source]` before registering that collection as a document available to `$ref` resolution. The parsed schema output is the document that enters the resolver.

Validation is fail-fast:

- if a collection is present without a matching schema, resolution fails with an explicit error naming the source
- if a collection does not satisfy its schema, resolution fails with an explicit error naming the source
- Core must not silently skip invalid collections
- Core must not fall back to unresolved `$ref` behavior for invalid collection data
- Core must not downgrade invalid collection data to warning-only behavior

Resolution precedence follows JEB §10.3: active mutable drafts from Studio take precedence over bootstrap inputs.

Studio and WebMCP mutations that update a collection-bound field must validate the resulting collection draft against the same `collectionSchemas[source]` before accepting the draft or saving it. Invalid edits are rejected; the page document must keep the authored `$ref` binding and the invalid collection state must not become the persisted source of truth.

---

### 11.11 Compliance Checklist

When generating or auditing a tenant with collections, ensure:

1. each collection has a data document under `src/data/collections/{slug}/{slug}.json`
2. each collection has a contract under `src/collections/{slug}/` with `schema.ts`, `types.ts`, and `index.ts`
3. every entity schema extends `BaseCollectionItem` with a required `id`
4. both an entity schema and a collection schema (`z.record`) are exported
5. `CollectionRegistry` registers every active collection
6. every active `collections[source]` has a matching `collectionSchemas[source]`
7. invalid or schema-less collection documents fail before `$ref` resolution
8. capsule `schema.ts` files do not import or inline collection entity schemas
9. capsule `types.ts` imports entity types from `src/collections/{slug}`
10. binding fields in page documents use `$ref` rather than inlined entity data
11. Studio persists entity edits into the collection document, not the page document
12. Studio and WebMCP reject edits that make the collection document invalid
13. dynamic route pages declare a `collection` binding in `PageConfig`

---

### 11.12 Architectural Boundaries

| Concern | Owner |
|---|---|
| Entity shape contract | `src/collections/{slug}/schema.ts` |
| Entity instances | `src/data/collections/{slug}/{slug}.json` |
| Collection validation at resolution | `CollectionRegistry` |
| Rendering of collection entities | Consuming capsule `View.tsx` |
| Persistence of entity edits | Collection document via Studio |
| Route resolution for entity pages | Engine via `PageConfig.collection` |

The capsule that renders a collection entity is a read-only consumer of the collection contract. It must not become the semantic authority for entity shape.

**Why it matters:** COP makes catalogs, blogs, menus, and any other entity-driven content first-class citizens of the OlonJS architecture without violating the source-of-truth separation, the binding contract, or the capsule composition model already established in v1.6.
