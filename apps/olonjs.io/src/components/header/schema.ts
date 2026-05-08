import { z } from 'zod';
import { BaseSectionData, CtaSchema, ImageSelectionSchema } from '@olonjs/core';
import { MenuItemSchema } from '@/lib/menu-item-schema';

/**
 * OlonJS v1.6 — JSP §2.5 Resolved Editing Surface Rule:
 * this schema describes the **resolved** Inspector/runtime surface. Authored `site.json` keeps
 * `data.menu.$ref` → `menu.json`; the engine resolves for the Form Factory and persists edits to `menu.json`.
 */
export const HeaderSettingsSchema = z.object({
  sticky: z.boolean().default(false),
});

export const HeaderSchema = BaseSectionData.extend({
  logoMark: ImageSelectionSchema.optional(),
  brandText: z.string().describe('ui:text'),
  signIn: CtaSchema.optional(),
  primaryCta: CtaSchema,
  menu: z.array(MenuItemSchema).describe('ui:list').optional(),
});
