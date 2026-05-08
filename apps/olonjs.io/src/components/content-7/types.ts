import { z } from 'zod';
import { Content7Schema, Content7SettingsSchema } from './schema';

export type Content7Data = z.infer<typeof Content7Schema>;
export type Content7Settings = z.infer<typeof Content7SettingsSchema>;
