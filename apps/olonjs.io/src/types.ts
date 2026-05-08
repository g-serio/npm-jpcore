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

export * from '@olonjs/core';
