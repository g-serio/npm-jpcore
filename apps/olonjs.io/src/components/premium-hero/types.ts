import { z } from 'zod';
import { PremiumHeroSchema, PremiumHeroSettingsSchema } from './schema';

export type PremiumHeroData = z.infer<typeof PremiumHeroSchema>;
export type PremiumHeroSettings = z.infer<typeof PremiumHeroSettingsSchema>;
