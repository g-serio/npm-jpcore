import { z } from 'zod';
import { BaseArrayItem, BaseSectionData, CtaSchema, ImageSelectionSchema } from '@olonjs/core';

export const ScrollAccordionItemSchema = BaseArrayItem.extend({
  number: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  icon: ImageSelectionSchema.optional(),
  description: z.string().describe('ui:textarea'),
  cta: CtaSchema,
});

export const ScrollAccordionSettingsSchema = z.object({});

export const ScrollAccordionSchema = BaseSectionData.extend({
  eyebrow: z.string().optional().describe('ui:text'),
  heading: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.array(ScrollAccordionItemSchema).describe('ui:list'),
});
