import { z } from 'zod';
import { BaseArrayItem, BaseSectionData, CtaSchema, ImageSelectionSchema } from '@olonjs/core/runtime';

export const PremiumHeroAvatarSchema = BaseArrayItem.extend({
  initials: z.string().describe('ui:text'),
  preset: z
    .enum(['amber', 'emerald', 'blue', 'rose', 'violet'])
    .default('amber')
    .describe('ui:select'),
});

export const PremiumHeroSettingsSchema = z.object({});

export const PremiumHeroSchema = BaseSectionData.extend({
  /** Full-bleed background; blended with section base color using `soft-light`. */
  backgroundImage: ImageSelectionSchema.optional(),
  badgeText: z.string().describe('ui:text'),
  primaryTitle: z.string().describe('ui:text'),
  secondaryTitle: z.string().describe('ui:text'),
  subtitle: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema,
  secondaryCta: CtaSchema,
  socialProofPrefix: z.string().describe('ui:text'),
  socialProofCount: z.string().describe('ui:text'),
  avatars: z.array(PremiumHeroAvatarSchema).describe('ui:list'),
});
