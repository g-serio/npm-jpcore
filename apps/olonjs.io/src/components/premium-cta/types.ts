import { z } from 'zod';
import { PremiumCtaSchema, PremiumCtaSettingsSchema } from './schema';

export type PremiumCtaData = z.infer<typeof PremiumCtaSchema>;
export type PremiumCtaSettings = z.infer<typeof PremiumCtaSettingsSchema>;
