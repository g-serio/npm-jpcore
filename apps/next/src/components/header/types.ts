import { z } from 'zod';
import { HeaderSchema, HeaderSettingsSchema } from './schema';

export type HeaderData = z.infer<typeof HeaderSchema>;
export type HeaderSettings = z.infer<typeof HeaderSettingsSchema>;
