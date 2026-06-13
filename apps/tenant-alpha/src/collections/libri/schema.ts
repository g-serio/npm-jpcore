import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const LibroSchema = BaseCollectionItem.extend({
  title: z.string().describe('ui:text'),
  author: z.string().describe('ui:text'),
  year: z.number().describe('ui:number'),
  genre: z.string().describe('ui:text'),
  summary: z.string().describe('ui:textarea'),
});

export const LibriCollectionSchema = z.record(z.string(), LibroSchema);
