import type { EmptyTenantData, EmptyTenantSettings } from '@/components/empty-tenant';
import type { FooterData, FooterSettings } from '@/components/footer';
import type { FormDemoData, FormDemoSettings } from '@/components/form-demo';
import type { HeaderData, HeaderSettings } from '@/components/header';
import type { PremiumCtaData, PremiumCtaSettings } from '@/components/premium-cta';
import type { PremiumHeroData, PremiumHeroSettings } from '@/components/premium-hero';
import type { ScrollAccordionData, ScrollAccordionSettings } from '@/components/scroll-accordion';
import type { StickySectionData, StickySectionSettings } from '@/components/sticky-section';
import type { Content7Data, Content7Settings } from '@/components/content-7';
import type { CodeBlockData, CodeBlockSettings } from '@/components/code-block';
import type { MenuItem } from '@olonjs/core/runtime';

export type SectionComponentPropsMap = {
  'empty-tenant': { data: EmptyTenantData; settings?: EmptyTenantSettings };
  'form-demo': { data: FormDemoData; settings?: FormDemoSettings };
  header: { data: HeaderData; settings?: HeaderSettings; menu?: MenuItem[] };
  footer: { data: FooterData; settings?: FooterSettings };
  'premium-hero': { data: PremiumHeroData; settings?: PremiumHeroSettings };
  'premium-cta': { data: PremiumCtaData; settings?: PremiumCtaSettings };
  'sticky-section': { data: StickySectionData; settings?: StickySectionSettings };
  'scroll-accordion': { data: ScrollAccordionData; settings?: ScrollAccordionSettings };
  'content-7': { data: Content7Data; settings?: Content7Settings };
  'code-block': { data: CodeBlockData; settings?: CodeBlockSettings };
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
    header: HeaderData;
    footer: FooterData;
    'premium-hero': PremiumHeroData;
    'premium-cta': PremiumCtaData;
    'sticky-section': StickySectionData;
    'scroll-accordion': ScrollAccordionData;
    'content-7': Content7Data;
    'code-block': CodeBlockData;
  }
  export interface SectionSettingsRegistry {
    'empty-tenant': EmptyTenantSettings;
    'form-demo': FormDemoSettings;
    header: HeaderSettings;
    footer: FooterSettings;
    'premium-hero': PremiumHeroSettings;
    'premium-cta': PremiumCtaSettings;
    'sticky-section': StickySectionSettings;
    'scroll-accordion': ScrollAccordionSettings;
    'content-7': Content7Settings;
    'code-block': CodeBlockSettings;
  }
}

declare module '@olonjs/core/runtime' {
  export interface SectionDataRegistry {
    'empty-tenant': EmptyTenantData;
    'form-demo': FormDemoData;
    header: HeaderData;
    footer: FooterData;
    'premium-hero': PremiumHeroData;
    'premium-cta': PremiumCtaData;
    'sticky-section': StickySectionData;
    'scroll-accordion': ScrollAccordionData;
    'content-7': Content7Data;
    'code-block': CodeBlockData;
  }
  export interface SectionSettingsRegistry {
    'empty-tenant': EmptyTenantSettings;
    'form-demo': FormDemoSettings;
    header: HeaderSettings;
    footer: FooterSettings;
    'premium-hero': PremiumHeroSettings;
    'premium-cta': PremiumCtaSettings;
    'sticky-section': StickySectionSettings;
    'scroll-accordion': ScrollAccordionSettings;
    'content-7': Content7Settings;
    'code-block': CodeBlockSettings;
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
