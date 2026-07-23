import { z } from 'zod';
import { BooksListSchema, BooksListSettingsSchema } from './schema';

export type BooksListData = z.infer<typeof BooksListSchema>;
export type BooksListSettings = z.infer<typeof BooksListSettingsSchema>;
