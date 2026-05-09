import { z } from 'zod';
import { BaseArrayItem } from '@olonjs/core/runtime';

/**
 * Menu item shape for `menu.json` / shell lists (ECIP §5.3 stable `id`).
 * Plain `BaseArrayItem.extend` — not `z.lazy` — so `ui:list` works in Studio.
 */
export const MenuItemSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  icon: z.string().optional().describe('ui:text'),
  external: z.boolean().optional(),
  isCta: z.boolean().optional(),
});

export type MenuItemData = z.infer<typeof MenuItemSchema>;
