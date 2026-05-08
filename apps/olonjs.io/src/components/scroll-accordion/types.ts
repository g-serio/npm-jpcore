import { z } from 'zod';
import { ScrollAccordionSchema, ScrollAccordionSettingsSchema } from './schema';

export type ScrollAccordionData = z.infer<typeof ScrollAccordionSchema>;
export type ScrollAccordionSettings = z.infer<typeof ScrollAccordionSettingsSchema>;
