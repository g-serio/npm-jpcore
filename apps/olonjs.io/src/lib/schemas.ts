import { EmptyTenantSchema } from '@/components/empty-tenant';
import { FooterSchema } from '@/components/footer';
import { FormDemoSchema, FormDemoSubmissionSchema } from '@/components/form-demo';
import { HeaderSchema } from '@/components/header';
import { PremiumCtaSchema } from '@/components/premium-cta';
import { PremiumHeroSchema } from '@/components/premium-hero';
import { ScrollAccordionSchema } from '@/components/scroll-accordion';
import { StickySectionSchema } from '@/components/sticky-section';
import { Content7Schema } from '@/components/content-7';
import { CodeBlockSchema } from '@/components/code-block';

export const SECTION_SCHEMAS = {
  'empty-tenant': EmptyTenantSchema,
  'form-demo': FormDemoSchema,
  header: HeaderSchema,
  footer: FooterSchema,
  'premium-hero': PremiumHeroSchema,
  'premium-cta': PremiumCtaSchema,
  'sticky-section': StickySectionSchema,
  'scroll-accordion': ScrollAccordionSchema,
  'content-7': Content7Schema,
  'code-block': CodeBlockSchema,
} as const;

export const SECTION_SUBMISSION_SCHEMAS = {
  'form-demo': FormDemoSubmissionSchema,
} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core';
