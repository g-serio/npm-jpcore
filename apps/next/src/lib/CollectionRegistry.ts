import { AutoriCollectionSchema } from '@/collections/autori';
import { LibriCollectionSchema } from '@/collections/libri';

export const CollectionRegistry = {
  autori: AutoriCollectionSchema,
  libri: LibriCollectionSchema,
} as const;

export type CollectionType = keyof typeof CollectionRegistry;
