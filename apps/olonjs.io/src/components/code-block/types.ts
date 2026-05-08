import { z } from 'zod';
import { CodeBlockSchema, CodeBlockSettingsSchema } from './schema';

export type CodeBlockData = z.infer<typeof CodeBlockSchema>;
export type CodeBlockSettings = z.infer<typeof CodeBlockSettingsSchema>;
