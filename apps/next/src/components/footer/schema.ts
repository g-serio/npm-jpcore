import { z } from 'zod';
import { BaseArrayItem, BaseSectionData } from '@olonjs/core';

export const FooterLinkSchema = BaseArrayItem.extend({
  id: z.string(),
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  external: z.boolean().optional(),
});

export const FooterSchema = BaseSectionData.extend({
  brandText: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  copyright: z.string().describe('ui:text'),
  links: z.array(FooterLinkSchema).default([]).describe('ui:list'),
  designSystemHref: z.string().optional().describe('ui:text'),
});

export const FooterSettingsSchema = z.object({
  showLogo: z.boolean().default(true),
});
