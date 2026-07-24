import { z } from 'zod';
import { LibroSchema, LibriCollectionSchema } from './schema';

export type Libro = z.infer<typeof LibroSchema>;
export type LibriCollection = z.infer<typeof LibriCollectionSchema>;
