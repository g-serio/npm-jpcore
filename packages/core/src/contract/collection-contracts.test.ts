import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import {
  buildCollectionContractHref,
  buildCollectionContract,
  buildSiteManifest,
  assertCollectionRecordKeys,
} from './webmcp-contracts';

describe('buildCollectionContractHref', () => {
  it('returns /schemas/collections/{source}.schema.json', () => {
    expect(buildCollectionContractHref('posts')).toBe('/schemas/collections/posts.schema.json');
    expect(buildCollectionContractHref('autori')).toBe('/schemas/collections/autori.schema.json');
  });
});

describe('buildCollectionContract', () => {
  const ItemSchema = z.object({
    id: z.string(),
    name: z.string().describe('ui:text'),
  });
  const CollectionSchema = z.record(z.string(), ItemSchema);

  it('emits kind olonjs-collection-contract with recordKeyMustMatchItemId', () => {
    const contract = buildCollectionContract({ source: 'autori', schema: CollectionSchema });
    expect(contract.version).toBe('1.0.0');
    expect(contract.kind).toBe('olonjs-collection-contract');
    expect(contract.source).toBe('autori');
    expect(contract.recordKeyMustMatchItemId).toBe(true);
    expect(contract.dataHref).toBe('/collections/autori/autori.json');
    expect(contract.contractHref).toBe('/schemas/collections/autori.schema.json');
  });

  it('emits itemSchema describing a single item value', () => {
    const contract = buildCollectionContract({ source: 'autori', schema: CollectionSchema });
    expect(contract.itemSchema).toBeDefined();
    expect(contract.itemSchema.type).toBe('object');
    const props = contract.itemSchema.properties as Record<string, unknown>;
    expect(props).toHaveProperty('id');
    expect(props).toHaveProperty('name');
  });

  it('preserves ui:* descriptors from Zod .describe()', () => {
    const contract = buildCollectionContract({ source: 'autori', schema: CollectionSchema });
    const props = contract.itemSchema.properties as Record<string, Record<string, unknown>>;
    expect(props.name.description).toBe('ui:text');
  });
});

describe('assertCollectionRecordKeys', () => {
  it('passes for valid keyed object where key === item.id', () => {
    const collection = {
      'alice': { id: 'alice', name: 'Alice' },
      'bob': { id: 'bob', name: 'Bob' },
    };
    expect(() => assertCollectionRecordKeys('autori', collection)).not.toThrow();
  });

  it('throws when key !== item.id', () => {
    const collection = {
      'alice': { id: 'wrong-id', name: 'Alice' },
    };
    expect(() => assertCollectionRecordKeys('autori', collection)).toThrow(/record key "alice" must equal item.id/);
  });

  it('throws when item has no id field', () => {
    const collection = {
      'alice': { name: 'Alice' },
    };
    expect(() => assertCollectionRecordKeys('autori', collection)).toThrow(/record key "alice" must equal item.id/);
  });

  it('throws when item is not an object', () => {
    const collection = {
      'alice': 'not-an-object',
    };
    expect(() => assertCollectionRecordKeys('autori', collection as never)).toThrow(/invalid item at key "alice"/);
  });
});

describe('buildSiteManifest with collections', () => {
  const ItemSchema = z.object({ id: z.string(), name: z.string() });
  const CollectionSchema = z.record(z.string(), ItemSchema);

  const siteConfig = { identity: { title: 'Test' } } as Parameters<typeof buildSiteManifest>[0]['siteConfig'];

  it('omits collections when collectionSchemas is undefined', () => {
    const manifest = buildSiteManifest({ pages: {}, schemas: {}, siteConfig });
    expect(manifest.collections).toBeUndefined();
  });

  it('omits collections when collectionSchemas is empty', () => {
    const manifest = buildSiteManifest({ pages: {}, schemas: {}, siteConfig, collectionSchemas: {} });
    expect(manifest.collections).toBeUndefined();
  });

  it('emits collections[] sorted by source when collectionSchemas is provided', () => {
    const manifest = buildSiteManifest({
      pages: {},
      schemas: {},
      siteConfig,
      collectionSchemas: { libri: CollectionSchema, autori: CollectionSchema },
    });
    expect(manifest.collections).toHaveLength(2);
    expect(manifest.collections![0].source).toBe('autori');
    expect(manifest.collections![0].dataHref).toBe('/collections/autori/autori.json');
    expect(manifest.collections![0].contractHref).toBe('/schemas/collections/autori.schema.json');
    expect(manifest.collections![1].source).toBe('libri');
  });
});
