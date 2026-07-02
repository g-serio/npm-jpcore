## 9. AddSectionConfig (ASC) v1.1

**Objective:** Formalize the Add Section contract used by Studio.

Core-facing type:

```typescript
interface AddSectionConfig {
  addableSectionTypes: readonly string[];
  sectionTypeLabels: Record<string, string>;
  getDefaultSectionData(sectionType: string): Record<string, unknown>;
}
```

Required shape:

- `addableSectionTypes` lists addable section type keys
- `sectionTypeLabels` maps type keys to display labels
- `getDefaultSectionData(type)` returns valid default data for a new section

Core creates a new section with deterministic UUID, type, and default data.

**Why it matters:** ASC gives Studio a deterministic add-section library without hardcoding tenant knowledge into Core.

---
