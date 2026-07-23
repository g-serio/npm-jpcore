import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { AutoreSchema } from '@/collections/autori';

export const AuthorsListSchema = BaseSectionData.extend({
  eyebrow: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), AutoreSchema).describe('ui:collection-ref:autori'),
});

export const AuthorsListSettingsSchema = z.object({});
