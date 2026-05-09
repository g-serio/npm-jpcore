import type { EmptyTenantData, EmptyTenantSettings } from '@/components/empty-tenant';
import type { FormDemoData, FormDemoSettings } from '@/components/form-demo';

export type SectionComponentPropsMap = {
  'empty-tenant': { data: EmptyTenantData; settings?: EmptyTenantSettings };
  'form-demo': { data: FormDemoData; settings?: FormDemoSettings };
};

// MTRP module augmentation. TypeScript treats `@olonjs/core` and
// `@olonjs/core/runtime` as separate module identifiers (different
// import specifiers). After ADR-0009 the tenant imports JsonPagesConfig
// from `/runtime` for the visitor path, so the section registries must
// be augmented for *both* identifiers, otherwise PageConfig.sections
// resolves to a generic FallbackSection on the runtime side.
declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    'empty-tenant': EmptyTenantData;
    'form-demo': FormDemoData;
  }
  export interface SectionSettingsRegistry {
    'empty-tenant': EmptyTenantSettings;
    'form-demo': FormDemoSettings;
  }
}

declare module '@olonjs/core/runtime' {
  export interface SectionDataRegistry {
    'empty-tenant': EmptyTenantData;
    'form-demo': FormDemoData;
  }
  export interface SectionSettingsRegistry {
    'empty-tenant': EmptyTenantSettings;
    'form-demo': FormDemoSettings;
  }
}

// ADR-0009 D7: tenant types re-export from the runtime subpath, NOT the
// full @olonjs/core. This is a value re-export — even though every
// consumer in this codebase only does `import type`, Vite's static
// graph treats `export *` as a runtime dependency edge. Pointing it at
// '@olonjs/core' would pull the full Studio bundle (AdminSidebar,
// FormFactory, StudioStage, admin-skin) into the visitor main chunk.
// Pointing it at '@olonjs/core/runtime' anchors the graph to the
// runtime-only bundle (~28 KB gz) so the visitor entry stays clean.
export * from '@olonjs/core/runtime';
