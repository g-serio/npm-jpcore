import { z } from 'zod';
import { StickySectionSchema, StickySectionSettingsSchema } from './schema';

export type StickySectionData = z.infer<typeof StickySectionSchema>;
export type StickySectionSettings = z.infer<typeof StickySectionSettingsSchema>;
