import { z } from 'zod';

/**
 * Image picker field: object { url, alt? } with ui:image-picker for Form Factory.
 * Use in section data and resolve with resolveAssetUrl(url, tenantId) in View.
 */
export const ImageSelectionSchema = z
  .object({
    url: z.string(),
    alt: z.string().optional(),
  }) 
  .describe('ui:image-picker');

/**
 * Base schemas shared by section capsules (CIP governance).
 * Capsules extend these for consistent anchorId, array items, and settings.
 */
export const BaseSectionData = z.object({
  id: z.string().optional(),
  anchorId: z.string().optional().describe('ui:text'),
});

export const BaseArrayItem = z.object({
  id: z.string().optional(),
});

export const BaseCollectionItem = z.object({
  id: z.string(),
});

export const BaseSectionSettingsSchema = z.object({
  paddingTop: z.enum(['none', 'sm', 'md', 'lg', 'xl', '2xl']).default('md').describe('ui:select'),
  paddingBottom: z.enum(['none', 'sm', 'md', 'lg', 'xl', '2xl']).default('md').describe('ui:select'),
  theme: z.enum(['dark', 'light', 'accent']).default('dark').describe('ui:select'),
  container: z.enum(['boxed', 'fluid']).default('boxed').describe('ui:select'),
});

export const CtaSchema = z.object({
  id: z.string().optional(),
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  variant: z.enum(['primary', 'secondary', 'accent']).default('primary').describe('ui:select'),
});

/**
 * Mixin for any section capsule that includes a contact form.
 * Merge into the section data schema to expose recipientEmail
 * as an editable field in the Studio inspector.
 * The View must set data-olon-recipient={data.recipientEmail} on the <form>.
 */
export const WithFormRecipient = z.object({
  recipientEmail: z.string().optional().describe('ui:text'),
});
