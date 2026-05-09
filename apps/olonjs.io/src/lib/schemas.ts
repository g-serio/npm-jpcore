// IMPORTANT: import schemas directly from ./schema sub-path, NOT from the
// component barrel (./<name>). The barrel re-exports './View' which would
// drag heavy View dependencies (Shiki, Tiptap, motion, react-scroll, etc.)
// into the main bundle that ships to every visitor — even though the Views
// themselves are lazy-loaded via ComponentRegistry.
//
// Saves ~150-200 KB raw on the main chunk per Lighthouse audit
// (unused-javascript, ~442 KB unused on 1040 KB main chunk pre-fix).
import { EmptyTenantSchema } from '@/components/empty-tenant/schema';
import { FooterSchema } from '@/components/footer/schema';
import { FormDemoSchema, FormDemoSubmissionSchema } from '@/components/form-demo/schema';
import { HeaderSchema } from '@/components/header/schema';
import { PremiumCtaSchema } from '@/components/premium-cta/schema';
import { PremiumHeroSchema } from '@/components/premium-hero/schema';
import { ScrollAccordionSchema } from '@/components/scroll-accordion/schema';
import { StickySectionSchema } from '@/components/sticky-section/schema';
import { Content7Schema } from '@/components/content-7/schema';
import { CodeBlockSchema } from '@/components/code-block/schema';

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
} from '@olonjs/core/runtime';
