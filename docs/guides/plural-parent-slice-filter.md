# Plural-parent slice filters

Tenant-side guide for **multi-value collection relations** and archive filtering via SPP.

This is a **protocol feature** (not tenant-specific). Full agnostic documentation:

`jsonpages-platform/docs/guides/plural-parent-slice-filter.md`

(when both repos are checked out, path is relative to your platform clone)

## Contract (one paragraph)

Store multiple related entities as a **keyed record** (`field: { [id]: Entity | $ref }`). Filter archives with a **plural-parent path** (`field.leaf`, e.g. `categories.slug`). The platform returns documents where **any** child matches. Single-relation fields keep **scalar** paths (`category.slug`). Render `$sliceFilter` and `GET /collections` must use the same resolved filter literals.

## Tenant touchpoints in OlonJS

| Area | What to change |
|------|----------------|
| Collection `schema.ts` | `z.record` for the plural relation field |
| `src/data/collections/...` | Migrate documents to record shape |
| `src/data/pages/...` | `$sliceFilter` plural-parent keys |
| Section `View.tsx` | `useCollectionSlice` filter literals aligned with page JSON |
| `lib/*` display helpers | any-of matching and counts over record values |

See the platform guide for shapes, anti-patterns, and verification steps.
