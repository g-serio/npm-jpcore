import { z } from 'zod';
import { AuthorsListSchema, AuthorsListSettingsSchema } from './schema';

export type AuthorsListData = z.infer<typeof AuthorsListSchema>;
export type AuthorsListSettings = z.infer<typeof AuthorsListSettingsSchema>;
