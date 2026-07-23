import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';
import { AutoreSchema } from '@/collections/autori';

const CollectionRefSchema = z.object({
  $ref: z.string(),
});

export const LibroSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  author: z.union([AutoreSchema, CollectionRefSchema]).describe('ui:collection-ref:autori'),
  year: z.number().describe('ui:number'),
  genre: z.string().describe('ui:text'),
  summary: z.string().describe('ui:textarea'),
});

export const LibriCollectionSchema = z.record(z.string(), LibroSchema);
