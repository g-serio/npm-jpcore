import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { LibroSchema } from '@/collections/libri';



export const BooksListSchema = BaseSectionData.extend({
  eyebrow: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), LibroSchema).describe('ui:collection-ref:libri'),
  pageSize: z.number().default(10).describe('ui:number'),
});

export const BooksListSettingsSchema = z.object({});