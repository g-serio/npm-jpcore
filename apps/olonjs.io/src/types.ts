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
import type { MenuItem } from '@olonjs/core';

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

// MTRP module augmentation. Post ADR-0016, `@olonjs/core` is the sole
// module identity for SectionDataRegistry/SectionSettingsRegistry — the
// former dual augmentation against `@olonjs/core/runtime` (ADR-0009) no
// longer applies since @olonjs/react and @olonjs/studio both import
// section types from this same `@olonjs/core` module.
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

// Tenant types re-export the full `@olonjs/core` surface. Post ADR-0016 this
// is safe: `@olonjs/core` is a pure-TS package with zero React/Studio code,
// so this no longer risks pulling AdminSidebar/FormFactory/StudioStage into
// the visitor bundle the way the pre-split monolithic core did (ADR-0009 D7).
export * from '@olonjs/core';
