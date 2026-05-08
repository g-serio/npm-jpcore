import { z } from 'zod';
import { BaseArrayItem, BaseSectionData, ImageSelectionSchema } from '@olonjs/core';

export const Content7ReadLinkSchema = z.object({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
});

export const Content7TileVariantSchema = z
  .enum(['elevated', 'surface'])
  .default('elevated')
  .describe('ui:select');

export const Content7CardSchema = BaseArrayItem.extend({
  image: ImageSelectionSchema,
  tileVariant: Content7TileVariantSchema,
  eyebrow: z.string().describe('ui:text'),
  copyLead: z.string().describe('ui:text'),
  copyEmphasis: z.string().describe('ui:text'),
  copyTrail: z.string().describe('ui:text'),
  readLink: Content7ReadLinkSchema,
});

export const Content7SettingsSchema = z.object({});

export const Content7Schema = BaseSectionData.extend({
  eyebrow: z.string().optional().describe('ui:text'),
  headingLead: z.string().describe('ui:text'),
  headingEmphasis: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  cards: z.array(Content7CardSchema).describe('ui:list'),
});
