## 5. Editor Component Implementation Protocol (ECIP) v1.6

**Objective:** Standardize the schema-driven editing contract used by Studio tooling.

### 5.1 Recursive Form Factory

The Admin UI builds forms by traversing the Zod ontology rather than hardcoding per-type editor implementations.

### 5.2 UI Metadata

Schema descriptions may encode UI metadata using `.describe('ui:...')`.
This is the contract by which the Form Factory chooses widgets.

### 5.3 Deterministic IDs

Every object in an editable `ZodArray` must extend `BaseArrayItem` or otherwise include stable `id`.
This guarantees React reconciliation stability during reorder/delete flows.

### 5.4 UI Metadata Vocabulary

Standard keys for the Form Factory are:

| Key | Use case |
|-----|----------|
| `ui:text` | Single-line text input |
| `ui:textarea` | Multi-line text |
| `ui:select` | Enum or single choice |
| `ui:number` | Numeric input |
| `ui:list` | Array editor with add/remove/reorder |
| `ui:icon-picker` | Icon selection via tenant-registered icon registry |

Unknown keys may be treated as `ui:text`.

#### `ui:icon-picker` — Tenant Icon Registry Contract

The icon picker is **empty by default**. Core does not ship any hardcoded icons.

The tenant must pass an `iconRegistry` in `JsonPagesConfig` at bootstrap:

```typescript
// App.tsx
const config: JsonPagesConfig = {
  // ...
  iconRegistry: iconMap, // Record<string, LucideIcon> from tenant IconResolver
};
```

Core provides `iconRegistry` via `IconRegistryContext`. The Form Factory reads this context and renders only the tenant-registered icons in the picker dialog.

**Tenant responsibility:** declare all usable icons in `src/lib/IconResolver.tsx` and export `iconMap`. Pass it to `JsonPagesConfig.iconRegistry`. If `iconRegistry` is empty or not provided, the picker renders no options.

### 5.5 Path-Only Nested Selection & Expansion

In strict nested editing behavior, nested targets are represented by path segments from root to leaf:

```typescript
export type SelectionPathSegment = { fieldKey: string; itemId?: string };
export type SelectionPath = SelectionPathSegment[];
```

Rules:

- expansion and focus for nested arrays must be computed from `SelectionPath`
- matching by `fieldKey` alone is non-compliant for nested structures
- legacy flat payload fields such as `itemField` and `itemId` are not the normative nested protocol

**Why it matters:** ECIP keeps the editor machine-discoverable and prevents nested arrays from opening the wrong branch or mutating the wrong node.

---