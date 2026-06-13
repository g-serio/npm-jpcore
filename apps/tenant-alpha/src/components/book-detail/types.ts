import { z } from 'zod';
import { BookDetailSchema, BookDetailSettingsSchema } from './schema';

export type BookDetailData = z.infer<typeof BookDetailSchema>;
export type BookDetailSettings = z.infer<typeof BookDetailSettingsSchema>;
