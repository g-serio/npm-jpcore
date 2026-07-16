import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';

export const PremiumCtaSettingsSchema = z.object({});

export const PremiumCtaSchema = BaseSectionData.extend({
  headingLight: z.string().describe('ui:text'),
  headingBold: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema,
  secondaryCta: CtaSchema,
  /** Short line under avatar stack (desktop social proof). */
  socialProofLine: z.string().describe('ui:text'),
  /** Bold stat next to avatars (e.g. "10k+"). */
  socialProofHighlight: z.string().default('10k+').describe('ui:text'),
});
