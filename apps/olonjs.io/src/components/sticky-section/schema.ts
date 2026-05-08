import { z } from 'zod';
import { BaseArrayItem, BaseSectionData, ImageSelectionSchema } from '@olonjs/core';

export const StickySectionProjectSchema = BaseArrayItem.extend({
  name: z.string().describe('ui:text'),
  tagline: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  stars: z.string().describe('ui:text'),
  starsLabel: z.string().describe('ui:text'),
  contributors: z.string().describe('ui:text'),
  contributorsLabel: z.string().describe('ui:text'),
  exploreUrl: z.string().describe('ui:text'),
  image: ImageSelectionSchema,
  iconVariant: z.string().describe('ui:icon-picker'),
});

export const StickySectionSettingsSchema = z.object({
  /** Distance from viewport top for the sticky sidebar (fixed header clearance). */
  stickyTopPx: z.number().optional().default(90).describe('ui:number'),
});

export const StickySectionSchema = BaseSectionData.extend({
  eyebrow: z.string().optional().describe('ui:text'),
  heading: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  projects: z.array(StickySectionProjectSchema).describe('ui:list'),
});
