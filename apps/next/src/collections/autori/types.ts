import { z } from 'zod';
import { AutoreSchema, AutoriCollectionSchema } from './schema';

export type Autore = z.infer<typeof AutoreSchema>;
export type AutoriCollection = z.infer<typeof AutoriCollectionSchema>;
