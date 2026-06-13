import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { LibroSchema } from '@/collections/libri';

export const BookDetailSchema = BaseSectionData.extend({
  item: LibroSchema.describe('ui:collection-ref'),
  backLabel: z.string().default('Torna ai libri').describe('ui:text'),
});

export const BookDetailSettingsSchema = z.object({});
