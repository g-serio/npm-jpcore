# Spec: Core Resolved Collection Item Contract (v1)

## Assumptions I'm Making
1. Scope is only `packages/core` (no direct behavior changes in platform API handlers in this spec).
2. We want strict behavior: no backward-compat fallback for legacy "naked object" resolved collection items.
3. Dynamic template pages (for example `post/[slug]`) must remain structurally safe during inspector-driven edits.
4. The collection identity contract is exactly `{ source, id }` (no `mode`, no `key`).
5. We keep authored persistence clean: wrapper metadata must not be written into final authored page JSON.

## Objective
Introduce an explicit runtime contract for already-resolved collection items in Core Inspector and orchestration flows, so collection edits are deterministic and identity-safe.

User goal:
- Edit collection-backed content as collection entities (not ambiguous duplicated blobs inside section `data`).
- Keep template page identity safe while still editing section content freely.

Success means:
- Runtime resolved items carry explicit identity (`source` + `id`).
- Writeback updates the correct collection document entry deterministically.
- No wrapper leakage into persisted authored JSON.
- No legacy fallback path.

## Tech Stack
- Monorepo: `npm-jpcore`
- Target package: `packages/core` (`@olonjs/core`)
- Language: TypeScript (strict)
- Runtime/build: Vite 6, React 19
- Tests: Vitest 3

## Commands
- Build core: `npm run build -w @olonjs/core`
- Core tests: `npm test -w @olonjs/core`
- Core boundary checks: `npm run test:boundary -w @olonjs/core`
- Full core checks: `npm run test:all -w @olonjs/core`

## Project Structure
- `packages/core/src/contract/kernel.ts` -> canonical core contract types
- `packages/core/src/contract/config-resolver.ts` -> resolve/ref/writeback logic for collections/menu
- `packages/core/src/studio/admin/FormFactory.tsx` -> schema-driven inspector editing
- `packages/core/src/runtime/engine/StudioRoute.tsx` -> studio orchestration, draft flows, save entry
- `packages/core/src/webmcp/runtime/webmcp-bridge.ts` -> MCP mutation routing in core runtime

## Code Style
Use explicit, named, structural types and narrow guards around runtime objects.

```ts
export type ResolvedCollectionItem<T = Record<string, unknown>> = {
  _collection: {
    source: string;
    id: string;
  };
  value: T;
};
```

Conventions:
- Keep contracts in `contract/*` as source of truth.
- Explicit runtime guards before writeback.
- No tenant-specific section logic in core.

## Testing Strategy
- Unit tests in core resolver/form modules.
- Primary focus:
  - resolve path emits wrapper shape for collection-backed resolved items.
  - writeback path requires wrapper and updates the correct `collectionsDraft[source][id]`.
  - authored persistence strips wrapper metadata from final page payload.
  - strict reject behavior when wrapper is missing on collection-resolved inputs.
- Run `npm run test:all -w @olonjs/core` before merge.

## Boundaries
- Always:
  - Keep implementation strictly in `packages/core`.
  - Preserve authored JSON cleanliness (no wrapper persistence).
  - Enforce strict wrapper requirement on collection-resolved runtime edits.
- Ask first:
  - Any public export changes in `packages/core/src/index.ts`.
  - Any contract shape changes beyond `{ source, id, value }`.
  - Any changes affecting tenant-facing schema authoring conventions.
- Never:
  - Add fallback compatibility path for legacy naked-object resolved items.
  - Add tenant-specific branching in core resolver/editor logic.
  - Persist `_collection` wrapper metadata in authored page JSON.

## Proposed Contract
Runtime-only wrapper for resolved collection items:

```ts
type ResolvedCollectionItem<T = Record<string, unknown>> = {
  _collection: {
    source: string;
    id: string;
  };
  value: T;
};
```

Rules:
1. Wrapper is mandatory for collection-resolved runtime edits.
2. `source + id` is canonical identity.
3. Inspector edits `value`, never identity fields.
4. Writeback targets `collectionsDraft[source][id]`.
5. Final authored page payload remains ref-based and wrapper-free.

## Implementation Plan (High Level)
1. Add contract type and guards in `kernel.ts`.
2. Extend resolver/writeback in `config-resolver.ts`:
   - emit wrapper for resolved collection items
   - consume wrapper on writeback
   - strip wrapper before authored persistence
3. Update `FormFactory.tsx` to edit wrapped `value` for collection-resolved fields.
4. Validate orchestration pass-through in `StudioRoute.tsx`.
5. Update WebMCP mutation path handling in `webmcp-bridge.ts` for wrapper-aware updates.
6. Add/adjust tests and run `test:all` for `@olonjs/core`.

## Success Criteria
1. Editing a collection-backed item title from inspector updates the intended collection entry (by `source` + `id`), deterministically.
2. The same entity rendered in multiple section locations reflects consistent updated value after save.
3. Persisted authored page data does not include `_collection` wrapper.
4. Collection-resolved update payload without wrapper fails with explicit error (strict mode).
5. Core test suite (`test:all`) passes.

## Open Questions
1. Should strict rejection surface as thrown runtime error, typed `Result` error, or form-level validation state?
2. In WebMCP, should wrapper-missing errors map to a dedicated MCP code for easier operator diagnosis?
3. Do we want an explicit exported helper `isResolvedCollectionItem()` for tenant-side tooling, or keep it internal to core for now?
