import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const AutoreSchema = BaseCollectionItem.extend({
  name: z.string().describe('ui:text'),
});

export const AutoriCollectionSchema = z.record(z.string(), AutoreSchema);
