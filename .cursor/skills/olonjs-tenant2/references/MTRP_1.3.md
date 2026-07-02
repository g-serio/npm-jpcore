
## 1. Modular Type Registry Pattern (MTRP) v1.3

**Objective:** Establish a strictly typed, open-ended protocol for extending content data structures where the Core engine is the orchestrator and the Tenant is the provider.

### 1.1 The Sovereign Dependency Inversion

The Core defines empty registries.
Tenant injects concrete definitions using module augmentation.

This allows Core to be distributed as a compiled NPM package while remaining aware of tenant-specific types at compile time.

### 1.2 Technical Implementation (`@olonjs/core/kernel`)

```typescript
export interface SectionDataRegistry {} // Augmented by Tenant
export interface SectionSettingsRegistry {} // Augmented by Tenant

export interface BaseSection<K extends keyof SectionDataRegistry> {
  id: string;
  type: K;
  data: SectionDataRegistry[K];
  settings?: K extends keyof SectionSettingsRegistry
    ? SectionSettingsRegistry[K]
    : BaseSectionSettings;
}

export type Section = {
  [K in keyof SectionDataRegistry]: BaseSection<K>
}[keyof SectionDataRegistry];
```

Core exports or allows the tenant to infer `SectionType` as `keyof SectionDataRegistry`.
After tenant augmentation this becomes the union of all supported section keys.

### 1.3 Architectural Rule

Core must remain open to tenant augmentation.
Tenant-specific section types must not require Core source edits.

**Why it matters:** MTRP is the foundation that allows one Core engine to serve many tenants while preserving end-to-end type safety.

---
