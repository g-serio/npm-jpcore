import { BookDetailSchema } from '@/components/book-detail';
import { BooksListSchema } from '@/components/books-list';
import { EmptyTenantSchema } from '@/components/empty-tenant';
import { FooterSchema } from '@/components/footer';
import { FormDemoSchema, FormDemoSubmissionSchema } from '@/components/form-demo';

export const SECTION_SCHEMAS = {
  'book-detail': BookDetailSchema,
  'books-list': BooksListSchema,
  'empty-tenant': EmptyTenantSchema,
  footer: FooterSchema,
  'form-demo': FormDemoSchema,
} as const;

/**
 * Registry of per-section-type submission schemas. Keys MUST match a key of
 * SECTION_SCHEMAS. A section type appearing here is declaring itself as
 * MCP-submittable: the Zod schema describes the payload accepted by the form.
 *
 * See ADR-0002 (docs/decisions/ADR-0002-form-submission-schemas.md).
 */
export const SECTION_SUBMISSION_SCHEMAS = {
  'form-demo': FormDemoSubmissionSchema,
} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseCollectionItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core';
