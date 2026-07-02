## 8. Base Section Data & Settings (BSDS) v1.1

**Objective:** Standardize base schema fragments for anchors, array items, and section settings.

### 8.1 BaseSectionData

Every section data schema must extend a base with at least:

- `anchorId?: string`

Canonical Zod:

```typescript
export const BaseSectionData = z.object({
  anchorId: z.string().optional().describe('ui:text'),
});
```

### 8.2 BaseArrayItem

Every array item schema editable in the Inspector must include:

- `id?: string`

Canonical Zod:

```typescript
export const BaseArrayItem = z.object({
  id: z.string().optional(),
});
```

Recommended: generate stable UUIDs for newly created items.

### 8.3 BaseSectionSettings

Common section-level settings may be defined once and extended by capsules.

Canonical example:

```typescript
export const BaseSectionSettingsSchema = z.object({
  paddingTop: z.enum(['none', 'sm', 'md', 'lg', 'xl', '2xl']).default('md').describe('ui:select'),
  paddingBottom: z.enum(['none', 'sm', 'md', 'lg', 'xl', '2xl']).default('md').describe('ui:select'),
  theme: z.enum(['dark', 'light', 'accent']).default('dark').describe('ui:select'),
  container: z.enum(['boxed', 'fluid']).default('boxed').describe('ui:select'),
});
```

**Why it matters:** Shared base fragments keep capsules aligned and make validation, add-section defaults, and Inspector behavior deterministic.

---