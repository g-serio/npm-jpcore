import { LibriCollectionSchema } from '@/collections/libri';

export const CollectionRegistry = {
  libri: LibriCollectionSchema,
} as const;

export type CollectionType = keyof typeof CollectionRegistry;
