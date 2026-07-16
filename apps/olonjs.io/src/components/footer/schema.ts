import { z } from 'zod';
import { BaseArrayItem, BaseSectionData, ImageSelectionSchema } from '@olonjs/core';
import { MenuItemSchema } from '@/lib/menu-item-schema';

const FooterLinkItem = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
});

export const FooterColumnItemSchema = BaseArrayItem.extend({
  title: z.string().describe('ui:text'),
  links: z.array(FooterLinkItem).describe('ui:list'),
});

export const FooterSocialItemSchema = MenuItemSchema.extend({
  icon: z.enum(['github', 'x', 'discord']).default('github').describe('ui:select'),
});

export const FooterSettingsSchema = z.object({});

export const FooterSchema = BaseSectionData.extend({
  brandText: z.string().describe('ui:text'),
  taglinePrimary: z.string().describe('ui:text'),
  taglineSecondary: z.string().describe('ui:text'),
  logoMark: ImageSelectionSchema.optional(),
  columns: z.array(FooterColumnItemSchema).describe('ui:list'),
  /** Resolved from `menu.json` via `data.socialLinks.$ref` in authored `site.json` (JSP §2.5). */
  socialLinks: z.array(FooterSocialItemSchema).describe('ui:list'),
  /** Resolved from `menu.json` via `data.legalLinks.$ref` in authored `site.json` (JSP §2.5). */
  legalLinks: z.array(MenuItemSchema).describe('ui:list'),
  copyrightSuffix: z.string().describe('ui:text'),
  copyrightYear: z.number().optional().describe('ui:number'),
});
