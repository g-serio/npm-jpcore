#!/bin/bash
set -e # Termina se c'è un errore

echo "Inizio ricostruzione progetto..."

mkdir -p "core/src/"
mkdir -p "core/src/contract"
echo "Creating core/src/contract/config-resolver.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/contract/config-resolver.test.ts"
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import {
  applyCollectionRefBindingsToDraft,
  applyMenuRefBindingsToDraft,
  applySiteMenuRefBindingsToDraft,
  getMenuRefBindings,
  resolveCollectionContext,
  resolveSectionMenuItems,
  resolveRuntimeConfig,
  validateCollectionDocuments,
} from './config-resolver';
import type { MenuConfig, Section, SiteConfig, ThemeConfig } from './kernel';

const themeConfig: ThemeConfig = {
  name: 'test',
  tokens: {
    colors: {},
    typography: { fontFamily: {} },
    borderRadius: {},
  },
};

describe('config-resolver menu refs', () => {
  it('resolves footer menu fields from menu.json like any other section data ref', () => {
    const siteConfig: SiteConfig = {
      identity: { title: 'Test' },
      footer: {
        id: 'global-footer',
        type: 'footer',
        data: {
          legalLinks: { $ref: 'menu.json#/footerLegal' },
        },
      },
    };
    const menuConfig: MenuConfig = {
      footerLegal: [{ label: 'Privacy', href: '/privacy' }],
    };

    const resolved = resolveRuntimeConfig({
      pages: {},
      siteConfig,
      themeConfig,
      menuConfig,
    });

    expect(resolved.siteConfig.footer.data).toEqual({
      legalLinks: [{ label: 'Privacy', href: '/privacy' }],
    });
  });

  it('discovers every section data field bound to menu.json', () => {
    expect(
      getMenuRefBindings({
        menu: { $ref: 'menu.json#/main' },
        legalLinks: { $ref: '../config/menu.json#/footer/legal' },
        theme: { $ref: 'theme.json#/tokens' },
      })
    ).toEqual([
      { fieldKey: 'menu', path: ['main'] },
      { fieldKey: 'legalLinks', path: ['footer', 'legal'] },
    ]);
  });

  it('writes edited resolved menu fields into menuDraft and preserves authored refs', () => {
    const authoredData = {
      brandText: 'OlonJS',
      legalLinks: { $ref: 'menu.json#/footerLegal' },
    };
    const nextData = {
      brandText: 'OlonJS',
      legalLinks: [
        { label: 'Privacy', href: '/privacy' },
        { label: 'Terms', href: '/terms' },
      ],
    };
    const menuDraft: MenuConfig = {
      main: [{ label: 'Home', href: '/' }],
      footerLegal: [{ label: 'Old', href: '/old' }],
    };

    const result = applyMenuRefBindingsToDraft(authoredData, nextData, menuDraft);

    expect(result.normalizedData).toEqual(authoredData);
    expect(result.menuDraft).toEqual({
      main: [{ label: 'Home', href: '/' }],
      footerLegal: [
        { label: 'Privacy', href: '/privacy' },
        { label: 'Terms', href: '/terms' },
      ],
    });
  });

  it('rebases resolved global site data onto authored menu refs before persistence', () => {
    const authoredSite: SiteConfig = {
      identity: { title: 'Test' },
      footer: {
        id: 'global-footer',
        type: 'footer',
        data: {
          socialLinks: { $ref: 'menu.json#/footerSocial' },
          legalLinks: { $ref: 'menu.json#/footerLegal' },
        },
      },
    };
    const resolvedSite: SiteConfig = {
      identity: { title: 'Test' },
      footer: {
        id: 'global-footer',
        type: 'footer',
        data: {
          socialLinks: [{ label: 'GitHub', href: 'https://github.com/olonjs', icon: 'github' }],
          legalLinks: [{ label: 'Privacy', href: '/privacy' }],
        },
      },
    };

    const result = applySiteMenuRefBindingsToDraft(authoredSite, resolvedSite, {
      footerSocial: [],
      footerLegal: [],
    });

    expect(result.site.footer.data).toEqual(authoredSite.footer.data);
    expect(result.menuDraft).toEqual({
      footerSocial: [{ label: 'GitHub', href: 'https://github.com/olonjs', icon: 'github' }],
      footerLegal: [{ label: 'Privacy', href: '/privacy' }],
    });
  });

  it('resolves section menu props from any section data.menu, not only headers', () => {
    const footerSection: Section = {
      id: 'global-footer',
      type: 'footer',
      data: {
        menu: [{ label: 'Privacy', href: '/privacy' }],
      },
    };

    expect(resolveSectionMenuItems(footerSection, [{ label: 'Home', href: '/' }])).toEqual([
      { label: 'Privacy', href: '/privacy' },
    ]);
  });
});

describe('config-resolver collection refs', () => {
  const looseCollectionSchema = z.record(z.unknown());
  const bookCollectionSchema = z.record(
    z.object({
      id: z.string(),
      title: z.string(),
      author: z.string(),
    })
  );
  const siteConfig: SiteConfig = {
    identity: { title: 'Test' },
    footer: {
      id: 'global-footer',
      type: 'footer',
      data: {},
    },
  };
  const menuConfig: MenuConfig = {};

  it('resolves page section fields from registered collection documents', () => {
    const resolved = resolveRuntimeConfig({
      pages: {
        libri: {
          id: 'libri-page',
          slug: 'libri',
          meta: {
            title: 'Catalogo libri',
            description: 'Catalogo libri usato per validare le collection.',
          },
          sections: [
            {
              id: 'books-list',
              type: 'books-list',
              data: {
                title: 'Libri',
                items: { $ref: '../collections/libri/libri.json' },
              },
            },
          ],
        },
      },
      siteConfig,
      themeConfig,
      menuConfig,
      collections: {
        libri: {
          neuromancer: {
            id: 'neuromancer',
            title: 'Neuromancer',
            author: 'William Gibson',
          },
        },
      },
      collectionSchemas: {
        libri: looseCollectionSchema,
      },
    });

    expect(resolved.pages.libri.sections[0].data).toEqual({
      title: 'Libri',
      items: {
        neuromancer: {
          id: 'neuromancer',
          title: 'Neuromancer',
          author: 'William Gibson',
        },
      },
    });
  });

  it('resolves nested refs between collection documents at runtime', () => {
    const authorSchema = z.record(
      z.object({
        id: z.string(),
        name: z.string(),
      })
    );
    const bookWithAuthorRefSchema = z.record(
      z.object({
        id: z.string(),
        title: z.string(),
        author: z.union([
          z.object({
            id: z.string(),
            name: z.string(),
          }),
          z.object({
            $ref: z.string(),
          }),
        ]),
      })
    );

    const resolved = resolveRuntimeConfig({
      pages: {
        libri: {
          id: 'libri-page',
          slug: 'libri',
          meta: {
            title: 'Catalogo libri',
            description: 'Catalogo libri usato per validare relazioni tra collection.',
          },
          sections: [
            {
              id: 'books-list',
              type: 'books-list',
              data: {
                items: { $ref: '../collections/libri/libri.json' },
              },
            },
          ],
        },
      },
      siteConfig,
      themeConfig,
      menuConfig,
      collections: {
        autori: {
          'frank-herbert': {
            id: 'frank-herbert',
            name: 'Frank Herbert',
          },
        },
        libri: {
          dune: {
            id: 'dune',
            title: 'Dune',
            author: {
              $ref: '../autori/autori.json#/frank-herbert',
            },
          },
        },
      },
      collectionSchemas: {
        autori: authorSchema,
        libri: bookWithAuthorRefSchema,
      },
    });

    expect(resolved.pages.libri.sections[0].data).toEqual({
      items: {
        dune: {
          id: 'dune',
          title: 'Dune',
          author: {
            id: 'frank-herbert',
            name: 'Frank Herbert',
          },
        },
      },
    });
  });

  it('keeps explicit refDocuments aliases available alongside collections', () => {
    const resolved = resolveRuntimeConfig({
      pages: {
        libri: {
          id: 'libri-page',
          slug: 'libri',
          meta: {
            title: 'Catalogo libri',
            description: 'Catalogo libri usato per validare le collection.',
          },
          sections: [
            {
              id: 'books-list',
              type: 'books-list',
              data: {
                items: { $ref: 'custom/books.json#/featured' },
              },
            },
          ],
        },
      },
      siteConfig,
      themeConfig,
      menuConfig,
      collections: {
        libri: {},
      },
      collectionSchemas: {
        libri: looseCollectionSchema,
      },
      refDocuments: {
        'custom/books.json': {
          featured: [
            {
              id: 'dune',
              title: 'Dune',
            },
          ],
        },
      },
    });

    expect(resolved.pages.libri.sections[0].data).toEqual({
      items: [
        {
          id: 'dune',
          title: 'Dune',
        },
      ],
    });
  });

  it('builds collection route context from page collection binding and route params', () => {
    const page = {
      id: 'book-detail-page',
      slug: 'libri/[slug]',
      meta: {
        title: 'Dettaglio libro',
        description: 'Pagina dettaglio usata per validare collection current.',
      },
      collection: {
        source: 'libri',
        paramKey: 'slug',
      },
      sections: [],
    };

    const context = resolveCollectionContext(page, { slug: 'dune' }, {
      libri: {
        dune: {
          id: 'dune',
          title: 'Dune',
        },
      },
    });

    expect(context).toEqual({
      source: 'libri',
      paramKey: 'slug',
      paramValue: 'dune',
      currentItem: {
        id: 'dune',
        title: 'Dune',
      },
    });
  });

  it('resolves collection:current to the active collection entity', () => {
    const page = {
      id: 'book-detail-page',
      slug: 'libri/[slug]',
      meta: {
        title: 'Dettaglio libro',
        description: 'Pagina dettaglio usata per validare collection current.',
      },
      collection: {
        source: 'libri',
        paramKey: 'slug',
      },
      sections: [
        {
          id: 'book-detail',
          type: 'book-detail',
          data: {
            item: { $ref: 'collection:current' },
          },
        },
      ],
    };
    const collections = {
      libri: {
        dune: {
          id: 'dune',
          title: 'Dune',
          author: 'Frank Herbert',
        },
      },
    };
    const collectionContext = resolveCollectionContext(page, { slug: 'dune' }, collections);

    const resolved = resolveRuntimeConfig({
      pages: {
        'libri/[slug]': page,
      },
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      collectionSchemas: {
        libri: looseCollectionSchema,
      },
      collectionContext,
    });

    expect(resolved.pages['libri/[slug]'].sections[0].data).toEqual({
      item: {
        id: 'dune',
        title: 'Dune',
        author: 'Frank Herbert',
      },
    });
  });

  it('resolves collection:current from the parsed collection document, not the raw item', () => {
    const page = {
      id: 'book-detail-page',
      slug: 'libri/[slug]',
      meta: {
        title: 'Dettaglio libro',
        description: 'Pagina dettaglio usata per validare collection current.',
      },
      collection: {
        source: 'libri',
        paramKey: 'slug',
      },
      sections: [
        {
          id: 'book-detail',
          type: 'book-detail',
          data: {
            item: { $ref: 'collection:current' },
          },
        },
      ],
    };
    const collections = {
      libri: {
        dune: {
          id: 'dune',
          title: 'Dune',
          draftOnly: true,
        },
      },
    };
    const collectionContext = resolveCollectionContext(page, { slug: 'dune' }, collections);

    const resolved = resolveRuntimeConfig({
      pages: {
        'libri/[slug]': page,
      },
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      collectionSchemas: {
        libri: z.record(
          z.object({
            id: z.string(),
            title: z.string(),
            author: z.string().default('Unknown'),
          })
        ),
      },
      collectionContext,
    });

    expect(resolved.pages['libri/[slug]'].sections[0].data).toEqual({
      item: {
        id: 'dune',
        title: 'Dune',
        author: 'Unknown',
      },
    });
    expect(resolved.collectionContext?.currentItem).toEqual({
      id: 'dune',
      title: 'Dune',
      author: 'Unknown',
    });
  });

  it('fails before resolving section props when a registered collection is invalid', () => {
    expect(() =>
      resolveRuntimeConfig({
        pages: {
          libri: {
            id: 'libri-page',
            slug: 'libri',
            meta: {
              title: 'Catalogo libri',
              description: 'Catalogo libri usato per validare le collection.',
            },
            sections: [
              {
                id: 'books-list',
                type: 'books-list',
                data: {
                  items: { $ref: '../collections/libri/libri.json' },
                },
              },
            ],
          },
        },
        siteConfig,
        themeConfig,
        menuConfig,
        collections: {
          libri: {
            dune: {
              id: 'dune',
              title: 'Dune',
            },
          },
        },
        collectionSchemas: {
          libri: bookCollectionSchema,
        },
      })
    ).toThrow('[JsonPages] Invalid collection "libri"');
  });

  it('preserves collection:current authored refs and writes edited entity data into collection draft', () => {
    const result = applyCollectionRefBindingsToDraft(
      {
        item: { $ref: 'collection:current' },
      },
      {
        item: {
          id: 'dune',
          title: 'Dune Messiah',
        },
      },
      {
        libri: {
          dune: {
            id: 'dune',
            title: 'Dune',
          },
        },
      },
      {
        source: 'libri',
        paramKey: 'slug',
        paramValue: 'dune',
        currentItem: {
          id: 'dune',
          title: 'Dune',
        },
      },
      {
        libri: looseCollectionSchema,
      }
    );

    expect(result.normalizedData).toEqual({
      item: { $ref: 'collection:current' },
    });
    expect(result.collectionsDraft).toEqual({
      libri: {
        dune: {
          id: 'dune',
          title: 'Dune Messiah',
        },
      },
    });
  });

  it('preserves collection document refs and writes edited collection data into collection draft', () => {
    const result = applyCollectionRefBindingsToDraft(
      {
        items: { $ref: '../collections/libri/libri.json' },
      },
      {
        items: {
          dune: {
            id: 'dune',
            title: 'Dune',
          },
        },
      },
      {},
      undefined,
      {
        libri: looseCollectionSchema,
      }
    );

    expect(result.normalizedData).toEqual({
      items: { $ref: '../collections/libri/libri.json' },
    });
    expect(result.collectionsDraft).toEqual({
      libri: {
        dune: {
          id: 'dune',
          title: 'Dune',
        },
      },
    });
  });

  it('preserves nested authored collection refs when edited resolved entities are written back', () => {
    const result = applyCollectionRefBindingsToDraft(
      {
        items: { $ref: '../collections/libri/libri.json' },
      },
      {
        items: {
          dune: {
            id: 'dune',
            title: 'Dune Messiah',
            author: {
              id: 'frank-herbert',
              name: 'Frank Herbert',
            },
          },
        },
      },
      {
        libri: {
          dune: {
            id: 'dune',
            title: 'Dune',
            author: {
              $ref: '../autori/autori.json#/frank-herbert',
            },
          },
        },
        autori: {
          'frank-herbert': {
            id: 'frank-herbert',
            name: 'Frank Herbert',
          },
        },
      },
      undefined,
      {
        libri: looseCollectionSchema,
        autori: looseCollectionSchema,
      }
    );

    expect(result.normalizedData).toEqual({
      items: { $ref: '../collections/libri/libri.json' },
    });
    expect(result.collectionsDraft?.libri?.dune).toEqual({
      id: 'dune',
      title: 'Dune Messiah',
      author: {
        $ref: '../autori/autori.json#/frank-herbert',
      },
    });
  });

  it('persists changed nested collection relations as authored refs', () => {
    const result = applyCollectionRefBindingsToDraft(
      {
        items: { $ref: '../collections/libri/libri.json' },
      },
      {
        items: {
          dune: {
            id: 'dune',
            title: 'Dune',
            author: {
              $ref: '../autori/autori.json#/ursula-k-le-guin',
            },
          },
        },
      },
      {
        libri: {
          dune: {
            id: 'dune',
            title: 'Dune',
            author: {
              $ref: '../autori/autori.json#/frank-herbert',
            },
          },
        },
        autori: {
          'frank-herbert': {
            id: 'frank-herbert',
            name: 'Frank Herbert',
          },
          'ursula-k-le-guin': {
            id: 'ursula-k-le-guin',
            name: 'Ursula K. Le Guin',
          },
        },
      },
      undefined,
      {
        libri: looseCollectionSchema,
        autori: looseCollectionSchema,
      }
    );

    expect(result.collectionsDraft?.libri?.dune).toEqual({
      id: 'dune',
      title: 'Dune',
      author: {
        $ref: '../autori/autori.json#/ursula-k-le-guin',
      },
    });
  });

  it('rejects collection draft edits that violate the collection schema', () => {
    expect(() =>
      applyCollectionRefBindingsToDraft(
        {
          item: { $ref: 'collection:current' },
        },
        {
          item: {
            id: 'dune',
            title: 'Dune Messiah',
          },
        },
        {
          libri: {
            dune: {
              id: 'dune',
              title: 'Dune',
              author: 'Frank Herbert',
            },
          },
        },
        {
          source: 'libri',
          paramKey: 'slug',
          paramValue: 'dune',
          currentItem: {
            id: 'dune',
            title: 'Dune',
            author: 'Frank Herbert',
          },
        },
        {
          libri: bookCollectionSchema,
        }
      )
    ).toThrow('[JsonPages] Invalid collection "libri"');
  });
});

describe('config-resolver collection validation', () => {
  const bookCollectionSchema = z.record(
    z.object({
      id: z.string(),
      title: z.string(),
      author: z.string(),
    })
  );

  it('returns parsed collection documents when source schemas accept them', () => {
    const collections = {
      libri: {
        dune: {
          id: 'dune',
          title: 'Dune',
          author: 'Frank Herbert',
        },
      },
    };

    expect(
      validateCollectionDocuments(collections, {
        libri: bookCollectionSchema,
      })
    ).toEqual(collections);
  });

  it('fails explicitly when a collection has no matching schema', () => {
    expect(() =>
      validateCollectionDocuments(
        {
          libri: {},
        },
        {}
      )
    ).toThrow('[JsonPages] Missing collection schema for "libri".');
  });

  it('fails explicitly with the collection source when a document is invalid', () => {
    expect(() =>
      validateCollectionDocuments(
        {
          libri: {
            dune: {
              id: 'dune',
              title: 'Dune',
            },
          },
        },
        {
          libri: bookCollectionSchema,
        }
      )
    ).toThrow('[JsonPages] Invalid collection "libri"');
  });
});

END_OF_FILE_CONTENT
echo "Creating core/src/contract/config-resolver.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/contract/config-resolver.ts"
import type { JsonPagesConfig } from './types-engine';
import type { MenuConfig, MenuItem, PageConfig, Section, SiteConfig, ThemeConfig } from './kernel';

export type RefDocuments = NonNullable<JsonPagesConfig['refDocuments']>;
type CollectionDocuments = NonNullable<JsonPagesConfig['collections']>;

interface RuntimeResolutionInput {
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: MenuConfig;
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  collectionContext?: CollectionResolutionContext | null;
  refDocuments?: JsonPagesConfig['refDocuments'];
}

interface RuntimeResolutionResult {
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: MenuConfig;
  collections: CollectionDocuments;
  collectionContext: CollectionResolutionContext | null;
}

interface ResolveContext {
  documents: Map<string, unknown>;
  cache: Map<string, unknown>;
  stack: string[];
  collectionContext?: CollectionResolutionContext | null;
}

export interface CollectionResolutionContext {
  source: string;
  paramKey: string;
  paramValue: string;
  currentItem: unknown;
}

export interface MenuRefBinding {
  fieldKey: string;
  path: string[];
}

export interface CollectionRefBinding {
  fieldKey: string;
  source: string;
  itemId?: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (!isRecord(value)) return false;
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

function isRefObject(value: unknown): value is Record<string, unknown> & { $ref: string } {
  return isRecord(value) && typeof value.$ref === 'string' && value.$ref.trim().length > 0;
}

function decodePointerSegment(segment: string): string {
  return segment.replace(/~1/g, '/').replace(/~0/g, '~');
}

function readJsonPointer(document: unknown, pointer: string): unknown {
  if (!pointer || pointer === '#') return document;
  const normalized = pointer.startsWith('#') ? pointer.slice(1) : pointer;
  if (!normalized) return document;
  if (normalized === '/') return document;

  let current: unknown = document;
  for (const rawSegment of normalized.replace(/^\//, '').split('/')) {
    const segment = decodePointerSegment(rawSegment);
    if (Array.isArray(current)) {
      const index = Number(segment);
      if (!Number.isInteger(index) || index < 0 || index >= current.length) return undefined;
      current = current[index];
      continue;
    }
    if (!isRecord(current) || !(segment in current)) return undefined;
    current = current[segment];
  }
  return current;
}

function normalizePath(input: string): string {
  const trimmed = input.trim().replace(/\\/g, '/');
  const withoutLeading = trimmed.replace(/^\/+/, '');
  const segments = withoutLeading.split('/');
  const normalized: string[] = [];

  for (const segment of segments) {
    if (!segment || segment === '.') continue;
    if (segment === '..') {
      if (normalized.length > 0) normalized.pop();
      continue;
    }
    normalized.push(segment);
  }

  return normalized.join('/');
}

function getDirname(path: string): string {
  const normalized = normalizePath(path);
  const idx = normalized.lastIndexOf('/');
  return idx === -1 ? '' : normalized.slice(0, idx);
}

function resolveDocumentCandidates(docPath: string, currentDocumentPath: string): string[] {
  const candidates = new Set<string>();
  const direct = normalizePath(docPath);
  if (direct) candidates.add(direct);

  const currentDir = getDirname(currentDocumentPath);
  const relative = normalizePath(currentDir ? `${currentDir}/${docPath}` : docPath);
  if (relative) candidates.add(relative);

  return Array.from(candidates);
}

function cloneUnknown<T>(value: T): T {
  if (Array.isArray(value)) {
    return value.map((item) => cloneUnknown(item)) as T;
  }
  if (isPlainObject(value)) {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, cloneUnknown(item)])
    ) as T;
  }
  return value;
}

function registerDocumentAliases(documents: Map<string, unknown>, aliases: string[], value: unknown): void {
  for (const alias of aliases) {
    const normalized = normalizePath(alias);
    if (!normalized) continue;
    documents.set(normalized, value);
  }
}

export function validateCollectionDocuments(
  collections?: JsonPagesConfig['collections'],
  collectionSchemas?: JsonPagesConfig['collectionSchemas']
): CollectionDocuments {
  const validatedCollections: CollectionDocuments = {};

  for (const [source, collection] of Object.entries(collections ?? {})) {
    const schema = collectionSchemas?.[source];
    if (!schema) {
      throw new Error(`[JsonPages] Missing collection schema for "${source}".`);
    }

    try {
      validatedCollections[source] = schema.parse(collection) as CollectionDocuments[string];
    } catch (error) {
      const detail = error instanceof Error && error.message ? `: ${error.message}` : '';
      throw new Error(`[JsonPages] Invalid collection "${source}"${detail}`);
    }
  }

  return validatedCollections;
}

function rebaseCollectionContext(
  collectionContext: CollectionResolutionContext | null | undefined,
  collections: CollectionDocuments
): CollectionResolutionContext | null {
  if (!collectionContext) return null;
  const collection = collections[collectionContext.source];
  if (!isRecord(collection)) return null;
  const currentItem = collection[collectionContext.paramValue];
  if (currentItem === undefined) return null;
  return {
    ...collectionContext,
    currentItem,
  };
}

function buildDocuments({
  pages,
  siteConfig,
  themeConfig,
  menuConfig,
  collections,
  refDocuments,
}: RuntimeResolutionInput): Map<string, unknown> {
  const documents = new Map<string, unknown>();

  for (const [alias, value] of Object.entries(refDocuments ?? {})) {
    registerDocumentAliases(documents, [alias], value);
  }

  registerDocumentAliases(documents, ['site.json', 'config/site.json', 'src/data/config/site.json'], siteConfig);
  registerDocumentAliases(documents, ['theme.json', 'config/theme.json', 'src/data/config/theme.json'], themeConfig);
  registerDocumentAliases(documents, ['menu.json', 'config/menu.json', 'src/data/config/menu.json'], menuConfig);

  for (const [slug, page] of Object.entries(pages)) {
    const safeSlug = slug.replace(/^\/+|\/+$/g, '') || 'home';
    registerDocumentAliases(documents, [`pages/${safeSlug}.json`, `src/data/pages/${safeSlug}.json`], page);
  }

  for (const [slug, collection] of Object.entries(collections ?? {})) {
    const safeSlug = slug.replace(/^\/+|\/+$/g, '');
    if (!safeSlug) continue;
    registerDocumentAliases(documents, [
      `collections/${safeSlug}/${safeSlug}.json`,
      `src/data/collections/${safeSlug}/${safeSlug}.json`,
    ], collection);
  }

  return documents;
}

function resolveRefTarget(
  ref: string,
  currentDocumentPath: string,
  context: ResolveContext
): { value: unknown; documentPath: string } | null {
  if (ref.trim() === 'collection:current') {
    const currentItem = context.collectionContext?.currentItem;
    if (currentItem === undefined) return null;
    const source = context.collectionContext?.source ?? 'current';
    const paramValue = context.collectionContext?.paramValue ?? 'current';
    return {
      value: currentItem,
      documentPath: `collections/${source}/${source}.json`,
    };
  }

  const [rawDocumentPath, rawPointer = ''] = ref.split('#');
  const pointer = rawPointer ? `/${rawPointer.replace(/^\//, '')}` : '';

  if (!rawDocumentPath) {
    const normalizedCurrent = normalizePath(currentDocumentPath);
    const currentDocument = context.documents.get(normalizedCurrent);
    if (currentDocument === undefined) return null;
    const currentValue = readJsonPointer(currentDocument, pointer);
    if (currentValue === undefined) return null;
    return { value: currentValue, documentPath: normalizedCurrent };
  }

  for (const candidate of resolveDocumentCandidates(rawDocumentPath, currentDocumentPath)) {
    const documentValue = context.documents.get(candidate);
    if (documentValue === undefined) continue;
    const targetValue = readJsonPointer(documentValue, pointer);
    if (targetValue === undefined) continue;
    return { value: targetValue, documentPath: candidate };
  }

  return null;
}

function resolveNode(
  value: unknown,
  currentDocumentPath: string,
  context: ResolveContext
): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => resolveNode(item, currentDocumentPath, context));
  }

  if (!isPlainObject(value)) {
    return value;
  }

  if (isRefObject(value)) {
    const refKey = `${normalizePath(currentDocumentPath)}::${value.$ref}`;
    if (context.stack.includes(refKey)) {
      console.warn('[JsonPages] Circular $ref skipped', value.$ref);
      return cloneUnknown(value);
    }
    if (context.cache.has(refKey)) {
      const cached = cloneUnknown(context.cache.get(refKey));
      const siblingEntries = Object.entries(value).filter(([key]) => key !== '$ref');
      if (siblingEntries.length === 0) return cached;
      const resolvedSiblings = Object.fromEntries(
        siblingEntries.map(([key, item]) => [key, resolveNode(item, currentDocumentPath, context)])
      );
      return isPlainObject(cached) ? { ...cached, ...resolvedSiblings } : cached;
    }

    const resolvedTarget = resolveRefTarget(value.$ref, currentDocumentPath, context);
    if (!resolvedTarget) {
      console.warn('[JsonPages] Unresolved $ref', value.$ref);
      return Object.fromEntries(
        Object.entries(value).map(([key, item]) => [key, resolveNode(item, currentDocumentPath, context)])
      );
    }

    context.stack.push(refKey);
    const resolvedValue = resolveNode(resolvedTarget.value, resolvedTarget.documentPath, context);
    context.stack.pop();
    context.cache.set(refKey, cloneUnknown(resolvedValue));

    const siblingEntries = Object.entries(value).filter(([key]) => key !== '$ref');
    if (siblingEntries.length === 0) return resolvedValue;

    const resolvedSiblings = Object.fromEntries(
      siblingEntries.map(([key, item]) => [key, resolveNode(item, currentDocumentPath, context)])
    );
    return isPlainObject(resolvedValue)
      ? { ...resolvedValue, ...resolvedSiblings }
      : resolvedValue;
  }

  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [key, resolveNode(item, currentDocumentPath, context)])
  );
}

function resolveDocument(
  value: unknown,
  entryPath: string,
  documents: Map<string, unknown>,
  collectionContext?: CollectionResolutionContext | null
): unknown {
  return resolveNode(value, entryPath, {
    documents,
    cache: new Map<string, unknown>(),
    stack: [],
    collectionContext,
  });
}

export function resolveCollectionContext(
  page: PageConfig,
  params: Record<string, string | undefined>,
  collections?: JsonPagesConfig['collections']
): CollectionResolutionContext | null {
  const binding = page.collection;
  if (!binding) return null;

  const source = String(binding.source);
  const paramKey = binding.paramKey;
  const paramValue = params[paramKey];
  if (!paramValue) return null;

  const collection = collections?.[source];
  if (!isRecord(collection)) return null;

  const currentItem = collection[paramValue];
  if (currentItem === undefined) return null;

  return {
    source,
    paramKey,
    paramValue,
    currentItem,
  };
}

function isMenuItemShape(value: unknown): value is MenuItem {
  return isRecord(value) && typeof value.label === 'string' && typeof value.href === 'string';
}

function parseMenuRefPointer(value: unknown): string[] | null {
  if (!isRefObject(value)) return null;
  const rawRef = value.$ref.trim();
  const [rawDocPath, rawPointer = ''] = rawRef.split('#');
  if (!/menu\.json$/i.test(rawDocPath)) return null;
  const pointer = rawPointer.replace(/^\//, '');
  if (!pointer) return null;
  const segments = pointer
    .split('/')
    .map(decodePointerSegment)
    .filter(Boolean);
  return segments.length > 0 ? segments : null;
}

export function getMenuRefBindings(sectionData: unknown): MenuRefBinding[] {
  if (!isRecord(sectionData)) return [];
  return Object.entries(sectionData)
    .map(([fieldKey, value]) => {
      const path = parseMenuRefPointer(value);
      return path ? { fieldKey, path } : null;
    })
    .filter((binding): binding is MenuRefBinding => binding != null);
}

function writeValueAtPath(target: unknown, path: string[], value: unknown): unknown {
  if (path.length === 0) return value;

  const [head, ...tail] = path;
  const source = isRecord(target) ? target : {};
  return {
    ...source,
    [head]: writeValueAtPath(source[head], tail, value),
  };
}

function preserveAuthoredRefs(authoredValue: unknown, nextValue: unknown): unknown {
  if (isRefObject(nextValue)) return cloneUnknown(nextValue);
  if (isRefObject(authoredValue)) return cloneUnknown(authoredValue);

  if (Array.isArray(nextValue)) {
    const authoredArray = Array.isArray(authoredValue) ? authoredValue : [];
    return nextValue.map((item, index) => preserveAuthoredRefs(authoredArray[index], item));
  }

  if (isPlainObject(nextValue)) {
    const authoredRecord = isRecord(authoredValue) ? authoredValue : {};
    return Object.fromEntries(
      Object.entries(nextValue).map(([key, item]) => [
        key,
        preserveAuthoredRefs(authoredRecord[key], item),
      ])
    );
  }

  return nextValue;
}

export function applyMenuRefBindingsToDraft(
  authoredSectionData: unknown,
  nextData: Record<string, unknown>,
  menuDraft: MenuConfig
): { normalizedData: Record<string, unknown>; menuDraft: MenuConfig } {
  const bindings = getMenuRefBindings(authoredSectionData);
  if (bindings.length === 0) {
    return { normalizedData: nextData, menuDraft };
  }

  const authoredData = isRecord(authoredSectionData) ? authoredSectionData : {};
  const normalizedData: Record<string, unknown> = { ...nextData };
  let nextMenuDraft = menuDraft;

  for (const binding of bindings) {
    if (authoredData[binding.fieldKey] !== undefined) {
      normalizedData[binding.fieldKey] = authoredData[binding.fieldKey];
    }
    const resolvedMenuValue = nextData[binding.fieldKey];
    if (Array.isArray(resolvedMenuValue)) {
      nextMenuDraft = writeValueAtPath(nextMenuDraft, binding.path, resolvedMenuValue) as MenuConfig;
    }
  }

  return { normalizedData, menuDraft: nextMenuDraft };
}

function parseCollectionRef(value: unknown, collectionContext?: CollectionResolutionContext | null): Omit<CollectionRefBinding, 'fieldKey'> | null {
  if (!isRefObject(value)) return null;
  const rawRef = value.$ref.trim();
  if (rawRef === 'collection:current') {
    if (!collectionContext) return null;
    return {
      source: collectionContext.source,
      itemId: collectionContext.paramValue,
    };
  }

  const [rawDocPath, rawPointer = ''] = rawRef.split('#');
  const normalizedPath = normalizePath(rawDocPath);
  const match = normalizedPath.match(/(?:^|\/)collections\/([^/]+)\/\1\.json$/);
  if (!match?.[1]) return null;

  const pointer = rawPointer.replace(/^\//, '');
  const itemId = pointer ? decodePointerSegment(pointer.split('/')[0]) : undefined;
  return {
    source: match[1],
    ...(itemId ? { itemId } : {}),
  };
}

export function getCollectionRefBindings(
  sectionData: unknown,
  collectionContext?: CollectionResolutionContext | null
): CollectionRefBinding[] {
  if (!isRecord(sectionData)) return [];
  return Object.entries(sectionData)
    .map(([fieldKey, value]) => {
      const binding = parseCollectionRef(value, collectionContext);
      return binding ? { fieldKey, ...binding } : null;
    })
    .filter((binding): binding is CollectionRefBinding => binding != null);
}

export function applyCollectionRefBindingsToDraft(
  authoredSectionData: unknown,
  nextData: Record<string, unknown>,
  collectionsDraft: JsonPagesConfig['collections'] | undefined,
  collectionContext?: CollectionResolutionContext | null,
  collectionSchemas?: JsonPagesConfig['collectionSchemas']
): { normalizedData: Record<string, unknown>; collectionsDraft: JsonPagesConfig['collections'] } {
  const bindings = getCollectionRefBindings(authoredSectionData, collectionContext);
  if (bindings.length === 0) {
    return { normalizedData: nextData, collectionsDraft };
  }

  const authoredData = isRecord(authoredSectionData) ? authoredSectionData : {};
  const normalizedData: Record<string, unknown> = { ...nextData };
  const nextCollectionsDraft = cloneUnknown(collectionsDraft ?? {}) as NonNullable<JsonPagesConfig['collections']>;

  for (const binding of bindings) {
    if (authoredData[binding.fieldKey] !== undefined) {
      normalizedData[binding.fieldKey] = authoredData[binding.fieldKey];
    }

    const resolvedValue = nextData[binding.fieldKey];

    if (isRefObject(resolvedValue)) {
      continue;
    }
    
    if (binding.itemId) {
      const sourceCollection = isRecord(nextCollectionsDraft[binding.source])
        ? nextCollectionsDraft[binding.source]
        : {};
      const authoredItem = sourceCollection[binding.itemId];
      nextCollectionsDraft[binding.source] = {
        ...sourceCollection,
        [binding.itemId]: preserveAuthoredRefs(authoredItem, resolvedValue),
      };
      continue;
    }

    if (isRecord(resolvedValue)) {
      nextCollectionsDraft[binding.source] = preserveAuthoredRefs(
        nextCollectionsDraft[binding.source],
        resolvedValue
      ) as CollectionDocuments[string];
    }
  }

  return {
    normalizedData,
    collectionsDraft: validateCollectionDocuments(nextCollectionsDraft, collectionSchemas),
  };
}

function applySectionDataMenuRefBindings(
  authoredSection: Section | undefined,
  nextSection: Section | undefined,
  menuDraft: MenuConfig
): { section: Section | undefined; menuDraft: MenuConfig } {
  if (!authoredSection || !nextSection || !isRecord(nextSection.data)) {
    return { section: nextSection, menuDraft };
  }

  const { normalizedData, menuDraft: nextMenuDraft } = applyMenuRefBindingsToDraft(
    authoredSection.data,
    nextSection.data,
    menuDraft
  );

  return {
    section: { ...nextSection, data: normalizedData } as Section,
    menuDraft: nextMenuDraft,
  };
}

export function applySiteMenuRefBindingsToDraft(
  authoredSite: SiteConfig,
  nextSite: SiteConfig,
  menuDraft: MenuConfig
): { site: SiteConfig; menuDraft: MenuConfig } {
  let nextMenuDraft = menuDraft;

  const headerResult = applySectionDataMenuRefBindings(
    authoredSite.header,
    nextSite.header,
    nextMenuDraft
  );
  nextMenuDraft = headerResult.menuDraft;

  const footerResult = applySectionDataMenuRefBindings(
    authoredSite.footer,
    nextSite.footer,
    nextMenuDraft
  );
  nextMenuDraft = footerResult.menuDraft;

  return {
    site: {
      ...nextSite,
      ...(headerResult.section ? { header: headerResult.section } : {}),
      footer: footerResult.section ?? nextSite.footer,
    },
    menuDraft: nextMenuDraft,
  };
}

function getSectionDataMenuCandidate(sectionData: unknown): MenuItem[] | null {
  if (!isRecord(sectionData)) return null;
  const menu = sectionData.menu;
  if (Array.isArray(menu) && menu.every(isMenuItemShape)) return menu as MenuItem[];
  return null;
}

export function resolveHeaderMenuItems(headerData: unknown, fallbackMain: MenuItem[]): MenuItem[] {
  const candidate = getSectionDataMenuCandidate(headerData);
  return candidate ?? (Array.isArray(fallbackMain) ? fallbackMain : []);
}

export function resolveSectionMenuItems(section: Section, fallbackMain: MenuItem[]): MenuItem[] | undefined {
  const candidate = getSectionDataMenuCandidate(section.data as unknown);
  if (candidate) return candidate;
  if (section.type === 'header') return Array.isArray(fallbackMain) ? fallbackMain : [];
  return undefined;
}

export function resolveRuntimeConfig(input: RuntimeResolutionInput): RuntimeResolutionResult {
  const collections = validateCollectionDocuments(input.collections, input.collectionSchemas);
  const collectionContext = rebaseCollectionContext(input.collectionContext, collections);
  const documents = buildDocuments({
    ...input,
    collections,
  });

  return {
    pages: Object.fromEntries(
      Object.entries(input.pages).map(([slug, page]) => [
        slug,
        resolveDocument(
          page,
          `pages/${slug.replace(/^\/+|\/+$/g, '') || 'home'}.json`,
          documents,
          collectionContext
        ),
      ])
    ) as Record<string, PageConfig>,
    siteConfig: resolveDocument(input.siteConfig, 'config/site.json', documents) as SiteConfig,
    themeConfig: resolveDocument(input.themeConfig, 'config/theme.json', documents) as ThemeConfig,
    menuConfig: resolveDocument(input.menuConfig, 'config/menu.json', documents) as MenuConfig,
    collections,
    collectionContext,
  };
}

END_OF_FILE_CONTENT
echo "Creating core/src/contract/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/contract/index.ts"
/**
 * Canonical contract surface for OlonJS core.
 *
 * `src/contract/` is the transition target for protocol, structural
 * types, config resolution, and agent-facing contracts. Legacy paths
 * under `src/lib/` remain compatibility shims during the migration.
 */
export * from './kernel';
export * from './types-engine';
export * from './config-resolver';
export * from './webmcp-contracts';
export * from '../lib/shared-types';

END_OF_FILE_CONTENT
echo "Creating core/src/contract/kernel.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/contract/kernel.ts"
/**
 * KERNEL: The Base Contract (MTRP)
 * Core is self-contained; structural types live here.
 */
export interface BaseSectionSettings {
  [key: string]: unknown;
}

export interface SectionDataRegistry {}
export interface SectionSettingsRegistry {}

export interface CollectionItemRegistry {}

export interface BaseSection<K extends keyof SectionDataRegistry> {
  id: string;
  type: K;
  data: SectionDataRegistry[K];
  settings?: K extends keyof SectionSettingsRegistry
    ? SectionSettingsRegistry[K]
    : BaseSectionSettings;
}

/** Structural shape used when no tenant has augmented the registries. */
export interface FallbackSection {
  id: string;
  type: string;
  data: Record<string, unknown>;
  settings?: Record<string, unknown>;
}

/** Computed union of all registered section types. */
export type Section =
  keyof SectionDataRegistry extends never
    ? FallbackSection
    : { [K in keyof SectionDataRegistry]: BaseSection<K> }[keyof SectionDataRegistry];

export type SectionType = keyof SectionDataRegistry extends never ? string : keyof SectionDataRegistry;

export interface CollectionItem {
  id: string;
}

export type CollectionType = keyof CollectionItemRegistry extends never ? string : keyof CollectionItemRegistry;

export type CollectionDocument<TItem = CollectionItem> = Record<string, TItem>;

export interface MenuItem {
  label: string;
  href: string;
  icon?: string;
  external?: boolean;
  isCta?: boolean;
  children?: MenuItem[];
}

export interface MenuConfig {
  main?: MenuItem[];
  [key: string]: MenuItem[] | undefined;
}

export interface PageMeta {
  title: string;
  description: string;
}

export interface PageCollectionBinding {
  source: CollectionType;
  paramKey: string;
}

export interface PageConfig {
  id: string;
  slug: string;
  meta: PageMeta;
  sections: Section[];
  collection?: PageCollectionBinding;
  /** When `false`, Core does not render the global header from `site.json` for this page. Omitted = default (show if configured). */
  'global-header'?: boolean;
}

/** Whether the global `site.json` header should be rendered for this page. */
export function shouldRenderSiteGlobalHeader(page: PageConfig, site: SiteConfig): boolean {
  return site.header != null && page['global-header'] !== false;
}

export interface SiteIdentity {
  title: string;
  logoUrl?: string;
}

export interface SiteConfig {
  identity: SiteIdentity;
  header?: Section;
  footer: Section;
}

export interface ThemeTokenMap {
  [key: string]: string;
}

export interface ThemeColors {

  [key: string]: string;
}

export interface ThemeFontFamily {

  [key: string]: string | undefined;
}

export interface ThemeTypography {
  fontFamily: ThemeFontFamily;
}

export interface ThemeBorderRadius {

  [key: string]: string;
}

export interface ThemeTokens {
  colors: ThemeColors;
  typography: ThemeTypography;
  borderRadius: ThemeBorderRadius;
}

export interface ThemeConfig {
  name: string;
  tokens: ThemeTokens;
}

/**
 * PROJECT STATE (The Universal Data Bundle)
 * Moved to Kernel to serve as SSOT for Engine and Persistence.
 */
export interface ProjectState {
  page: PageConfig;
  site: SiteConfig;
  menu: MenuConfig;
  theme: ThemeConfig;
  collections?: Record<string, CollectionDocument<unknown>>;
}

export interface PageRendererProps {
  pageConfig: PageConfig;
  siteConfig: SiteConfig;
  menuConfig: MenuConfig;
  selectedId?: string | null;
}

END_OF_FILE_CONTENT
echo "Creating core/src/contract/types-engine.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/contract/types-engine.ts"
/**
 * Engine contract: Core must not import from src/components or src/data.
 */
import type React from 'react';
import type { LucideIcon } from 'lucide-react';
import type { CollectionDocument, MenuConfig, PageConfig, ProjectState, SiteConfig, ThemeConfig } from './kernel';

export interface SelectionPathSegment {
  fieldKey: string;
  itemId?: string;
}

export type SelectionPath = SelectionPathSegment[];

export interface PersistenceConfig {
  saveToFile?: (state: ProjectState, slug: string) => Promise<void>;
  hotSave?: (state: ProjectState, slug: string) => Promise<void>;
  coldSave?: (state: ProjectState, slug: string) => Promise<void>;
  showLocalSave?: boolean;
  showHotSave?: boolean;
  showColdSave?: boolean;
  flushUploadedAssets?: (urls: string[]) => Promise<Record<string, string>>;
}

export interface ThemeCssConfig {
  tenant: string;
  admin?: string;
}

export interface AddSectionConfig {
  addableSectionTypes?: string[];
  sectionTypeLabels?: Record<string, string>;
  getDefaultSectionData?: (sectionType: string) => Record<string, unknown>;
}

export interface LibraryImageEntry {
  id: string;
  url: string;
  alt: string;
  tags?: string[];
}

export interface AssetsConfig {
  assetsBaseUrl?: string;
  assetsManifest?: LibraryImageEntry[];
  /**
   * Uploads an image and returns the final canonical URL that must be persisted in JSON.
   *
   * Valid examples:
   * - /assets/images/foo.png
   * - /assets/tenant-a/foo.png
   * - https://cdn.example.com/foo.png
   *
   * Invalid examples:
   * - public/assets/foo.png
   * - C:\\foo\\bar.png
   * - data:image/png;base64,...
   */
  onAssetUpload?: (file: File) => Promise<string>;
}

export interface WebMcpConfig {
  enabled?: boolean;
  namespace?: string;
}

type SchemaLike = { parse: (v: unknown) => unknown; shape?: Record<string, unknown> };

export interface JsonPagesConfig {
  tenantId: string;
  basePath?: string;
  registry: Record<string, React.ComponentType<unknown>>;
  schemas: Record<string, SchemaLike>;
  /**
   * Optional registry of Zod submission schemas for sections that can be filled
   * by external agents (e.g. MCP-connected AI clients).
   *
   * Keyed by the same section-type strings used in `schemas`. Each value is a
   * Zod schema describing the section's *submission payload* (what the user
   * fills in) — distinct from `schemas` entries, which describe the section's
   * *UI configuration* (how the tenant author configures the section).
   *
   * When a section type appears on a page AND has an entry here, its JSON
   * Schema representation is emitted on the page contract as
   * `sectionSubmissionSchemas` (see `OlonJsPageContract`).
   *
   * The shape mirrors `schemas` (duck-typed on `{ parse, shape? }`) so core
   * does not force `zod` on consumers at the type level. In practice tenants
   * pass `z.object(...)` instances; the JSON Schema serializer casts to
   * `z.ZodTypeAny` at its own boundary.
   *
   * See `docs/decisions/ADR-0002-form-submission-schemas.md` for rationale,
   * tenant convention, and the full emission contract.
   */
  submissionSchemas?: Record<string, SchemaLike>;
  collectionSchemas?: Record<string, SchemaLike>;
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: MenuConfig;
  collections?: Record<string, CollectionDocument<unknown>>;
  refDocuments?: Record<string, unknown>;
  persistence?: Partial<PersistenceConfig>;
  themeCss: ThemeCssConfig;
  NotFoundComponent?: React.ComponentType;
  addSection?: AddSectionConfig;
  assets?: AssetsConfig;
  overlayDisabledSectionTypes?: string[];
  webmcp?: WebMcpConfig;
  iconRegistry?: Record<string, LucideIcon>;
}

END_OF_FILE_CONTENT
echo "Creating core/src/contract/webmcp-contracts.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/contract/webmcp-contracts.ts"
import { z } from 'zod';
import type { PageConfig, SiteConfig } from './kernel';
import type { JsonPagesConfig } from './types-engine';

const WEBMCP_TOOL_REQUEST_TYPE = 'olonjs:webmcp:tool-call';
const WEBMCP_TOOL_RESULT_TYPE = 'olonjs:webmcp:tool-result';

export interface WebMcpToolContract {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
}

export interface WebMcpSectionInstance {
  id: string;
  type: string;
  scope: 'global' | 'local';
  label: string;
}

export interface OlonJsPageContract {
  version: '1.0.0';
  kind: 'olonjs-page-contract';
  slug: string;
  title: string;
  description: string;
  manifestHref: string;
  systemPrompt: string;
  sectionTypes: string[];
  sectionInstances: WebMcpSectionInstance[];
  sectionSchemas: Record<string, Record<string, unknown>>;
  /**
   * Optional JSON Schema representations of submission payloads for form-capable
   * sections present on this page. Keyed by section type.
   *
   * Emitted only for section types that (a) actually appear on this page AND
   * (b) have an entry in `JsonPagesConfig.submissionSchemas`. Absent (not `{}`)
   * when no section on the page qualifies, to keep the contract tight.
   *
   * MCP agents consuming this contract can discover form shapes directly from
   * reading the page, without requiring a separate tool call.
   *
   * See `docs/decisions/ADR-0002-form-submission-schemas.md` (emission contract).
   */
  sectionSubmissionSchemas?: Record<string, Record<string, unknown>>;
  tools: WebMcpToolContract[];
}

export interface OlonJsPageManifest {
  version: '1.0.0';
  kind: 'olonjs-page-mcp-manifest';
  generatedAt: string;
  slug: string;
  title: string;
  description: string;
  contractHref: string;
  transport: {
    kind: 'window-message';
    requestType: string;
    resultType: string;
    target: 'window';
  };
  capabilities: {
    resources: Array<{
      uri: string;
      name: string;
      mimeType: string;
      description: string;
    }>;
  };
  sectionTypes: string[];
  sectionInstances: WebMcpSectionInstance[];
  tools: Array<Pick<WebMcpToolContract, 'name' | 'description'>>;
}

export interface OlonJsSiteManifestIndex {
  version: '1.0.0';
  kind: 'olonjs-mcp-manifest-index';
  generatedAt: string;
  pages: Array<{
    slug: string;
    title: string;
    description: string;
    manifestHref: string;
    contractHref: string;
    sectionTypes: string[];
  }>;
}

export interface BuildPageContractInput {
  slug: string;
  pageConfig: PageConfig;
  schemas: JsonPagesConfig['schemas'];
  submissionSchemas?: JsonPagesConfig['submissionSchemas'];
  siteConfig: SiteConfig;
}

export interface BuildSiteManifestInput {
  pages: Record<string, PageConfig>;
  schemas: JsonPagesConfig['schemas'];
  submissionSchemas?: JsonPagesConfig['submissionSchemas'];
  siteConfig: SiteConfig;
}

function cloneJson<T>(value: T): T {
  return value == null ? value : (JSON.parse(JSON.stringify(value)) as T);
}

function getTypeName(schema: z.ZodTypeAny): z.ZodFirstPartyTypeKind | undefined {
  return schema?._def?.typeName as z.ZodFirstPartyTypeKind | undefined;
}

function unwrapSchema(schema: z.ZodTypeAny) {
  let current: z.ZodTypeAny = schema;
  let isOptional = false;
  let isNullable = false;
  let defaultValue: unknown;

  for (;;) {
    const typeName = getTypeName(current);
    if (typeName === z.ZodFirstPartyTypeKind.ZodOptional) {
      isOptional = true;
      current = (current as z.ZodOptional<z.ZodTypeAny>)._def.innerType;
      continue;
    }
    if (typeName === z.ZodFirstPartyTypeKind.ZodDefault) {
      isOptional = true;
      if (defaultValue === undefined) {
        try {
          defaultValue = (current as z.ZodDefault<z.ZodTypeAny>)._def.defaultValue();
        } catch {
          defaultValue = undefined;
        }
      }
      current = (current as z.ZodDefault<z.ZodTypeAny>)._def.innerType;
      continue;
    }
    if (typeName === z.ZodFirstPartyTypeKind.ZodNullable) {
      isNullable = true;
      current = (current as z.ZodNullable<z.ZodTypeAny>)._def.innerType;
      continue;
    }
    break;
  }

  return { schema: current, isOptional, isNullable, defaultValue };
}

function withSchemaMetadata(
  schema: z.ZodTypeAny,
  jsonSchema: Record<string, unknown>,
  meta: ReturnType<typeof unwrapSchema>
): Record<string, unknown> {
  const next = cloneJson(jsonSchema) ?? {};
  if (schema.description && next.description == null) {
    next.description = schema.description;
  }
  if (meta.defaultValue !== undefined && next.default == null) {
    next.default = meta.defaultValue;
  }
  if (meta.isNullable) {
    return { anyOf: [next, { type: 'null' }] };
  }
  return next;
}

function unionToEnum(options: readonly z.ZodTypeAny[]): Record<string, unknown> | null {
  const values: unknown[] = [];
  let primitiveType: 'string' | 'number' | 'boolean' | null = null;

  for (const option of options) {
    const unwrapped = unwrapSchema(option).schema;
    const typeName = getTypeName(unwrapped);

    if (typeName === z.ZodFirstPartyTypeKind.ZodLiteral) {
      const literal = (unwrapped as z.ZodLiteral<unknown>)._def.value;
      values.push(literal);
      const literalType = typeof literal;
      if (literalType === 'string' || literalType === 'number' || literalType === 'boolean') {
        primitiveType = primitiveType ?? literalType;
        continue;
      }
      return null;
    }

    if (typeName === z.ZodFirstPartyTypeKind.ZodEnum) {
      values.push(...(unwrapped as z.ZodEnum<[string, ...string[]]>)._def.values);
      primitiveType = primitiveType ?? 'string';
      continue;
    }

    return null;
  }

  if (values.length === 0) return null;
  if (primitiveType === 'number') return { type: 'number', enum: values };
  if (primitiveType === 'boolean') return { type: 'boolean', enum: values };
  return { type: 'string', enum: values.map((value) => String(value)) };
}

function zodToJsonSchema(schema: z.ZodTypeAny): Record<string, unknown> {
  const meta = unwrapSchema(schema);
  const current = meta.schema;
  const typeName = getTypeName(current);

  switch (typeName) {
    case z.ZodFirstPartyTypeKind.ZodObject: {
      const shape = (current as z.AnyZodObject)._def.shape();
      const properties: Record<string, unknown> = {};
      const required: string[] = [];

      for (const [key, childSchema] of Object.entries(shape)) {
        const child = childSchema as z.ZodTypeAny;
        const childMeta = unwrapSchema(child);
        properties[key] = zodToJsonSchema(child);
        if (!childMeta.isOptional) required.push(key);
      }

      const objectSchema: Record<string, unknown> = {
        type: 'object',
        properties,
        additionalProperties: false,
      };
      if (required.length > 0) objectSchema.required = required;
      return withSchemaMetadata(schema, objectSchema, meta);
    }

    case z.ZodFirstPartyTypeKind.ZodString:
      return withSchemaMetadata(schema, { type: 'string' }, meta);

    case z.ZodFirstPartyTypeKind.ZodBoolean:
      return withSchemaMetadata(schema, { type: 'boolean' }, meta);

    case z.ZodFirstPartyTypeKind.ZodNumber: {
      const checks = Array.isArray((current as z.ZodNumber)._def.checks)
        ? (current as z.ZodNumber)._def.checks
        : [];
      const isInteger = checks.some((check) => check.kind === 'int');
      return withSchemaMetadata(schema, { type: isInteger ? 'integer' : 'number' }, meta);
    }

    case z.ZodFirstPartyTypeKind.ZodArray:
      return withSchemaMetadata(
        schema,
        { type: 'array', items: zodToJsonSchema((current as z.ZodArray<z.ZodTypeAny>)._def.type) },
        meta
      );

    case z.ZodFirstPartyTypeKind.ZodEnum:
      return withSchemaMetadata(
        schema,
        { type: 'string', enum: [...(current as z.ZodEnum<[string, ...string[]]>)._def.values] },
        meta
      );

    case z.ZodFirstPartyTypeKind.ZodLiteral: {
      const literal = (current as z.ZodLiteral<unknown>)._def.value;
      const primitiveType = literal === null ? 'null' : typeof literal;
      const literalSchema: Record<string, unknown> = { const: literal };
      if (primitiveType !== 'object') {
        literalSchema.type = primitiveType;
      }
      return withSchemaMetadata(schema, literalSchema, meta);
    }

    case z.ZodFirstPartyTypeKind.ZodRecord:
      return withSchemaMetadata(
        schema,
        {
          type: 'object',
          additionalProperties: zodToJsonSchema(
            (current as z.ZodRecord<z.ZodString, z.ZodTypeAny>)._def.valueType
          ),
        },
        meta
      );

    case z.ZodFirstPartyTypeKind.ZodUnion: {
      const options = (current as z.ZodUnion<readonly [z.ZodTypeAny, z.ZodTypeAny, ...z.ZodTypeAny[]]>)._def.options;
      const enumSchema = unionToEnum(options);
      if (enumSchema) return withSchemaMetadata(schema, enumSchema, meta);
      return withSchemaMetadata(
        schema,
        { anyOf: options.map((option) => zodToJsonSchema(option)) },
        meta
      );
    }

    default:
      return withSchemaMetadata(schema, {}, meta);
  }
}

function buildMutationInputSchema(): Record<string, unknown> {
  return {
    type: 'object',
    additionalProperties: false,
    properties: {
      slug: {
        type: 'string',
        description: 'Canonical page slug currently open in Studio.',
      },
      sectionId: {
        type: 'string',
        description: 'Concrete section instance id inside the current draft.',
      },
      sectionType: {
        type: 'string',
        description: 'Section type being updated (for example "hero" or "header"). Used to select the correct validation schema.',
      },
      scope: {
        type: 'string',
        enum: ['local', 'global'],
        default: 'local',
      },
      data: {
        type: 'object',
        description: 'Full replacement payload validated against the schema declared for sectionType.',
      },
      itemPath: {
        type: 'array',
        description: 'Optional root-to-leaf selection path for targeted field mutation.',
        items: {
          type: 'object',
          additionalProperties: false,
          properties: {
            fieldKey: { type: 'string' },
            itemId: { type: 'string' },
          },
          required: ['fieldKey'],
        },
      },
      value: {
        description: 'Value written to the final field targeted by itemPath.',
      },
      fieldKey: {
        type: 'string',
        description: 'Shorthand for a top-level scalar field update when itemPath is omitted.',
      },
    },
    required: ['sectionId'],
    oneOf: [
      { required: ['data'] },
      { required: ['itemPath', 'value'] },
      { required: ['fieldKey', 'value'] },
    ],
  };
}

function inferSectionLabel(section: { type?: string; data?: unknown }): string {
  const data = section.data && typeof section.data === 'object' ? (section.data as Record<string, unknown>) : {};
  if (typeof data.title === 'string' && data.title.trim()) return data.title.trim();
  if (typeof data.sectionTitle === 'string' && data.sectionTitle.trim()) return data.sectionTitle.trim();
  if (typeof data.label === 'string' && data.label.trim()) return data.label.trim();
  return section.type ?? 'section';
}

function buildToolName(): 'update-section' {
  return 'update-section';
}

export function buildPageContractHref(slug: string): string {
  return `/schemas/${slug}.schema.json`;
}

export function buildPageManifestHref(slug: string): string {
  return `/mcp-manifests/${slug}.json`;
}

function getPageSections(pageConfig: PageConfig, siteConfig: SiteConfig) {
  const pageSections = Array.isArray(pageConfig?.sections) ? pageConfig.sections : [];
  const globalSections: Array<(typeof pageSections)[number] & { scope: 'global' }> = [];

  if (siteConfig.header && pageConfig['global-header'] !== false) {
    globalSections.push({ ...siteConfig.header, scope: 'global' });
  }
  if (siteConfig.footer) {
    globalSections.push({ ...siteConfig.footer, scope: 'global' });
  }

  return [
    ...globalSections,
    ...pageSections.map((section) => ({ ...section, scope: 'local' as const })),
  ];
}

export function buildPageContract({
  slug,
  pageConfig,
  schemas,
  submissionSchemas,
  siteConfig,
}: BuildPageContractInput): OlonJsPageContract {
  const title = typeof pageConfig.meta?.title === 'string' ? pageConfig.meta.title : slug;
  const description = typeof pageConfig.meta?.description === 'string' ? pageConfig.meta.description : '';
  const pageSections = getPageSections(pageConfig, siteConfig);
  const sectionTypes = Array.from(new Set(pageSections.map((section) => String(section.type)).filter(Boolean)));

  const sectionSchemas = Object.fromEntries(
    sectionTypes
      .filter((sectionType) => schemas?.[sectionType] != null)
      .map((sectionType) => {
        const schema = schemas[sectionType] as z.ZodTypeAny;
        return [sectionType, zodToJsonSchema(schema)];
      })
  ) as Record<string, Record<string, unknown>>;

  const submissionSchemasEmitted = Object.fromEntries(
    sectionTypes
      .filter((sectionType) => submissionSchemas?.[sectionType] != null)
      .map((sectionType) => {
        const schema = submissionSchemas![sectionType] as z.ZodTypeAny;
        return [sectionType, zodToJsonSchema(schema)];
      })
  ) as Record<string, Record<string, unknown>>;

  const sectionInstances: WebMcpSectionInstance[] = pageSections.map((section) => ({
    id: section.id,
    type: String(section.type),
    scope: section.scope === 'global' ? 'global' : 'local',
    label: inferSectionLabel(section),
  }));

  const tools: WebMcpToolContract[] =
    sectionTypes.filter((sectionType) => sectionSchemas[sectionType] != null).length > 0
      ? [
          {
            name: buildToolName(),
            description:
              'Update a section field in the Studio draft. Does not persist — call save when all updates are complete. Use sectionType to select the matching schema from sectionSchemas.',
            inputSchema: buildMutationInputSchema(),
          },
          {
            name: 'save',
            description:
              'Persist all pending draft changes using the active save mode (local file, hot save, or save2repo). Call once after all update-section calls are complete.',
            inputSchema: { type: 'object', additionalProperties: false, properties: {} },
          },
        ]
      : [];

  const contract: OlonJsPageContract = {
    version: '1.0.0',
    kind: 'olonjs-page-contract',
    slug,
    title,
    description,
    manifestHref: buildPageManifestHref(slug),
    systemPrompt: `You are operating the "${title}" page in OlonJS Studio. Use only the declared tools and keep mutations valid against the section schema.`,
    sectionTypes,
    sectionInstances,
    sectionSchemas,
    tools,
  };

  if (Object.keys(submissionSchemasEmitted).length > 0) {
    contract.sectionSubmissionSchemas = submissionSchemasEmitted;
  }

  return contract;
}

export function buildPageManifest(input: BuildPageContractInput): OlonJsPageManifest {
  const contract = buildPageContract(input);
  return {
    version: '1.0.0',
    kind: 'olonjs-page-mcp-manifest',
    generatedAt: new Date().toISOString(),
    slug: input.slug,
    title: contract.title,
    description: contract.description,
    contractHref: buildPageContractHref(input.slug),
    transport: {
      kind: 'window-message',
      requestType: WEBMCP_TOOL_REQUEST_TYPE,
      resultType: WEBMCP_TOOL_RESULT_TYPE,
      target: 'window',
    },
    capabilities: {
      resources: [
        {
          uri: `olon://pages/${input.slug}`,
          name: `${contract.title} Data`,
          mimeType: 'application/json',
          description: `Structured content for the ${input.slug} page.`,
        },
        {
          uri: 'olon://pages',
          name: 'Site Map',
          mimeType: 'application/json',
          description: 'Structured content for the map of this site',
        },
      ],
    },
    sectionTypes: contract.sectionTypes,
    sectionInstances: contract.sectionInstances,
    tools: contract.tools.map(({ name, description }) => ({
      name,
      description,
    })),
  };
}

export function buildSiteManifest({
  pages,
  schemas,
  submissionSchemas,
  siteConfig,
}: BuildSiteManifestInput): OlonJsSiteManifestIndex {
  const pageEntries = Object.entries(pages ?? {}).sort(([a], [b]) => a.localeCompare(b));
  return {
    version: '1.0.0',
    kind: 'olonjs-mcp-manifest-index',
    generatedAt: new Date().toISOString(),
    pages: pageEntries.map(([slug, pageConfig]) => {
      const pageManifest = buildPageManifest({ slug, pageConfig, schemas, submissionSchemas, siteConfig });
      return {
        slug,
        title: pageManifest.title,
        description: pageManifest.description,
        manifestHref: buildPageManifestHref(slug),
        contractHref: buildPageContractHref(slug),
        sectionTypes: pageManifest.sectionTypes,
      };
    }),
  };
}

export function buildLlmsTxt(input: BuildSiteManifestInput): string {
  const siteTitle = input.siteConfig.identity?.title || 'OlonJS Site';
  const manifestIndex = buildSiteManifest(input);

  let markdown = `# ${siteTitle}\n\n`;

  if (manifestIndex.pages.some((page) => page.slug === 'home')) {
    const homePage = manifestIndex.pages.find((page) => page.slug === 'home');
    if (homePage?.description) {
      markdown += `${homePage.description}\n\n`;
    }
  }

  markdown += '> **AI Agents:** This site is built with OlonJS. It exposes a native Model Context Protocol (MCP) manifest for direct structural interaction. \n';
  markdown += '> To read the site map or access structured content, use the URI `olon://pages` or `olon://pages/[slug]`.\n';
  markdown += '> Endpoint: `/mcp-manifest.json`\n\n';
  markdown += '## Pages\n\n';

  for (const page of manifestIndex.pages) {
    const urlPath = page.slug === 'home' ? '/' : `/${page.slug}`;
    markdown += `- **[${page.title}](${urlPath})** (\`${page.slug}\`)\n`;
    if (page.description) {
      markdown += `  ${page.description}\n`;
    }
    markdown += `  *Contract:* \`${page.contractHref}\` | *Manifest:* \`${page.manifestHref}\`\n\n`;
  }

  return markdown.trim();
}

END_OF_FILE_CONTENT
echo "Creating core/src/contract/zod-schemas.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/contract/zod-schemas.ts"
/**
 * Internal Zod source of truth for the OlonJS public contract (ADR-0003).
 *
 * These schemas are the SOT for the JSON Schema artifacts published at
 * https://olon.js.org/schemas/v1/. They are NOT re-exported from the package
 * (Zod is internal authoring; JSON Schema is the public contract surface).
 *
 * The generator script (`scripts/bump-schemas.ts`) imports from this file
 * directly via relative path and emits Draft-07 JSON Schemas.
 *
 * ## Authoring gotchas (see ADR-0013)
 *
 * 1. **Field-level `.describe()` on `definitions`-registered schemas breaks
 *    the $ref.** `zod-to-json-schema` matches by reference identity. `.optional()`
 *    wraps the schema and preserves the inner reference (emits clean `$ref`).
 *    `.describe()` *clones* the schema with a new description, breaking identity:
 *    the lib decomposes the clone inline and emits per-property `$ref` like
 *    `#/definitions/Name/properties/<field>`. Always chain through `.optional()`
 *    when adding field-level descriptions to schemas registered in `definitions`,
 *    or place the description on the schema definition itself.
 *
 * 2. **Cross-ref placeholders must be required-by-default.** For top-level fields
 *    of `TenantManifestSchema` that the generator rewrites to cross-file `$ref`,
 *    use `z.object({}).passthrough()` (or any non-undefined-accepting type) —
 *    NOT `z.unknown()`. `z.unknown()` accepts `undefined` and produces
 *    non-required fields in the output JSON Schema.
 *
 * Fix order, per ADR-0003 §AD-3: if the generated JSON Schema is verbose,
 * semantically off, or harder to read than necessary, fix THIS file — never
 * the .schema.json output.
 */
import { z } from 'zod';
import type { MenuItem } from './kernel';

export const MenuItemSchema: z.ZodType<MenuItem> = z.lazy(() =>
  z
    .object({
      id: z.string().optional().describe('Stable identifier for this menu entry. Must be unique within its parent list when present. Optional in source data; the persistence layer assigns one if absent.'),
      label: z.string().describe('Visible link text. Plain text, no markdown.'),
      href: z.string().describe('Target URL. Accepts absolute (https://…), root-relative (/path), anchor (#id), mailto: and tel: schemes.'),
      icon: z.string().optional().describe('An icon slug from the theme\'s icon set (e.g. `arrow-right`), or an absolute URL to a custom asset. SVG is preferred for resolution independence.'),
      external: z.boolean().optional().describe('When true, the link points outside the current site and should typically open in a new tab.'),
      isCta: z.boolean().optional().describe('When true, this item is rendered with call-to-action emphasis rather than as a plain link.'),
      children: z.array(MenuItemSchema).optional().describe('Sub-items rendered as a nested menu. Recursive; depth is not limited by the contract.'),
    })
    .describe('A single navigation entry. Items may nest recursively via `children`.'),
);

export const MenuConfigSchema = z
  .object({
    main: z.array(MenuItemSchema).optional().describe('The default top-level menu. Conventionally the primary navigation.'),
  })
  .catchall(z.array(MenuItemSchema))
  .describe('Navigation menus, keyed by menu name. `main` is the default; additional named menus (footer, sidebar, …) sit alongside.');

export const SectionSchema = z
  .object({
    id: z.string().describe('Stable identifier for this section instance. Must be unique within its parent page or shell. Used as the addressable anchor for in-page navigation and for agent-driven section selection.'),
    type: z.string().describe('Section type identifier. Resolves to a concrete section schema published separately by the theme or tenant.'),
    data: z.record(z.string(), z.unknown()).describe('Section content payload. Shape is determined by the section type and validated against the type-specific schema, not by this contract.'),
    settings: z
      .record(z.string(), z.unknown())
      .optional()
      .describe('Optional rendering settings (padding, theme variant, container width, …). Shape is determined by the section type.'),
  })
  .describe('A page section: a self-contained, agent-addressable unit of content. The contract treats `data` and `settings` as open records; concrete shapes live in section-type schemas.');

export const CollectionItemSchema = z
  .object({
    id: z.string().describe('Stable collection item identifier. Must match the item key in its parent collection document and is used for routing, React keys, and agent addressing.'),
  })
  .catchall(z.unknown())
  .describe('Base shape for a collection entity. Tenant-specific fields are allowed as additional properties and are validated by the tenant collection schema.');

export const CollectionDocumentSchema = z
  .record(z.string(), CollectionItemSchema)
  .describe('COP collection document: a keyed record of entities independent from pages. Keys are stable entity identifiers; values must include the same stable `id` field.');

export const PageCollectionBindingSchema = z
  .object({
    source: z.string().regex(/^[a-z0-9-]+$/).describe('Collection source key, matching an entry in the tenant `collections` map and its collection document path.'),
    paramKey: z.string().regex(/^[a-zA-Z_][a-zA-Z0-9_]*$/).describe('Dynamic route parameter name used to select the active collection entity (for example `slug` in `libri/[slug]`).'),
  })
  .describe('Binds a dynamic page route to a collection source. At runtime, the route parameter selects `collection:current` for sections on this page.');

export const SiteIdentitySchema = z
  .object({
    title: z.string().describe('Human-readable site name. Used in page titles, social previews, and the default header brand.'),
    logoUrl: z.string().optional().describe('URL of the site logo, root-relative (`/brand/logo.svg`) or absolute. SVG is preferred for resolution independence; the theme decides aspect-ratio handling (wordmark vs. square mark).'),
  })
  .describe('Brand identity for a site: human-readable name and logo URL. Used by themes for the document title, header brand, social cards, and PWA manifests.');

export const SiteConfigSchema = z
  .object({
    identity: SiteIdentitySchema,
    header: SectionSchema.optional(),
    footer: SectionSchema,
  })
  .describe('Site-level configuration: brand identity, an optional global header section (rendered above every page unless the page opts out via `global-header: false`), and a required global footer section (rendered below every page).');

export const PageMetaSchema = z
  .object({
    title: z
      .string()
      .min(10)
      .describe('Page title used in `<title>`, social cards, and search results. Minimum 10 characters; aim for 30–60 for optimal display in search results.'),
    description: z
      .string()
      .min(50)
      .describe('Page description for SEO and social cards. Minimum 50 characters; aim for 120–160.'),
  })
  .describe('Page metadata for SEO, social previews, and the document `<head>`.');

export const PageContractSchema = z
  .object({
    id: z
      .string()
      .regex(/^[a-z0-9-]+-page$/)
      .describe('Stable page identifier. Convention: kebab-case ending in `-page` (e.g. `home-page`, `docs-getting-started-page`).'),
    slug: z
      .string()
      .regex(/^[a-z0-9-/[\]]+$/)
      .describe('URL path segment(s). Kebab-case; slashes allowed for nested routes. Dynamic COP routes use bracketed params (e.g. `libri/[slug]`).'),
    meta: PageMetaSchema,
    collection: PageCollectionBindingSchema.optional(),
    sections: z
      .array(SectionSchema)
      .describe('Ordered list of page sections rendered top-to-bottom. Each section follows the open Section shape; concrete data is determined by the section `type`.'),
    'global-header': z
      .boolean()
      .default(true)
      .describe('When `false`, this page opts out of the site-level global header. Defaults to `true` when omitted.'),
  })
  .describe('Full contract for a single page: identity, URL slug, SEO metadata, ordered sections, and global-header opt-out.');

/**
 * Cross-ref placeholders for TenantManifestSchema.
 *
 * `design`, `site`, `menu`, `page` are top-level canonical schemas with their
 * own `$id`. Inlining their full Zod here would duplicate them in
 * `tenant.schema.json`. Instead we emit `z.unknown()` placeholders and let the
 * generator rewrite the corresponding properties to cross-file `$ref` pointers
 * (see `crossRefs` on the tenant resource in `scripts/bump-schemas.ts`).
 *
 * This keeps Zod as the structural SOT and the manifest as a thin wrapper.
 */
export const TenantManifestSchema = z
  .object({
    identity: SiteIdentitySchema,
    design: z.object({}).passthrough(),
    site: z.object({}).passthrough(),
    menu: z.object({}).passthrough(),
    pages: z.array(z.object({}).passthrough()),
    collections: z.record(z.string(), z.object({}).passthrough()).optional(),
  })
  .describe(
    'Top-level Olon tenant manifest. Bundles a tenant\'s complete public contract: brand identity, design system tokens, site shell, navigation, full page list, and optional COP collections. Each top-level field references a separately-published canonical schema; this manifest is the entry point for agents discovering or validating a complete Olon tenant.',
  );

END_OF_FILE_CONTENT
mkdir -p "core/src/dna"
echo "Creating core/src/dna/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/dna/index.ts"
/**
 * @olonjs/core — DNA surface
 *
 * Framework-owned utilities, schemas, hooks, and types that tenants
 * consume but MUST NOT own or modify. Re-exported from the main
 * `@olonjs/core` barrel so tenants keep a single import origin.
 *
 * If a tenant needs to customize any of these, the customization
 * belongs in a tenant-authored wrapper — NOT in a fork of the file.
 */

export * from './lib/base-schemas';
export * from './lib/cloudSaveStream';
export * from './lib/deploySteps';
export * from './lib/OlonFormsContext';

export * from './types/deploy';

END_OF_FILE_CONTENT
mkdir -p "core/src/dna/lib"
echo "Creating core/src/dna/lib/OlonFormsContext.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/dna/lib/OlonFormsContext.ts"
import { createContext, useContext } from 'react';

export type FormStatus = 'idle' | 'submitting' | 'success' | 'error';

export interface FormState {
  status: FormStatus;
  message: string;
}

const DEFAULT_FORM_STATE: FormState = { status: 'idle', message: '' };

/**
 * Context holding the submission state of every olon-managed form,
 * keyed by the form's id attribute (or anchorId).
 * Provided by App.tsx via useOlonForms().
 */
export const OlonFormsContext = createContext<Record<string, FormState>>({});

/**
 * Read the submission state for a specific form.
 * @param formId - must match the id attribute on the <form> element.
 */
export function useFormState(formId: string): FormState {
  const states = useContext(OlonFormsContext);
  return states[formId] ?? DEFAULT_FORM_STATE;
}

END_OF_FILE_CONTENT
echo "Creating core/src/dna/lib/base-schemas.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/dna/lib/base-schemas.ts"
import { z } from 'zod';

/**
 * Image picker field: object { url, alt? } with ui:image-picker for Form Factory.
 * Use in section data and resolve with resolveAssetUrl(url, tenantId) in View.
 */
export const ImageSelectionSchema = z
  .object({
    url: z.string(),
    alt: z.string().optional(),
  }) 
  .describe('ui:image-picker');

/**
 * Base schemas shared by section capsules (CIP governance).
 * Capsules extend these for consistent anchorId, array items, and settings.
 */
export const BaseSectionData = z.object({
  id: z.string().optional(),
  anchorId: z.string().optional().describe('ui:text'),
});

export const BaseArrayItem = z.object({
  id: z.string().optional(),
});

export const BaseCollectionItem = z.object({
  id: z.string(),
});

export const BaseSectionSettingsSchema = z.object({
  paddingTop: z.enum(['none', 'sm', 'md', 'lg', 'xl', '2xl']).default('md').describe('ui:select'),
  paddingBottom: z.enum(['none', 'sm', 'md', 'lg', 'xl', '2xl']).default('md').describe('ui:select'),
  theme: z.enum(['dark', 'light', 'accent']).default('dark').describe('ui:select'),
  container: z.enum(['boxed', 'fluid']).default('boxed').describe('ui:select'),
});

export const CtaSchema = z.object({
  id: z.string().optional(),
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  variant: z.enum(['primary', 'secondary', 'accent']).default('primary').describe('ui:select'),
});

/**
 * Mixin for any section capsule that includes a contact form.
 * Merge into the section data schema to expose recipientEmail
 * as an editable field in the Studio inspector.
 * The View must set data-olon-recipient={data.recipientEmail} on the <form>.
 */
export const WithFormRecipient = z.object({
  recipientEmail: z.string().optional().describe('ui:text'),
});

END_OF_FILE_CONTENT
echo "Creating core/src/dna/lib/cloudSaveStream.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/dna/lib/cloudSaveStream.ts"
import type { StepId } from '../types/deploy';

interface SaveStreamStepEvent {
  id: StepId;
  status: 'running' | 'done';
  label?: string;
}

interface SaveStreamLogEvent {
  stepId: StepId;
  message: string;
}

interface SaveStreamDoneEvent {
  deployUrl?: string;
  commitSha?: string;
}

interface SaveStreamErrorEvent {
  message?: string;
}

interface StartCloudSaveStreamInput {
  apiBaseUrl: string;
  apiKey: string;
  path: string;
  content: unknown;
  message?: string;
  signal?: AbortSignal;
  onStep: (event: SaveStreamStepEvent) => void;
  onLog?: (event: SaveStreamLogEvent) => void;
  onDone: (event: SaveStreamDoneEvent) => void;
}

function parseSseEventBlock(rawBlock: string): { event: string; data: string } | null {
  const lines = rawBlock
    .split('\n')
    .map((line) => line.trimEnd())
    .filter((line) => line.length > 0);

  if (lines.length === 0) return null;

  let eventName = 'message';
  const dataLines: string[] = [];
  for (const line of lines) {
    if (line.startsWith('event:')) {
      eventName = line.slice(6).trim();
      continue;
    }
    if (line.startsWith('data:')) {
      dataLines.push(line.slice(5).trim());
    }
  }
  return { event: eventName, data: dataLines.join('\n') };
}

export async function startCloudSaveStream(input: StartCloudSaveStreamInput): Promise<void> {
  const response = await fetch(`${input.apiBaseUrl}/save-stream`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${input.apiKey}`,
    },
    body: JSON.stringify({
      path: input.path,
      content: input.content,
      message: input.message,
    }),
    signal: input.signal,
  });

  if (!response.ok || !response.body) {
    const body = (await response.json().catch(() => ({}))) as SaveStreamErrorEvent;
    throw new Error(body.message ?? `Cloud save stream failed: ${response.status}`);
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let receivedDone = false;

  while (true) {
    const { value, done } = await reader.read();
    if (!done) {
      buffer += decoder.decode(value, { stream: true });
    } else {
      buffer += decoder.decode();
    }

    const chunks = buffer.split('\n\n');
    buffer = done ? '' : (chunks.pop() ?? '');

    for (const chunk of chunks) {
      const parsed = parseSseEventBlock(chunk);
      if (!parsed) continue;
      if (!parsed.data) continue;

      if (parsed.event === 'step') {
        const payload = JSON.parse(parsed.data) as SaveStreamStepEvent;
        input.onStep(payload);
      } else if (parsed.event === 'log') {
        const payload = JSON.parse(parsed.data) as SaveStreamLogEvent;
        input.onLog?.(payload);
      } else if (parsed.event === 'error') {
        const payload = JSON.parse(parsed.data) as SaveStreamErrorEvent;
        throw new Error(payload.message ?? 'Cloud save failed.');
      } else if (parsed.event === 'done') {
        const payload = JSON.parse(parsed.data) as SaveStreamDoneEvent;
        input.onDone(payload);
        receivedDone = true;
      }
    }

    if (done) break;
  }

  if (!receivedDone) {
    throw new Error('Cloud save stream ended before completion.');
  }
}


END_OF_FILE_CONTENT
echo "Creating core/src/dna/lib/deploySteps.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/dna/lib/deploySteps.ts"
import type { DeployStep } from '../types/deploy';

export const DEPLOY_STEPS: readonly DeployStep[] = [
  {
    id: 'commit',
    label: 'Commit',
    verb: 'Committing',
    poem: ['Crystallizing your edit', 'into permanent history.'],
    color: '#60a5fa',
    glyph: '◈',
    duration: 2200,
  },
  {
    id: 'push',
    label: 'Push',
    verb: 'Pushing',
    poem: ['Sending your vision', 'across the wire.'],
    color: '#a78bfa',
    glyph: '◎',
    duration: 2800,
  },
  {
    id: 'build',
    label: 'Build',
    verb: 'Building',
    poem: ['Assembling the pieces,', 'brick by digital brick.'],
    color: '#f59e0b',
    glyph: '⬡',
    duration: 7500,
  },
  {
    id: 'live',
    label: 'Live',
    verb: 'Going live',
    poem: ['Your content', 'is now breathing.'],
    color: '#34d399',
    glyph: '✦',
    duration: 1600,
  },
] as const;


END_OF_FILE_CONTENT
mkdir -p "core/src/dna/types"
echo "Creating core/src/dna/types/deploy.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/dna/types/deploy.ts"
export type StepId = 'commit' | 'push' | 'build' | 'live';

export type StepState = 'pending' | 'active' | 'done';

export type DeployPhase = 'idle' | 'running' | 'done' | 'error';

export interface DeployStep {
  id: StepId;
  label: string;
  verb: string;
  poem: [string, string];
  color: string;
  glyph: string;
  duration: number;
}


END_OF_FILE_CONTENT
echo "Creating core/src/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/index.ts"
/**
 * @olonjs/core - Public API (legacy alias: @jsonpages/core)
 */

// Conceptual surfaces for the future split.
export * as contract from './contract';
export * as kernel from './kernel';
export * as runtime from './runtime';
export * as studio from './studio';
export * as webmcp from './webmcp';

// Flat legacy surface kept intact for current tenants.
export * from './kernel';
export * from './studio/events';
export * from './lib/utils';
export * from './runtime';
export * from './dna';
export {
  applyValueAtSelectionPath,
  buildWebMcpToolName,
  buildWebMcpSaveToolName,
  createWebMcpToolInputSchema,
  createWebMcpSaveToolInputSchema,
  ensureWebMcpRuntime,
  parseWebMcpMutationArgs,
  registerWebMcpTool,
  resolveWebMcpMutationData,
  type WebMcpMutationArgs,
} from './webmcp';

// Utils
export { resolveAssetUrl } from './runtime/assets/asset-resolver';
export { themeManager } from './runtime/theme/theme-manager';

// Admin
export { AdminSidebar, type LayerItem, type OnUpdateSection } from './studio/admin/AdminSidebar';
export { StudioStage } from './studio/admin/StudioStage';
export { PreviewEntry } from './studio/admin/PreviewEntry';
export { AddSectionLibrary } from './studio/admin/AddSectionLibrary';
export { FormFactory } from './studio/admin/FormFactory';
export { InputWidgets, type WidgetType } from './studio/admin/InputRegistry';

END_OF_FILE_CONTENT
mkdir -p "core/src/kernel"
echo "Creating core/src/kernel/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/kernel/index.ts"
/**
 * Conceptual public surface for OlonJS kernel/contract concerns.
 *
 * This barrel is intentionally package-local for now: it lets us
 * converge imports around the future split without breaking the current
 * @olonjs/core entrypoint.
 */
export * from '../contract/kernel';
export * from '../contract/types-engine';
export * from '../lib/shared-types';
export {
  applyMenuRefBindingsToDraft,
  applySiteMenuRefBindingsToDraft,
  getMenuRefBindings,
  resolveHeaderMenuItems,
  resolveRuntimeConfig,
  resolveSectionMenuItems,
} from '../contract/config-resolver';

END_OF_FILE_CONTENT
mkdir -p "core/src/lib"
echo "Creating core/src/lib/DefaultNotFound.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/lib/DefaultNotFound.tsx"
/**
 * Default 404 used by the Engine when no NotFoundComponent is provided in config.
 * No dependency on src/components (e.g. IconResolver); safe for NPM package.
 */
import React from 'react';
import { Link } from 'react-router-dom';

export const DefaultNotFound: React.FC = () => (
  <div
    style={
      {
        '--local-bg': 'var(--color-background)',
        '--local-text': 'var(--color-text)',
        '--local-text-muted': 'var(--color-text-muted)',
        '--local-primary': 'var(--color-primary)',
        '--local-radius-md': 'var(--radius-md)',
      } as React.CSSProperties
    }
    className="min-h-screen flex flex-col items-center justify-center bg-[var(--local-bg)] px-6"
  >
    <h1 className="text-6xl font-bold text-[var(--local-text)] mb-4">404</h1>
    <p className="text-xl text-[var(--local-text-muted)] mb-8">Page not found</p>
    <Link
      to="/"
      className="inline-flex items-center gap-2 px-6 py-3 rounded-[var(--local-radius-md)] bg-[var(--local-primary)] text-[var(--local-bg)] font-semibold text-sm hover:opacity-90 transition-opacity"
    >
      Back to Home
    </Link>
  </div>
);

END_OF_FILE_CONTENT
echo "Creating core/src/lib/shared-types.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/lib/shared-types.ts"
/**
 * Shared types between Admin Engine and Input Registry.
 */
export interface BaseWidgetProps<T = unknown> {
  label: string;
  value: T;
  onChange: (val: T) => void;
  options?: string[];
}

END_OF_FILE_CONTENT
echo "Creating core/src/lib/utils.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/lib/utils.ts"
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

END_OF_FILE_CONTENT
mkdir -p "core/src/runtime"
echo "Creating core/src/runtime-entry.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime-entry.ts"
/**
 * @olonjs/core/runtime — runtime-only public surface.
 *
 * This entry produces the `dist/olonjs-core-runtime.js` bundle. It
 * exports a strict subset of the full `@olonjs/core` API: enough for a
 * tenant to mount the visitor engine, render pages, read theme tokens,
 * resolve asset URLs, and use the no-op StudioContext. It deliberately
 * does NOT export:
 *   - JsonPagesEngine, StudioRoute, PreviewRoute (full-engine surface)
 *   - AdminSidebar, FormFactory, StudioStage, AddSectionLibrary,
 *     PreviewEntry, InputWidgets, FormFactory (studio admin UI)
 *   - admin-skin.css inline asset
 *
 * The exports are listed explicitly (no `export *`) so the bundle
 * boundary is auditable: anything reachable from this module is in the
 * runtime bundle, anything not listed here is not.
 *
 * See ADR-0009 (D1, D2, D7, D8). Wired into `package.json` via the
 * `"./runtime"` subpath export in Phase 2 / Task 2.3.
 */

// ── Engine ────────────────────────────────────────────────────────
export { OlonJSEngine, type OlonJSEngineProps } from './runtime/engine/OlonJSEngine';

// ── Configuration types ───────────────────────────────────────────
export type {
  JsonPagesConfig,
  LibraryImageEntry,
  AddSectionConfig,
} from './contract/types-engine';

// ── Config resolution (used by SSG entry) ────────────────────────
export { resolveRuntimeConfig } from './contract/config-resolver';
export { resolvePublicPageDocument } from './runtime/engine/public-page-document';

// ── Utility ──────────────────────────────────────────────────────
// cn() is the className merge helper used by every tenant ui/* component.
// Re-exported here so tenant code can import it from /runtime without
// bringing in the full Studio bundle.
export { cn } from './lib/utils';

// ── Kernel types & registries (augmentable via MTRP) ──────────────
// The tenant's MTRP module augmentation (`declare module
// '@olonjs/core/runtime'`) needs these interfaces to attach to.
// Without this re-export the augmentation has no anchor and
// JsonPagesConfig.PageConfig.sections falls back to FallbackSection.
export type {
  CollectionDocument,
  CollectionItem,
  CollectionItemRegistry,
  CollectionType,
  SectionDataRegistry,
  SectionSettingsRegistry,
  BaseSection,
  SectionType,
  MenuItem,
  PageCollectionBinding,
  PageConfig,
  SiteConfig,
  ThemeConfig,
  MenuConfig,
  ProjectState,
} from './contract/kernel';

// ── Config context (runtime-side state container) ─────────────────
export {
  ConfigProvider,
  useConfig,
  type ConfigContextValue,
} from './runtime/config/ConfigContext';

// ── Rendering primitives ──────────────────────────────────────────
export { PageRenderer } from './runtime/rendering/PageRenderer';
export { SectionRenderer } from './runtime/rendering/SectionRenderer';

// ── Theme ─────────────────────────────────────────────────────────
export { ThemeLoader, type ThemeLoaderProps } from './runtime/theme/ThemeLoader';
// `themeManager` (singleton, identity-bearing) and `buildThemeVariableMap`
// (pure function) live in the same source file. ADR-0012 externalizes the
// file as a unit in the full-bundle Vite config, so the runtime bundle must
// re-export every symbol the full bundle's public surface forwards through
// `runtime/theme/index.ts → runtime/index.ts → src/index.ts`.
export { themeManager, buildThemeVariableMap } from './runtime/theme/theme-manager';

// ── URL utilities ─────────────────────────────────────────────────
export { normalizeBasePath, withBasePath } from './runtime/url';

// ── Assets ────────────────────────────────────────────────────────
export { resolveAssetUrl } from './runtime/assets/asset-resolver';

// ── Default 404 ───────────────────────────────────────────────────
export { DefaultNotFound } from './lib/DefaultNotFound';

// ── Studio surface kept in runtime per ADR-0009 D3 ───────────────
// These are the no-op-friendly Studio pieces that even visitor mode
// uses (SectionRenderer reads `useStudio().mode` for IDAC overlay
// gating). They live in studio/ for legacy reasons; conceptually they
// are runtime concerns.
export { StudioProvider, useStudio } from './studio/StudioContext';
export { STUDIO_EVENTS } from './studio/events';

// ── Icon registry ─────────────────────────────────────────────────
export {
  IconRegistryContext,
  useIconRegistry,
  type IconRegistry,
} from './runtime/icons/IconRegistryContext';

// ── DNA surface ───────────────────────────────────────────────────
// Tenant-owned framework primitives: deploy steps + types, cloud save
// stream, OlonForms context, base section schemas. Verified not to
// transitively import from studio/admin (only `react` and `zod`).
// These need to be reachable from tenants that adopt @olonjs/core/runtime
// because the tenant App.tsx uses them in both visitor and admin paths
// (forms render in visitor; deploy/save flows are admin-only but their
// constants are statically imported).
export * from './dna';

END_OF_FILE_CONTENT
mkdir -p "core/src/runtime/assets"
echo "Creating core/src/runtime/assets/asset-resolver.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/assets/asset-resolver.test.ts"
import { describe, expect, it } from 'vitest';

import {
  isCanonicalAssetUrl,
  isTransientAssetUrl,
  resolveAssetUrl,
} from './asset-resolver';

describe('resolveAssetUrl', () => {
  it('keeps absolute URLs unchanged', () => {
    expect(resolveAssetUrl('https://cdn.example.com/foo.png', 'tenant-a')).toBe(
      'https://cdn.example.com/foo.png'
    );
  });

  it('keeps /assets URLs unchanged', () => {
    expect(resolveAssetUrl('/assets/images/foo.png', 'tenant-a')).toBe(
      '/assets/images/foo.png'
    );
  });

  it('normalizes assets/ URLs to browser-facing /assets/ URLs', () => {
    expect(resolveAssetUrl('assets/images/foo.png', 'tenant-a')).toBe(
      '/assets/images/foo.png'
    );
  });

  it('resolves relative filenames into tenant-scoped asset URLs', () => {
    expect(resolveAssetUrl('hero.png', 'tenant-a')).toBe('/assets/tenant-a/hero.png');
  });

  it('resolves paths under sub-route base path', () => {
    expect(resolveAssetUrl('assets/images/foo.png', 'tenant-a', '/core/')).toBe(
      '/core/assets/images/foo.png'
    );
    expect(resolveAssetUrl('/assets/images/foo.png', 'tenant-a', '/core/')).toBe(
      '/core/assets/images/foo.png'
    );
  });

  it('keeps /uploaded-assets URLs unchanged', () => {
    expect(resolveAssetUrl('/uploaded-assets/hero.png', 'tenant-a')).toBe(
      '/uploaded-assets/hero.png'
    );
  });
});

describe('asset URL guards', () => {
  it('accepts canonical asset URLs and rejects transient or filesystem paths', () => {
    expect(isCanonicalAssetUrl('/assets/images/foo.png')).toBe(true);
    expect(isCanonicalAssetUrl('/uploaded-assets/foo.png')).toBe(true);
    expect(isCanonicalAssetUrl('https://cdn.example.com/foo.png')).toBe(true);
    expect(isCanonicalAssetUrl('assets/images/foo.png')).toBe(false);
    expect(isCanonicalAssetUrl('public/assets/foo.png')).toBe(false);
    expect(isCanonicalAssetUrl('C:\\assets\\foo.png')).toBe(false);
    expect(isCanonicalAssetUrl('data:image/png;base64,aaaa')).toBe(false);
  });

  it('detects transient preview-only URLs', () => {
    expect(isTransientAssetUrl('data:image/png;base64,aaaa')).toBe(true);
    expect(isTransientAssetUrl('blob:http://localhost/123')).toBe(true);
    expect(isTransientAssetUrl('/assets/images/foo.png')).toBe(false);
  });
});

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/assets/asset-resolver.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/assets/asset-resolver.ts"
/**
 * Centralized asset resolution for tenant-scoped static assets.
 */
import { withBasePath } from '../url';

const FILE_EXTENSION_RE = /\.(jpg|jpeg|png|gif|svg|pdf|webp|mp4|webm|ogg)$/i;
const WINDOWS_PATH_RE = /^[a-zA-Z]:[\\/]/;
const ABSOLUTE_URL_RE = /^[a-zA-Z][a-zA-Z\d+\-.]*:/;

const isAbsoluteUrl = (path: string): boolean => ABSOLUTE_URL_RE.test(path);

export const isTransientAssetUrl = (path: string): boolean => {
  const value = path.trim();
  return value.startsWith('data:') || value.startsWith('blob:');
};

export const isCanonicalAssetUrl = (path: string): boolean => {
  const value = path.trim();
  if (!value || value.startsWith('#') || isTransientAssetUrl(value)) return false;
  if (value.startsWith('public/') || value.startsWith('public\\')) return false;
  if (WINDOWS_PATH_RE.test(value) || value.startsWith('\\\\')) return false;
  if (isAbsoluteUrl(value)) return true;
  return value.startsWith('/assets/') || value.startsWith('/uploaded-assets/');
};

export const resolveAssetUrl = (
  path: string,
  tenantId: string = 'default',
  basePath: string = '/'
): string => {
  const value = path.trim();
  if (!value) return value;

  if (isAbsoluteUrl(value) || value.startsWith('#')) {
    return value;
  }

  if (value.startsWith('/assets/') || value.startsWith('/uploaded-assets/')) return withBasePath(value, basePath);
  if (value.startsWith('assets/')) return withBasePath(`/${value}`, basePath);

  const hasFileExtension = FILE_EXTENSION_RE.test(value);
  if (!hasFileExtension) {
    return withBasePath(value.startsWith('/') ? value : `/${value}`, basePath);
  }

  const cleanPath = value.replace(/^\//, '');
  return withBasePath(`/assets/${tenantId}/${cleanPath}`, basePath);
};

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/assets/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/assets/index.ts"
export {
  isCanonicalAssetUrl,
  isTransientAssetUrl,
  resolveAssetUrl,
} from './asset-resolver';

END_OF_FILE_CONTENT
mkdir -p "core/src/runtime/config"
echo "Creating core/src/runtime/config/ConfigContext.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/config/ConfigContext.tsx"
/**
 * Inversion of Control: registry and schemas are provided by the Engine from Tenant config.
 * SectionRenderer and AdminSidebar consume these; they do not import ComponentRegistry or SECTION_SCHEMAS.
 */
import React, { createContext, useContext } from 'react';
import type { AssetsConfig, JsonPagesConfig } from '../../contract/types-engine';

type Registry = JsonPagesConfig['registry'];
type Schemas = JsonPagesConfig['schemas'];

export interface ConfigContextValue {
  registry: Registry;
  schemas: Schemas;
  tenantId?: string;
  basePath?: string;
  assets?: AssetsConfig;
  overlayDisabledSectionTypes?: string[];
}

const ConfigContext = createContext<ConfigContextValue | undefined>(undefined);

export const ConfigProvider: React.FC<{
  config: Pick<
    JsonPagesConfig,
    'registry' | 'schemas' | 'tenantId' | 'basePath' | 'assets' | 'overlayDisabledSectionTypes'
  >;
  children: React.ReactNode;
}> = ({ config, children }) => (
  <ConfigContext.Provider
    value={{
      registry: config.registry,
      schemas: config.schemas,
      tenantId: config.tenantId,
      basePath: config.basePath,
      assets: config.assets,
      overlayDisabledSectionTypes: config.overlayDisabledSectionTypes,
    }}
  >
    {children}
  </ConfigContext.Provider>
);

export function useConfig(): ConfigContextValue {
  const context = useContext(ConfigContext);
  if (context === undefined) {
    throw new Error('useConfig must be used within ConfigProvider');
  }
  return context;
}

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/config/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/config/index.ts"
export {
  ConfigProvider,
  useConfig,
  type ConfigContextValue,
} from './ConfigContext';

END_OF_FILE_CONTENT
mkdir -p "core/src/runtime/engine"
echo "Creating core/src/runtime/engine/EngineErrorBoundary.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/EngineErrorBoundary.tsx"
import React, { Component, type ErrorInfo, type ReactNode } from 'react';

/**
 * Engine-level error boundary: prevents black screen on any render error
 * and surfaces a visible error UI.
 */
export class EngineErrorBoundary extends Component<
  { children: ReactNode },
  { hasError: boolean; error: Error | null }
> {
  constructor(props: { children: ReactNode }) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('[JsonPages Engine]', error, errorInfo);
  }

  render() {
    if (this.state.hasError && this.state.error) {
      return (
        <div
          style={{
            minHeight: '100vh',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 24,
            backgroundColor: '#0f172a',
            color: '#e2e8f0',
            fontFamily: 'ui-sans-serif, system-ui, sans-serif',
          }}
        >
          <h1 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: 8 }}>
            JsonPages Engine Error
          </h1>
          <pre
            style={{
              maxWidth: '100%',
              overflow: 'auto',
              padding: 16,
              backgroundColor: 'rgba(0,0,0,0.3)',
              borderRadius: 8,
              fontSize: 12,
              marginTop: 8,
            }}
          >
            {this.state.error.message}
          </pre>
        </div>
      );
    }
    return this.props.children;
  }
}

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/JsonPagesEngine.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/JsonPagesEngine.tsx"
/**
 * JsonPagesEngine — full engine surface.
 *
 * Mounts visitor + admin + preview routes. Imports admin-skin.css and
 * the studio routes (StudioRoute, PreviewRoute), so this engine pulls
 * Studio code into the bundle of any consumer that imports it.
 *
 * For visitor-only deployments, prefer `OlonJSEngine` from
 * `@olonjs/core/runtime` (ADR-0009 D7). That sibling never references
 * studio admin modules; the package-level export split keeps Studio
 * out of the runtime bundle entirely.
 *
 * The actual provider tree, theme bootstrap, and router setup live in
 * `JsonPagesEngineCore`. This file only declares the route tree.
 */

import React from 'react';
import { Route } from 'react-router-dom';
import type { JsonPagesConfig } from '../../contract/types-engine';
import {
  JsonPagesEngineCore,
  JsonPagesRouterShell,
  type EngineRuntimeContext,
} from './JsonPagesEngineCore';
import { PreviewRoute } from './PreviewRoute';
import { StudioRoute } from './StudioRoute';
import { VisitorRoute } from './VisitorRoute';

import defaultAdminCss from '../../studio/admin/admin-skin.css?inline';

const FALLBACK_ADMIN_CSS = `
:root { --background: #0f172a; --foreground: #f1f5f9; }
body { background-color: var(--background); color: var(--foreground); }
`;

export interface JsonPagesEngineProps {
  config: JsonPagesConfig;
}

function buildFullRoutes(ctx: EngineRuntimeContext) {
  const visitorProps = {
    pageRegistry: ctx.pageRegistry,
    siteConfig: ctx.siteConfig,
    menuConfig: ctx.menuConfig,
    themeConfig: ctx.themeConfig,
    collections: ctx.collections,
    collectionSchemas: ctx.collectionSchemas,
    refDocuments: ctx.refDocuments,
    tenantCss: ctx.tenantCss,
    adminCss: ctx.adminCss,
    NotFoundComponent: ctx.NotFoundComponent,
  };

  const studioProps = {
    pageRegistry: ctx.pageRegistry,
    schemas: ctx.schemas,
    siteConfig: ctx.siteConfig,
    menuConfig: ctx.menuConfig,
    themeConfig: ctx.themeConfig,
    collections: ctx.collections,
    collectionSchemas: ctx.collectionSchemas,
    refDocuments: ctx.refDocuments,
    tenantCss: ctx.tenantCss,
    adminCss: ctx.adminCss,
    addSectionConfig: ctx.addSectionConfig,
    addableSectionTypes: ctx.addableSectionTypes,
    webMcp: ctx.webmcp,
    saveToFile: ctx.persistence.saveToFile,
    hotSave: ctx.persistence.hotSave,
    coldSave: ctx.persistence.coldSave,
    showLocalSave: ctx.persistence.showLocalSave,
    showHotSave: ctx.persistence.showHotSave,
    showColdSave: ctx.persistence.showColdSave,
  };

  return (
    <Route element={<JsonPagesRouterShell />}>
      <Route path="/" element={<VisitorRoute {...visitorProps} />} />
      <Route path="/*" element={<VisitorRoute {...visitorProps} />} />
      <Route path="/admin" element={<StudioRoute {...studioProps} />} />
      <Route path="/admin/*" element={<StudioRoute {...studioProps} />} />
      <Route
        path="/admin/preview"
        element={<PreviewRoute tenantCss={ctx.tenantCss} adminCss={ctx.adminCss} />}
      />
      <Route
        path="/admin/preview/*"
        element={<PreviewRoute tenantCss={ctx.tenantCss} adminCss={ctx.adminCss} />}
      />
      <Route path="*" element={<ctx.NotFoundComponent />} />
    </Route>
  );
}

export function JsonPagesEngine({ config }: JsonPagesEngineProps) {
  const adminCss =
    typeof defaultAdminCss === 'string' ? defaultAdminCss : FALLBACK_ADMIN_CSS;
  return (
    <JsonPagesEngineCore
      config={config}
      adminCss={adminCss}
      routesBuilder={buildFullRoutes}
    />
  );
}

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/JsonPagesEngineCore.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/JsonPagesEngineCore.tsx"
/**
 * Engine composition root — internal, never exported from the package.
 *
 * Both `JsonPagesEngine` (full, mounts admin + preview routes) and
 * `OlonJSEngine` (runtime-only, mounts visitor route only) wrap this Core.
 * The Core handles everything route-agnostic: provider tree, theme +
 * webmcp bootstrap, base-path normalization, the `<RouterProvider>` itself.
 *
 * The caller supplies a `routesBuilder(ctx)` callback that receives the
 * resolved runtime context and returns the route tree to mount. This lets
 * the Core stay studio-agnostic — `OlonJSEngine`'s caller never references
 * `studio/admin/` modules, so tree-shaking and the explicit subpath split
 * (per ADR-0009 D1, D4) keep Studio out of the runtime bundle.
 *
 * See ADR-0009 for the architectural decisions, docs/plans/core-studio-split.md
 * for the implementation plan (Task 1.3).
 */

import React, { useEffect, useMemo, useState } from 'react';
import {
  createBrowserRouter,
  createRoutesFromElements,
  Outlet,
  RouterProvider,
  ScrollRestoration,
} from 'react-router-dom';
import { resolveRuntimeConfig } from '../../contract/config-resolver';
import type { JsonPagesConfig } from '../../contract/types-engine';
import { ensureWebMcpRuntime } from '../../webmcp';
import { DefaultNotFound } from '../../lib/DefaultNotFound';
import { ConfigProvider } from '../config/ConfigContext';
import { themeManager } from '../theme/theme-manager';
import { normalizeBasePath } from '../url';
import { IconRegistryContext } from '../icons/IconRegistryContext';
import { EngineErrorBoundary } from './EngineErrorBoundary';

/**
 * Resolved runtime context handed to the route builder. Anything a route
 * (visitor or studio) might need is exposed here so the caller never has
 * to recompute derived state.
 */
export interface EngineRuntimeContext {
  registry: NonNullable<JsonPagesConfig['registry']>;
  schemas: NonNullable<JsonPagesConfig['schemas']>;
  pageRegistry: NonNullable<JsonPagesConfig['pages']>;
  siteConfig: JsonPagesConfig['siteConfig'];
  menuConfig: JsonPagesConfig['menuConfig'];
  themeConfig: JsonPagesConfig['themeConfig'];
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
  addSectionConfig: JsonPagesConfig['addSection'];
  addableSectionTypes: string[];
  webmcp: JsonPagesConfig['webmcp'];
  persistence: {
    saveToFile: NonNullable<JsonPagesConfig['persistence']>['saveToFile'];
    hotSave: NonNullable<JsonPagesConfig['persistence']>['hotSave'];
    coldSave: NonNullable<JsonPagesConfig['persistence']>['coldSave'];
    showLocalSave: boolean;
    showHotSave: boolean;
    showColdSave: boolean;
  };
  routerBasePath: string;
  tenantCss: string;
  /**
   * The full engine injects the Studio admin skin here; the runtime engine
   * passes an empty string. Routes that only render in tenant/visitor mode
   * (i.e. the `ThemeLoader` with `mode="tenant"`) ignore this value.
   */
  adminCss: string;
  NotFoundComponent: React.ComponentType;
}

export interface JsonPagesEngineCoreProps {
  config: JsonPagesConfig;
  /**
   * Returns the full route tree to mount under the data router. The
   * callback receives the resolved runtime context. The tree is wrapped
   * in the router shell (with `<ScrollRestoration />`) by the Core.
   */
  routesBuilder: (ctx: EngineRuntimeContext) => React.ReactElement;
  /**
   * Studio admin skin CSS injected at startup. The full engine passes the
   * `?inline`-imported admin-skin.css; the runtime engine passes `''` so
   * studio assets stay out of the runtime bundle (ADR-0009 D6).
   */
  adminCss?: string;
}

/**
 * Data-router shell — `<ScrollRestoration />` only works under
 * `<RouterProvider>` (not legacy `<BrowserRouter>`). Renders matched routes
 * via `<Outlet />`.
 */
function JsonPagesRouterShell() {
  return (
    <>
      <ScrollRestoration />
      <Outlet />
    </>
  );
}

export function JsonPagesEngineCore({ config, routesBuilder, adminCss = '' }: JsonPagesEngineCoreProps) {
  const {
    registry = {},
    schemas = {},
    basePath = '/',
    pages: pageRegistry = {},
    siteConfig,
    themeConfig,
    menuConfig,
    collections,
    collectionSchemas,
    refDocuments,
    themeCss,
    addSection: addSectionConfig,
    NotFoundComponent = DefaultNotFound,
  } = config;

  const addableSectionTypes: string[] =
    addSectionConfig?.addableSectionTypes ??
    (Object.keys(schemas).filter((type) => type !== 'header' && type !== 'footer') as string[]);

  const persistence = {
    saveToFile: config.persistence?.saveToFile,
    hotSave: config.persistence?.hotSave,
    coldSave: config.persistence?.coldSave,
    showLocalSave: config.persistence?.showLocalSave ?? true,
    showHotSave: config.persistence?.showHotSave ?? false,
    showColdSave: config.persistence?.showColdSave ?? false,
  };

  // tenantCss flows through the engine config (`themeCss.tenant`) and is
  // owned by the consuming tenant. adminCss is supplied by the caller
  // (the full engine wrapper passes the inlined admin-skin.css string;
  // the runtime engine passes '').
  const tenantCss = typeof themeCss?.tenant === 'string' ? themeCss.tenant : '';
  const resolvedAdminCss =
    typeof themeCss?.admin === 'string' ? themeCss.admin : adminCss;

  const baseResolvedRuntime = useMemo(
    () =>
      resolveRuntimeConfig({
        pages: pageRegistry,
        siteConfig,
        themeConfig,
        menuConfig,
        collections,
        collectionSchemas,
        refDocuments,
      }),
    [pageRegistry, siteConfig, themeConfig, menuConfig, collections, collectionSchemas, refDocuments]
  );

  const [isReady, setIsReady] = useState(false);
  const routerBasePath = normalizeBasePath(basePath);

  useEffect(() => {
    try {
      if (baseResolvedRuntime.themeConfig?.tokens) {
        themeManager.setTheme(baseResolvedRuntime.themeConfig);
      }
    } catch (error) {
      console.warn('[JsonPages] setTheme failed', error);
    }

    if (config.webmcp?.enabled) {
      ensureWebMcpRuntime();
    }

    setIsReady(true);
  }, [baseResolvedRuntime.themeConfig, config.webmcp?.enabled]);

  const ctx: EngineRuntimeContext = {
    registry,
    schemas,
    pageRegistry,
    siteConfig,
    menuConfig,
    themeConfig: baseResolvedRuntime.themeConfig,
    collections,
    collectionSchemas,
    refDocuments,
    addSectionConfig,
    addableSectionTypes,
    webmcp: config.webmcp,
    persistence,
    routerBasePath,
    tenantCss,
    adminCss: resolvedAdminCss,
    NotFoundComponent,
  };

  const router = useMemo(() => {
    const routes = createRoutesFromElements(routesBuilder(ctx));
    return createBrowserRouter(routes, { basename: routerBasePath });
    // The `ctx` object is recreated each render but its members are
    // stable references derived from `config` props; the routesBuilder
    // is a pure function of those. We re-memo on the same set of
    // dependencies the previous monolithic engine used, plus the
    // builder identity (in practice, the wrapper engines export a
    // module-level constant, so identity is stable).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    NotFoundComponent,
    addSectionConfig,
    addableSectionTypes,
    resolvedAdminCss,
    baseResolvedRuntime.themeConfig,
    menuConfig,
    collections,
    collectionSchemas,
    pageRegistry,
    persistence.coldSave,
    persistence.hotSave,
    persistence.saveToFile,
    persistence.showColdSave,
    persistence.showHotSave,
    persistence.showLocalSave,
    refDocuments,
    routerBasePath,
    schemas,
    siteConfig,
    tenantCss,
    config.webmcp,
    routesBuilder,
  ]);

  if (!isReady) {
    return (
      <div
        style={{
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: '#0f172a',
          color: '#94a3b8',
          fontFamily: 'ui-sans-serif, system-ui, sans-serif',
          fontSize: 14,
        }}
      >
        Loading...
      </div>
    );
  }

  return (
    <EngineErrorBoundary>
      <IconRegistryContext.Provider value={config.iconRegistry ?? {}}>
        <ConfigProvider
          config={{
            registry,
            schemas,
            tenantId: config.tenantId ?? 'default',
            basePath: routerBasePath,
            assets: config.assets,
            overlayDisabledSectionTypes: config.overlayDisabledSectionTypes,
          }}
        >
          <RouterProvider router={router} />
        </ConfigProvider>
      </IconRegistryContext.Provider>
    </EngineErrorBoundary>
  );
}

// Internal export for the wrapper engines that need the same shell name.
// Not exported from the package's public API.
export { JsonPagesRouterShell };

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/OlonJSEngine.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/OlonJSEngine.tsx"
/**
 * OlonJSEngine — runtime-only engine surface.
 *
 * Sibling of `JsonPagesEngine`. Same `JsonPagesConfig` prop shape, same
 * provider tree, same router setup — but mounts only the visitor route.
 * Has zero transitive imports from `studio/admin/` or `studio/orchestration/`,
 * so when this module is the entry point of `@olonjs/core/runtime` (per
 * ADR-0009 D1, D2, D7) the resulting bundle does not contain Studio code.
 *
 * If a user navigates to `/admin` on a deployment built around this
 * engine, the request falls through to `DefaultNotFound` (or the
 * tenant's `NotFoundComponent`). Public sites that don't host an editor
 * should adopt this engine for visitor traffic and fall back to
 * `JsonPagesEngine` only on admin paths (see ADR-0009 D7 + Task 3.1
 * for the tenant adoption pattern).
 *
 * What's deliberately omitted vs. JsonPagesEngine:
 * - No `StudioRoute`, `PreviewRoute` mounting.
 * - No `admin-skin.css?inline` import. The runtime engine passes an
 *   empty string for `adminCss`; routes mounted here only run
 *   `ThemeLoader` in `mode="tenant"`, which ignores `adminCss` (verified
 *   in Task 1.2). The visitor-relevant `[data-radix-portal]` z-index
 *   rule was migrated to the tenant's own index.css.
 *
 * See ADR-0009 and docs/plans/core-studio-split.md (Task 1.4).
 */

import React from 'react';
import { Route } from 'react-router-dom';
import type { JsonPagesConfig } from '../../contract/types-engine';
import {
  JsonPagesEngineCore,
  JsonPagesRouterShell,
  type EngineRuntimeContext,
} from './JsonPagesEngineCore';
import { VisitorRoute } from './VisitorRoute';

export interface OlonJSEngineProps {
  config: JsonPagesConfig;
}

function buildRuntimeRoutes(ctx: EngineRuntimeContext) {
  const visitorProps = {
    pageRegistry: ctx.pageRegistry,
    siteConfig: ctx.siteConfig,
    menuConfig: ctx.menuConfig,
    themeConfig: ctx.themeConfig,
    collections: ctx.collections,
    collectionSchemas: ctx.collectionSchemas,
    refDocuments: ctx.refDocuments,
    tenantCss: ctx.tenantCss,
    adminCss: ctx.adminCss, // empty string at the Core level for runtime; ignored by ThemeLoader in tenant mode
    NotFoundComponent: ctx.NotFoundComponent,
  };

  return (
    <Route element={<JsonPagesRouterShell />}>
      <Route path="/" element={<VisitorRoute {...visitorProps} />} />
      <Route path="/*" element={<VisitorRoute {...visitorProps} />} />
      <Route path="*" element={<ctx.NotFoundComponent />} />
    </Route>
  );
}

export function OlonJSEngine({ config }: OlonJSEngineProps) {
  // adminCss is intentionally omitted (defaults to '' in the Core).
  return <JsonPagesEngineCore config={config} routesBuilder={buildRuntimeRoutes} />;
}

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/PreviewRoute.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/PreviewRoute.tsx"
import React from 'react';
import { PreviewEntry } from '../../studio/admin/PreviewEntry';
import { ThemeLoader } from '../theme/ThemeLoader';

export interface PreviewRouteProps {
  tenantCss: string;
  adminCss: string;
}

export const PreviewRoute: React.FC<PreviewRouteProps> = ({ tenantCss, adminCss }) => (
  <ThemeLoader mode="tenant" tenantCss={tenantCss} adminCss={adminCss}>
    <PreviewEntry />
  </ThemeLoader>
);

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/StudioRoute.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/StudioRoute.tsx"
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { AddSectionLibrary } from '../../studio/admin/AddSectionLibrary';
import { AdminSidebar, type LayerItem } from '../../studio/admin/AdminSidebar';
import { StudioStage } from '../../studio/admin/StudioStage';
import { appendDraftSection, reorderPageSections } from '../../studio/orchestration/section-ops';
import { useStudioPersistence } from '../../studio/orchestration/useStudioPersistence';
import { useStudioSelectionState } from '../../studio/orchestration/useStudioSelectionState';
import {
  applyCollectionRefBindingsToDraft,
  applyMenuRefBindingsToDraft,
  resolveCollectionContext,
  resolveRuntimeConfig,
} from '../../contract/config-resolver';
import type { JsonPagesConfig, SelectionPath } from '../../contract/types-engine';
import type { MenuConfig, PageConfig, ProjectState, Section, SiteConfig } from '../../contract/kernel';
import { StudioProvider } from '../../studio/StudioContext';
import { ThemeLoader } from '../theme/ThemeLoader';
import { STUDIO_EVENTS } from '../../studio/events';
import {
  buildWebMcpToolName,
  buildWebMcpSaveToolName,
  createWebMcpToolInputSchema,
  createWebMcpSaveToolInputSchema,
  ensureWebMcpRuntime,
  parseWebMcpMutationArgs,
  registerWebMcpTool,
  resolveWebMcpMutationData,
} from '../../webmcp';
import {
  buildPageContractHref,
  buildPageManifestHref,
  syncHeadLink,
  syncWebMcpJsonLd,
} from './head-sync';
import {
  isRecord,
  normalizeSlugSegments,
  resolvePageMatchFromRegistry,
  resolveSlugFromPathname,
} from './route-utils';

export interface StudioRouteProps {
  pageRegistry: Record<string, PageConfig>;
  schemas: JsonPagesConfig['schemas'];
  siteConfig: SiteConfig;
  menuConfig: MenuConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
  tenantCss: string;
  adminCss: string;
  addSectionConfig: JsonPagesConfig['addSection'];
  addableSectionTypes: string[];
  webMcp?: JsonPagesConfig['webmcp'];
  saveToFile?: (state: ProjectState, slug: string) => Promise<void>;
  hotSave?: (state: ProjectState, slug: string) => Promise<void>;
  coldSave?: (state: ProjectState, slug: string) => Promise<void>;
  showLocalSave?: boolean;
  showHotSave?: boolean;
  showColdSave?: boolean;
}

export const StudioRoute: React.FC<StudioRouteProps> = ({
  pageRegistry,
  schemas,
  siteConfig,
  menuConfig,
  themeConfig,
  collections,
  collectionSchemas,
  refDocuments,
  tenantCss,
  adminCss,
  addSectionConfig,
  addableSectionTypes,
  webMcp,
  saveToFile,
  hotSave,
  coldSave,
  showLocalSave = true,
  showHotSave = false,
  showColdSave = false,
}) => {
  const location = useLocation();
  const slug = resolveSlugFromPathname(location.pathname, 'admin');
  const navigate = useNavigate();
  const pageSlugs = Object.keys(pageRegistry).sort((a, b) =>
    a === 'home' ? -1 : b === 'home' ? 1 : a.localeCompare(b)
  );
  const [draft, setDraft] = useState<PageConfig | null>(null);
  const [hasChanges, setHasChanges] = useState(false);
  const cloneMenuConfig = useCallback((value: unknown): MenuConfig => {
    try {
      return JSON.parse(JSON.stringify(value ?? {})) as MenuConfig;
    } catch {
      return {} as MenuConfig;
    }
  }, []);
  const getInitialMenuDraft = useCallback((): MenuConfig => {
    const refMenu =
      refDocuments?.['src/data/config/menu.json'] ??
      refDocuments?.['config/menu.json'] ??
      refDocuments?.['menu.json'];
    return cloneMenuConfig(refMenu ?? menuConfig);
  }, [cloneMenuConfig, menuConfig, refDocuments]);
  const cloneCollectionsConfig = useCallback((value: unknown): JsonPagesConfig['collections'] => {
    try {
      return JSON.parse(JSON.stringify(value ?? {})) as JsonPagesConfig['collections'];
    } catch {
      return {};
    }
  }, []);
  const getInitialCollectionsDraft = useCallback((): JsonPagesConfig['collections'] => {
    const fromRefs: NonNullable<JsonPagesConfig['collections']> = {};
    for (const [alias, value] of Object.entries(refDocuments ?? {})) {
      const normalizedAlias = alias.replace(/\\/g, '/');
      const match = normalizedAlias.match(/(?:^|\/)collections\/([^/]+)\/\1\.json$/);
      if (match?.[1]) {
        fromRefs[match[1]] = value as Record<string, unknown>;
      }
    }
    return cloneCollectionsConfig({
      ...fromRefs,
      ...(collections ?? {}),
    });
  }, [cloneCollectionsConfig, collections, refDocuments]);
  const [globalDraft, setGlobalDraft] = useState<SiteConfig>(() => {
    try {
      const base = JSON.parse(JSON.stringify(siteConfig ?? {})) as SiteConfig;
      if (!base.identity) base.identity = { title: 'Site' };
      return base;
    } catch {
      return siteConfig;
    }
  });
  const [addSectionLibraryOpen, setAddSectionLibraryOpen] = useState(false);
  const [menuDraft, setMenuDraft] = useState<MenuConfig>(() => getInitialMenuDraft());
  const [collectionsDraft, setCollectionsDraft] = useState<JsonPagesConfig['collections']>(() => getInitialCollectionsDraft());
  const [sidebarWidth, setSidebarWidth] = useState(400);
  const {
    activeSectionId,
    clearSelection,
    expandedItemPath,
    scrollToSectionId,
    selected,
    setActiveSectionId,
    setExpandedItemPath,
    setScrollToSectionId,
    setSelected,
  } = useStudioSelectionState();
  const pageMatch = useMemo(
    () => resolvePageMatchFromRegistry(pageRegistry, slug),
    [pageRegistry, slug]
  );
  const draftRegistrySlug = pageMatch?.registrySlug ?? slug;
  const persistenceSlug = draftRegistrySlug;
  const collectionContext = useMemo(
    () => pageMatch ? resolveCollectionContext(pageMatch.page, pageMatch.params, collectionsDraft) : null,
    [collectionsDraft, pageMatch]
  );
  const resolvedRuntime = useMemo(
    () =>
      resolveRuntimeConfig({
        pages: draft ? { [draftRegistrySlug]: draft } : {},
        siteConfig: globalDraft,
        themeConfig,
        menuConfig: menuDraft,
        collections: collectionsDraft,
        collectionSchemas,
        collectionContext,
        refDocuments,
      }),
    [draft, draftRegistrySlug, globalDraft, themeConfig, menuDraft, collectionsDraft, collectionSchemas, collectionContext, refDocuments]
  );
  const resolvedDraft = draft ? resolvedRuntime.pages[draftRegistrySlug] ?? draft : null;
  const resolvedCollectionContext = resolvedRuntime.collectionContext;
  const draftRef = useRef<PageConfig | null>(draft);
  const globalDraftRef = useRef<SiteConfig>(globalDraft);
  const menuDraftRef = useRef<MenuConfig>(menuDraft);
  const collectionsDraftRef = useRef<JsonPagesConfig['collections']>(collectionsDraft);
  const sidebarMin = 360;
  const sidebarMax = 920;
  const {
    buildProjectState,
    hotSaveInProgress,
    hotSaveSuccessFeedback,
    persistProjectState,
    requestInlineFlush,
    runHotSave,
    saveSuccessFeedback,
  } = useStudioPersistence({
    slug: persistenceSlug,
    saveToFile,
    hotSave,
    authoredSiteConfig: siteConfig,
    themeConfig,
    collections: collectionsDraft,
    collectionSchemas,
    refDocuments,
  });

  const commitCollectionsDraft = useCallback(
    (nextCollectionsDraft: JsonPagesConfig['collections']) => {
      collectionsDraftRef.current = nextCollectionsDraft;
      setCollectionsDraft(nextCollectionsDraft);
      return nextCollectionsDraft;
    },
    []
  );

  useEffect(() => {
    draftRef.current = draft;
  }, [draft]);

  useEffect(() => {
    globalDraftRef.current = globalDraft;
  }, [globalDraft]);

  useEffect(() => {
    menuDraftRef.current = menuDraft;
  }, [menuDraft]);

  useEffect(() => {
    collectionsDraftRef.current = collectionsDraft;
  }, [collectionsDraft]);

  const handleResizeStart = useCallback((e: React.PointerEvent) => {
    e.preventDefault();
    const handleEl = e.currentTarget as HTMLElement;
    handleEl.setPointerCapture(e.pointerId);
    const startX = e.clientX;
    const startWidth = sidebarWidth;
    const onPointerMove = (moveEvent: PointerEvent) => {
      const delta = startX - moveEvent.clientX;
      const next = Math.min(sidebarMax, Math.max(sidebarMin, startWidth + delta));
      setSidebarWidth(next);
    };
    const onPointerUp = () => {
      handleEl.releasePointerCapture(e.pointerId);
      handleEl.removeEventListener('pointermove', onPointerMove);
      handleEl.removeEventListener('pointerup', onPointerUp);
      handleEl.removeEventListener('pointercancel', onPointerUp);
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    };
    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
    handleEl.addEventListener('pointermove', onPointerMove);
    handleEl.addEventListener('pointerup', onPointerUp);
    handleEl.addEventListener('pointercancel', onPointerUp);
  }, [sidebarWidth]);

  const allLayers: LayerItem[] = draft
    ? [
        ...(globalDraft.header ? [{ id: globalDraft.header.id, type: globalDraft.header.type, scope: 'global' as const, title: 'Header' }] : []),
        ...draft.sections.map((s) => ({
          id: s.id,
          type: s.type,
          scope: 'local' as const,
          title: (s.data as Record<string, unknown>)?.title as string | undefined ?? (s.data as Record<string, unknown>)?.titleHighlight as string | undefined,
        })),
        ...(globalDraft.footer ? [{ id: globalDraft.footer.id, type: globalDraft.footer.type, scope: 'global' as const, title: 'Footer' }] : []),
      ]
    : [];

  useEffect(() => {
    const data = resolvePageMatchFromRegistry(pageRegistry, slug)?.page;
    if (data) setDraft(JSON.parse(JSON.stringify(data)));
    clearSelection();
    setHasChanges(false);
  }, [clearSelection, slug, pageRegistry]);

  useEffect(() => {
    setMenuDraft(getInitialMenuDraft());
  }, [getInitialMenuDraft]);

  useEffect(() => {
    setCollectionsDraft(getInitialCollectionsDraft());
  }, [getInitialCollectionsDraft]);

  const getAuthoredGlobalSection = useCallback(
    (site: SiteConfig, sectionId: string): Section | null => {
      if (site.header?.id === sectionId) return site.header;
      if (site.footer?.id === sectionId) return site.footer;
      return null;
    },
    []
  );

  const getResolvedGlobalSection = useCallback(
    (site: SiteConfig, sectionId: string): Section | null => {
      if (site.header?.id === sectionId) return site.header;
      if (site.footer?.id === sectionId) return site.footer;
      return null;
    },
    []
  );

  const applyGlobalSectionUpdate = useCallback(
    (
      sectionId: string,
      nextData: Record<string, unknown>,
      currentGlobalDraft: SiteConfig,
      currentResolvedSite: SiteConfig,
      currentMenuDraft: MenuConfig
    ): { nextGlobalDraft: SiteConfig; nextMenuDraft: MenuConfig } => {
      const authoredSection = getAuthoredGlobalSection(currentGlobalDraft, sectionId);
      const resolvedSection = getResolvedGlobalSection(currentResolvedSite, sectionId);
      if (!authoredSection || !resolvedSection) {
        return { nextGlobalDraft: currentGlobalDraft, nextMenuDraft: currentMenuDraft };
      }

      const { normalizedData, menuDraft: nextMenuDraft } = applyMenuRefBindingsToDraft(
        authoredSection.data,
        nextData,
        currentMenuDraft
      );

      const nextSection = { ...authoredSection, data: normalizedData } as Section;
      const nextGlobalDraft =
        authoredSection.type === 'header'
          ? { ...currentGlobalDraft, header: nextSection }
          : { ...currentGlobalDraft, footer: nextSection };

      return { nextGlobalDraft, nextMenuDraft };
    },
    [getAuthoredGlobalSection, getResolvedGlobalSection]
  );

  const handleResetToFile = useCallback(() => {
    const data = resolvePageMatchFromRegistry(pageRegistry, slug)?.page;
    if (data) setDraft(JSON.parse(JSON.stringify(data)));
    clearSelection();
    setHasChanges(false);
  }, [clearSelection, slug, pageRegistry]);

  const handleReorderSection = useCallback(
    (sectionId: string, newIndex: number, currentDraft: PageConfig) => {
      setDraft(reorderPageSections(currentDraft, sectionId, newIndex));
      setHasChanges(true);
    },
    []
  );

  const executeWebMcpMutation = useCallback(
    async (rawArgs: unknown) => {
      const args = parseWebMcpMutationArgs(rawArgs);
      const normalizedSlug = typeof args.slug === 'string' ? normalizeSlugSegments(args.slug) : slug;
      if (normalizedSlug !== slug) {
        throw new Error(`WebMCP slug mismatch. Active Studio slug is "${slug}", received "${normalizedSlug}".`);
      }

      await requestInlineFlush();

      const currentDraft = draftRef.current;
      const currentGlobalDraft = globalDraftRef.current;
      const currentMenuDraft = menuDraftRef.current;
      const currentCollectionsDraft = collectionsDraftRef.current;
      if (!currentDraft) {
        throw new Error('Studio draft is not ready yet.');
      }

      const scope = args.scope === 'global' ? 'global' : 'local';
      let sectionTypeToUse = args.sectionType;

      if (scope === 'global') {
        const targetSection =
          currentGlobalDraft.header?.id === args.sectionId
            ? currentGlobalDraft.header
            : currentGlobalDraft.footer?.id === args.sectionId
              ? currentGlobalDraft.footer
              : null;

        if (!targetSection) {
          throw new Error(`Global section "${args.sectionId}" was not found.`);
        }

        if (!sectionTypeToUse) {
          sectionTypeToUse = targetSection.type;
        } else if (targetSection.type !== sectionTypeToUse) {
          throw new Error(`Section "${args.sectionId}" is type "${targetSection.type}", not "${sectionTypeToUse}".`);
        }

        const schema = schemas[sectionTypeToUse];
        if (!schema || typeof schema.parse !== 'function') {
          throw new Error(`Missing schema for section type "${sectionTypeToUse}".`);
        }

        const resolvedCurrentSection = getResolvedGlobalSection(resolvedRuntime.siteConfig, args.sectionId);
        const currentData =
          resolvedCurrentSection && isRecord(resolvedCurrentSection.data)
            ? resolvedCurrentSection.data
            : isRecord(targetSection.data)
              ? targetSection.data
              : {};
        const nextData = resolveWebMcpMutationData(currentData, args);
        const parsedData = schema.parse(nextData) as Record<string, unknown>;
        const { nextGlobalDraft, nextMenuDraft } = applyGlobalSectionUpdate(
          args.sectionId,
          parsedData,
          currentGlobalDraft,
          resolvedRuntime.siteConfig,
          currentMenuDraft
        );
        globalDraftRef.current = nextGlobalDraft;
        menuDraftRef.current = nextMenuDraft;
        setGlobalDraft(nextGlobalDraft);
        setMenuDraft(nextMenuDraft);
      } else {
        const targetSection = currentDraft.sections.find((section) => section.id === args.sectionId);
        if (!targetSection) {
          throw new Error(`Local section "${args.sectionId}" was not found in page "${slug}".`);
        }

        if (!sectionTypeToUse) {
          sectionTypeToUse = targetSection.type;
        } else if (targetSection.type !== sectionTypeToUse) {
          throw new Error(`Section "${args.sectionId}" is type "${targetSection.type}", not "${sectionTypeToUse}".`);
        }

        const schema = schemas[sectionTypeToUse];
        if (!schema || typeof schema.parse !== 'function') {
          throw new Error(`Missing schema for section type "${sectionTypeToUse}".`);
        }

        const currentData = isRecord(targetSection.data) ? targetSection.data : {};
        const nextData = resolveWebMcpMutationData(currentData, args);
        const parsedData = schema.parse(nextData) as Record<string, unknown>;
        const collectionResult = applyCollectionRefBindingsToDraft(
          targetSection.data,
          parsedData,
          currentCollectionsDraft,
          resolvedCollectionContext,
          collectionSchemas
        );

        const nextDraft = {
          ...currentDraft,
          sections: currentDraft.sections.map((section) =>
            section.id === args.sectionId ? ({ ...section, data: collectionResult.normalizedData } as Section) : section
          ),
        };
        commitCollectionsDraft(collectionResult.collectionsDraft);
        draftRef.current = nextDraft;
        setDraft(nextDraft);
      }

      setSelected({ id: args.sectionId, type: sectionTypeToUse, scope });
      setExpandedItemPath(Array.isArray(args.itemPath) ? args.itemPath : null);
      setHasChanges(true);

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              ok: true,
              slug,
              sectionId: args.sectionId,
              sectionType: sectionTypeToUse,
              scope,
            }),
          },
        ],
        isError: false,
      };
    },
    [applyGlobalSectionUpdate, collectionSchemas, commitCollectionsDraft, getResolvedGlobalSection, requestInlineFlush, resolvedCollectionContext, resolvedRuntime.siteConfig, schemas, slug]
  );

  const executeWebMcpSave = useCallback(
    async () => {
      await requestInlineFlush();
      const currentDraft = draftRef.current;
      const currentGlobalDraft = globalDraftRef.current;
      const currentMenuDraft = menuDraftRef.current;
      const currentCollectionsDraft = collectionsDraftRef.current;
      if (!currentDraft) {
        throw new Error('Studio draft is not ready yet.');
      }

      if (showHotSave && hotSave) {
        await runHotSave(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft, () => setHasChanges(false));
      } else if (showLocalSave && saveToFile) {
        await persistProjectState(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft, () => setHasChanges(false));
      } else if (showColdSave && coldSave) {
        await coldSave(buildProjectState(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft), persistenceSlug);
        setHasChanges(false);
      } else {
        throw new Error('No save mode is configured for this tenant.');
      }

      return {
        content: [{ type: 'text', text: JSON.stringify({ ok: true, slug: persistenceSlug }) }],
        isError: false,
      };
    },
    [showHotSave, hotSave, showLocalSave, saveToFile, showColdSave, coldSave, requestInlineFlush, runHotSave, persistProjectState, buildProjectState, persistenceSlug]
  );

  const handleWebMcpToolCall = useCallback(
    async (toolName: string, rawArgs: unknown) => {
      if (toolName === buildWebMcpToolName()) return executeWebMcpMutation(rawArgs);
      if (toolName === buildWebMcpSaveToolName()) return executeWebMcpSave();
      throw new Error(`Unknown WebMCP tool "${toolName}".`);
    },
    [executeWebMcpMutation, executeWebMcpSave]
  );

  const handleStudioMessage = useCallback(
    (event: MessageEvent) => {
      if (event.origin !== window.location.origin) return;
      if (event.data.type === STUDIO_EVENTS.SECTION_SELECT) {
        setSelected(event.data.section);
        const itemPath = event.data.itemPath;
        if (Array.isArray(itemPath) && itemPath.length > 0) {
          setExpandedItemPath((itemPath as SelectionPath).map((s) => ({
            fieldKey: s.fieldKey,
            ...(s.itemId != null ? { itemId: String(s.itemId) } : {}),
          })));
        } else {
          setExpandedItemPath(null);
        }
      }
      if (event.data.type === STUDIO_EVENTS.INLINE_FIELD_UPDATE) {
        const sectionId = typeof event.data.sectionId === 'string' ? event.data.sectionId : null;
        const fieldKey = typeof event.data.fieldKey === 'string' ? event.data.fieldKey : null;
        if (sectionId && fieldKey) {
          setDraft((prev) => {
            if (!prev) return prev;
            const nextDraft: PageConfig = {
              ...prev,
              sections: prev.sections.map((section) =>
                section.id === sectionId
                  ? {
                      ...section,
                      data: {
                        ...(section.data as Record<string, unknown>),
                        [fieldKey]: event.data.value,
                      },
                    } as Section
                  : section
              ),
            };
            draftRef.current = nextDraft;
            return nextDraft;
          });
          setHasChanges(true);
        }
      }
      if (event.data.type === STUDIO_EVENTS.ACTIVE_SECTION_CHANGED) {
        setActiveSectionId(event.data.activeSectionId ?? null);
      }
      if (event.data.type === 'jsonpages:section-reorder' && draftRef.current) {
        const { sectionId, newIndex } = event.data as { sectionId?: string; newIndex?: number };
        if (typeof sectionId === 'string' && typeof newIndex === 'number' && newIndex >= 0) {
          handleReorderSection(sectionId, newIndex, draftRef.current);
        }
      }
      if (event.data.type === STUDIO_EVENTS.WEBMCP_TOOL_CALL) {
        const requestId = typeof event.data.requestId === 'string' ? event.data.requestId : crypto.randomUUID();
        const toolName = typeof event.data.toolName === 'string' ? event.data.toolName : '';
        void handleWebMcpToolCall(toolName, event.data.args)
          .then((result) => {
            window.postMessage(
              { type: STUDIO_EVENTS.WEBMCP_TOOL_RESULT, requestId, toolName, result, ok: true },
              window.location.origin
            );
          })
          .catch((error: unknown) => {
            const message = error instanceof Error ? error.message : String(error);
            window.postMessage(
              {
                type: STUDIO_EVENTS.WEBMCP_TOOL_RESULT,
                requestId,
                toolName,
                ok: false,
                error: message,
              },
              window.location.origin
            );
          });
      }
    },
    [handleReorderSection, handleWebMcpToolCall]
  );

  useEffect(() => {
    window.addEventListener('message', handleStudioMessage);
    return () => window.removeEventListener('message', handleStudioMessage);
  }, [handleStudioMessage]);

  useEffect(() => {
    if (!webMcp?.enabled) return;
    ensureWebMcpRuntime();

    const currentDraft = draftRef.current;
    if (!currentDraft) return;

    const currentGlobalDraft = globalDraftRef.current;
    const catalog: Array<{ id: string; type: string }> = [];
    if (currentGlobalDraft?.header?.id && currentGlobalDraft.header?.type) {
      catalog.push({ id: currentGlobalDraft.header.id, type: String(currentGlobalDraft.header.type) });
    }
    if (currentGlobalDraft?.footer?.id && currentGlobalDraft.footer?.type) {
      catalog.push({ id: currentGlobalDraft.footer.id, type: String(currentGlobalDraft.footer.type) });
    }
    for (const section of currentDraft.sections) {
      if (typeof section.id === 'string' && section.id.length > 0) {
        catalog.push({ id: section.id, type: String(section.type) });
      }
    }

    const unregisterUpdate = registerWebMcpTool({
      name: buildWebMcpToolName(),
      description: 'Update a section field in the Studio draft. Does not persist — call save when all updates are complete. Use "sectionType" in input args to ensure correct schema validation.',
      inputSchema: createWebMcpToolInputSchema(catalog),
      execute: (args) => handleWebMcpToolCall(buildWebMcpToolName(), args),
    });

    const unregisterSave = registerWebMcpTool({
      name: buildWebMcpSaveToolName(),
      description: 'Persist all pending draft changes using the active save mode (local file, hot save, or save2repo). Call once after all update-section calls are complete.',
      inputSchema: createWebMcpSaveToolInputSchema(),
      execute: () => handleWebMcpToolCall(buildWebMcpSaveToolName(), {}),
    });

    return () => {
      unregisterUpdate();
      unregisterSave();
    };
  }, [webMcp?.enabled, slug, draft, globalDraft, handleWebMcpToolCall]);

  const handleRequestScrollToSection = useCallback((sectionId: string) => {
    const layer = allLayers.find((l) => l.id === sectionId);
    if (layer) setSelected({ id: layer.id, type: layer.type, scope: layer.scope });
    setExpandedItemPath(null);
    setScrollToSectionId(sectionId);
  }, [allLayers]);

  const handleScrollRequested = useCallback(() => {
    setScrollToSectionId(null);
  }, []);

  const handleDeleteSection = useCallback(
    (sectionId: string) => {
      setDraft((prev) => {
        if (!prev) return prev;
        return { ...prev, sections: prev.sections.filter((s) => s.id !== sectionId) };
      });
      setHasChanges(true);
      setSelected((prev) => (prev?.id === sectionId ? null : prev));
    },
    []
  );

  const handleUpdate = (newData: Record<string, unknown>) => {
    if (!selected || !draft) return;
    if (selected.scope === 'global') {
      const { nextGlobalDraft, nextMenuDraft } = applyGlobalSectionUpdate(
        selected.id,
        newData,
        globalDraft,
        resolvedRuntime.siteConfig,
        menuDraft
      );
      setGlobalDraft(nextGlobalDraft);
      setMenuDraft(nextMenuDraft);
      globalDraftRef.current = nextGlobalDraft;
      menuDraftRef.current = nextMenuDraft;
      setHasChanges(true);
    } else {
      const authoredSection = draft.sections.find((s) => s.id === selected.id);
      const collectionResult = applyCollectionRefBindingsToDraft(
        authoredSection?.data,
        newData,
        collectionsDraft,
        resolvedCollectionContext,
        collectionSchemas
      );
      const updatedSections = draft.sections.map((s) =>
        s.id === selected.id ? ({ ...s, data: collectionResult.normalizedData } as Section) : s
      );
      commitCollectionsDraft(collectionResult.collectionsDraft);
      setDraft({ ...draft, sections: updatedSections });
      setHasChanges(true);
    }
  };

  const handleUpdateSection = useCallback(
    (sectionId: string, scope: 'global' | 'local', _sectionType: string, newData: Record<string, unknown>) => {
      if (scope === 'global') {
        const { nextGlobalDraft, nextMenuDraft } = applyGlobalSectionUpdate(
          sectionId,
          newData,
          globalDraft,
          resolvedRuntime.siteConfig,
          menuDraft
        );
        setGlobalDraft(nextGlobalDraft);
        setMenuDraft(nextMenuDraft);
        globalDraftRef.current = nextGlobalDraft;
        menuDraftRef.current = nextMenuDraft;
        setHasChanges(true);
      } else if (draft) {
        const authoredSection = draft.sections.find((s) => s.id === sectionId);
        const collectionResult = applyCollectionRefBindingsToDraft(
          authoredSection?.data,
          newData,
          collectionsDraft,
          resolvedCollectionContext,
          collectionSchemas
        );
        const updatedSections = draft.sections.map((s) =>
          s.id === sectionId ? ({ ...s, data: collectionResult.normalizedData } as Section) : s
        );
        commitCollectionsDraft(collectionResult.collectionsDraft);
        setDraft({ ...draft, sections: updatedSections });
        setHasChanges(true);
      }
    },
    [applyGlobalSectionUpdate, collectionSchemas, collectionsDraft, commitCollectionsDraft, draft, globalDraft, menuDraft, resolvedCollectionContext, resolvedRuntime.siteConfig]
  );

  const handleSaveToFile = async () => {
    if (!saveToFile) return;
    await requestInlineFlush();
    const currentDraft = draftRef.current;
    const currentGlobalDraft = globalDraftRef.current;
    const currentMenuDraft = menuDraftRef.current;
    const currentCollectionsDraft = collectionsDraftRef.current;
    if (!currentDraft) return;
    persistProjectState(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft, () => setHasChanges(false)).catch((err) => {
      console.error('[JsonPages] saveToFile failed', err);
      const msg = err instanceof Error ? err.message : String(err);
      alert(`Save to file failed: ${msg}`);
    });
  };

  const handleHotSave = async () => {
    if (!hotSave) return;
    await requestInlineFlush();
    const currentDraft = draftRef.current;
    const currentGlobalDraft = globalDraftRef.current;
    const currentMenuDraft = menuDraftRef.current;
    const currentCollectionsDraft = collectionsDraftRef.current;
    if (!currentDraft) return;
    runHotSave(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft, () => setHasChanges(false)).catch((err) => {
      console.error('[JsonPages] hotSave failed', err);
      const msg = err instanceof Error ? err.message : String(err);
      alert(`Hot save failed: ${msg}`);
    });
  };

  const handleColdSave = async () => {
    if (!coldSave) return;
    await requestInlineFlush();
    const currentDraft = draftRef.current;
    const currentGlobalDraft = globalDraftRef.current;
    const currentMenuDraft = menuDraftRef.current;
    const currentCollectionsDraft = collectionsDraftRef.current;
    if (!currentDraft) return;
    coldSave(buildProjectState(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft), persistenceSlug)
      .then(() => setHasChanges(false))
      .catch((err) => {
        console.error('[JsonPages] coldSave failed', err);
        const msg = err instanceof Error ? err.message : String(err);
        alert(`Save2Repo failed: ${msg}`);
      });
  };

  const handleAddSection = (sectionType: string) => {
    if (!draft) return;
    const defaultData = addSectionConfig?.getDefaultSectionData?.(sectionType) ?? {};
    const { draft: nextDraft, section } = appendDraftSection(draft, sectionType, defaultData);
    setDraft(nextDraft);
    setHasChanges(true);
    setSelected({ id: section.id, type: sectionType, scope: 'local' });
  };

  useEffect(() => {
    const currentPage = resolvedDraft ?? draft;
    const title = typeof currentPage?.meta?.title === 'string' ? currentPage.meta.title : slug;
    const description = typeof currentPage?.meta?.description === 'string' ? currentPage.meta.description : '';
    syncHeadLink('mcp-manifest', buildPageManifestHref(slug));
    syncHeadLink('olon-contract', buildPageContractHref(slug));
    syncWebMcpJsonLd(title, description, `/admin${slug === 'home' ? '' : `/${slug}`}`);
  }, [draft, resolvedDraft, slug]);

  if (!draft) return <div>Loading Studio...</div>;

  const sidebarData =
    selected?.scope === 'global'
      ? {
          sections: [resolvedRuntime.siteConfig.header, resolvedRuntime.siteConfig.footer].filter(
            (s): s is Section => s != null
          ),
        }
      : (resolvedDraft ?? draft);

  const allSectionsData: Section[] = [
    ...(resolvedRuntime.siteConfig.header ? [resolvedRuntime.siteConfig.header] : []),
    ...((resolvedDraft ?? draft)?.sections ?? []),
    ...(resolvedRuntime.siteConfig.footer ? [resolvedRuntime.siteConfig.footer] : []),
  ];

  return (
    <ThemeLoader mode="admin" tenantCss={tenantCss} adminCss={adminCss}>
      <StudioProvider mode="studio">
        <div className="flex flex-col h-screen w-screen bg-background text-foreground overflow-hidden">
          <div className="flex flex-1 min-h-0 overflow-hidden">
            <main className="flex-1 min-w-0 relative bg-zinc-900/50 overflow-hidden">
              <StudioStage
                draft={resolvedDraft ?? draft}
                globalDraft={resolvedRuntime.siteConfig}
                menuConfig={resolvedRuntime.menuConfig}
                themeConfig={resolvedRuntime.themeConfig}
                slug={slug}
                selectedId={selected?.id}
                scrollToSectionId={scrollToSectionId}
                onScrollRequested={handleScrollRequested}
              />
            </main>
            <div
              className="flex shrink-0 relative h-full z-10"
              style={{ width: sidebarWidth, minWidth: sidebarMin, maxWidth: sidebarMax }}
            >
              <div
                role="separator"
                aria-label="Resize inspector"
                className="absolute left-0 top-0 bottom-0 w-1.5 cursor-col-resize hover:bg-primary/40 active:bg-primary/60 transition-colors shrink-0"
                style={{ zIndex: 9999 }}
                onPointerDown={handleResizeStart}
              />
              <AdminSidebar
                selectedSection={selected}
                pageData={sidebarData}
                allSectionsData={allSectionsData}
                collections={collectionsDraft}
                collectionSource={resolvedCollectionContext?.source}
                onUpdate={handleUpdate}
                onUpdateSection={handleUpdateSection}
                onClose={clearSelection}
                expandedItemPath={expandedItemPath}
                onReorderSection={
                  draft
                    ? (sectionId, newIndex) => handleReorderSection(sectionId, newIndex, draft)
                    : undefined
                }
                allLayers={allLayers}
                activeSectionId={activeSectionId}
                onRequestScrollToSection={handleRequestScrollToSection}
                onDeleteSection={draft ? handleDeleteSection : undefined}
                onAddSection={
                  addableSectionTypes.length > 0
                    ? () => setAddSectionLibraryOpen(true)
                    : undefined
                }
                hasChanges={hasChanges}
                onSaveToFile={saveToFile != null ? handleSaveToFile : undefined}
                saveSuccessFeedback={saveSuccessFeedback}
                onHotSave={hotSave != null ? handleHotSave : undefined}
                onColdSave={coldSave != null ? handleColdSave : undefined}
                hotSaveSuccessFeedback={hotSaveSuccessFeedback}
                hotSaveInProgress={hotSaveInProgress}
                showLocalSave={showLocalSave}
                showHotSave={showHotSave}
                showColdSave={showColdSave}
                onResetToFile={handleResetToFile}
                pageSlugs={pageSlugs}
                currentSlug={slug}
                onPageChange={
                  pageSlugs.length > 1
                    ? (s) => {
                        const nextSlug = normalizeSlugSegments(s);
                        navigate(nextSlug === 'home' ? '/admin' : `/admin/${nextSlug}`);
                      }
                    : undefined
                }
              />
            </div>
          </div>
          <AddSectionLibrary
            open={addSectionLibraryOpen}
            onClose={() => setAddSectionLibraryOpen(false)}
            sectionTypes={addableSectionTypes}
            sectionTypeLabels={addSectionConfig?.sectionTypeLabels}
            onSelect={handleAddSection}
          />
        </div>
      </StudioProvider>
    </ThemeLoader>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/VisitorRoute.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/VisitorRoute.tsx"
import React, { useEffect, useMemo } from 'react';
import { useLocation } from 'react-router-dom';
import { resolveCollectionContext, resolveRuntimeConfig } from '../../contract/config-resolver';
import type { JsonPagesConfig } from '../../contract/types-engine';
import type { MenuConfig, PageConfig, SiteConfig } from '../../contract/kernel';
import { StudioProvider } from '../../studio/StudioContext';
import { PageRenderer } from '../rendering/PageRenderer';
import { ThemeLoader } from '../theme/ThemeLoader';
import { themeManager } from '../theme/theme-manager';
import {
  buildPageContractHref,
  buildPageManifestHref,
  syncHeadLink,
  syncWebMcpJsonLd,
} from './head-sync';
import {
  resolvePageMatchFromRegistry,
  resolveSlugFromPathname,
} from './route-utils';

export interface VisitorRouteProps {
  pageRegistry: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  menuConfig: MenuConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
  tenantCss: string;
  adminCss: string;
  NotFoundComponent: React.ComponentType;
}

export const VisitorRoute: React.FC<VisitorRouteProps> = ({
  pageRegistry,
  siteConfig,
  menuConfig,
  themeConfig,
  collections,
  collectionSchemas,
  refDocuments,
  tenantCss,
  adminCss,
  NotFoundComponent,
}) => {
  const location = useLocation();
  const slug = resolveSlugFromPathname(location.pathname);
  const pageMatch = useMemo(
    () => resolvePageMatchFromRegistry(pageRegistry, slug),
    [pageRegistry, slug]
  );
  const collectionContext = useMemo(
    () => pageMatch ? resolveCollectionContext(pageMatch.page, pageMatch.params, collections) : null,
    [collections, pageMatch]
  );
  const resolvedRuntime = useMemo(
    () =>
      resolveRuntimeConfig({
        pages: pageMatch ? { [pageMatch.registrySlug]: pageMatch.page } : {},
        siteConfig,
        themeConfig,
        menuConfig,
        collections,
        collectionSchemas,
        collectionContext,
        refDocuments,
      }),
    [pageMatch, siteConfig, themeConfig, menuConfig, collections, collectionSchemas, collectionContext, refDocuments]
  );
  const pageConfig = pageMatch ? resolvedRuntime.pages[pageMatch.registrySlug] : undefined;

  useEffect(() => {
    try {
      if (resolvedRuntime.themeConfig?.tokens) {
        themeManager.setTheme(resolvedRuntime.themeConfig);
      }
    } catch (e) {
      console.warn('[JsonPages] visitor theme resolution failed', e);
    }
  }, [resolvedRuntime.themeConfig]);

  useEffect(() => {
    if (!pageConfig) return;
    const title = typeof pageConfig.meta?.title === 'string' ? pageConfig.meta.title : slug;
    const description = typeof pageConfig.meta?.description === 'string' ? pageConfig.meta.description : '';
    syncHeadLink('mcp-manifest', buildPageManifestHref(slug));
    syncHeadLink('olon-contract', buildPageContractHref(slug));
    syncWebMcpJsonLd(title, description, slug === 'home' ? '/' : `/${slug}`);
  }, [pageConfig, slug]);

  if (!pageConfig) return <NotFoundComponent />;

  return (
    <ThemeLoader mode="tenant" tenantCss={tenantCss} adminCss={adminCss}>
      <StudioProvider mode="visitor">
        <PageRenderer
          pageConfig={pageConfig}
          siteConfig={resolvedRuntime.siteConfig}
          menuConfig={resolvedRuntime.menuConfig}
        />
      </StudioProvider>
    </ThemeLoader>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/head-sync.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/head-sync.ts"
import {
  buildPageContractHref,
  buildPageManifestHref,
} from '../../contract/webmcp-contracts';

export function syncHeadLink(rel: string, href: string) {
  if (typeof document === 'undefined') return;
  const selector = `link[rel="${rel}"]`;
  let link = document.head.querySelector(selector) as HTMLLinkElement | null;
  if (!link) {
    link = document.createElement('link');
    link.rel = rel;
    document.head.appendChild(link);
  }
  link.href = href;
}

export function syncWebMcpJsonLd(title: string, description: string, url: string) {
  if (typeof document === 'undefined') return;
  const scriptId = 'olonjs-webmcp-jsonld';
  let script = document.getElementById(scriptId) as HTMLScriptElement | null;
  if (!script) {
    script = document.createElement('script');
    script.type = 'application/ld+json';
    script.id = scriptId;
    document.head.appendChild(script);
  }
  script.textContent = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: title,
    description,
    url,
    'subjectOf': {
    '@type': 'CreativeWork',
    'additionalType': 'mcp-manifest',
    'url': '/mcp-manifests/home.json'
  }
  });
}

export { buildPageContractHref, buildPageManifestHref };

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/index.ts"
export { EngineErrorBoundary } from './EngineErrorBoundary';
export { JsonPagesEngine, type JsonPagesEngineProps } from './JsonPagesEngine';
export { OlonJSEngine, type OlonJSEngineProps } from './OlonJSEngine';
export { PreviewRoute, type PreviewRouteProps } from './PreviewRoute';
export { StudioRoute, type StudioRouteProps } from './StudioRoute';
export { VisitorRoute, type VisitorRouteProps } from './VisitorRoute';
export {
  buildPageContractHref,
  buildPageManifestHref,
  syncHeadLink,
  syncWebMcpJsonLd,
} from './head-sync';
export {
  isRecord,
  normalizeSlugSegments,
  resolvePageMatchFromRegistry,
  resolveMenuMainFromHeaderData,
  resolvePageFromRegistry,
  resolveSlugFromPathname,
  type PageRouteMatch,
} from './route-utils';
export {
  resolvePublicPageDocument,
  type ResolvedPublicPageDocument,
  type ResolvePublicPageDocumentInput,
} from './public-page-document';

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/public-page-document.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/public-page-document.test.ts"
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { resolvePublicPageDocument } from './public-page-document';
import type { MenuConfig, PageConfig, SiteConfig, ThemeConfig } from '../../contract/kernel';

const themeConfig: ThemeConfig = {
  name: 'test',
  tokens: {
    colors: {},
    typography: { fontFamily: {} },
    borderRadius: {},
  },
};

const siteConfig: SiteConfig = {
  identity: { title: 'Test' },
  footer: {
    id: 'global-footer',
    type: 'footer',
    data: {},
  },
};

const menuConfig: MenuConfig = {};

const pages: Record<string, PageConfig> = {
  libri: {
    id: 'libri-page',
    slug: 'libri',
    meta: {
      title: 'Catalogo libri',
      description: 'Catalogo libri usato per validare le collection.',
    },
    sections: [
      {
        id: 'books-list',
        type: 'books-list',
        data: {
          title: 'Libri',
          items: { $ref: '../collections/libri/libri.json' },
        },
      },
    ],
  },
  'libri/[slug]': {
    id: 'book-detail-page',
    slug: 'libri/[slug]',
    meta: {
      title: 'Dettaglio libro',
      description: 'Pagina dettaglio usata per validare collection current.',
    },
    collection: {
      source: 'libri',
      paramKey: 'slug',
    },
    sections: [
      {
        id: 'book-detail',
        type: 'book-detail',
        data: {
          item: { $ref: 'collection:current' },
        },
      },
    ],
  },
};

const collections = {
  libri: {
    dune: {
      id: 'dune',
      title: 'Dune',
      author: 'Frank Herbert',
    },
    neuromancer: {
      id: 'neuromancer',
      title: 'Neuromancer',
      author: 'William Gibson',
    },
  },
};
const collectionSchemas = {
  libri: z.record(
    z.object({
      id: z.string(),
      title: z.string(),
      author: z.string(),
    })
  ),
};

describe('resolvePublicPageDocument', () => {
  it('resolves collection document refs for a direct page slug', () => {
    const resolved = resolvePublicPageDocument({
      slug: 'libri',
      pages,
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      collectionSchemas,
    });

    expect(resolved?.pageMatch.registrySlug).toBe('libri');
    expect(resolved?.page.slug).toBe('libri');
    expect(resolved?.page.sections[0].data).toEqual({
      title: 'Libri',
      items: collections.libri,
    });
  });

  it('resolves collection:current for a dynamic page slug', () => {
    const resolved = resolvePublicPageDocument({
      slug: 'libri/dune',
      pages,
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      collectionSchemas,
    });

    expect(resolved?.pageMatch.registrySlug).toBe('libri/[slug]');
    expect(resolved?.pageMatch.requestedSlug).toBe('libri/dune');
    expect(resolved?.page.slug).toBe('libri/dune');
    expect(resolved?.collectionContext?.paramValue).toBe('dune');
    expect(resolved?.page.sections[0].data).toEqual({
      item: {
        id: 'dune',
        title: 'Dune',
        author: 'Frank Herbert',
      },
    });
  });

  it('returns collection:current from the parsed collection document', () => {
    const resolved = resolvePublicPageDocument({
      slug: 'libri/dune',
      pages,
      siteConfig,
      themeConfig,
      menuConfig,
      collections: {
        libri: {
          dune: {
            id: 'dune',
            title: 'Dune',
            draftOnly: true,
          },
        },
      },
      collectionSchemas: {
        libri: z.record(
          z.object({
            id: z.string(),
            title: z.string(),
            author: z.string().default('Unknown'),
          })
        ),
      },
    });

    expect(resolved?.collectionContext?.currentItem).toEqual({
      id: 'dune',
      title: 'Dune',
      author: 'Unknown',
    });
    expect(resolved?.page.sections[0].data).toEqual({
      item: {
        id: 'dune',
        title: 'Dune',
        author: 'Unknown',
      },
    });
  });

  it('returns null when no direct or dynamic page matches', () => {
    expect(resolvePublicPageDocument({
      slug: 'missing',
      pages,
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      collectionSchemas,
    })).toBeNull();
  });
});

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/public-page-document.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/public-page-document.ts"
import {
  resolveCollectionContext,
  resolveRuntimeConfig,
  type CollectionResolutionContext,
} from '../../contract/config-resolver';
import type { MenuConfig, PageConfig, SiteConfig } from '../../contract/kernel';
import type { JsonPagesConfig } from '../../contract/types-engine';
import { resolvePageMatchFromRegistry, type PageRouteMatch } from './route-utils';

export interface ResolvePublicPageDocumentInput {
  slug: string;
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  menuConfig: MenuConfig;
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
}

export interface ResolvedPublicPageDocument {
  page: PageConfig;
  siteConfig: SiteConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  menuConfig: MenuConfig;
  pageMatch: PageRouteMatch;
  collectionContext: CollectionResolutionContext | null;
}

export function resolvePublicPageDocument(
  input: ResolvePublicPageDocumentInput
): ResolvedPublicPageDocument | null {
  const pageMatch = resolvePageMatchFromRegistry(input.pages, input.slug);
  if (!pageMatch) return null;

  const collectionContext = resolveCollectionContext(
    pageMatch.page,
    pageMatch.params,
    input.collections
  );
  const resolvedRuntime = resolveRuntimeConfig({
    pages: { [pageMatch.registrySlug]: pageMatch.page },
    siteConfig: input.siteConfig,
    themeConfig: input.themeConfig,
    menuConfig: input.menuConfig,
    collections: input.collections,
    collectionSchemas: input.collectionSchemas,
    collectionContext,
    refDocuments: input.refDocuments,
  });
  const resolvedPage = resolvedRuntime.pages[pageMatch.registrySlug] ?? pageMatch.page;

  return {
    page: {
      ...resolvedPage,
      slug: pageMatch.requestedSlug,
    },
    siteConfig: resolvedRuntime.siteConfig,
    themeConfig: resolvedRuntime.themeConfig,
    menuConfig: resolvedRuntime.menuConfig,
    pageMatch,
    collectionContext: resolvedRuntime.collectionContext,
  };
}

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/route-utils.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/route-utils.test.ts"
import { describe, expect, it } from 'vitest';

import { resolvePageMatchFromRegistry, resolveSlugFromPathname } from './route-utils';

describe('resolveSlugFromPathname', () => {
  it('resolves home for root pathname', () => {
    expect(resolveSlugFromPathname('/')).toBe('home');
  });

  it('supports prefixed pathnames', () => {
    expect(resolveSlugFromPathname('/core/', 'core')).toBe('home');
    expect(resolveSlugFromPathname('/core/platform/overview', 'core')).toBe('platform/overview');
  });
});

describe('resolvePageMatchFromRegistry', () => {
  const pageRegistry = {
    libri: {
      id: 'libri-page',
      slug: 'libri',
      meta: { title: 'Libri', description: 'Catalogo libri' },
      sections: [],
    },
    'libri/[slug]': {
      id: 'book-detail-page',
      slug: 'libri/[slug]',
      meta: { title: 'Libro', description: 'Dettaglio libro' },
      sections: [],
    },
    'docs/[slug]': {
      id: 'docs-template-page',
      slug: 'docs/[slug]',
      meta: { title: 'Docs', description: 'Dettaglio documentazione' },
      sections: [],
    },
    'docs/intro': {
      id: 'docs-intro-page',
      slug: 'docs/intro',
      meta: { title: 'Intro', description: 'Pagina diretta' },
      sections: [],
    },
  };

  it('matches direct slugs first', () => {
    const match = resolvePageMatchFromRegistry(pageRegistry, 'docs/intro');

    expect(match?.registrySlug).toBe('docs/intro');
    expect(match?.params).toEqual({});
    expect(match?.page.id).toBe('docs-intro-page');
  });

  it('matches bracket route templates and extracts params', () => {
    const match = resolvePageMatchFromRegistry(pageRegistry, 'libri/dune');

    expect(match?.registrySlug).toBe('libri/[slug]');
    expect(match?.requestedSlug).toBe('libri/dune');
    expect(match?.params).toEqual({ slug: 'dune' });
    expect(match?.page.id).toBe('book-detail-page');
  });

  it('does not match templates with different segment counts', () => {
    expect(resolvePageMatchFromRegistry(pageRegistry, 'libri/dune/extra')).toBeUndefined();
  });
});

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/engine/route-utils.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/engine/route-utils.ts"
import type { MenuItem, PageConfig } from '../../contract/kernel';
import { resolveHeaderMenuItems } from '../../contract/config-resolver';

export function normalizeSlugSegments(value: string): string {
  return value
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean)
    .join('/');
}

export function resolveSlugFromPathname(pathname: string, prefix = ''): string {
  const normalizedPrefix = normalizeSlugSegments(prefix);
  const normalizedPath = pathname.replace(/\/+/g, '/');
  let remainder = normalizedPath;

  if (normalizedPrefix) {
    const prefixedPath = `/${normalizedPrefix}`;
    if (remainder === prefixedPath) {
      remainder = '/';
    } else if (remainder.startsWith(`${prefixedPath}/`)) {
      remainder = remainder.slice(prefixedPath.length);
    }
  }

  const slug = normalizeSlugSegments(remainder);
  return slug || 'home';
}

export function resolvePageFromRegistry(
  pageRegistry: Record<string, PageConfig>,
  requestedSlug: string
): PageConfig | undefined {
  return resolvePageMatchFromRegistry(pageRegistry, requestedSlug)?.page;
}

export interface PageRouteMatch {
  page: PageConfig;
  registrySlug: string;
  requestedSlug: string;
  params: Record<string, string>;
}

function matchRouteTemplate(templateSlug: string, requestedSlug: string): Record<string, string> | null {
  const templateSegments = normalizeSlugSegments(templateSlug).split('/').filter(Boolean);
  const requestedSegments = normalizeSlugSegments(requestedSlug).split('/').filter(Boolean);
  if (templateSegments.length !== requestedSegments.length) return null;

  const params: Record<string, string> = {};
  for (let index = 0; index < templateSegments.length; index += 1) {
    const templateSegment = templateSegments[index];
    const requestedSegment = requestedSegments[index];
    const paramMatch = templateSegment.match(/^\[([A-Za-z0-9_-]+)\]$/);
    if (paramMatch) {
      params[paramMatch[1]] = requestedSegment;
      continue;
    }
    if (templateSegment !== requestedSegment) return null;
  }

  return params;
}

export function resolvePageMatchFromRegistry(
  pageRegistry: Record<string, PageConfig>,
  requestedSlug: string
): PageRouteMatch | undefined {
  const normalized = normalizeSlugSegments(requestedSlug) || 'home';
  const directPage = pageRegistry[normalized];
  if (directPage) {
    return {
      page: directPage,
      registrySlug: normalized,
      requestedSlug: normalized,
      params: {},
    };
  }

  for (const [registrySlug, page] of Object.entries(pageRegistry)) {
    const params = matchRouteTemplate(page.slug || registrySlug, normalized);
    if (!params) continue;
    return {
      page,
      registrySlug,
      requestedSlug: normalized,
      params,
    };
  }

  return undefined;
}

export function resolveMenuMainFromHeaderData(
  headerData: unknown,
  fallbackMain: MenuItem[]
): MenuItem[] {
  return resolveHeaderMenuItems(headerData, fallbackMain);
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

END_OF_FILE_CONTENT
mkdir -p "core/src/runtime/icons"
echo "Creating core/src/runtime/icons/IconRegistryContext.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/icons/IconRegistryContext.tsx"
/**
 * Icon registry context — moved here from `studio/admin/` per ADR-0009 D5.
 *
 * The registry maps section schema icon names to LucideIcon components and
 * is consumed at *render* time (Section icons in the visitor flow), not
 * just by Studio. Owning it here keeps `runtime/` decoupled from
 * `studio/admin/`.
 *
 * The original path (`packages/core/src/studio/admin/IconRegistryContext.tsx`)
 * remains as a thin re-export shim for backwards compatibility with any
 * external consumer that imported it directly.
 */
import { createContext, useContext } from 'react';
import type { LucideIcon } from 'lucide-react';

export type IconRegistry = Record<string, LucideIcon>;

export const IconRegistryContext = createContext<IconRegistry>({});

export const useIconRegistry = (): IconRegistry => useContext(IconRegistryContext);

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/index.ts"
/**
 * Conceptual public surface for runtime and studio concerns.
 *
 * This keeps the engine-facing API grouped even before we physically
 * split packages.
 */
export { PageRenderer } from './rendering/PageRenderer';
export { SectionRenderer } from './rendering/SectionRenderer';
export { JsonPagesEngine, type JsonPagesEngineProps } from './engine/JsonPagesEngine';
export { StudioProvider, useStudio } from '../studio/StudioContext';
export { ConfigProvider, useConfig, type ConfigContextValue } from './config/ConfigContext';
export { ThemeLoader, type ThemeLoaderProps } from './theme/ThemeLoader';
export { DefaultNotFound } from '../lib/DefaultNotFound';
export { STUDIO_EVENTS } from '../studio/events';
export * from './engine';
export * from './assets';
export * from './config';
export * from './rendering';
export * from './theme';
export * from './url';

END_OF_FILE_CONTENT
mkdir -p "core/src/runtime/rendering"
echo "Creating core/src/runtime/rendering/PageRenderer.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/rendering/PageRenderer.tsx"
import React, { useState, useRef, useEffect } from 'react';
import { shouldRenderSiteGlobalHeader, type PageRendererProps } from '../../contract/kernel';
import { resolveSectionMenuItems } from '../../contract/config-resolver';
import { SectionRenderer } from './SectionRenderer';
import { useDocumentMeta } from './useDocumentMeta';

const REORDER_DATA_KEY = 'application/json';

type Props = PageRendererProps & {
  onReorder?: (sectionId: string, newIndex: number) => void;
  scrollToSectionId?: string | null;
  onActiveSectionChange?: (sectionId: string | null) => void;
};

export const PageRenderer: React.FC<Props> = ({
  pageConfig,
  siteConfig,
  menuConfig,
  selectedId,
  onReorder,
  scrollToSectionId,
  onActiveSectionChange,
}) => {
  useDocumentMeta(pageConfig.meta);
  const [dropIndex, setDropIndex] = useState<number | null>(null);
  const sectionRefs = useRef<Record<string, HTMLElement | null>>({});
  const onActiveSectionChangeRef = useRef(onActiveSectionChange);
  onActiveSectionChangeRef.current = onActiveSectionChange;

  const showGlobalHeader = shouldRenderSiteGlobalHeader(pageConfig, siteConfig);
  const headerSection = showGlobalHeader ? siteConfig.header ?? null : null;
  const footerSection = siteConfig.footer ?? null;

  const handleSectionHover = (sectionId: string) => {
    onActiveSectionChangeRef.current?.(sectionId);
  };

  useEffect(() => {
    if (!scrollToSectionId) return;
    const el = sectionRefs.current[scrollToSectionId];
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }, [scrollToSectionId]);

  useEffect(() => {
    const callback = onActiveSectionChangeRef.current;
    if (!callback) return;
    const ids: string[] = [
      ...(headerSection ? [headerSection.id] : []),
      ...pageConfig.sections.map((section) => section.id),
      ...(footerSection ? [footerSection.id] : []),
    ];
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && entry.intersectionRatio > 0.5) {
            const id = (entry.target as HTMLElement).getAttribute('data-section-id');
            if (id) onActiveSectionChangeRef.current?.(id);
          }
        });
      },
      { threshold: [0, 0.5, 1], rootMargin: '-20% 0px -20% 0px' }
    );
    let cancelled = false;
    const rafId = requestAnimationFrame(() => {
      if (cancelled) return;
      ids.forEach((id) => {
        const el = sectionRefs.current[id];
        if (el) observer.observe(el);
      });
    });
    return () => {
      cancelled = true;
      cancelAnimationFrame(rafId);
      observer.disconnect();
    };
  }, [footerSection, headerSection, pageConfig.sections, pageConfig['global-header'], showGlobalHeader]);

  const handleDragOver = (event: React.DragEvent, index: number) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
    setDropIndex(index);
  };

  const handleDragLeave = () => {
    setDropIndex(null);
  };

  const handleDrop = (event: React.DragEvent, insertIndex: number) => {
    event.preventDefault();
    setDropIndex(null);
    if (!onReorder) return;
    try {
      const raw = event.dataTransfer.getData(REORDER_DATA_KEY);
      const { sectionId } = JSON.parse(raw) as { sectionId?: string };
      if (typeof sectionId === 'string') onReorder(sectionId, insertIndex);
    } catch {
      // ignore malformed drag payloads
    }
  };

  const renderPageSections = () => {
    const reorderable = typeof onReorder === 'function';
    const sections = pageConfig.sections.map((section, index) => {
      const showDropIndicator = dropIndex === index;

      if (!reorderable) {
        return (
          <div
            key={section.id}
            ref={(element) => {
              sectionRefs.current[section.id] = element;
            }}
            data-section-id={section.id}
            onMouseEnter={() => handleSectionHover(section.id)}
          >
            <SectionRenderer
              section={section}
              menu={resolveSectionMenuItems(section, menuConfig.main ?? [])}
              selectedId={selectedId}
            />
          </div>
        );
      }

      return (
        <div
          key={section.id}
          ref={(element) => {
            sectionRefs.current[section.id] = element;
          }}
          data-section-id={section.id}
          style={{ position: 'relative' }}
          onMouseEnter={() => handleSectionHover(section.id)}
        >
          <div
            data-jp-drop-zone
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: -1,
              height: 12,
              zIndex: 55,
              pointerEvents: 'auto',
              backgroundColor: showDropIndicator ? 'rgba(59, 130, 246, 0.4)' : 'transparent',
              borderTop: showDropIndicator ? '2px solid rgb(96, 165, 250)' : '2px solid transparent',
            }}
            onDragOver={(event) => handleDragOver(event, index)}
            onDragLeave={handleDragLeave}
            onDrop={(event) => handleDrop(event, index)}
          />
          <SectionRenderer
            section={section}
            menu={resolveSectionMenuItems(section, menuConfig.main ?? [])}
            selectedId={selectedId}
            reorderable
            sectionIndex={index}
            totalSections={pageConfig.sections.length}
            onReorder={onReorder}
          />
        </div>
      );
    });

    if (reorderable && sections.length > 0) {
      const lastIndex = pageConfig.sections.length;
      const showDropIndicator = dropIndex === lastIndex;
      sections.push(
        <div
          key="jp-drop-after-last"
          data-jp-drop-zone
          style={{
            position: 'relative',
            left: 0,
            right: 0,
            height: 24,
            minHeight: 24,
            zIndex: 55,
            pointerEvents: 'auto',
            backgroundColor: showDropIndicator ? 'rgba(59, 130, 246, 0.4)' : 'transparent',
            borderTop: showDropIndicator ? '2px solid rgb(96, 165, 250)' : '2px solid transparent',
          }}
          onDragOver={(event) => handleDragOver(event, lastIndex)}
          onDragLeave={handleDragLeave}
          onDrop={(event) => handleDrop(event, lastIndex)}
        />
      );
    }

    return sections;
  };

  return (
    <div className="min-h-screen flex flex-col bg-[var(--color-background)]">
      {headerSection != null && (
        <div
          ref={(element) => {
            sectionRefs.current[headerSection.id] = element;
          }}
          data-section-id={headerSection.id}
          onMouseEnter={() => handleSectionHover(headerSection.id)}
        >
          <SectionRenderer
            section={headerSection}
            menu={resolveSectionMenuItems(headerSection, menuConfig.main ?? [])}
            selectedId={selectedId}
          />
        </div>
      )}

      <main className="flex-1">{renderPageSections()}</main>

      {footerSection != null && (
        <div
          ref={(element) => {
            sectionRefs.current[footerSection.id] = element;
          }}
          data-section-id={footerSection.id}
          onMouseEnter={() => handleSectionHover(footerSection.id)}
        >
          <SectionRenderer
            section={footerSection}
            menu={resolveSectionMenuItems(footerSection, menuConfig.main ?? [])}
            selectedId={selectedId}
          />
        </div>
      )}
    </div>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/rendering/SectionRenderer.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/rendering/SectionRenderer.tsx"
import React, { Component, type ErrorInfo, type ReactNode } from 'react';
import { AlertTriangle, ChevronDown, ChevronUp } from 'lucide-react';
import { useConfig } from '../config/ConfigContext';
import { useStudio } from '../../studio/StudioContext';
import { cn } from '../../lib/utils';
import type { MenuItem, Section } from '../../contract/kernel';

class SectionErrorBoundary extends Component<{ children: ReactNode; type: string }, { hasError: boolean }> {
  constructor(props: { children: ReactNode; type: string }) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error(`[JsonPages] Component Crash [${this.props.type}]:`, error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="p-8 m-4 bg-amber-500/5 border-2 border-dashed border-amber-500/20 rounded-xl flex flex-col items-center text-center gap-3">
          <AlertTriangle className="text-amber-500" size={32} />
          <div className="space-y-1">
            <h4 className="text-sm font-bold text-amber-200 uppercase tracking-tight">Component Error</h4>
            <p className="text-xs text-amber-500/70 font-mono">Type: {this.props.type}</p>
          </div>
          <p className="text-xs text-zinc-400 max-w-[280px] leading-relaxed">
            This section failed to render. Check the console for details or verify the JSON data structure.
          </p>
        </div>
      );
    }
    return this.props.children;
  }
}

interface SectionRendererProps {
  section: Section;
  menu?: MenuItem[];
  selectedId?: string | null;
  reorderable?: boolean;
  sectionIndex?: number;
  totalSections?: number;
  onReorder?: (sectionId: string, newIndex: number) => void;
}

const SovereignOverlay: React.FC<{
  type: string;
  scope: string;
  isSelected: boolean;
  sectionId?: string;
  sectionIndex?: number;
  totalSections?: number;
  onReorder?: (sectionId: string, newIndex: number) => void;
}> = ({ type, scope, isSelected, sectionId, sectionIndex = 0, totalSections = 0, onReorder }) => {
  const canMoveUp = typeof sectionIndex === 'number' && sectionIndex > 0 && onReorder;
  const canMoveDown = typeof sectionIndex === 'number' && sectionIndex < totalSections - 1 && onReorder;

  return (
    <div
      data-jp-section-overlay
      aria-hidden
      className={cn(
        'absolute inset-0 pointer-events-none transition-all duration-200 z-[50]',
        'border-2 border-transparent group-hover:border-blue-400/50 group-hover:border-dashed',
        isSelected && 'border-2 border-blue-600 border-solid bg-blue-500/5'
      )}
    >
      <div
        className={cn(
          'absolute top-0 right-0 flex flex-nowrap items-center gap-1 pl-1 pr-2 py-1 text-[9px] font-black uppercase tracking-widest transition-opacity pointer-events-auto',
          'bg-blue-600 text-white',
          isSelected || 'group-hover:opacity-100 opacity-0'
        )}
      >
        {onReorder && sectionId != null && (
          <span className="shrink-0 flex items-center gap-0.5">
            <button
              type="button"
              onClick={(event) => {
                event.stopPropagation();
                if (canMoveUp) onReorder(sectionId, sectionIndex - 1);
              }}
              disabled={!canMoveUp}
              className="inline-flex items-center justify-center min-w-[18px] min-h-[18px] rounded bg-white/20 hover:bg-white/30 disabled:opacity-30 disabled:pointer-events-none"
              title="Move section up"
              aria-label="Move section up"
            >
              <ChevronUp size={12} strokeWidth={2.5} />
            </button>
            <button
              type="button"
              onClick={(event) => {
                event.stopPropagation();
                if (canMoveDown) onReorder(sectionId, sectionIndex + 2);
              }}
              disabled={!canMoveDown}
              className="inline-flex items-center justify-center min-w-[18px] min-h-[18px] rounded bg-white/20 hover:bg-white/30 disabled:opacity-30 disabled:pointer-events-none"
              title="Move section down"
              aria-label="Move section down"
            >
              <ChevronDown size={12} strokeWidth={2.5} />
            </button>
          </span>
        )}
        <span className="shrink-0">{type}</span>
        <span className="opacity-50 shrink-0">|</span>
        <span className="shrink-0">{scope}</span>
      </div>
    </div>
  );
};

export const SectionRenderer: React.FC<SectionRendererProps> = ({
  section,
  menu,
  selectedId,
  reorderable: reorderableProp,
  sectionIndex,
  totalSections,
  onReorder,
}) => {
  const { mode } = useStudio();
  const { registry, overlayDisabledSectionTypes } = useConfig();
  const isStudio = mode === 'studio';
  const isSelected = isStudio && selectedId === section.id;

  const Component = registry[section.type];
  const scope = section.type === 'header' || section.type === 'footer' ? 'global' : 'local';
  const disableOverlayForSection = Array.isArray(overlayDisabledSectionTypes)
    ? overlayDisabledSectionTypes.includes(section.type as string)
    : false;

  const isStickyHeader =
    section.type === 'header' &&
    typeof section.settings === 'object' &&
    section.settings !== null &&
    'sticky' in section.settings &&
    Boolean((section.settings as { sticky?: unknown }).sticky);

  if (!Component) {
    return (
      <div className="p-6 m-4 bg-red-500/10 text-red-400 border border-red-500/20 rounded-lg text-sm font-mono">
        <strong>Missing Component:</strong> {section.type}
      </div>
    );
  }

  const renderInnerComponent = () => {
    const DynamicComponent = Component as React.ComponentType<{
      data: unknown;
      settings?: unknown;
      menu?: MenuItem[];
    }>;
    if (menu) {
      return <DynamicComponent data={section.data} settings={section.settings} menu={menu} />;
    }
    return <DynamicComponent data={section.data} settings={section.settings} />;
  };

  const anchorId =
    typeof section.data === 'object' && section.data !== null && 'anchorId' in section.data
      ? String((section.data as { anchorId?: unknown }).anchorId ?? '')
      : undefined;

  return (
    <div
      id={anchorId || undefined}
      data-section-id={isStudio ? section.id : undefined}
      data-section-type={isStudio ? section.type : undefined}
      data-section-scope={isStudio ? scope : undefined}
      {...(isStudio && isSelected ? { 'data-jp-selected': true } : {})}
      className={cn(
        'relative w-full',
        isStudio && !disableOverlayForSection && 'group cursor-pointer',
        isStudio && isStickyHeader
          ? 'sticky top-0 z-[60]'
          : section.type === 'header'
            ? 'relative'
            : 'relative z-0',
        isSelected && 'z-[70]'
      )}
    >
      <div className={section.type === 'header' ? 'relative' : 'relative z-0'}>
        <SectionErrorBoundary type={section.type}>{renderInnerComponent()}</SectionErrorBoundary>
      </div>

      {isStudio && !disableOverlayForSection && (
        <SovereignOverlay
          type={section.type}
          scope={scope}
          isSelected={Boolean(isSelected)}
          sectionId={reorderableProp && scope === 'local' ? section.id : undefined}
          sectionIndex={reorderableProp && scope === 'local' ? sectionIndex : undefined}
          totalSections={reorderableProp && scope === 'local' ? totalSections : undefined}
          onReorder={reorderableProp && scope === 'local' ? onReorder : undefined}
        />
      )}
    </div>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/rendering/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/rendering/index.ts"
export { PageRenderer } from './PageRenderer';
export { SectionRenderer } from './SectionRenderer';
export { useDocumentMeta } from './useDocumentMeta';

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/rendering/useDocumentMeta.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/rendering/useDocumentMeta.ts"
import { useEffect } from 'react';
import type { PageMeta } from '../../contract/kernel';

export const useDocumentMeta = (meta: PageMeta): void => {
  useEffect(() => {
    document.title = meta.title;
    let metaDescription = document.querySelector('meta[name="description"]');
    if (!metaDescription) {
      metaDescription = document.createElement('meta');
      metaDescription.setAttribute('name', 'description');
      document.head.appendChild(metaDescription);
    }
    metaDescription.setAttribute('content', meta.description);
  }, [meta.title, meta.description]);
};

END_OF_FILE_CONTENT
mkdir -p "core/src/runtime/theme"
echo "Creating core/src/runtime/theme/ThemeLoader.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/theme/ThemeLoader.tsx"
import React, { useLayoutEffect } from 'react';

export interface ThemeLoaderProps {
  mode: 'tenant' | 'admin';
  tenantCss: string;
  adminCss: string;
  children: React.ReactNode;
}

export const ThemeLoader: React.FC<ThemeLoaderProps> = ({ mode, tenantCss, adminCss, children }) => {
  useLayoutEffect(() => {
    const styleId = `jp-theme-${mode}`;
    const css = mode === 'tenant' ? tenantCss : adminCss;

    if (!document.getElementById(styleId) && css) {
      const style = document.createElement('style');
      style.id = styleId;
      style.innerHTML = css;
      document.head.appendChild(style);
    }

    return () => {
      const style = document.getElementById(styleId);
      if (style) style.remove();
    };
  }, [mode, tenantCss, adminCss]);

  return <>{children}</>;
};

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/theme/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/theme/index.ts"
export { ThemeLoader, type ThemeLoaderProps } from './ThemeLoader';
export { buildThemeVariableMap, themeManager } from './theme-manager';

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/theme/theme-manager.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/theme/theme-manager.test.ts"
import { expect, test } from 'vitest';

import type { ThemeConfig } from '../../contract/kernel';
import { buildThemeVariableMap, themeManager } from './theme-manager';

type DeepPartial<T> = {
  [K in keyof T]?: T[K] extends object ? DeepPartial<T[K]> : T[K];
};

function createTheme(
  overrides: DeepPartial<ThemeConfig['tokens']> = {}
): ThemeConfig {
  return {
    name: 'Test Theme',
    tokens: {
      colors: {
        primary: '#111111',
        secondary: '#222222',
        accent: '#333333',
        background: '#444444',
        surface: '#555555',
        surfaceAlt: '#666666',
        text: '#777777',
        textMuted: '#888888',
        border: '#999999',
        ...overrides.colors,
      },
      typography: {
        fontFamily: {
          primary: 'Inter, sans-serif',
          mono: 'JetBrains Mono, monospace',
          display: 'Bricolage Grotesque, sans-serif',
          ...overrides.typography?.fontFamily,
        },
      },
      borderRadius: {
        sm: '4px',
        md: '8px',
        lg: '12px',
        ...overrides.borderRadius,
      },
    },
  };
}

class FakeStyle {
  private values = new Map<string, string>();

  setProperty(name: string, value: string): void {
    this.values.set(name, value);
  }

  removeProperty(name: string): void {
    this.values.delete(name);
  }

  getPropertyValue(name: string): string {
    return this.values.get(name) ?? '';
  }
}

test('buildThemeVariableMap exports dynamic variables and semantic aliases', () => {
  const theme = createTheme({
    colors: {
      pi: '#314159',
    },
  });

  const vars = buildThemeVariableMap(theme);

  expect(vars['--theme-colors-primary']).toBe('#111111');
  expect(vars['--theme-colors-pi']).toBe('#314159');
  expect(vars['--theme-typography-font-family-display']).toBe('Bricolage Grotesque, sans-serif');
  expect(vars['--theme-primary']).toBe('var(--theme-colors-primary)');
  expect(vars['--theme-font-display']).toBe('var(--theme-typography-font-family-display)');
  expect(vars['--theme-radius-lg']).toBe('var(--theme-border-radius-lg)');
});

test('buildThemeVariableMap skips optional aliases when source token is missing', () => {
  const theme = createTheme({
    typography: {
      fontFamily: {
        display: undefined,
      },
    },
  });

  const vars = buildThemeVariableMap(theme);

  expect(vars['--theme-typography-font-family-display']).toBeUndefined();
  expect(vars['--theme-font-display']).toBeUndefined();
});

test('themeManager.setTheme removes stale dynamic tokens before applying next theme', () => {
  const fakeStyle = new FakeStyle();
  const previousDocument = Reflect.get(globalThis, 'document');

  Reflect.set(globalThis, 'document', {
    documentElement: {
      style: fakeStyle,
    },
  });

  try {
    themeManager.setTheme(
      createTheme({
        colors: {
          pi: '#314159',
        },
      })
    );
    expect(fakeStyle.getPropertyValue('--theme-colors-pi')).toBe('#314159');
    expect(fakeStyle.getPropertyValue('--theme-font-display')).toBe('var(--theme-typography-font-family-display)');

    themeManager.setTheme(createTheme());
    expect(fakeStyle.getPropertyValue('--theme-colors-pi')).toBe('');
    expect(fakeStyle.getPropertyValue('--theme-font-display')).toBe('var(--theme-typography-font-family-display)');
  } finally {
    if (previousDocument === undefined) {
      Reflect.deleteProperty(globalThis, 'document');
    } else {
      Reflect.set(globalThis, 'document', previousDocument);
    }
  }
});

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/theme/theme-manager.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/theme/theme-manager.ts"
import type { ThemeConfig } from '../../contract/kernel';

type ThemeLeafValue = string | number;
interface ThemeNode {
  [key: string]: ThemeLeafValue | ThemeNode;
}

const appliedThemeProperties = new Set<string>();

function toKebabCase(value: string): string {
  return value.replace(/([a-z0-9])([A-Z])/g, '$1-$2').replace(/[_\s]+/g, '-').toLowerCase();
}

function flattenThemeNode(
  node: ThemeNode,
  path: string[] = [],
  result: Record<string, string> = {}
): Record<string, string> {
  Object.entries(node).forEach(([key, value]) => {
    const nextPath = [...path, toKebabCase(key)];
    if (typeof value === 'string' || typeof value === 'number') {
      result[`--theme-${nextPath.join('-')}`] = String(value);
      return;
    }

    if (value && typeof value === 'object' && !Array.isArray(value)) {
      flattenThemeNode(value as ThemeNode, nextPath, result);
    }
  });

  return result;
}

function addAlias(
  mappings: Record<string, string>,
  alias: string,
  sourceVariableName: string,
  sourceValue: string | undefined
): void {
  if (!sourceValue) return;
  mappings[alias] = `var(${sourceVariableName})`;
}

export function buildThemeVariableMap(theme: ThemeConfig): Record<string, string> {
  const dynamicMappings = flattenThemeNode(theme.tokens as unknown as ThemeNode);
  const mappings = { ...dynamicMappings };

  addAlias(mappings, '--theme-primary', '--theme-colors-primary', dynamicMappings['--theme-colors-primary']);
  addAlias(mappings, '--theme-secondary', '--theme-colors-secondary', dynamicMappings['--theme-colors-secondary']);
  addAlias(mappings, '--theme-accent', '--theme-colors-accent', dynamicMappings['--theme-colors-accent']);
  addAlias(mappings, '--theme-background', '--theme-colors-background', dynamicMappings['--theme-colors-background']);
  addAlias(mappings, '--theme-surface', '--theme-colors-surface', dynamicMappings['--theme-colors-surface']);
  addAlias(mappings, '--theme-surface-alt', '--theme-colors-surface-alt', dynamicMappings['--theme-colors-surface-alt']);
  addAlias(mappings, '--theme-text', '--theme-colors-text', dynamicMappings['--theme-colors-text']);
  addAlias(mappings, '--theme-text-muted', '--theme-colors-text-muted', dynamicMappings['--theme-colors-text-muted']);
  addAlias(mappings, '--theme-border', '--theme-colors-border', dynamicMappings['--theme-colors-border']);
  addAlias(
    mappings,
    '--theme-font-primary',
    '--theme-typography-font-family-primary',
    dynamicMappings['--theme-typography-font-family-primary']
  );
  addAlias(
    mappings,
    '--theme-font-mono',
    '--theme-typography-font-family-mono',
    dynamicMappings['--theme-typography-font-family-mono']
  );
  addAlias(
    mappings,
    '--theme-font-display',
    '--theme-typography-font-family-display',
    dynamicMappings['--theme-typography-font-family-display']
  );
  addAlias(mappings, '--theme-radius-sm', '--theme-border-radius-sm', dynamicMappings['--theme-border-radius-sm']);
  addAlias(mappings, '--theme-radius-md', '--theme-border-radius-md', dynamicMappings['--theme-border-radius-md']);
  addAlias(mappings, '--theme-radius-lg', '--theme-border-radius-lg', dynamicMappings['--theme-border-radius-lg']);

  return mappings;
}

export const themeManager = {
  setTheme: (theme: ThemeConfig): void => {
    const root = document.documentElement;
    const mappings = buildThemeVariableMap(theme);

    appliedThemeProperties.forEach((property) => {
      root.style.removeProperty(property);
    });
    appliedThemeProperties.clear();

    Object.entries(mappings).forEach(([key, value]) => {
      root.style.setProperty(key, value);
      appliedThemeProperties.add(key);
    });
  },
};

END_OF_FILE_CONTENT
mkdir -p "core/src/runtime/url"
echo "Creating core/src/runtime/url/base-path.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/url/base-path.test.ts"
import { describe, expect, it } from 'vitest';

import { normalizeBasePath, withBasePath } from './base-path';

describe('normalizeBasePath', () => {
  it('falls back to root when missing', () => {
    expect(normalizeBasePath()).toBe('/');
    expect(normalizeBasePath('')).toBe('/');
    expect(normalizeBasePath('/')).toBe('/');
  });

  it('normalizes non-root base paths with leading and trailing slash', () => {
    expect(normalizeBasePath('core')).toBe('/core/');
    expect(normalizeBasePath('/core')).toBe('/core/');
    expect(normalizeBasePath('/core/')).toBe('/core/');
  });
});

describe('withBasePath', () => {
  it('keeps root-based paths unchanged when base path is root', () => {
    expect(withBasePath('/pages/home.json', '/')).toBe('/pages/home.json');
    expect(withBasePath('pages/home.json', '/')).toBe('/pages/home.json');
  });

  it('prepends base path for sub-route deployments', () => {
    expect(withBasePath('/pages/home.json', '/core/')).toBe('/core/pages/home.json');
    expect(withBasePath('pages/home.json', '/core')).toBe('/core/pages/home.json');
  });

  it('keeps absolute URLs and anchors unchanged', () => {
    expect(withBasePath('https://example.com/a', '/core/')).toBe('https://example.com/a');
    expect(withBasePath('#section', '/core/')).toBe('#section');
  });
});

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/url/base-path.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/url/base-path.ts"
const ABSOLUTE_URL_RE = /^[a-zA-Z][a-zA-Z\d+\-.]*:/;

export function normalizeBasePath(value?: string): string {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (!raw || raw === '/') return '/';

  const withLeadingSlash = raw.startsWith('/') ? raw : `/${raw}`;
  const withoutTrailingSlashes = withLeadingSlash.replace(/\/+$/, '');
  return withoutTrailingSlashes.length > 0 ? `${withoutTrailingSlashes}/` : '/';
}

export function withBasePath(pathname: string, basePath?: string): string {
  const value = pathname.trim();
  if (!value) return normalizeBasePath(basePath);
  if (ABSOLUTE_URL_RE.test(value) || value.startsWith('#')) return value;

  const normalizedBasePath = normalizeBasePath(basePath);
  const normalizedPath = value.startsWith('/') ? value : `/${value}`;
  if (normalizedBasePath === '/') return normalizedPath;

  const withoutLeadingSlash = normalizedPath.replace(/^\/+/, '');
  return `${normalizedBasePath}${withoutLeadingSlash}`;
}

END_OF_FILE_CONTENT
echo "Creating core/src/runtime/url/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/runtime/url/index.ts"
export { normalizeBasePath, withBasePath } from './base-path';

END_OF_FILE_CONTENT
mkdir -p "core/src/studio"
echo "Creating core/src/studio/StudioContext.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/StudioContext.tsx"
import React, { createContext, useContext, useEffect, ReactNode } from 'react';

type StudioMode = 'visitor' | 'studio';

interface StudioContextType {
  mode: StudioMode;
}

const StudioContext = createContext<StudioContextType | undefined>(undefined);

export const StudioProvider: React.FC<{ mode: StudioMode; children: ReactNode }> = ({ mode, children }) => {
  useEffect(() => {
    if (mode !== 'studio') return;

    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node instanceof HTMLElement && node.hasAttribute('data-radix-portal')) {
            node.setAttribute('data-jp-studio-portal', 'true');
          }
        });
      });
    });

    observer.observe(document.body, { childList: true });

    return () => observer.disconnect();
  }, [mode]);

  return (
    <StudioContext.Provider value={{ mode }}>
      {children}
    </StudioContext.Provider>
  );
};

export const useStudio = () => {
  const context = useContext(StudioContext);
  if (context === undefined) {
    throw new Error('useStudio must be used within a StudioProvider');
  }
  return context;
};

END_OF_FILE_CONTENT
mkdir -p "core/src/studio/admin"
echo "Creating core/src/studio/admin/AddSectionLibrary.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/AddSectionLibrary.tsx"
/**
 * Add Section Library — tenant-agnostic.
 * Displays a list of section types (from config) and invokes onSelect(type) when one is chosen.
 * Labels come from config.sectionTypeLabels or are derived by humanizing the type id.
 */
import React, { useEffect } from 'react';
import { Layers, X } from 'lucide-react';
import { cn } from '../../lib/utils';

function humanizeTypeId(typeId: string): string {
  return typeId
    .split('-')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

export interface AddSectionLibraryProps {
  open: boolean;
  onClose: () => void;
  /** Section type ids that can be added (e.g. from config.addSection.addableSectionTypes or derived). */
  sectionTypes: string[];
  /** Optional display label per type; falls back to humanized type id. */
  sectionTypeLabels?: Record<string, string>;
  onSelect: (sectionType: string) => void;
}

export const AddSectionLibrary: React.FC<AddSectionLibraryProps> = ({
  open,
  onClose,
  sectionTypes,
  sectionTypeLabels,
  onSelect,
}) => {
  useEffect(() => {
    if (!open) return;
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [open, onClose]);

  if (!open) return null;

  const getLabel = (typeId: string) =>
    sectionTypeLabels?.[typeId] ?? humanizeTypeId(typeId);

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="jp-add-section-title"
    >
      <div
        className="absolute inset-0 bg-zinc-950/80 backdrop-blur-sm"
        onClick={onClose}
        aria-hidden="true"
      />
      <div className="relative w-full max-w-md max-h-[85vh] flex flex-col rounded-xl border border-zinc-700 bg-zinc-900 shadow-2xl overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800 shrink-0">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-blue-500/20 text-blue-400">
              <Layers size={18} />
            </div>
            <h2 id="jp-add-section-title" className="text-sm font-bold text-white">
              Add section
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-md text-zinc-400 hover:text-white hover:bg-zinc-800 transition-colors"
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {sectionTypes.length === 0 ? (
            <p className="text-xs text-zinc-500 text-center py-8">
              No section types available. Configure addableSectionTypes or schemas.
            </p>
          ) : (
            <ul className="grid gap-2" role="listbox">
              {sectionTypes.map((typeId) => (
                <li key={typeId} role="option">
                  <button
                    type="button"
                    onClick={() => {
                      onSelect(typeId);
                      onClose();
                    }}
                    className={cn(
                      'w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left',
                      'border border-zinc-700/80 bg-zinc-800/50',
                      'hover:border-blue-500/40 hover:bg-zinc-800 transition-colors',
                      'focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:ring-offset-2 focus:ring-offset-zinc-900'
                    )}
                  >
                    <span className="flex items-center justify-center w-9 h-9 rounded-md bg-zinc-700/80 text-zinc-400 text-xs font-mono shrink-0">
                      {typeId}
                    </span>
                    <span className="text-sm font-medium text-zinc-200">
                      {getLabel(typeId)}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="px-5 py-3 border-t border-zinc-800 shrink-0">
          <p className="text-[10px] text-zinc-500 uppercase tracking-wider">
            Choose a section type to add to the bottom of this page
          </p>
        </div>
      </div>
    </div>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/AdminSidebar.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/AdminSidebar.tsx"
import React, { useState, useEffect, useRef, useDeferredValue, useMemo } from 'react';
import { z } from 'zod';
import {
  DndContext,
  DragOverlay,
  PointerSensor,
  TouchSensor,
  KeyboardSensor,
  useSensor,
  useSensors,
  closestCenter,
  type DragEndEvent,
  type DragStartEvent,
} from '@dnd-kit/core';
import { restrictToVerticalAxis } from '@dnd-kit/modifiers';
import {
  SortableContext,
  verticalListSortingStrategy,
  useSortable,
  sortableKeyboardCoordinates,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { useConfig } from '../../runtime/config/ConfigContext';
import { cn } from '../../lib/utils';
import { FormFactory } from './FormFactory';
import type { PageConfig, Section } from '../../contract/kernel';
import type { JsonPagesConfig } from '../../contract/types-engine';
import { Layers, ChevronUp, GripVertical, Settings, Trash2, AlertCircle, X, Plus, Save } from 'lucide-react';
import { Button } from '../ui/button';
import { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider } from '../ui/tooltip';
import { PageSelector } from './PageSelector';

interface SelectedSectionInfo {
  id: string;
  type: string;
  scope: string;
}

export interface LayerItem {
  id: string;
  type: string;
  scope: string;
  title?: string;
}

/** Used by the section-settings modal to update a section without changing Inspector selection. */
export type OnUpdateSection = (
  sectionId: string,
  scope: 'global' | 'local',
  sectionType: string,
  newData: Record<string, unknown>
) => void;

interface AdminSidebarProps {
  selectedSection: SelectedSectionInfo | null;
  pageData: PageConfig | { sections: Section[] };
  /** All sections (header + page sections + footer) for resolving modal section data. */
  allSectionsData?: Section[];
  collections?: JsonPagesConfig['collections'];
  collectionSource?: string;
  onUpdate: (newData: Record<string, unknown>) => void;
  /** Update a section by id/scope (e.g. from settings modal). When provided with allSectionsData, gear opens modal. */
  onUpdateSection?: OnUpdateSection;
  onClose: () => void;
  /** Root-to-leaf path for deep focus (e.g. silos -> blocks). When null, no canvas selection. */
  expandedItemPath?: Array<{ fieldKey: string; itemId?: string }> | null;
  onReorderSection?: (sectionId: string, newIndex: number) => void;
  allLayers?: LayerItem[];
  activeSectionId?: string | null;
  onRequestScrollToSection?: (sectionId: string) => void;
  onDeleteSection?: (sectionId: string) => void;
  /** When provided, shows an "Add section" button in the inspector header that opens the section library. */
  onAddSection?: () => void;
  /** Whether there are unsaved changes for the current draft. */
  hasChanges?: boolean;
  /** Save to file (writes JSON to repo via server). */
  onSaveToFile?: () => void;
  /** Hot Save callback (typically cloud save2edge). */
  onHotSave?: () => void;
  /** Cold Save callback (typically save2repo / deploy pipeline). */
  onColdSave?: () => void;
  /** When true, show "Salvato" in the status bar (e.g. for 2s after save-to-file succeeds). */
  saveSuccessFeedback?: boolean;
  /** When true, show "Saved" feedback for hot save (e.g. for 2s after success). */
  hotSaveSuccessFeedback?: boolean;
  /** When true, hot save action is currently running. */
  hotSaveInProgress?: boolean;
  /** Controls visibility of the local Save button. */
  showLocalSave?: boolean;
  /** Controls visibility of Hot Save button. */
  showHotSave?: boolean;
  /** Controls visibility of Save2Repo / Cold Save button. */
  showColdSave?: boolean;
  /** Restore page from file (resets in-memory draft for current slug). Hidden by default; set showResetToFile to display. */
  onResetToFile?: () => void;
  /** When true, shows the "Ripristina da file" button (default false = hidden). */
  showResetToFile?: boolean;
  /** Available page slugs. When length > 0 and onPageChange set, shows page selector under Inspector header. */
  pageSlugs?: string[];
  /** Current page slug. */
  currentSlug?: string;
  /** Called when user selects another page; engine should navigate to /admin/:slug. */
  onPageChange?: (slug: string) => void;
}

const SETTINGS_KEYS = new Set(['anchorId', 'paddingTop', 'paddingBottom', 'theme', 'container']);
const INLINE_EDITOR_UI_HINTS = new Set(['ui:editorial-markdown']);

const unwrapSchema = (schema: z.ZodTypeAny): z.ZodTypeAny => {
  if (schema instanceof z.ZodOptional || schema instanceof z.ZodDefault || schema instanceof z.ZodNullable) {
    return unwrapSchema(schema._def.innerType);
  }
  return schema;
};

const getUiHint = (schema: z.ZodTypeAny | undefined): string => {
  if (!schema) return '';
  const raw = schema as z.ZodTypeAny & { _def?: { description?: unknown } };
  const direct = typeof schema.description === 'string' ? schema.description : null;
  if (direct) return direct;
  const defDescription = typeof raw._def?.description === 'string' ? raw._def.description : null;
  if (defDescription) return defDescription;
  const unwrapped = unwrapSchema(schema);
  if (unwrapped !== schema) {
    return getUiHint(unwrapped);
  }
  return '';
};

const humanizeLabel = (label: string): string =>
  label
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());

/** Activation: 8px movement to start drag (avoids accidental drag on click). Touch: 200ms delay so scroll works. */
const pointerSensor = { activationConstraint: { distance: 8 } };
const touchSensor = { activationConstraint: { delay: 200, tolerance: 5 } };

interface LayerRowOpts {
  isSelected: boolean;
  isActive: boolean;
  isDragging: boolean;
  canDelete: boolean;
  deleteConfirm: boolean;
  onSelect: () => void;
  onDelete: () => void;
  onOpenSettings: (e: React.MouseEvent) => void;
}

/** Shared row UI (used by both sortable and overlay). */
function LayerRowContent({
  layer,
  opts,
  dragHandleProps,
}: {
  layer: LayerItem;
  opts: LayerRowOpts;
  dragHandleProps?: { 'aria-pressed'?: boolean; 'aria-roledescription'?: string } & Record<string, unknown>;
}) {
  const { isSelected, isActive, isDragging, canDelete, onSelect, onOpenSettings, onDelete } = opts;
  const canReorder = !!dragHandleProps;
  return (
    <div
      className={cn(
        'group flex items-center gap-2 pl-1 pr-2 py-2.5 rounded-lg text-left transition-all duration-200 cursor-pointer border-l-2',
        isSelected ? 'bg-primary/[0.08] border-primary' : isActive ? 'bg-zinc-800/30 border-emerald-500/60' : 'border-transparent hover:bg-zinc-800/40',
        isDragging && 'opacity-50 shadow-lg',
        canReorder ? 'cursor-grab active:cursor-grabbing' : 'cursor-default'
      )}
    >
      {canReorder ? (
        <span
          className="shrink-0 w-5 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-150 cursor-grab touch-none"
          aria-label="Trascina per riordinare"
          {...dragHandleProps}
        >
          <GripVertical size={12} className="text-zinc-600" />
        </span>
      ) : (
        <span className="shrink-0 w-5 flex items-center justify-center opacity-0 group-hover:opacity-100 pointer-events-none">
          <GripVertical size={12} className="text-zinc-600/50" />
        </span>
      )}
      <button type="button" onClick={onSelect} className="flex-1 min-w-0 text-left">
        <div className="flex items-center gap-1.5">
          <span className={cn('text-xs font-bold uppercase tracking-[0.06em] truncate', isSelected ? 'text-primary' : 'text-zinc-500')}>
            {layer.type}
          </span>
          {isActive && <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 shrink-0" aria-hidden />}
        </div>
        <span className="text-[11px] text-zinc-600 block truncate leading-snug mt-0.5">
          {layer.title ?? `${layer.type} section`}
        </span>
      </button>
      <div className="flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity duration-150">
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="ghost" size="icon-xs" className="text-zinc-600 hover:text-zinc-300" onClick={(e) => { e.stopPropagation(); onOpenSettings(e); }}>
              <Settings size={12} />
            </Button>
          </TooltipTrigger>
          <TooltipContent>Settings</TooltipContent>
        </Tooltip>
        {canDelete && (
          <Tooltip>
            <TooltipTrigger asChild>
              <Button variant="ghost" size="icon-xs" className="text-zinc-600 hover:text-destructive" onClick={(e) => { e.stopPropagation(); onDelete(); }}>
                <Trash2 size={12} />
              </Button>
            </TooltipTrigger>
            <TooltipContent>Delete section</TooltipContent>
          </Tooltip>
        )}
      </div>
    </div>
  );
}

/** Sortable row: drag handle only, smooth transform/transition from @dnd-kit. */
function SortableLayerRow({
  layer,
  opts,
}: {
  layer: LayerItem;
  opts: LayerRowOpts & { canReorder: boolean };
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: layer.id,
    disabled: !opts.canReorder,
  });
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };
  return (
    <div ref={setNodeRef} style={style} className={cn(isDragging && 'z-10')}>
      <LayerRowContent
        layer={layer}
        opts={{ ...opts, isDragging }}
        dragHandleProps={opts.canReorder ? { ...attributes, ...listeners, 'aria-roledescription': 'elemento trascinabile' } : undefined}
      />
    </div>
  );
}

export const AdminSidebar: React.FC<AdminSidebarProps> = ({
  selectedSection,
  pageData,
  allSectionsData = [],
  collections,
  collectionSource,
  onUpdate,
  onUpdateSection,
  onClose,
  expandedItemPath = null,
  onReorderSection,
  allLayers = [],
  activeSectionId,
  onRequestScrollToSection,
  onDeleteSection,
  onAddSection,
  hasChanges = false,
  onSaveToFile,
  onHotSave,
  onColdSave,
  saveSuccessFeedback = false,
  hotSaveSuccessFeedback = false,
  hotSaveInProgress = false,
  showLocalSave = true,
  showHotSave = false,
  showColdSave = false,
  onResetToFile,
  showResetToFile = false,
  pageSlugs = [],
  currentSlug = 'home',
  onPageChange,
}) => {
  const { schemas } = useConfig();
  const [layersOpen, setLayersOpen] = useState(true);
  const [deleteConfirm, setDeleteConfirm] = useState<string | null>(null);
  const [activeDragId, setActiveDragId] = useState<string | null>(null);
  const [sidebarExpandedItem, setSidebarExpandedItem] = useState<{ fieldKey: string; itemId?: string } | null>(null);
  /** When set, the section-settings modal is open for this section id (avoids Inspector tab/selection state freeze). */
  const [settingsModalSectionId, setSettingsModalSectionId] = useState<string | null>(null);
  const contentScrollRef = useRef<HTMLDivElement>(null);
  const modalContentRef = useRef<HTMLDivElement>(null);

  const sensors = useSensors(
    useSensor(PointerSensor, pointerSensor),
    useSensor(TouchSensor, touchSensor),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
  );

  /** Defer heavy form render so first-time open + edit doesn't freeze the UI (enterprise-grade UX). */
  const deferredSection = useDeferredValue(selectedSection);
  const isFormPending = selectedSection != null && deferredSection?.id !== selectedSection.id;

  // Canvas path takes precedence; otherwise single-level sidebar expansion.
  const effectiveExpandedItemPath =
    expandedItemPath && expandedItemPath.length > 0
      ? expandedItemPath
      : sidebarExpandedItem
        ? [sidebarExpandedItem]
        : null;
  const effectiveExpandedItem =
    effectiveExpandedItemPath?.length
      ? {
          fieldKey: effectiveExpandedItemPath[effectiveExpandedItemPath.length - 1].fieldKey,
          itemId: effectiveExpandedItemPath[effectiveExpandedItemPath.length - 1].itemId,
        }
      : null;

  // When engine clears path (e.g. user clicked section on canvas), clear sidebar expansion too.
  const prevPathRef = useRef(expandedItemPath);
  useEffect(() => {
    if (prevPathRef.current != null && expandedItemPath == null) setSidebarExpandedItem(null);
    prevPathRef.current = expandedItemPath;
  }, [expandedItemPath]);

  /** When a section is selected (from Stage preview click or from Page Layers click), collapse the list so behaviour is the same. */
  useEffect(() => {
    if (selectedSection?.id != null) setLayersOpen(false);
  }, [selectedSection?.id]);

  /** Scroll sidebar content to top. Double rAF so it runs after layout (fixes scroll not moving). */
  const scrollSidebarToTop = () => {
    const id = requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        const el = contentScrollRef.current;
        if (el) {
          el.scrollTo({ top: 0, behavior: 'smooth' });
        }
      });
    });
    return () => cancelAnimationFrame(id);
  };

  /** Scroll sidebar to top when Page Layers list is opened via chevron (effect runs after commit). */
  const prevLayersOpenRef = useRef(layersOpen);
  useEffect(() => {
    if (layersOpen && !prevLayersOpenRef.current) {
      const cancel = scrollSidebarToTop();
      prevLayersOpenRef.current = layersOpen;
      return cancel;
    }
    prevLayersOpenRef.current = layersOpen;
  }, [layersOpen]);

  /** Defer scroll to next frame to avoid blocking main thread when form mounts (enterprise-grade UX). */
  useEffect(() => {
    if (!effectiveExpandedItem) return;
    const scrollEl = contentScrollRef.current;
    if (!scrollEl) return;
    const id = requestAnimationFrame(() => {
      const el = scrollEl.querySelector('[data-jp-expanded-item]') ?? scrollEl.querySelector('[data-jp-focused-field]');
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
    return () => cancelAnimationFrame(id);
  }, [effectiveExpandedItem]);

  const handleLayerClick = (sectionId: string) => {
    setLayersOpen(false);
    onRequestScrollToSection?.(sectionId);
  };

  /** Toggle Page Layers list (header or chevron); scroll to top when opening so list is in view. */
  const handlePageLayersToggle = () => {
    setLayersOpen((prev) => {
      const next = !prev;
      if (next) scrollSidebarToTop();
      return next;
    });
  };

  /** Open the section-settings modal for the given section (no Inspector tab/selection change to avoid UI freeze). */
  const handleOpenSectionSettings = (sectionId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (allSectionsData.length > 0 && onUpdateSection) {
      setSettingsModalSectionId(sectionId);
    } else {
      setLayersOpen(false);
      onRequestScrollToSection?.(sectionId);
    }
  };

  // ESC closes the section-settings modal.
  useEffect(() => {
    if (settingsModalSectionId == null) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setSettingsModalSectionId(null);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [settingsModalSectionId]);

  const handleDelete = (sectionId: string) => {
    if (deleteConfirm === sectionId) {
      onDeleteSection?.(sectionId);
      setDeleteConfirm(null);
    } else {
      setDeleteConfirm(sectionId);
      setTimeout(() => setDeleteConfirm(null), 3000);
    }
  };

  const sortableIds = useMemo(
    () => allLayers.filter((l) => l.scope === 'local').map((l) => l.id),
    [allLayers]
  );
  const canReorder = !!onReorderSection && sortableIds.length > 0;

  const handleDragStart = (event: DragStartEvent) => {
    setActiveDragId(event.active.id as string);
  };

  const handleDragEnd = (event: DragEndEvent) => {
    setActiveDragId(null);
    const { active, over } = event;
    if (!over || active.id === over.id || !onReorderSection) return;
    const from = allLayers.findIndex((l) => l.id === active.id);
    const to = allLayers.findIndex((l) => l.id === over.id);
    if (from === -1 || to === -1) return;
    const newIndex = from < to ? to : to - 1;
    onReorderSection(active.id as string, newIndex);
  };

  const section = selectedSection
    ? pageData.sections.find((s: Section) => s.id === selectedSection.id)
    : undefined;
  /** Section/schema for the form only: deferred so heavy FormFactory doesn't block the main thread. */
  const formSection = deferredSection
    ? pageData.sections.find((s: Section) => s.id === deferredSection.id)
    : undefined;
  const formSchema = deferredSection
    ? (schemas[deferredSection.type] as z.ZodObject<z.ZodRawShape> | undefined)
    : undefined;
  const isInlineEditorialSection = useMemo(() => {
    if (!formSchema) return false;
    const shape = formSchema.shape;
    const contentKeys = Object.keys(shape).filter((k) => !SETTINGS_KEYS.has(k));
    if (contentKeys.length === 0) return false;
    return contentKeys.every((k) => INLINE_EDITOR_UI_HINTS.has(getUiHint(shape[k])));
  }, [formSchema]);
  useEffect(() => {
    if (selectedSection?.id != null && isInlineEditorialSection) {
      setLayersOpen(true);
    }
  }, [selectedSection?.id, isInlineEditorialSection]);

  /** When no section is selected, Page Layers list is always shown (open); otherwise use accordion state. */
  const showLayersList = allLayers.length > 0 && (layersOpen || !selectedSection);

  /** Page switcher: current page label (slug if no labels map). */
  const currentPageLabel = currentSlug ? currentSlug.charAt(0).toUpperCase() + currentSlug.slice(1) : 'Select page';

  /** Rows with separators (header→content, content→footer). Order is controlled by parent via allLayers. */
  const layerRowsWithSeparators = useMemo(() => {
    const rows: Array<{ layer: LayerItem; showSeparatorAbove: boolean }> = [];
    let prevType: string | null = null;
    for (const layer of allLayers) {
      const type = layer.type.toUpperCase();
      const showSeparatorAbove =
        prevType !== null &&
        ((prevType === 'HEADER' && type !== 'HEADER') ||
          (prevType !== 'HEADER' && prevType !== 'FOOTER' && type === 'FOOTER'));
      rows.push({ layer, showSeparatorAbove });
      prevType = type;
    }
    return rows;
  }, [allLayers]);

  return (
    <TooltipProvider>
      <aside className="relative w-full h-full bg-zinc-950 border-l border-zinc-800 flex flex-col shadow-2xl shrink-0 min-w-0 animate-in slide-in-from-right duration-300">
        {/* Header: Inspector + page context or type|scope */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800 shrink-0">
          <div className="min-w-0">
            <h2 className="text-sm font-bold text-white">Inspector</h2>
            <p className="text-[10px] tracking-[0.06em] text-zinc-600 mt-0.5">
              {selectedSection ? (
                <>
                  <span className="text-primary font-bold">{selectedSection.type}</span>
                  <span className="text-zinc-700 mx-1.5">|</span>
                  <span className="uppercase">{selectedSection.scope}</span>
                </>
              ) : (
                <span className="text-zinc-600">
                  {currentPageLabel} · {allLayers.length} sections
                </span>
              )}
            </p>
          </div>
          <Button variant="ghost" size="icon-sm" onClick={onClose} aria-label="Close Inspector">
            <X size={14} />
          </Button>
        </div>

        {/* Page Switcher: encapsulated in PageSelector (styling, a11y, single source of truth) */}
        {pageSlugs.length > 0 && onPageChange && (
          <PageSelector
            pageSlugs={pageSlugs}
            currentSlug={currentSlug}
            onPageChange={onPageChange}
            sectionCount={allLayers.length}
            currentPageLabel={currentPageLabel}
          />
        )}

        {/* Page Layers header */}
        {allLayers.length > 0 && (
          <div className="flex items-center gap-2 px-4 py-2 border-t border-zinc-800/50">
            <button
              type="button"
              onClick={handlePageLayersToggle}
              className="flex items-center gap-2 flex-1 cursor-pointer min-w-0 text-left"
              aria-expanded={showLayersList}
              aria-label={showLayersList ? 'Collapse Page Layers' : 'Expand Page Layers'}
            >
              <Layers size={14} className="text-zinc-500 shrink-0" />
              <span className="text-[11px] font-semibold tracking-[0.04em] text-zinc-400">Page Layers</span>
              <span className="text-[10px] text-zinc-600">({allLayers.length})</span>
              <ChevronUp
                size={13}
                className={cn('ml-auto text-zinc-600 transition-transform duration-200 shrink-0', !layersOpen && 'rotate-180')}
              />
            </button>
            {onAddSection != null && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="ghost" size="icon-sm" className="text-zinc-500 hover:text-primary" onClick={onAddSection}>
                    <Plus size={14} />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Add section</TooltipContent>
              </Tooltip>
            )}
          </div>
        )}

      {/* Radix ScrollArea uses an inner display:table wrapper that breaks position:sticky in descendants. */}
      <div className="relative flex-1 min-h-0 min-w-0 flex flex-col overflow-hidden">
        <div
          ref={contentScrollRef}
          className="min-h-0 min-w-0 flex-1 overflow-y-auto overflow-x-hidden flex flex-col"
          role="region"
          aria-label="Inspector content"
        >
        <div className="flex flex-col min-h-0">
        {showLayersList && (
          <div className="py-1">
            <DndContext
              sensors={sensors}
              collisionDetection={closestCenter}
              modifiers={[restrictToVerticalAxis]}
              onDragStart={handleDragStart}
              onDragEnd={handleDragEnd}
              accessibility={{
                announcements: {
                  onDragStart: () => `Sezione presa in carico. Usa i tasti freccia per spostare, Spazio per rilasciare.`,
                  onDragOver: ({ over }) => over ? `Posizione ${sortableIds.indexOf(String(over.id)) + 1} di ${sortableIds.length}.` : undefined,
                  onDragEnd: ({ over }) => over ? `Sezione rilasciata in nuova posizione.` : `Riposizionamento annullato.`,
                  onDragCancel: () => `Riposizionamento annullato.`,
                },
              }}
            >
              <SortableContext items={sortableIds} strategy={verticalListSortingStrategy}>
                <div className="px-2 space-y-0.5">
                  {layerRowsWithSeparators.map(({ layer, showSeparatorAbove }) => (
                    <React.Fragment key={layer.id}>
                      {showSeparatorAbove && <div className="mx-3 border-t border-zinc-800/60 my-1" />}
                      {layer.scope === 'local' && canReorder ? (
                        <SortableLayerRow
                          layer={layer}
                          opts={{
                            isSelected: selectedSection?.id === layer.id,
                            isActive: activeSectionId === layer.id,
                            isDragging: false,
                            canReorder: true,
                            canDelete: !!onDeleteSection,
                            deleteConfirm: deleteConfirm === layer.id,
                            onSelect: () => handleLayerClick(layer.id),
                            onDelete: () => handleDelete(layer.id),
                            onOpenSettings: (e) => handleOpenSectionSettings(layer.id, e),
                          }}
                        />
                      ) : (
                        <div>
                          <LayerRowContent
                            layer={layer}
                            opts={{
                              isSelected: selectedSection?.id === layer.id,
                              isActive: activeSectionId === layer.id,
                              isDragging: false,
                              canDelete: layer.scope === 'local' && !!onDeleteSection,
                              deleteConfirm: deleteConfirm === layer.id,
                              onSelect: () => handleLayerClick(layer.id),
                              onDelete: () => handleDelete(layer.id),
                              onOpenSettings: (e) => handleOpenSectionSettings(layer.id, e),
                            }}
                          />
                        </div>
                      )}
                    </React.Fragment>
                  ))}
                </div>
              </SortableContext>
              <DragOverlay dropAnimation={{ duration: 200, easing: 'cubic-bezier(0.18, 0.67, 0.6, 1.22)' }}>
                {activeDragId ? (() => {
                  const layer = allLayers.find((l) => l.id === activeDragId);
                  if (!layer) return null;
                  return (
                    <div className="px-2 w-full max-w-[var(--inspector-width,280px)]">
                      <LayerRowContent
                        layer={layer}
                        opts={{
                          isSelected: false,
                          isActive: false,
                          isDragging: true,
                          canDelete: false,
                          deleteConfirm: false,
                          onSelect: () => {},
                          onDelete: () => {},
                          onOpenSettings: () => {},
                        }}
                        dragHandleProps={{ 'aria-hidden': true }}
                      />
                    </div>
                  );
                })() : null}
              </DragOverlay>
            </DndContext>
            {deleteConfirm && (
              <div className="flex items-center gap-2 py-2 px-3 mt-1 mx-2 rounded-md bg-amber-500/10 border border-amber-500/30">
                <AlertCircle size={12} className="text-amber-500 shrink-0" />
                <p className="text-[10px] text-amber-500 font-medium">Click delete again to confirm</p>
              </div>
            )}
          </div>
        )}

        </div>
        {effectiveExpandedItem && section && (() => {
          const data = (section.data as Record<string, unknown>) || {};
          let label: string;
          if (effectiveExpandedItemPath && effectiveExpandedItemPath.length > 0) {
            let current: unknown = data;
            for (const seg of effectiveExpandedItemPath) {
              const next = (current as Record<string, unknown>)?.[seg.fieldKey];
              if (seg.itemId != null && Array.isArray(next)) {
                const item = (next as Record<string, unknown>[]).find(
                  (i) => String((i as Record<string, unknown>)?.id) === String(seg.itemId)
                );
                current = item ?? null;
              } else {
                current = next;
              }
            }
            const rec = (current as Record<string, unknown>) || {};
            const fieldKey = effectiveExpandedItem.fieldKey;
            label =
              (typeof rec.name === 'string' ? rec.name : null) ??
              (typeof rec.title === 'string' ? rec.title : null) ??
              (typeof rec.label === 'string' ? rec.label : null) ??
              humanizeLabel(fieldKey);
          } else {
            const fieldKey = effectiveExpandedItem.fieldKey;
            if (effectiveExpandedItem.itemId != null) {
              const arr = Array.isArray(data[fieldKey]) ? (data[fieldKey] as Record<string, unknown>[]) : [];
              const item = arr.find((i) => String(i?.id) === String(effectiveExpandedItem!.itemId));
              const rec = (item as Record<string, unknown>) || {};
              label =
                (typeof rec.name === 'string' ? rec.name : null) ??
                (typeof rec.title === 'string' ? rec.title : null) ??
                (typeof rec.label === 'string' ? rec.label : null) ??
                humanizeLabel(fieldKey);
            } else {
              label = humanizeLabel(fieldKey);
            }
          }
          return (
            <div className="px-4 py-2 border-b border-zinc-800 bg-zinc-900/50">
              <p className="text-[10px] font-bold uppercase tracking-widest text-zinc-500">Editing</p>
              <p className="text-xs font-medium text-white truncate mt-0.5">{label}</p>
            </div>
          );
        })()}

        <div
          className="flex-1 p-4"
          onFocusCapture={() => selectedSection != null && setLayersOpen(false)}
        >
          {!selectedSection ? (
            <p className="text-xs text-zinc-600 text-center py-10">
              Select a layer above or on the stage to edit.
            </p>
          ) : isFormPending ? (
            <div className="space-y-4 animate-pulse" role="status" aria-label="Loading form">
              <div className="h-4 w-3/4 rounded bg-zinc-800" />
              <div className="h-10 rounded bg-zinc-800/80" />
              <div className="h-10 rounded bg-zinc-800/80" />
              <div className="h-20 rounded bg-zinc-800/80" />
              <div className="h-10 rounded bg-zinc-800/60" />
            </div>
          ) : !formSchema ? (
            <div className="text-xs text-red-400 p-4 border border-dashed border-red-900/30 rounded bg-red-900/10">
              No schema found for {deferredSection?.type ?? selectedSection.type}
            </div>
          ) : (() => {
            const shapeKeys = Object.keys(formSchema.shape);
            const contentKeys = shapeKeys.filter(
              (k) =>
                !SETTINGS_KEYS.has(k) &&
                !INLINE_EDITOR_UI_HINTS.has(getUiHint(formSchema.shape[k]))
            );
            const data = (formSection?.data as Record<string, unknown>) || {};
            if (contentKeys.length === 0) {
              return (
                <p className="text-xs text-zinc-500">Inline editorial section: edit content directly on the canvas.</p>
              );
            }
            return (
              <FormFactory
                schema={formSchema}
                data={data}
                collections={collections}
                collectionSource={collectionSource}
                onChange={(newData) => onUpdate(newData)}
                keys={contentKeys}
                expandedItemPath={effectiveExpandedItemPath}
                onSidebarExpandedItemChange={setSidebarExpandedItem}
              />
            );
          })()}
        </div>
        </div>
      </div>

      <div className="px-4 py-2.5 border-t border-zinc-800 bg-zinc-900/50 flex items-center justify-between gap-3 opacity-100 shrink-0">
        {((showLocalSave && onSaveToFile != null) || (showHotSave && onHotSave != null) || (showColdSave && onColdSave != null) || onResetToFile != null) && (
          <>
            <div className="flex items-center gap-2 min-w-0">
              <div className={cn(
                'w-2 h-2 rounded-full transition-colors duration-300 shrink-0',
                hasChanges ? 'bg-amber-500 shadow-[0_0_8px_rgba(245,158,11,0.5)]' : 'bg-emerald-500'
              )} />
              <span className={cn(
                'text-sm font-medium transition-colors duration-300 truncate',
                (saveSuccessFeedback || hotSaveSuccessFeedback) ? 'text-emerald-400' : hasChanges ? 'text-amber-500' : 'text-zinc-500'
              )}>
                {(saveSuccessFeedback || hotSaveSuccessFeedback) ? 'Saved' : hasChanges ? 'Unsaved Changes' : 'All Changes Saved'}
              </span>
            </div>
            {showLocalSave && onSaveToFile != null && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    size="default"
                    disabled={!hasChanges}
                    className="h-9 min-w-[156px] px-5 text-sm gap-2 ml-auto"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      onSaveToFile();
                    }}
                  >
                    <Save size={14} />
                    <span>Save</span>
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Save to local file</TooltipContent>
              </Tooltip>
            )}
            {showHotSave && onHotSave != null && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    size="default"
                    disabled={!hasChanges || hotSaveInProgress}
                    className="h-9 min-w-[156px] px-5 text-sm gap-2 ml-auto"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      onHotSave();
                    }}
                  >
                    <Save size={14} />
                    <span>{hotSaveInProgress ? 'Saving...' : 'Hot Save'}</span>
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Hot save to edge</TooltipContent>
              </Tooltip>
            )}
            {showColdSave && onColdSave != null && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    size="default"
                    disabled={!hasChanges}
                    className="h-9 min-w-[156px] px-5 text-sm gap-2 ml-auto"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      onColdSave();
                    }}
                  >
                    <Save size={14} />
                    <span>Save2Repo</span>
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Save to repository</TooltipContent>
              </Tooltip>
            )}
            {onResetToFile != null && showResetToFile && (
              <button
                type="button"
                onClick={onResetToFile}
                className="shrink-0 flex items-center gap-1.5 px-2 py-1 rounded text-[11px] font-medium transition-all border border-zinc-700 bg-zinc-900 text-zinc-400 hover:bg-zinc-800 hover:border-zinc-600 hover:text-zinc-300"
                title="Ripristina la pagina dal file (elimina le modifiche in memoria)"
              >
                <span>Ripristina da file</span>
              </button>
            )}
          </>
        )}
      </div>

      {/* Section settings modal: centered, close via X or Escape to avoid Inspector state freeze. */}
      {settingsModalSectionId != null && allSectionsData.length > 0 && onUpdateSection != null && (() => {
        const modalSection = allSectionsData.find((s) => s.id === settingsModalSectionId);
        const layer = allLayers.find((l) => l.id === settingsModalSectionId);
        if (!modalSection) return null;
        const scope = (layer?.scope === 'global' ? 'global' : 'local') as 'global' | 'local';
        const sectionType = modalSection.type;
        const schema = schemas[sectionType] as z.ZodObject<z.ZodRawShape> | undefined;
        const shapeKeys = schema ? Object.keys(schema.shape) : [];
        const settingsKeys = shapeKeys.filter((k) => SETTINGS_KEYS.has(k));
        const data = (modalSection.data as Record<string, unknown>) ?? {};

        if (settingsKeys.length === 0) {
          return (
            <div
              className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 p-4"
              role="dialog"
              aria-modal="true"
              aria-labelledby="section-settings-modal-title"
              onClick={() => setSettingsModalSectionId(null)}
            >
              <div
                ref={modalContentRef}
                className="relative rounded-lg border border-zinc-700 bg-zinc-900 shadow-xl max-w-md w-full overflow-hidden"
                onClick={(e) => e.stopPropagation()}
              >
                <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800">
                  <h2 id="section-settings-modal-title" className="text-sm font-bold text-white">
                    Settings — {sectionType}
                  </h2>
                  <button
                    type="button"
                    onClick={() => setSettingsModalSectionId(null)}
                    className="p-1.5 rounded text-zinc-500 hover:text-white hover:bg-zinc-800 transition-colors"
                    aria-label="Close settings"
                  >
                    <X size={18} />
                  </button>
                </div>
                <div className="p-4">
                  <p className="text-xs text-zinc-500">No settings fields for this section.</p>
                </div>
              </div>
            </div>
          );
        }

        return (
          <div
            className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 p-4"
            role="dialog"
            aria-modal="true"
            aria-labelledby="section-settings-modal-title"
            onClick={(e) => e.target === e.currentTarget && setSettingsModalSectionId(null)}
          >
            <div
              ref={modalContentRef}
              className="relative rounded-lg border border-zinc-700 bg-zinc-900 shadow-xl max-w-md w-full max-h-[85vh] flex flex-col overflow-hidden"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800 shrink-0">
                <h2 id="section-settings-modal-title" className="text-sm font-bold text-white">
                  Settings — {sectionType}
                </h2>
                <button
                  type="button"
                  onClick={() => setSettingsModalSectionId(null)}
                  className="p-1.5 rounded text-zinc-500 hover:text-white hover:bg-zinc-800 transition-colors"
                  aria-label="Close settings (Escape)"
                >
                  <X size={18} />
                </button>
              </div>
              <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
                <FormFactory
                  schema={schema!}
                  data={data}
                  collections={collections}
                  collectionSource={collectionSource}
                  onChange={(newData) => {
                    const merged = { ...(modalSection.data as Record<string, unknown>), ...newData };
                    onUpdateSection(settingsModalSectionId, scope, sectionType, merged);
                  }}
                  keys={settingsKeys}
                />
              </div>
            </div>
          </div>
        );
      })()}
    </aside>
    </TooltipProvider>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/FormFactory.collection-ref.test.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/FormFactory.collection-ref.test.tsx"
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { z } from 'zod';
import { FormFactory } from './FormFactory';

const bookSchema = z.object({
  id: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  author: z.string().describe('ui:text'),
  summary: z.string().describe('ui:textarea'),
});

const authorSchema = z.object({
  id: z.string(),
  name: z.string(),
});

const collectionRecordSchema = z.object({
  items: z.record(z.string(), bookSchema).describe('ui:collection-ref'),
});

const collectionItemSchema = z.object({
  item: bookSchema.describe('ui:collection-ref'),
});

const relatedBookSchema = z.object({
  id: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  author: z.union([authorSchema, z.object({ $ref: z.string() })]).describe('ui:collection-ref:autori'),
});

const relatedCollectionRecordSchema = z.object({
  items: z.record(z.string(), relatedBookSchema).describe('ui:collection-ref:libri'),
});

const StatefulFormFactory = ({
  schema,
  initialData,
  collections,
  collectionSource,
  onChange,
}: {
  schema: z.ZodObject<z.ZodRawShape>;
  initialData: Record<string, unknown>;
  collections?: Record<string, Record<string, unknown>>;
  collectionSource?: string;
  onChange: (next: Record<string, unknown>) => void;
}) => {
  const [data, setData] = useState(initialData);

  return (
    <FormFactory
      schema={schema}
      data={data}
      collections={collections}
      collectionSource={collectionSource}
      onChange={(next) => {
        setData(next);
        onChange(next);
      }}
      expandedItemPath={null}
    />
  );
};

describe('FormFactory ui:collection-ref', () => {
  it('renders collection records as expandable editable items', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const data = {
      items: {
        dune: {
          id: 'dune',
          title: 'Dune',
          author: 'Frank Herbert',
          summary: 'Desert planet politics.',
        },
        neuromancer: {
          id: 'neuromancer',
          title: 'Neuromancer',
          author: 'William Gibson',
          summary: 'Cyberspace noir.',
        },
      },
    };

    render(<StatefulFormFactory schema={collectionRecordSchema} initialData={data} onChange={onChange} />);

    expect(screen.getByText('2 items')).toBeInTheDocument();
    expect(screen.getByText(/entity data is owned by the collection document/i)).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Dune' }));
    await user.clear(screen.getByDisplayValue('Dune'));
    await user.type(screen.getByDisplayValue(''), 'Dune Messiah');

    const lastChange = onChange.mock.calls[onChange.mock.calls.length - 1]?.[0];
    expect(lastChange.items.dune.title).toBe('Dune Messiah');
    expect(lastChange.items.neuromancer.title).toBe('Neuromancer');
  });

  it('renders a single collection object as an editable entity', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const data = {
      item: {
        id: 'dune',
        title: 'Dune',
        author: 'Frank Herbert',
        summary: 'Desert planet politics.',
      },
    };

    render(<StatefulFormFactory schema={collectionItemSchema} initialData={data} onChange={onChange} />);

    await user.clear(screen.getByDisplayValue('Desert planet politics.'));
    await user.type(screen.getByDisplayValue(''), 'Politics, ecology, and prophecy.');

    const lastChange = onChange.mock.calls[onChange.mock.calls.length - 1]?.[0];
    expect(lastChange.item.summary).toBe('Politics, ecology, and prophecy.');
    expect(lastChange.item.title).toBe('Dune');
  });

  it('renders nested collection relations as selectors that emit authored refs', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const data = {
      items: {
        dune: {
          id: 'dune',
          title: 'Dune',
          author: {
            id: 'frank-herbert',
            name: 'Frank Herbert',
          },
        },
      },
    };

    render(
      <StatefulFormFactory
        schema={relatedCollectionRecordSchema}
        initialData={data}
        collections={{
          autori: {
            'frank-herbert': {
              id: 'frank-herbert',
              name: 'Frank Herbert',
            },
            'ursula-k-le-guin': {
              id: 'ursula-k-le-guin',
              name: 'Ursula K. Le Guin',
            },
          },
        }}
        onChange={onChange}
      />
    );

    await user.click(screen.getByRole('button', { name: 'Dune' }));
    await user.selectOptions(screen.getByLabelText('Author'), 'ursula-k-le-guin');

    const lastChange = onChange.mock.calls[onChange.mock.calls.length - 1]?.[0];
    expect(lastChange.items.dune.author).toEqual({
      $ref: '../autori/autori.json#/ursula-k-le-guin',
    });
  });
});

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/FormFactory.nested-array.test.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/FormFactory.nested-array.test.tsx"
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { z } from 'zod';
import { FormFactory } from './FormFactory';

/** Mirrors header-style menu → optional children lists (no `id` in JSON → legacy-* keys). */
const nestedMenuSchema = z.object({
  menu: z
    .array(
      z.object({
        label: z.string().describe('ui:text'),
        href: z.string().describe('ui:text'),
        children: z
          .array(
            z.object({
              label: z.string().describe('ui:text'),
              href: z.string().describe('ui:text'),
            })
          )
          .optional()
          .describe('ui:list'),
      })
    )
    .describe('ui:list'),
});

describe('FormFactory nested ui:list', () => {
  it('keeps inner array row expanded when expandedItemPath does not include inner openItemId', async () => {
    const user = userEvent.setup();
    const data = {
      menu: [
        {
          label: 'Platform',
          href: '/platform',
          children: [
            { label: 'Overview', href: '/platform/overview' },
            { label: 'Architecture', href: '/platform/architecture' },
          ],
        },
      ],
    };

    render(
      <FormFactory
        schema={nestedMenuSchema}
        data={data}
        onChange={() => {}}
        expandedItemPath={null}
      />
    );

    await user.click(screen.getByRole('button', { name: /platform/i }));

    await user.click(screen.getByRole('button', { name: /overview/i }));

    const overviewHref = screen.getByDisplayValue('/platform/overview');
    expect(overviewHref).toBeVisible();
  });
});

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/FormFactory.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/FormFactory.tsx"
import React from 'react';
import { z } from 'zod';
import { InputWidgets, WidgetType } from './InputRegistry';
import { Plus, Trash2, ChevronDown, ChevronUp, ArrowUp, ArrowDown } from 'lucide-react';
import { BaseWidgetProps } from '../../lib/shared-types';
import type { JsonPagesConfig } from '../../contract/types-engine';

/**
 * 🛠️ HELPER: Generates a default value based on the Zod schema.
 * 🛡️ FIX: Now injects a deterministic UUID for every object created.
 */
const generateDefaultValue = (schema: z.ZodTypeAny): unknown => {
  if (schema instanceof z.ZodOptional || schema instanceof z.ZodDefault) {
    return generateDefaultValue(schema._def.innerType);
  }
  
  if (schema instanceof z.ZodObject) {
    // Inizializziamo l'oggetto con un ID univoco per la stabilità di React
    const obj: Record<string, unknown> = {
      id: crypto.randomUUID() 
    };
    
    for (const key in schema.shape) {
      // Se lo schema ha già un campo ID, non lo sovrascriviamo qui, 
      // lasciamo che venga processato normalmente se ha un default.
      if (key === 'id') continue;
      obj[key] = generateDefaultValue(schema.shape[key]);
    }
    return obj;
  }
  
  if (schema instanceof z.ZodArray) return [];
  if (schema instanceof z.ZodString) return "";
  if (schema instanceof z.ZodNumber) return 0;
  if (schema instanceof z.ZodBoolean) return false;
  if (schema instanceof z.ZodEnum) return schema._def.values[0];
  return null;
};

/**
 * 🛠️ HELPER: Extracts the real schema ignoring Zod wrappers.
 */
const getEffectiveSchema = (schema: z.ZodTypeAny): z.ZodTypeAny => {
  if (schema instanceof z.ZodOptional || schema instanceof z.ZodDefault || schema instanceof z.ZodNullable) {
    return getEffectiveSchema(schema._def.innerType);
  }
  return schema;
};

const getUiHint = (schema: z.ZodTypeAny): string | null => {
  const raw = schema as z.ZodTypeAny & { _def?: { description?: unknown } };
  if (typeof schema.description === 'string' && schema.description.length > 0) {
    return schema.description;
  }
  if (typeof raw._def?.description === 'string' && raw._def.description.length > 0) {
    return raw._def.description;
  }
  const effective = getEffectiveSchema(schema);
  if (effective !== schema) {
    return getUiHint(effective);
  }
  return null;
};

interface FormFactoryProps {
  schema: z.ZodObject<z.ZodRawShape>;
  data: Record<string, unknown>;
  onChange: (newData: Record<string, unknown>) => void;
  collections?: JsonPagesConfig['collections'];
  collectionSource?: string;
  /** When set, only render fields whose key is in this array (e.g. Content vs Settings tabs). */
  keys?: string[] | null;
  /** Root-to-leaf path for deep focus (e.g. silos -> blocks). First segment applies to this level. */
  expandedItemPath?: Array<{ fieldKey: string; itemId?: string }> | null;
  /** Called when user expands/collapses an array item in the sidebar (so parent can drive fade). */
  onSidebarExpandedItemChange?: (item: { fieldKey: string; itemId?: string } | null) => void;
}

/**
 * 🏭 POLYMORPHIC FORM FACTORY (V2.8.0)
 * Governance through deterministic IDs.
 */
const fadeWhenUnfocused = (inItemScope: boolean, isFocused: boolean) =>
  inItemScope && !isFocused ? 'opacity-10' : 'opacity-100';

/** Match canvas-sent field key to schema key (e.g. "badge" vs "BADGE", "titleHighlight" vs "TITLEHIGHLIGHT"). */
const fieldKeyMatches = (focusedKey: string | null | undefined, schemaKey: string) =>
  focusedKey != null && schemaKey.toLowerCase() === focusedKey.toLowerCase();

const humanizeLabel = (label: string): string =>
  label
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());

const isRecord = (value: unknown): value is Record<string, unknown> =>
  value != null && typeof value === 'object' && !Array.isArray(value);

const getCollectionRefItemCount = (value: unknown, schema: z.ZodTypeAny): number => {
  if (schema instanceof z.ZodRecord && isRecord(value)) return Object.keys(value).length;
  if (schema instanceof z.ZodObject && isRecord(value)) return 1;
  if (Array.isArray(value)) return value.length;
  return 0;
};

const formatItemCount = (count: number): string => `${count} ${count === 1 ? 'item' : 'items'}`;

const getRecordItemLabel = (key: string, item: Record<string, unknown>, index: number): string => {
  const label =
    (typeof item.title === 'string' ? item.title : null) ||
    (typeof item.label === 'string' ? item.label : null) ||
    (typeof item.name === 'string' ? item.name : null) ||
    (typeof item.id === 'string' ? item.id : null);

  return label ?? `Item #${index + 1} (${key})`;
};

const getCollectionRefSource = (uiHint: string): string | null => {
  const [, , source] = uiHint.split(':');
  return source?.trim() || null;
};

const getRelationSelectedId = (value: unknown): string => {
  if (isRecord(value) && typeof value.id === 'string') return value.id;
  if (isRecord(value) && typeof value.$ref === 'string') {
    const pointer = value.$ref.split('#')[1]?.replace(/^\//, '') ?? '';
    return pointer.split('/')[0] ?? '';
  }
  return '';
};

const buildCollectionItemRef = (
  targetSource: string,
  itemId: string,
  currentCollectionSource?: string
): { $ref: string } => ({
  $ref: currentCollectionSource
    ? `../${targetSource}/${targetSource}.json#/${itemId}`
    : `../collections/${targetSource}/${targetSource}.json#/${itemId}`,
});

export const FormFactory: React.FC<FormFactoryProps> = ({
  schema,
  data,
  onChange,
  collections,
  collectionSource,
  keys,
  expandedItemPath,
  onSidebarExpandedItemChange,
}) => {
  const shape = schema.shape;
  const fieldKeys = keys != null
    ? Object.keys(shape).filter((k) => keys.includes(k))
    : Object.keys(shape);
  const firstSeg = expandedItemPath?.[0];
  const effectiveFocusedFieldKey = firstSeg?.fieldKey ?? null;
  const inItemScope = effectiveFocusedFieldKey != null;

  return (
    <div className="space-y-4">
      {fieldKeys.map((key) => {
        const fieldSchema = shape[key];
        if (!fieldSchema) return null;

        const effectiveSchema = getEffectiveSchema(fieldSchema);
        const uiHint = getUiHint(fieldSchema) || 'ui:text';
        const value = data[key];

        // Editorial fields are edited directly on Stage and not in Inspector form.
        if (uiHint === 'ui:editorial-markdown') return null;
        if (uiHint === 'ui:hidden') return null;

        if (uiHint.startsWith('ui:collection-ref')) {
          const isFocusedField = fieldKeyMatches(effectiveFocusedFieldKey, key);
          const relationSource = getCollectionRefSource(uiHint);
          if (
            relationSource &&
            !(effectiveSchema instanceof z.ZodRecord) &&
            !(effectiveSchema instanceof z.ZodObject)
          ) {
            const relationCollection = isRecord(collections?.[relationSource])
              ? (collections?.[relationSource] as Record<string, unknown>)
              : {};
            const relationEntries = Object.entries(relationCollection).filter(([, item]) => isRecord(item));
            const selectedId = getRelationSelectedId(value);
            const selectId = `collection-ref-${key}`;

            return (
              <div
                key={key}
                className={`grid w-full gap-2 mb-4 transition-opacity duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
                {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
              >
                <label htmlFor={selectId} className="text-[11px] font-semibold tracking-[0.02em] text-zinc-300">
                  {humanizeLabel(key)}
                </label>
                <select
                  id={selectId}
                  className="h-9 rounded-md border border-zinc-700 bg-zinc-900/50 px-3 text-[13px] text-zinc-100 focus:outline-none focus:ring-2 focus:ring-blue-600"
                  value={selectedId}
                  onChange={(event) => {
                    const itemId = event.target.value;
                    if (!itemId) return;
                    onChange({
                      ...data,
                      [key]: buildCollectionItemRef(relationSource, itemId, collectionSource),
                    });
                  }}
                >
                  <option value="" disabled>
                    Select...
                  </option>
                  {relationEntries.map(([recordKey, item], index) => {
                    const itemRecord = item as Record<string, unknown>;
                    const itemId = typeof itemRecord.id === 'string' ? itemRecord.id : recordKey;
                    return (
                      <option key={itemId} value={itemId}>
                        {getRecordItemLabel(recordKey, itemRecord, index)}
                      </option>
                    );
                  })}
                </select>
              </div>
            );
          }
          const itemCount = getCollectionRefItemCount(value, effectiveSchema);
          const recordValue = isRecord(value) ? value : {};
          const openItemIdFromPath = fieldKeyMatches(firstSeg?.fieldKey, key) ? firstSeg?.itemId : undefined;
          const pathTail =
            expandedItemPath && fieldKeyMatches(firstSeg?.fieldKey, key) && expandedItemPath.length > 1
              ? expandedItemPath.slice(1)
              : undefined;

          return (
            <div
              key={key}
              className={`rounded-lg border border-zinc-800 bg-zinc-900/30 p-4 transition-opacity duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
              {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
            >
              <div className="flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-[11px] font-semibold tracking-[0.04em] text-zinc-300">
                    {humanizeLabel(key)}
                  </p>
                  <p className="mt-1 text-[11px] leading-relaxed text-zinc-500">
                    Externally bound collection. The page keeps its reference; entity data is owned by the collection document.
                  </p>
                </div>
                <span className="shrink-0 rounded-full border border-zinc-700 px-2 py-1 text-[10px] font-semibold text-zinc-400">
                  {formatItemCount(itemCount)}
                </span>
              </div>

              {effectiveSchema instanceof z.ZodRecord && (
                <div className="mt-4 space-y-2">
                  {Object.entries(recordValue).map(([recordKey, recordItem], index) => {
                    const itemRecord = isRecord(recordItem) ? recordItem : {};
                    const itemSchema = getEffectiveSchema(effectiveSchema.valueSchema);
                    const itemId = String(itemRecord.id ?? recordKey);
                    const isExpandedItem = openItemIdFromPath != null && String(openItemIdFromPath) === itemId;
                    const isFadedItem = inItemScope && isFocusedField && openItemIdFromPath != null && !isExpandedItem;

                    return (
                      <CollectionRefRecordItemWrapper
                        key={recordKey}
                        itemId={itemId}
                        openItemId={openItemIdFromPath != null ? String(openItemIdFromPath) : undefined}
                        isFaded={isFadedItem}
                        label={getRecordItemLabel(recordKey, itemRecord, index)}
                        onExpandedChange={onSidebarExpandedItemChange ? (open) => onSidebarExpandedItemChange(open ? { fieldKey: key, itemId } : null) : undefined}
                      >
                        {itemSchema instanceof z.ZodObject ? (
                          <FormFactory
                            schema={itemSchema}
                            data={itemRecord}
                            collections={collections}
                            collectionSource={relationSource ?? collectionSource}
                            expandedItemPath={isExpandedItem ? pathTail : undefined}
                            onChange={(val) => {
                              onChange({
                                ...data,
                                [key]: {
                                  ...recordValue,
                                  [recordKey]: val,
                                },
                              });
                            }}
                          />
                        ) : (
                          <div className="text-[10px] text-red-400">Collection records must contain object items.</div>
                        )}
                      </CollectionRefRecordItemWrapper>
                    );
                  })}
                </div>
              )}

              {effectiveSchema instanceof z.ZodObject && (
                <div className="mt-4 border-t border-zinc-800 pt-4">
                  <FormFactory
                    schema={effectiveSchema}
                    data={recordValue}
                    collections={collections}
                    collectionSource={relationSource ?? collectionSource}
                    expandedItemPath={pathTail}
                    onChange={(val) => onChange({ ...data, [key]: val })}
                  />
                </div>
              )}
            </div>
          );
        }

        // 0. IMAGE PICKER: object value but single widget (no nested form)
        if (uiHint === 'ui:image-picker' && effectiveSchema instanceof z.ZodObject) {
          const isFocusedField = fieldKeyMatches(effectiveFocusedFieldKey, key);
          const Widget = (InputWidgets['ui:image-picker'] || InputWidgets['ui:text']) as React.ComponentType<BaseWidgetProps<unknown>>;
          return (
            <div
              key={key}
              className={`transition-opacity duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
              {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
            >
              <Widget
                label={key}
                value={value}
                onChange={(val) => onChange({ ...data, [key]: val })}
              />
            </div>
          );
        }

        // 1. OBJECT HANDLING
        if (effectiveSchema instanceof z.ZodObject) {
          const objectData = (value as Record<string, unknown>) || {};
          const isFocusedField = fieldKeyMatches(effectiveFocusedFieldKey, key);
          return (
            <div
              key={key}
              className={`group/obj mb-6 p-4 border border-zinc-800 rounded-lg bg-zinc-900/20 hover:border-zinc-700 transition-[border-color,opacity] duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
              {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
            >
              <div className="flex items-center gap-2 mb-4">
                <div className="w-1 h-3 bg-blue-500 rounded-full" />
                <h4 className="text-[11px] font-semibold text-zinc-300 tracking-[0.02em]">
                  {humanizeLabel(key)}
                </h4>
              </div>
              <FormFactory 
                schema={effectiveSchema} 
                data={objectData} 
                collections={collections}
                collectionSource={collectionSource}
                onChange={(val) => onChange({ ...data, [key]: val })}
                expandedItemPath={expandedItemPath && fieldKeyMatches(firstSeg?.fieldKey, key) ? expandedItemPath.slice(1) : undefined}
              />
            </div>
          );
        }

        // 2. ARRAY HANDLING
        if (effectiveSchema instanceof z.ZodArray) {
          const items = (Array.isArray(value) ? value : []) as unknown[];
          const itemSchema = getEffectiveSchema(effectiveSchema.element);

          const moveItem = (from: number, to: number) => {
            if (to < 0 || to >= items.length) return;
            const newItems = [...items];
            const [removed] = newItems.splice(from, 1);
            newItems.splice(to, 0, removed);
            onChange({ ...data, [key]: newItems });
          };

          const isFocusedField = fieldKeyMatches(effectiveFocusedFieldKey, key);
          const openItemIdFromPath = fieldKeyMatches(firstSeg?.fieldKey, key) ? firstSeg?.itemId : undefined;
          const effectiveOpenItemId = openItemIdFromPath;
          return (
            <div
              key={key}
              className={`mb-8 transition-opacity duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
              {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
            >
              <div className="flex items-center justify-between mb-3">
                <label className="text-[12px] font-semibold text-zinc-300 tracking-[0.01em]">
                  {humanizeLabel(key)} ({items.length})
                </label>
                <button 
                  type="button"
                  onClick={() => {
                    const newItem = generateDefaultValue(itemSchema);
                    onChange({ ...data, [key]: [...items, newItem] });
                  }}
                  className="flex items-center gap-1 px-2.5 py-1.5 bg-blue-600/10 hover:bg-blue-600/20 text-blue-400 rounded text-[11px] font-semibold transition-colors"
                >
                  <Plus size={12} /> Add Item
                </button>
              </div>

              <div className="space-y-2">
                {items.map((item, index) => {
                  const itemRecord = item as Record<string, unknown>;
                  
                  // 🛡️ STABLE KEY STRATEGY:
                  // Prioritizziamo l'ID dell'oggetto. Se manca (dati legacy), 
                  // usiamo l'indice ma con un prefisso per evitare collisioni.
                  const stableKey = (itemRecord.id as string) || `legacy-${index}`;

                  const itemTitle = 
                    (typeof itemRecord.title === 'string' ? itemRecord.title : null) || 
                    (typeof itemRecord.label === 'string' ? itemRecord.label : null) || 
                    (typeof itemRecord.name === 'string' ? itemRecord.name : null) || 
                    (typeof itemRecord.content === 'string' ? itemRecord.content : null) || 
                    (typeof itemRecord.text === 'string' ? itemRecord.text : null) || 
                    `${humanizeLabel(key)} #${index + 1}`;

                  const openItemId = effectiveOpenItemId;
                  const itemIdStr = String(itemRecord.id ?? stableKey);
                  const isExpandedItem = openItemId != null && String(openItemId) === itemIdStr;
                  const pathTail =
                    isExpandedItem && expandedItemPath && expandedItemPath.length > 1 ? expandedItemPath.slice(1) : undefined;
                  const isFadedItem = inItemScope && isFocusedField && openItemId != null && !isExpandedItem;
                  return (
                    <ArrayItemWrapper 
                      key={stableKey} 
                      itemId={itemIdStr}
                      openItemId={openItemId != null ? String(openItemId) : undefined}
                      isFaded={isFadedItem}
                      index={index}
                      isFirst={index === 0}
                      isLast={index === items.length - 1}
                      label={itemTitle}
                      onExpandedChange={onSidebarExpandedItemChange ? (open) => onSidebarExpandedItemChange(open ? { fieldKey: key, itemId: itemIdStr } : null) : undefined}
                      onRemove={() => {
                        const newItems = items.filter((_, i) => i !== index);
                        onChange({ ...data, [key]: newItems });
                      }}
                      onMoveUp={() => moveItem(index, index - 1)}
                      onMoveDown={() => moveItem(index, index + 1)}
                    >
                      {itemSchema instanceof z.ZodObject ? (
                        <FormFactory 
                          schema={itemSchema} 
                          data={itemRecord || {}}
                          collections={collections}
                          collectionSource={collectionSource}
                          expandedItemPath={pathTail}
                          onChange={(val) => {
                            const newItems = [...items];
                            newItems[index] = val;
                            onChange({ ...data, [key]: newItems });
                          }}
                        />
                      ) : (
                        <div className="text-[10px] text-red-400">Primitive arrays not supported.</div>
                      )}
                    </ArrayItemWrapper>
                  );
                })}
              </div>
            </div>
          );
        }

        // 3. ATOMIC WIDGET HANDLING
        const widgetKey: WidgetType =
          uiHint in InputWidgets ? (uiHint as WidgetType) : 'ui:text';
        const Widget = (InputWidgets[widgetKey] || InputWidgets['ui:text']) as React.ComponentType<BaseWidgetProps>;
        const options = effectiveSchema instanceof z.ZodEnum ? (effectiveSchema._def.values as string[]) : undefined;
        const isFocusedField = fieldKeyMatches(effectiveFocusedFieldKey, key);

        return (
          <div
            key={key}
            className={`transition-opacity duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
            {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
          >
            <Widget 
              label={key}
              value={value}
              options={options}
              onChange={(val) => onChange({ ...data, [key]: val })}
            />
          </div>
        );
      })}
    </div>
  );
};

interface ArrayItemWrapperProps {
  itemId: string;
  /** When this matches itemId, the item is expanded (e.g. after clicking it on the Stage). */
  openItemId?: string | null;
  /** When true, fade this row (other items in the same array when one is focused). */
  isFaded?: boolean;
  index: number;
  isFirst: boolean;
  isLast: boolean;
  label: string;
  /** Called when user toggles open/close (so parent can drive fade). */
  onExpandedChange?: (open: boolean) => void;
  onRemove: () => void;
  onMoveUp: () => void;
  onMoveDown: () => void;
  children: React.ReactNode;
}

const ArrayItemWrapper: React.FC<ArrayItemWrapperProps> = ({ 
  itemId,
  openItemId,
  isFaded = false,
  label, 
  onExpandedChange,
  onRemove, 
  onMoveUp, 
  onMoveDown, 
  isFirst, 
  isLast, 
  children 
}) => {
  const shouldOpen = openItemId != null && String(openItemId) === String(itemId);
  const [isOpen, setIsOpen] = React.useState(shouldOpen);
  // Only sync from path/canvas when this array level has an openItemId. Otherwise nested lists
  // (e.g. header menu → children) get shouldOpen false for every row and the effect would
  // immediately undo a manual chevron toggle.
  React.useEffect(() => {
    if (openItemId == null) return;
    if (shouldOpen && !isOpen) setIsOpen(true);
    if (!shouldOpen && isOpen) setIsOpen(false);
  }, [openItemId, shouldOpen, isOpen]);

  const handleToggle = () => {
    const next = !isOpen;
    setIsOpen(next);
    onExpandedChange?.(next);
  };

  const isExpandedTarget = shouldOpen && isOpen;
  return (
    <div
      className={`border border-zinc-800 rounded-md bg-zinc-900/40 overflow-hidden transition-opacity duration-200 ${isFaded ? 'opacity-10' : 'opacity-100'}`}
      {...(isExpandedTarget ? { 'data-jp-expanded-item': itemId } : {})}
    >
      <div className="flex items-center justify-between px-3 py-2 bg-zinc-900/60">
        <div className="flex items-center gap-2 flex-1 min-w-0">
          <button 
            type="button"
            onClick={handleToggle}
            className="flex items-center gap-2 text-[12px] font-semibold text-zinc-200 tracking-[0.01em] truncate"
          >
            {isOpen ? <ChevronUp size={12} className="shrink-0" /> : <ChevronDown size={12} className="shrink-0" />}
            <span className="truncate">{label}</span>
          </button>
        </div>
        
        <div className="flex items-center gap-1 shrink-0 ml-2">
          <button 
            type="button"
            disabled={isFirst}
            onClick={onMoveUp}
            className="text-zinc-500 hover:text-blue-400 disabled:opacity-20 p-1 transition-colors"
          >
            <ArrowUp size={12} />
          </button>
          <button 
            type="button"
            disabled={isLast}
            onClick={onMoveDown}
            className="text-zinc-500 hover:text-blue-400 disabled:opacity-20 p-1 transition-colors"
          >
            <ArrowDown size={12} />
          </button>
          <div className="w-px h-3 bg-zinc-800 mx-1" />
          <button 
            type="button"
            onClick={onRemove}
            className="text-zinc-600 hover:text-red-500 transition-colors p-1"
          >
            <Trash2 size={12} />
          </button>
        </div>
      </div>
      {isOpen && (
        <div className="p-4 border-t border-zinc-800 bg-black/20">
          {children}
        </div>
      )}
    </div>
  );
};

interface CollectionRefRecordItemWrapperProps {
  itemId: string;
  openItemId?: string | null;
  isFaded?: boolean;
  label: string;
  onExpandedChange?: (open: boolean) => void;
  children: React.ReactNode;
}

const CollectionRefRecordItemWrapper: React.FC<CollectionRefRecordItemWrapperProps> = ({
  itemId,
  openItemId,
  isFaded = false,
  label,
  onExpandedChange,
  children,
}) => {
  const shouldOpen = openItemId != null && String(openItemId) === String(itemId);
  const [isOpen, setIsOpen] = React.useState(shouldOpen);

  React.useEffect(() => {
    if (openItemId == null) return;
    if (shouldOpen && !isOpen) setIsOpen(true);
    if (!shouldOpen && isOpen) setIsOpen(false);
  }, [openItemId, shouldOpen, isOpen]);

  const handleToggle = () => {
    const next = !isOpen;
    setIsOpen(next);
    onExpandedChange?.(next);
  };

  const isExpandedTarget = shouldOpen && isOpen;
  return (
    <div
      className={`border border-zinc-800 rounded-md bg-zinc-900/40 overflow-hidden transition-opacity duration-200 ${isFaded ? 'opacity-10' : 'opacity-100'}`}
      {...(isExpandedTarget ? { 'data-jp-expanded-item': itemId } : {})}
    >
      <button
        type="button"
        onClick={handleToggle}
        className="flex w-full items-center gap-2 px-3 py-2 bg-zinc-900/60 text-left text-[12px] font-semibold text-zinc-200 tracking-[0.01em]"
      >
        {isOpen ? <ChevronUp size={12} className="shrink-0" /> : <ChevronDown size={12} className="shrink-0" />}
        <span className="truncate">{label}</span>
      </button>
      {isOpen && (
        <div className="p-4 border-t border-zinc-800 bg-black/20">
          {children}
        </div>
      )}
    </div>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/IconRegistryContext.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/IconRegistryContext.tsx"
/**
 * Re-export shim. The icon registry context now lives in
 * `runtime/icons/IconRegistryContext.tsx` (per ADR-0009 D5). This file is
 * kept so existing imports — both relative (sibling files in
 * `studio/admin/`) and any external consumers that referenced the old
 * path — keep working without modification.
 *
 * To remove this shim, replace all imports of
 * `studio/admin/IconRegistryContext` with `runtime/icons/IconRegistryContext`
 * (deferred: the shim is harmless and removal is a future major).
 */
export {
  IconRegistryContext,
  useIconRegistry,
  type IconRegistry,
} from '../../runtime/icons/IconRegistryContext';

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/InputRegistry.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/InputRegistry.tsx"
import { useState } from 'react';
import { Input } from '../ui/input';
import { Textarea } from '../ui/textarea';
import { Checkbox } from '../ui/checkbox';
import { Label } from '../ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../ui/select';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '../ui/dialog';
import { Button } from '../ui/button';
import {
  ImageIcon,
  type LucideIcon,
} from 'lucide-react';
import { useIconRegistry } from './IconRegistryContext';
import { BaseWidgetProps } from '../../lib/shared-types';
import { cn } from '../../lib/utils';
import { ImagePreviewField } from './image-picker';

const humanizeLabel = (label: string): string =>
  label
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());

export const InputWidgets = {
  'ui:text': ({ label, value, onChange }: BaseWidgetProps<string>) => (
    <div className="grid w-full items-center gap-2 mb-4">
      <Label className="text-[11px] font-semibold tracking-[0.02em] text-zinc-300">
        {humanizeLabel(label)}
      </Label>
      <Input 
        type="text" 
        className="h-9 text-[13px] bg-zinc-900/50 border-zinc-700 focus-visible:ring-blue-600"
        value={value || ''} 
        onChange={(e) => onChange(e.target.value)} 
      />
    </div>
  ),

  'ui:textarea': ({ label, value, onChange }: BaseWidgetProps<string>) => (
    <div className="grid w-full gap-2 mb-4">
      <Label className="text-[11px] font-semibold tracking-[0.02em] text-zinc-300">
        {humanizeLabel(label)}
      </Label>
      <Textarea 
        className="min-h-[96px] text-[13px] bg-zinc-900/50 border-zinc-700 focus-visible:ring-blue-600 resize-none"
        value={value || ''} 
        onChange={(e) => onChange(e.target.value)} 
      />
    </div>
  ),

  'ui:select': ({ label, value, onChange, options = [] }: BaseWidgetProps<string>) => (
    <div className="grid w-full gap-2 mb-4">
      <Label className="text-[11px] font-semibold tracking-[0.02em] text-zinc-300">
        {humanizeLabel(label)}
      </Label>
      <Select value={value || ""} onValueChange={onChange}>
        <SelectTrigger className="w-full h-9 text-[13px] bg-zinc-900/50 border-zinc-700 focus:ring-blue-600">
          <SelectValue placeholder={`Select...`} />
        </SelectTrigger>
        <SelectContent className="dark">
          {options.map((opt) => (
            <SelectItem key={opt} value={opt} className="text-[13px]">
              {opt}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  ),

  'ui:checkbox': ({ label, value, onChange }: BaseWidgetProps<boolean>) => (
    <div className="flex items-center space-x-2 mb-4 p-2.5 rounded border border-zinc-700/60 bg-zinc-900/20">
      <Checkbox 
        id={label} 
        checked={!!value} 
        onCheckedChange={(checked) => onChange(checked === true)} 
      />
      <Label 
        htmlFor={label} 
        className="text-[13px] font-medium cursor-pointer select-none text-zinc-200"
      >
        {humanizeLabel(label)}
      </Label>
    </div>
  ),

  'ui:image-picker': ({ label, value, onChange }: BaseWidgetProps<unknown>) => {
    const selection: { url: string; alt: string } =
      value != null && typeof value === 'object' && 'url' in value
        ? {
            url: String((value as { url?: unknown }).url ?? ''),
            alt: String((value as { alt?: unknown }).alt ?? ''),
          }
        : { url: typeof value === 'string' ? value : '', alt: '' };

    const handleChange = (next: { url: string; alt: string }) => {
      onChange(next);
    };

    return (
      <div className="mb-4">
        <ImagePreviewField
          label={label}
          value={selection}
          onChange={handleChange}
        />
      </div>
    );
  },

  'ui:icon-picker': ({ label, value, onChange }: BaseWidgetProps<string>) => {
    const [open, setOpen] = useState(false);
    const tenantIcons = useIconRegistry();
    const options: { name: string; Icon: LucideIcon }[] =
      Object.entries(tenantIcons).map(([name, Icon]) => ({ name, Icon }));
    const selected = options.find((o) => o.name === (value || ''));

    return (
      <div className="grid w-full gap-1.5 mb-4">
        <Label className="text-[9px] uppercase font-black tracking-widest text-zinc-500">
          {label}
        </Label>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button
              variant="outline"
              className="w-full h-9 rounded-md border border-zinc-800 bg-zinc-900/50 hover:bg-zinc-800/50 flex items-center gap-2 text-left"
            >
              {selected ? (
                <>
                  <selected.Icon size={16} className="text-zinc-400 shrink-0" />
                  <span className="text-[11px] text-zinc-300 capitalize truncate">{selected.name}</span>
                </>
              ) : (
                <>
                  <ImageIcon size={16} className="text-zinc-500 shrink-0" />
                  <span className="text-[11px] text-zinc-500">Choose icon...</span>
                </>
              )}
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[280px] p-4">
            <DialogHeader>
              <DialogTitle className="text-sm">Choose icon</DialogTitle>
              <DialogDescription className="text-xs">
                Click an icon to select it.
              </DialogDescription>
            </DialogHeader>
            <div className="grid grid-cols-5 gap-2 py-2">
              {options.map(({ name, Icon }) => (
                <button
                  key={name}
                  type="button"
                  onClick={() => {
                    onChange(name);
                    setOpen(false);
                  }}
                  className={cn(
                    'flex items-center justify-center w-10 h-10 rounded-md border transition-colors',
                    value === name
                      ? 'border-blue-500 bg-blue-500/20 text-blue-400'
                      : 'border-zinc-800 bg-zinc-900/50 hover:bg-zinc-800/50 text-zinc-400 hover:text-zinc-200'
                  )}
                  title={name}
                >
                  <Icon size={20} />
                </button>
              ))}
            </div>
          </DialogContent>
        </Dialog>
      </div>
    );
  },
} as const;

export type WidgetType = keyof typeof InputWidgets;

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/PageSelector.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/PageSelector.tsx"
import React, { useState } from 'react';
import { FileText, ChevronDown, Plus } from 'lucide-react';
import { cn } from '../../lib/utils';
import { Popover, PopoverTrigger, PopoverContent } from '../ui/popover';

export interface PageSelectorProps {
  /** Available page slugs. */
  pageSlugs: string[];
  /** Current page slug. */
  currentSlug: string;
  /** Called when user selects another page. */
  onPageChange: (slug: string) => void;
  /** Optional: show section count per page (e.g. "9s"). Omit to hide. */
  sectionCount?: number;
  /** Optional: when set, shows "New page" and calls this on click. Omit to hide (no dead UI). */
  onNewPage?: () => void;
  /** Optional class for the wrapper (e.g. spacing). */
  className?: string;
  /** Optional: override label for current page (default: capitalized slug). */
  currentPageLabel?: string;
}

const defaultLabel = (slug: string) =>
  slug ? slug.charAt(0).toUpperCase() + slug.slice(1) : 'Select page';

/**
 * Enterprise-grade page switcher: popover trigger + list, a11y, single source of styling.
 * Use in Inspector header when multiple pages exist and onPageChange is provided.
 */
export const PageSelector: React.FC<PageSelectorProps> = ({
  pageSlugs,
  currentSlug,
  onPageChange,
  sectionCount,
  onNewPage,
  className,
  currentPageLabel,
}) => {
  const [open, setOpen] = useState(false);
  const label = currentPageLabel ?? defaultLabel(currentSlug);

  const handlePageSelect = (slug: string) => {
    onPageChange(slug);
    setOpen(false);
  };

  return (
    <div className={cn('mx-3 mt-2 mb-2', className)}>
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <button
            type="button"
            aria-haspopup="listbox"
            aria-label={`Select page, current: ${label}`}
            className={cn(
              'flex items-center gap-2 w-full pl-3 pr-4 py-2 rounded-lg border text-left transition-all duration-150 cursor-pointer',
              'bg-transparent border-zinc-800 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50 hover:border-zinc-700',
              'data-[state=open]:bg-zinc-950 data-[state=open]:border-zinc-800 data-[state=open]:text-zinc-100',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-zinc-950'
            )}
          >
            <FileText size={14} className="shrink-0 text-zinc-500" aria-hidden />
            <span className="text-xs font-medium flex-1 truncate">{label}</span>
            <ChevronDown size={13} className="shrink-0 text-zinc-500" aria-hidden />
          </button>
        </PopoverTrigger>
        <PopoverContent
          align="start"
          sideOffset={4}
          className="min-w-[var(--radix-popover-trigger-width)] bg-zinc-950 border-zinc-800 p-1"
          role="listbox"
          aria-label="Page list"
        >
          {pageSlugs.map((slug) => {
            const isActive = slug === currentSlug;
            const optionLabel = defaultLabel(slug);
            return (
              <button
                key={slug}
                type="button"
                role="option"
                aria-selected={isActive}
                onClick={() => handlePageSelect(slug)}
                className={cn(
                  'flex items-center justify-between w-full px-2.5 py-2 rounded-md text-xs transition-colors cursor-pointer',
                  isActive
                    ? 'bg-primary/10 text-primary font-semibold'
                    : 'text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200'
                )}
              >
                <span>{optionLabel}</span>
                {sectionCount != null && (
                  <span className="text-[10px] text-zinc-600 tabular-nums" aria-hidden>
                    {sectionCount}s
                  </span>
                )}
              </button>
            );
          })}
          {onNewPage != null && (
            <div className="border-t border-zinc-800 mt-1 pt-1">
              <button
                type="button"
                onClick={() => {
                  onNewPage();
                  setOpen(false);
                }}
                className="flex items-center gap-1.5 w-full px-2.5 py-2 rounded-md text-[11px] text-zinc-600 hover:text-zinc-300 hover:bg-zinc-800 transition-colors cursor-pointer"
                aria-label="New page"
              >
                <Plus size={12} aria-hidden />
                <span>New page</span>
              </button>
            </div>
          )}
        </PopoverContent>
      </Popover>
    </div>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/PreviewEntry.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/PreviewEntry.tsx"
import React, { useState, useEffect } from 'react';
import { StudioProvider } from '../StudioContext';
import { STUDIO_EVENTS } from '../events';
import type { PageConfig, SiteConfig, MenuConfig, MenuItem } from '../../contract/kernel';
import type { SelectionPath } from '../../contract/types-engine';
import { resolveHeaderMenuItems } from '../../contract/config-resolver';
import { PageRenderer } from '../../runtime/rendering/PageRenderer';
import { themeManager } from '../../runtime/theme/theme-manager';
import { buildSelectionPath } from './selection-path';

const INTERACTIVE_SELECTION_GUARD =
  '[data-jp-ignore-select="true"],[data-jp-interactive="true"],.ProseMirror,[contenteditable="true"],button,input,textarea,select,[role="button"],[role="menuitem"]';
const IDAC_SELECTION_MARKER =
  '[data-jp-field],[data-jp-item-id],[data-jp-item-field]';

export const PreviewEntry: React.FC = () => {
  const [draft, setDraft] = useState<PageConfig | null>(null);
  const [globalDraft, setGlobalDraft] = useState<SiteConfig | null>(null);
  const [menuConfig, setMenuConfig] = useState<MenuConfig>({ main: [] });
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [scrollToSectionId, setScrollToSectionId] = useState<string | null>(null);

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin || event.source !== window.parent) return;

      if (event.data.type === STUDIO_EVENTS.UPDATE_DRAFTS) {
        setDraft(event.data.draft);
        setGlobalDraft(event.data.globalDraft);
        if (event.data.menuConfig) {
          setMenuConfig(event.data.menuConfig as MenuConfig);
        }
        if (event.data.themeConfig) {
           themeManager.setTheme(event.data.themeConfig);
        }
      }

      if (event.data.type === STUDIO_EVENTS.SYNC_SELECTION) {
        setSelectedId(event.data.selectedId);
      }

      if (event.data.type === STUDIO_EVENTS.REQUEST_SCROLL_TO_SECTION) {
        setScrollToSectionId(event.data.sectionId ?? null);
      }

      if (event.data.type === STUDIO_EVENTS.REQUEST_INLINE_FLUSH) {
        const requestId = typeof event.data.requestId === 'string' ? event.data.requestId : null;
        window.dispatchEvent(new CustomEvent(STUDIO_EVENTS.REQUEST_INLINE_FLUSH, { detail: { requestId } }));
        setTimeout(() => {
          window.parent.postMessage(
            { type: STUDIO_EVENTS.INLINE_FLUSHED, requestId },
            window.location.origin
          );
        }, 0);
      }

    };

    window.addEventListener('message', handleMessage);
    window.parent.postMessage({ type: STUDIO_EVENTS.STAGE_READY }, '*');
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  /**
   * 📍 DOCUMENT-LEVEL CLICK (iframe event propagation fix)
   * Capture clicks at document root so we always receive them regardless of
   * React tree or pointer-events. Find section + item/field and notify parent.
   */
  useEffect(() => {
    const hasIdacSelectionMarker = (target: HTMLElement): boolean =>
      !!target.closest(IDAC_SELECTION_MARKER);

    const shouldIgnoreSelectionTarget = (target: HTMLElement): boolean => {
      if (target.closest('[data-jp-ignore-select="true"]')) return true;

      // Interactive controls are ignored unless explicitly annotated with IDAC markers.
      if (target.closest(INTERACTIVE_SELECTION_GUARD) && !hasIdacSelectionMarker(target)) {
        return true;
      }

      // Keep in-iframe links non-navigable, but allow inspector selection when IDAC is present.
      if (target.closest('a[href]') && !hasIdacSelectionMarker(target)) return true;
      return false;
    };

    const handleDocumentClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      if (shouldIgnoreSelectionTarget(target)) {
        if (target.closest('a[href]')) e.preventDefault();
        return;
      }
      const x = e.clientX;
      const y = e.clientY;
      let sectionEl: HTMLElement | null = null;
      let el: HTMLElement | null = target;
      while (el && el !== document.body) {
        const id = el.getAttribute?.('data-section-id');
        const type = el.getAttribute?.('data-section-type');
        const scope = el.getAttribute?.('data-section-scope');
        if (id && type && scope) {
          sectionEl = el;
          break;
        }
        el = el.parentElement;
      }
      if (!sectionEl) return;
      e.preventDefault();
      e.stopPropagation();
      const sectionId = sectionEl.getAttribute('data-section-id');
      const sectionType = sectionEl.getAttribute('data-section-type');
      const sectionScope = sectionEl.getAttribute('data-section-scope');
      if (!sectionId || !sectionType || !sectionScope) return;
      const section = { id: sectionId, type: sectionType, scope: sectionScope };
      // Click directly on section container (out of item scope) → restore section-level view
      if (target === sectionEl) {
        window.parent.postMessage({ type: STUDIO_EVENTS.SECTION_SELECT, section }, '*');
        return;
      }

      const rootAtPoint = (document.elementFromPoint(x, y) as HTMLElement) ?? target;
      if (!rootAtPoint || !sectionEl.contains(rootAtPoint)) {
        window.parent.postMessage({ type: STUDIO_EVENTS.SECTION_SELECT, section }, '*');
        return;
      }
      // Section container click: restore section-level view, out of item scope
      if (rootAtPoint === sectionEl) {
        window.parent.postMessage({ type: STUDIO_EVENTS.SECTION_SELECT, section }, '*');
        return;
      }
      // Collect deterministic root-to-leaf path for both array items and scalar fields.
      let itemPath: SelectionPath = buildSelectionPath(rootAtPoint, sectionEl);

      if (itemPath.length === 0 && rootAtPoint) {
        let best: HTMLElement | null = null;
        const visit = (node: HTMLElement) => {
          const rect = node.getBoundingClientRect();
          if (rect.left <= x && x <= rect.right && rect.top <= y && y <= rect.bottom) {
            for (let i = 0; i < node.children.length; i++) visit(node.children[i] as HTMLElement);
            if (node.getAttribute?.('data-jp-item-id') || node.getAttribute?.('data-jp-field')) best = node;
          }
        };
        visit(rootAtPoint);
        if (best) {
          itemPath = buildSelectionPath(best as HTMLElement, sectionEl);
        }
      }
      const payload: Record<string, unknown> = { type: STUDIO_EVENTS.SECTION_SELECT, section };
      if (itemPath.length > 0) {
        payload.itemPath = itemPath;
      }
      window.parent.postMessage(payload, '*');
    };

    document.addEventListener('click', handleDocumentClick, true);
    return () => document.removeEventListener('click', handleDocumentClick, true);
  }, []);

  /** Clear scrollToSectionId after triggering scroll (must run unconditionally for Rules of Hooks). */
  useEffect(() => {
    if (!scrollToSectionId) return;
    const t = setTimeout(() => setScrollToSectionId(null), 600);
    return () => clearTimeout(t);
  }, [scrollToSectionId]);

  if (!draft || !globalDraft) {
    return (
      <div className="flex items-center justify-center h-screen w-full bg-zinc-950 text-zinc-500 font-mono text-xs uppercase tracking-widest animate-pulse">
        Waiting for Studio Signal...
      </div>
    );
  }

  const currentMenuConfig: MenuConfig = {
    ...menuConfig,
    main: resolveHeaderMenuItems(globalDraft.header?.data, menuConfig.main ?? []),
  };

  const handleActiveSectionChange = (sectionId: string | null) => {
    window.parent.postMessage({
      type: STUDIO_EVENTS.ACTIVE_SECTION_CHANGED,
      activeSectionId: sectionId,
    }, '*');
  };

  return (
    <StudioProvider mode="studio">
      <div className="jp-ice-active">
        <PageRenderer
          pageConfig={draft}
          siteConfig={globalDraft}
          menuConfig={currentMenuConfig}
          selectedId={selectedId}
          scrollToSectionId={scrollToSectionId}
          onActiveSectionChange={handleActiveSectionChange}
        />
      </div>
    </StudioProvider>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/StudioStage.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/StudioStage.tsx"
import React, { useEffect, useRef, useCallback } from 'react';
import { STUDIO_EVENTS } from '../events';
import type { PageConfig, SiteConfig, ThemeConfig, MenuConfig } from '../../contract/kernel';

interface StudioStageProps {
  draft: PageConfig;
  globalDraft: SiteConfig;
  menuConfig: MenuConfig;
  themeConfig: ThemeConfig;
  slug: string;
  selectedId?: string | null;
  scrollToSectionId?: string | null;
  onScrollRequested?: () => void;
}

/**
 * 📺 STUDIO STAGE (Full Preview Mode)
 * Manages the Iframe and the PostMessage protocol.
 * NOW INCLUDES: Handshake Listener to fix the "Waiting..." race condition.
 */
export const StudioStage: React.FC<StudioStageProps> = ({
  draft,
  globalDraft,
  menuConfig,
  themeConfig,
  slug,
  selectedId,
  scrollToSectionId,
  onScrollRequested,
}) => {
  const iframeRef = useRef<HTMLIFrameElement>(null);

  /**
   * 📤 TRANSMITTER
   * Encapsulated function to send the current state to the Iframe.
   */
  const sendDataToStage = useCallback(() => {
    if (iframeRef.current?.contentWindow) {
      iframeRef.current.contentWindow.postMessage({
        type: STUDIO_EVENTS.UPDATE_DRAFTS,
        draft,
        globalDraft,
        menuConfig,
        themeConfig,
      }, '*');
    }
  }, [draft, globalDraft, menuConfig, themeConfig]);

  /**
   * 🔄 SYNC 1: Reactivity
   * Send data whenever the draft changes in the Inspector.
   */
  useEffect(() => {
    sendDataToStage();
  }, [sendDataToStage]);

  /**
   * 🤝 SYNC 2: The Handshake (Fixes the Race Condition)
   * Listen for the Iframe saying "I am ready" and send data immediately.
   */
  useEffect(() => {
    const handleHandshake = (event: MessageEvent) => {
      if (event.data.type === STUDIO_EVENTS.STAGE_READY) {
        // console.log("🤝 Handshake received from Stage. Transmitting data...");
        sendDataToStage();
      }
    };

    window.addEventListener('message', handleHandshake);
    return () => window.removeEventListener('message', handleHandshake);
  }, [sendDataToStage]);

  /**
   * 🎯 SYNC 3: Selection
   * Independent channel for high-frequency selection updates.
   */
  useEffect(() => {
    if (iframeRef.current?.contentWindow) {
      iframeRef.current.contentWindow.postMessage({
        type: STUDIO_EVENTS.SYNC_SELECTION,
        selectedId
      }, '*');
    }
  }, [selectedId]);

  useEffect(() => {
    if (!scrollToSectionId || !iframeRef.current?.contentWindow) return;
    iframeRef.current.contentWindow.postMessage({
      type: STUDIO_EVENTS.REQUEST_SCROLL_TO_SECTION,
      sectionId: scrollToSectionId,
    }, '*');
    onScrollRequested?.();
  }, [scrollToSectionId, onScrollRequested]);

  return (
    <div className="w-full h-full bg-background overflow-hidden">
      <iframe
        ref={iframeRef}
        src={`/admin/preview/${slug}`}
        className="w-full h-full border-none"
        title="JsonPages Stage"
      />
    </div>
  );
};



END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/admin-skin.css..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/admin-skin.css"
@import "tailwindcss";

@source "../**/*.tsx";

@theme {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-destructive-foreground: var(--destructive-foreground);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);
}

:root {
  --background: oklch(0.141 0.005 285.823);
  --foreground: oklch(0.985 0 0);
  --card: oklch(0.21 0.006 285.885);
  --card-foreground: oklch(0.985 0 0);
  --popover: oklch(0.21 0.006 285.885);
  --popover-foreground: oklch(0.985 0 0);
  --primary: oklch(0.42 0.18 266);
  --primary-foreground: oklch(0.97 0.014 254.604);
  --secondary: oklch(0.274 0.006 286.033);
  --secondary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.274 0.006 286.033);
  --muted-foreground: oklch(0.705 0.015 286.067);
  --accent: oklch(0.42 0.18 266);
  --accent-foreground: oklch(0.97 0.014 254.604);
  --destructive: oklch(0.704 0.191 22.216);
  --destructive-foreground: oklch(0.97 0.014 254.604);
  --border: oklch(1 0 0 / 10%);
  --input: oklch(1 0 0 / 15%);
  --ring: oklch(0.552 0.016 285.938);
  --radius: 0.5rem;
  font-family: ui-sans-serif, system-ui, sans-serif;
  --jp-inspector-label-size: 11px;
  --jp-inspector-field-size: 13px;
}

@layer base {
  * { border-color: var(--border); }
  body {
    background-color: var(--background);
    color: var(--foreground);
    @apply antialiased;
  }
}

[data-radix-portal] { z-index: 9999 !important; }

END_OF_FILE_CONTENT
mkdir -p "core/src/studio/admin/image-picker"
echo "Creating core/src/studio/admin/image-picker/ImagePickerDialog.test.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/image-picker/ImagePickerDialog.test.tsx"
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import { ConfigProvider } from '../../../runtime/config/ConfigContext';
import { ImagePickerDialog } from './ImagePickerDialog';

function renderDialog(onSelect = vi.fn(), onAssetUpload?: (file: File) => Promise<string>) {
  return render(
    <ConfigProvider
      config={{
        registry: {},
        schemas: {},
        tenantId: 'tenant-a',
        assets: {
          onAssetUpload,
          assetsManifest: [],
        },
      }}
    >
      <ImagePickerDialog open onOpenChange={() => {}} onSelect={onSelect} />
    </ConfigProvider>
  );
}

describe('ImagePickerDialog upload tab', () => {
  const originalFetch = globalThis.fetch;
  const originalFileReader = globalThis.FileReader;

  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn(() => Promise.resolve(new Response(null))));
  });

  afterEach(() => {
    vi.restoreAllMocks();

    if (originalFetch === undefined) {
      Reflect.deleteProperty(globalThis, 'fetch');
    } else {
      Reflect.set(globalThis, 'fetch', originalFetch);
    }

    if (originalFileReader === undefined) {
      Reflect.deleteProperty(globalThis, 'FileReader');
    } else {
      Reflect.set(globalThis, 'FileReader', originalFileReader);
    }
  });

  it('shows upload preview using the canonical URL returned by onAssetUpload', async () => {
    const user = userEvent.setup();

    renderDialog(vi.fn(), vi.fn(async () => '/assets/images/hero.png'));

    await user.click(screen.getByRole('button', { name: 'Upload' }));
    const input = document.querySelector('input[type="file"]');
    if (!(input instanceof HTMLInputElement)) {
      throw new Error('Expected upload input');
    }

    await user.upload(input, new File(['image'], 'hero.png', { type: 'image/png' }));

    await waitFor(() => {
      const preview = screen.getByAltText('Upload preview') as HTMLImageElement;
      expect(preview).toHaveAttribute('src', '/assets/images/hero.png');
    });

    expect(screen.getByRole('button', { name: 'Inserisci immagine' })).toBeEnabled();
  });

  it('blocks confirmation when only a transient data preview is available', async () => {
    const user = userEvent.setup();

    class FakeFileReader {
      onload: ((event: ProgressEvent<FileReader>) => void) | null = null;

      readAsDataURL(): void {
        this.onload?.({
          target: { result: 'data:image/png;base64,preview' },
        } as ProgressEvent<FileReader>);
      }
    }

    Reflect.set(globalThis, 'FileReader', FakeFileReader);

    renderDialog(vi.fn(), vi.fn(async () => {
      throw new Error('upload failed');
    }));

    await user.click(screen.getByRole('button', { name: 'Upload' }));
    const input = document.querySelector('input[type="file"]');
    if (!(input instanceof HTMLInputElement)) {
      throw new Error('Expected upload input');
    }

    await user.upload(input, new File(['image'], 'fallback.png', { type: 'image/png' }));

    await waitFor(() => {
      const preview = screen.getByAltText('Upload preview') as HTMLImageElement;
      expect(preview).toHaveAttribute('src', 'data:image/png;base64,preview');
    });

    expect(screen.getByRole('alert')).toHaveTextContent(
      "Upload non persistito: serve un URL asset canonico per inserire l'immagine."
    );
    expect(screen.getByRole('button', { name: 'Inserisci immagine' })).toBeDisabled();
  });

  it('confirms only the final canonical URL when persistence is valid', async () => {
    const user = userEvent.setup();
    const onSelect = vi.fn();

    renderDialog(onSelect, vi.fn(async () => '/assets/tenant-a/hero.png'));

    await user.click(screen.getByRole('button', { name: 'Upload' }));
    const input = document.querySelector('input[type="file"]');
    if (!(input instanceof HTMLInputElement)) {
      throw new Error('Expected upload input');
    }

    await user.upload(input, new File(['image'], 'hero.png', { type: 'image/png' }));

    const confirmButton = screen.getByRole('button', { name: 'Inserisci immagine' });
    await waitFor(() => expect(confirmButton).toBeEnabled());
    await user.click(confirmButton);

    expect(onSelect).toHaveBeenCalledWith({
      url: '/assets/tenant-a/hero.png',
      alt: 'hero.png',
    });
  });
});

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/image-picker/ImagePickerDialog.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/image-picker/ImagePickerDialog.tsx"
import React, { useState, useRef, useCallback, useEffect } from 'react';
import {
  Image as ImageIcon,
  Upload,
  Link2,
  Search,
  Check,
  Trash2,
  X,
} from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '../../ui/dialog';
import { Button } from '../../ui/button';
import { Input } from '../../ui/input';
import { Label } from '../../ui/label';
import {
  isCanonicalAssetUrl,
  resolveAssetUrl,
} from '../../../runtime/assets/asset-resolver';
import { useConfig } from '../../../runtime/config/ConfigContext';
import { cn } from '../../../lib/utils';
import type { ImageSelection } from './types';
import type { LibraryImageEntry } from '../../../contract/types-engine';

const TABS = ['library', 'upload', 'url'] as const;
type TabId = (typeof TABS)[number];

interface UploadPreview {
  name: string;
  size: number;
  previewSrc: string;
  finalUrl?: string;
  isPersistent: boolean;
}

interface ImagePickerDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSelect: (image: ImageSelection) => void;
}

function LibraryTab({
  library,
  selectedId,
  onSelect,
}: {
  library: LibraryImageEntry[];
  selectedId: string | null;
  onSelect: (id: string | null) => void;
}) {
  const [search, setSearch] = useState('');
  const [activeTag, setActiveTag] = useState('all');
  const tags = ['all', ...new Set(library.flatMap((img) => img.tags ?? []))];

  const filtered = library.filter((img) => {
    const matchTag = activeTag === 'all' || (img.tags ?? []).includes(activeTag);
    const matchSearch =
      !search || (img.alt ?? '').toLowerCase().includes(search.toLowerCase());
    return matchTag && matchSearch;
  });

  return (
    <div className="space-y-4">
      <div className="relative">
        <Search
          size={14}
          className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-600 pointer-events-none"
        />
        <Input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Cerca immagini..."
          className="pl-9 h-8 text-xs bg-zinc-900/50 border-zinc-800"
        />
      </div>
      <div className="flex flex-wrap gap-1.5">
        {tags.map((tag) => (
          <button
            key={tag}
            type="button"
            onClick={() => setActiveTag(tag)}
            className={cn(
              'px-2.5 py-1 rounded text-[10px] font-medium border transition-colors',
              activeTag === tag
                ? 'border-blue-500 bg-blue-500/20 text-blue-400'
                : 'border-zinc-700 text-zinc-500 hover:border-zinc-600 hover:text-zinc-400'
            )}
          >
            {tag === 'all' ? 'Tutte' : tag}
          </button>
        ))}
      </div>
      {filtered.length > 0 ? (
        <div className="grid grid-cols-3 gap-2.5 max-h-[45vh] overflow-y-auto">
          {filtered.map((img) => {
            const isSelected = selectedId === img.id;
            return (
              <button
                key={img.id}
                type="button"
                onClick={() => onSelect(isSelected ? null : img.id)}
                className={cn(
                  'group relative aspect-[4/3] rounded-lg overflow-hidden',
                  'ring-1 transition-all duration-150',
                  isSelected
                    ? 'ring-blue-500 ring-2 ring-offset-1 ring-offset-zinc-900'
                    : 'ring-zinc-800 hover:ring-zinc-600 hover:scale-[1.02]'
                )}
              >
                <img
                  src={img.url}
                  alt={img.alt}
                  loading="lazy"
                  className={cn(
                    'w-full h-full object-cover transition-[filter] duration-150',
                    isSelected ? 'brightness-[0.6]' : 'brightness-[0.85] group-hover:brightness-100'
                  )}
                />
                <div
                  className={cn(
                    'absolute inset-x-0 bottom-0 px-2 py-1.5',
                    'bg-gradient-to-t from-black/70 to-transparent',
                    'opacity-0 group-hover:opacity-100 transition-opacity',
                    isSelected && 'opacity-100'
                  )}
                >
                  <span className="text-[10px] text-white font-medium leading-tight line-clamp-2">
                    {img.alt}
                  </span>
                </div>
                {isSelected && (
                  <div className="absolute top-2 right-2 w-6 h-6 rounded-full bg-blue-600 flex items-center justify-center">
                    <Check size={14} className="text-white" />
                  </div>
                )}
              </button>
            );
          })}
        </div>
      ) : (
        <div className="text-center py-12 text-zinc-600 text-xs">
          Nessuna immagine in libreria. Configura assets.assetsManifest nel tenant (es. da public/assets).
        </div>
      )}
    </div>
  );
}

function UploadTab({
  preview,
  onPreviewChange,
  onAssetUpload,
  tenantId,
}: {
  preview: UploadPreview | null;
  onPreviewChange: (p: UploadPreview | null) => void;
  onAssetUpload?: (file: File) => Promise<string>;
  tenantId: string;
}) {
  const [dragOver, setDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFile = useCallback(
    async (file: File) => {
      // #region agent log
      fetch('http://127.0.0.1:7588/ingest/86d71502-47e1-433c-9b6d-5a1390d00813',{method:'POST',headers:{'Content-Type':'application/json','X-Debug-Session-Id':'34bba5'},body:JSON.stringify({sessionId:'34bba5',location:'ImagePickerDialog.tsx:handleFile',message:'handleFile called',data:{fileName:file.name,hasOnAssetUpload:!!onAssetUpload},timestamp:Date.now(),hypothesisId:'H5'})}).catch(()=>{});
      // #endregion
      if (!file.type.startsWith('image/')) return;
      if (onAssetUpload) {
        try {
          const url = await onAssetUpload(file);
          const finalUrl = isCanonicalAssetUrl(url) ? url : undefined;
          // #region agent log
          fetch('http://127.0.0.1:7588/ingest/86d71502-47e1-433c-9b6d-5a1390d00813',{method:'POST',headers:{'Content-Type':'application/json','X-Debug-Session-Id':'34bba5'},body:JSON.stringify({sessionId:'34bba5',location:'ImagePickerDialog.tsx:handleFile',message:'onAssetUpload resolved',data:{url:url?.slice(0,50)},timestamp:Date.now(),hypothesisId:'H2,H5'})}).catch(()=>{});
          // #endregion
          onPreviewChange({
            name: file.name,
            size: file.size,
            previewSrc: resolveAssetUrl(url, tenantId),
            finalUrl,
            isPersistent: finalUrl != null,
          });
        } catch {
          const reader = new FileReader();
          reader.onload = (e) => {
            onPreviewChange({
              name: file.name,
              size: file.size,
              previewSrc: e.target?.result as string,
              isPersistent: false,
            });
          };
          reader.readAsDataURL(file);
        }
        return;
      }
      const reader = new FileReader();
      reader.onload = (e) => {
        onPreviewChange({
          name: file.name,
          size: file.size,
          previewSrc: e.target?.result as string,
          isPersistent: false,
        });
      };
      reader.readAsDataURL(file);
    },
    [onPreviewChange, onAssetUpload, tenantId]
  );

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      e.stopPropagation();
      setDragOver(false);
      const file = e.dataTransfer?.files?.[0];
      if (file) handleFile(file);
    },
    [handleFile]
  );

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragOver(true);
  }, []);

  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      if (file) handleFile(file);
    },
    [handleFile]
  );

  return (
    <div className="space-y-3">
      <div
        onDragOver={handleDragOver}
        onDragEnter={handleDragOver}
        onDragLeave={(e) => {
          e.preventDefault();
          e.stopPropagation();
          setDragOver(false);
        }}
        onDrop={handleDrop}
        onClick={() => !preview && fileInputRef.current?.click()}
        className={cn(
          'rounded-xl border-2 border-dashed transition-all min-h-[240px]',
          'flex flex-col items-center justify-center overflow-hidden cursor-pointer relative',
          dragOver
            ? 'border-blue-500/50 bg-blue-500/[0.04]'
            : preview
              ? 'border-zinc-800 bg-transparent cursor-default'
              : 'border-zinc-800 bg-white/[0.01] hover:border-zinc-600 hover:bg-white/[0.02]'
        )}
      >
      {preview ? (
        <>
          <img
            src={preview.previewSrc}
            alt="Upload preview"
            className="w-full max-h-[320px] object-contain"
          />
          <div className="absolute bottom-0 inset-x-0 bg-gradient-to-t from-black/80 to-transparent p-4 flex items-center justify-between">
            <div>
              <p className="text-xs font-medium text-white">{preview.name}</p>
              <p className="text-[10px] text-zinc-400">
                {(preview.size / 1024).toFixed(1)} KB
              </p>
            </div>
            <Button
              type="button"
              variant="ghost"
              className="text-zinc-400 hover:text-red-400 hover:bg-red-500/10 h-8 w-8 p-0"
              onClick={(e) => {
                e.stopPropagation();
                onPreviewChange(null);
              }}
            >
              <Trash2 size={14} />
            </Button>
          </div>
        </>
      ) : (
        <>
          <div className="w-12 h-12 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-500 mb-3">
            <Upload size={22} />
          </div>
          <p className="text-sm font-medium text-white mb-1">
            Trascina un&apos;immagine qui
          </p>
          <p className="text-[11px] text-zinc-500 mb-3">
            oppure clicca per selezionare un file
          </p>
          <span className="text-[10px] text-zinc-600 bg-white/[0.03] px-3 py-1 rounded">
            PNG, JPG, WebP — max 5MB
          </span>
        </>
      )}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handleInputChange}
        />
      </div>
      {preview != null && !preview.isPersistent && (
        <p
          role="alert"
          className="rounded-lg border border-amber-500/25 bg-amber-500/10 px-3 py-2 text-[11px] text-amber-200"
        >
          Upload non persistito: serve un URL asset canonico per inserire l&apos;immagine.
        </p>
      )}
    </div>
  );
}

function UrlTab({
  urlPreview,
  onUrlPreviewChange,
}: {
  urlPreview: string | null;
  onUrlPreviewChange: (url: string | null) => void;
}) {
  const [urlInput, setUrlInput] = useState('');
  const [error, setError] = useState(false);

  const handleCheck = () => {
    if (!urlInput.trim()) return;
    try {
      new URL(urlInput);
      onUrlPreviewChange(urlInput);
      setError(false);
    } catch {
      setError(true);
      onUrlPreviewChange(null);
    }
  };

  return (
    <div className="space-y-4">
      <div>
        <Label className="block text-[10px] font-bold uppercase tracking-[0.08em] text-zinc-500 mb-1.5">
          URL immagine
        </Label>
        <div className="flex gap-2">
          <Input
            value={urlInput}
            onChange={(e) => {
              setUrlInput(e.target.value);
              setError(false);
            }}
            onKeyDown={(e) => e.key === 'Enter' && handleCheck()}
            placeholder="https://images.unsplash.com/photo-..."
            className={cn('h-8 text-xs bg-zinc-900/50 border-zinc-800', error && 'border-red-500/50')}
          />
          <Button type="button" variant="outline" onClick={handleCheck} className="shrink-0 h-8">
            Anteprima
          </Button>
        </div>
        {error && (
          <p className="text-[11px] text-red-400 mt-1.5">
            URL non valido. Inserisci un URL completo (https://…)
          </p>
        )}
      </div>
      {urlPreview ? (
        <div className="rounded-lg overflow-hidden ring-1 ring-zinc-800">
          <img
            src={urlPreview}
            alt="URL preview"
            className="w-full max-h-[320px] object-contain bg-black/30"
            onError={() => {
              setError(true);
              onUrlPreviewChange(null);
            }}
          />
          <div className="px-3.5 py-2.5 bg-white/[0.02] border-t border-zinc-800 flex items-center gap-2">
            <Check size={14} className="text-emerald-400" />
            <span className="text-[11px] text-zinc-500">Immagine caricata correttamente</span>
          </div>
        </div>
      ) : !error ? (
        <div className="flex flex-col items-center py-12 text-zinc-600">
          <Link2 size={32} className="mb-3 opacity-40" />
          <p className="text-xs">Incolla un URL e premi Anteprima per verificare</p>
        </div>
      ) : null}
    </div>
  );
}

export const ImagePickerDialog: React.FC<ImagePickerDialogProps> = ({
  open,
  onOpenChange,
  onSelect,
}) => {
  const { assets, tenantId = 'default' } = useConfig();
  const library = assets?.assetsManifest ?? [];
  const [tab, setTab] = useState<TabId>('library');
  const [selectedLibraryId, setSelectedLibraryId] = useState<string | null>(null);
  const [uploadPreview, setUploadPreview] = useState<UploadPreview | null>(null);
  const [urlPreview, setUrlPreview] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setTab('library');
      setSelectedLibraryId(null);
      setUploadPreview(null);
      setUrlPreview(null);
    }
  }, [open]);

  // #region agent log
  useEffect(() => {
    if (!open || tab !== 'upload') return;
    const onBeforeUnload = () => {
      fetch('http://127.0.0.1:7588/ingest/86d71502-47e1-433c-9b6d-5a1390d00813',{method:'POST',headers:{'Content-Type':'application/json','X-Debug-Session-Id':'34bba5'},body:JSON.stringify({sessionId:'34bba5',location:'ImagePickerDialog.tsx:beforeunload',message:'beforeunload fired',data:{},timestamp:Date.now(),hypothesisId:'H1'})}).catch(()=>{});
    };
    window.addEventListener('beforeunload', onBeforeUnload);
    return () => window.removeEventListener('beforeunload', onBeforeUnload);
  }, [open, tab]);
  // #endregion

  // Prevent browser default (navigate to file = full page reload) when Upload tab is open. Capture only, no stopPropagation, so drop still reaches the zone.
  useEffect(() => {
    if (!open || tab !== 'upload') return;
    const prevent = (e: DragEvent) => {
      e.preventDefault();
    };
    const opts = { capture: true } as AddEventListenerOptions;
    document.addEventListener('dragover', prevent, opts);
    document.addEventListener('drop', prevent, opts);
    window.addEventListener('dragover', prevent, opts);
    window.addEventListener('drop', prevent, opts);
    return () => {
      document.removeEventListener('dragover', prevent, opts);
      document.removeEventListener('drop', prevent, opts);
      window.removeEventListener('dragover', prevent, opts);
      window.removeEventListener('drop', prevent, opts);
    };
  }, [open, tab]);

  const canConfirm =
    (tab === 'library' && selectedLibraryId != null) ||
    (tab === 'upload' && uploadPreview?.isPersistent === true && uploadPreview.finalUrl != null) ||
    (tab === 'url' && urlPreview != null);

  const handleConfirm = () => {
    if (tab === 'library' && selectedLibraryId) {
      const img = library.find((i) => i.id === selectedLibraryId);
      if (img) onSelect({ url: img.url, alt: img.alt });
    } else if (tab === 'upload' && uploadPreview?.isPersistent && uploadPreview.finalUrl) {
      onSelect({
        url: uploadPreview.finalUrl,
        alt: uploadPreview.name,
      });
    } else if (tab === 'url' && urlPreview) {
      onSelect({ url: urlPreview, alt: '' });
    }
    // Defer close so parent state (section draft) is committed and Stage re-renders before modal unmounts
    setTimeout(() => onOpenChange(false), 0);
  };

  const statusLabel =
    tab === 'library' && selectedLibraryId
      ? '1 immagine selezionata'
      : tab === 'upload' && uploadPreview
        ? uploadPreview.isPersistent
          ? uploadPreview.name
          : 'Upload non persistito'
        : tab === 'url' && urlPreview
          ? 'URL pronto'
          : 'Nessuna selezione';

  // Drag-and-drop reload fix: prevent browser from navigating to dropped file (would cause full page reload).
  // Backdrop (dialog.tsx) and modal content both block drop; document-level listener (when Upload tab) prevents default only so drop still reaches the zone.
  const blockDropNavigation = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className="max-w-2xl p-0 gap-0 max-h-[90vh] flex flex-col"
        preventCloseOnBackdropClick={tab === 'upload'}
        onDragOver={blockDropNavigation}
        onDrop={blockDropNavigation}
      >
        <DialogHeader className="px-5 py-4 flex flex-row items-start justify-between gap-4 border-b border-zinc-800">
          <div className="flex items-center gap-3">
            <div className="p-1.5 rounded-lg bg-blue-500/15 text-blue-500">
              <ImageIcon size={18} />
            </div>
            <div>
              <DialogTitle>Image Picker</DialogTitle>
              <DialogDescription>
                Scegli dalla libreria, carica dal disco o inserisci un link
              </DialogDescription>
            </div>
          </div>
          <button
            type="button"
            onClick={() => onOpenChange(false)}
            className="p-1.5 rounded text-zinc-500 hover:text-white hover:bg-zinc-800 transition-colors"
            aria-label="Chiudi"
          >
            <X size={18} />
          </button>
        </DialogHeader>

        <div className="flex border-b border-zinc-800">
          {TABS.map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setTab(t)}
              className={cn(
                'flex items-center gap-2 px-4 py-3 text-xs font-medium border-b-2 transition-colors',
                tab === t
                  ? 'border-blue-500 text-blue-400'
                  : 'border-transparent text-zinc-500 hover:text-zinc-300'
              )}
            >
              {t === 'library' && <ImageIcon size={14} />}
              {t === 'upload' && <Upload size={14} />}
              {t === 'url' && <Link2 size={14} />}
              {t === 'library' ? 'Libreria' : t === 'upload' ? 'Upload' : 'URL'}
            </button>
          ))}
        </div>

        <div className="flex-1 overflow-y-auto p-5 min-h-0">
          {tab === 'library' && (
            <LibraryTab
              library={library}
              selectedId={selectedLibraryId}
              onSelect={setSelectedLibraryId}
            />
          )}
          {tab === 'upload' && (
            <UploadTab
              preview={uploadPreview}
              onPreviewChange={setUploadPreview}
              onAssetUpload={assets?.onAssetUpload}
              tenantId={tenantId}
            />
          )}
          {tab === 'url' && (
            <UrlTab
              urlPreview={urlPreview}
              onUrlPreviewChange={setUrlPreview}
            />
          )}
        </div>

        <DialogFooter className="px-5 py-4 border-t border-zinc-800 flex-row justify-between">
          <span className="text-[10px] uppercase tracking-[0.05em] text-zinc-600">
            {statusLabel}
          </span>
          <div className="flex gap-2">
            <Button type="button" variant="outline" size="sm" onClick={() => onOpenChange(false)}>
              Annulla
            </Button>
            <Button
              type="button"
              size="sm"
              disabled={!canConfirm}
              onClick={handleConfirm}
              className={cn(!canConfirm && 'opacity-40')}
            >
              Inserisci immagine
            </Button>
          </div>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/image-picker/ImagePreviewField.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/image-picker/ImagePreviewField.tsx"
import React, { useState } from 'react';
import { Image as ImageIcon, Pencil, Trash2 } from 'lucide-react';
import { Button } from '../../ui/button';
import { Label } from '../../ui/label';
import { cn } from '../../../lib/utils';
import { useConfig } from '../../../runtime/config/ConfigContext';
import { resolveAssetUrl } from '../../../runtime/assets/asset-resolver';
import { ImagePickerDialog } from './ImagePickerDialog';
import type { ImageSelection, ImagePreviewFieldProps } from './types';

export const ImagePreviewField: React.FC<ImagePreviewFieldProps> = ({
  value,
  onChange,
  label = 'IMAGE',
  className,
}) => {
  const { tenantId = 'default' } = useConfig();
  const [pickerOpen, setPickerOpen] = useState(false);
  const [hover, setHover] = useState(false);

  const hasImage = Boolean(value?.url);
  const displayUrl = value?.url ? resolveAssetUrl(value.url, tenantId) : '';

  const handleSelect = (img: ImageSelection) => {
    onChange(img);
    setPickerOpen(false);
  };

  const handleRemove = (e: React.MouseEvent) => {
    e.stopPropagation();
    onChange({ url: '', alt: '' });
  };

  return (
    <div className={cn('space-y-1.5', className)}>
      <Label className="text-[9px] uppercase font-black tracking-widest text-zinc-500">
        {label}
      </Label>

      {hasImage ? (
        <div
          role="button"
          tabIndex={0}
          onClick={() => setPickerOpen(true)}
          onKeyDown={(e) => e.key === 'Enter' && setPickerOpen(true)}
          onMouseEnter={() => setHover(true)}
          onMouseLeave={() => setHover(false)}
          className={cn(
            'relative rounded-lg overflow-hidden cursor-pointer',
            'ring-1 ring-zinc-800 transition-all',
            hover && 'ring-blue-500/40'
          )}
        >
          <img
            src={displayUrl}
            alt={value?.alt ?? ''}
            className="w-full h-40 object-cover block"
            onError={(e) => {
              (e.target as HTMLImageElement).style.display = 'none';
            }}
          />
          <div
            className={cn(
              'absolute inset-0 flex items-center justify-center gap-2 transition-all duration-150',
              hover ? 'bg-black/50' : 'bg-black/0'
            )}
          >
            {hover && (
              <>
                <div className="flex items-center gap-1.5 bg-white/15 backdrop-blur-md rounded-lg px-3.5 py-2 text-white text-xs font-medium">
                  <Pencil size={13} />
                  <span>Cambia</span>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  className="h-8 w-8 p-0 bg-red-500/15 backdrop-blur-md text-red-300 hover:text-red-200 hover:bg-red-500/25"
                  onClick={handleRemove}
                >
                  <Trash2 size={13} />
                </Button>
              </>
            )}
          </div>
          <div className="px-2.5 py-1.5 bg-black/50 text-[10px] text-zinc-500 truncate">
            {(value?.url ?? '').length > 50
              ? '…' + (value?.url ?? '').slice(-47)
              : value?.url ?? ''}
          </div>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className={cn(
            'w-full rounded-lg border-2 border-dashed border-zinc-800 py-7',
            'flex flex-col items-center gap-2',
            'bg-white/[0.01] transition-all',
            'hover:border-blue-500/30 hover:bg-blue-500/[0.03]',
            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500'
          )}
        >
          <div className="w-9 h-9 rounded-lg bg-blue-500/10 flex items-center justify-center text-blue-500">
            <ImageIcon size={18} />
          </div>
          <span className="text-xs text-zinc-400 font-medium">
            Clicca per aggiungere un'immagine
          </span>
          <span className="text-[10px] text-zinc-600">Libreria · Upload · URL</span>
        </button>
      )}

      <ImagePickerDialog
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        onSelect={handleSelect}
      />
    </div>
  );
};

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/image-picker/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/image-picker/index.ts"
export { ImagePickerDialog } from './ImagePickerDialog';
export { ImagePreviewField } from './ImagePreviewField';
export type { ImageSelection, ImagePreviewFieldProps } from './types';
export { DEFAULT_IMAGE_SELECTION } from './types';

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/image-picker/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/image-picker/types.ts"
/**
 * Image Picker widget: value shape for schema fields with .describe('ui:image-picker').
 */
export interface ImageSelection {
  url: string;
  alt: string;
}

export const DEFAULT_IMAGE_SELECTION: ImageSelection = { url: '', alt: '' };

export interface ImagePreviewFieldProps {
  value: ImageSelection;
  onChange: (image: ImageSelection) => void;
  label?: string;
  className?: string;
}

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/index.ts"
export { AddSectionLibrary } from './AddSectionLibrary';
export { AdminSidebar, type LayerItem } from './AdminSidebar';
export { FormFactory } from './FormFactory';
export { InputWidgets, type WidgetType } from './InputRegistry';
export { PageSelector } from './PageSelector';
export { PreviewEntry } from './PreviewEntry';
export { buildSelectionPath } from './selection-path';
export { StudioStage } from './StudioStage';

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/selection-path.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/selection-path.test.ts"
import { expect, test } from 'vitest';
import { buildSelectionPath } from './selection-path';

class FakeElement {
  parentElement: FakeElement | null;
  private attrs: Record<string, string>;

  constructor(attrs: Record<string, string> = {}, parent: FakeElement | null = null) {
    this.attrs = attrs;
    this.parentElement = parent;
  }

  getAttribute(name: string): string | null {
    return this.attrs[name] ?? null;
  }
}

test('scalar field only returns single field segment', () => {
  const section = new FakeElement();
  const title = new FakeElement({ 'data-jp-field': 'title' }, section);

  const path = buildSelectionPath(title as unknown as HTMLElement, section as unknown as HTMLElement);
  expect(path).toEqual([{ fieldKey: 'title' }]);
});

test('array item only returns array segment with item id', () => {
  const section = new FakeElement();
  const item = new FakeElement(
    { 'data-jp-item-id': 'item-1', 'data-jp-item-field': 'menu' },
    section
  );

  const path = buildSelectionPath(item as unknown as HTMLElement, section as unknown as HTMLElement);
  expect(path).toEqual([{ fieldKey: 'menu', itemId: 'item-1' }]);
});

test('array item + nested field returns root-to-leaf path', () => {
  const section = new FakeElement();
  const item = new FakeElement(
    { 'data-jp-item-id': 'item-1', 'data-jp-item-field': 'menu' },
    section
  );
  const label = new FakeElement({ 'data-jp-field': 'label' }, item);

  const path = buildSelectionPath(label as unknown as HTMLElement, section as unknown as HTMLElement);
  expect(path).toEqual([
    { fieldKey: 'menu', itemId: 'item-1' },
    { fieldKey: 'label' },
  ]);
});

test('interactive href field in item path stays deterministic', () => {
  const section = new FakeElement();
  const item = new FakeElement(
    { 'data-jp-item-id': 'cta-1', 'data-jp-item-field': 'ctas', 'data-jp-field': 'href' },
    section
  );

  const path = buildSelectionPath(item as unknown as HTMLElement, section as unknown as HTMLElement);
  expect(path).toEqual([
    { fieldKey: 'ctas', itemId: 'cta-1' },
    { fieldKey: 'href' },
  ]);
});

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/selection-path.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/selection-path.ts"
import type { SelectionPath } from '../../contract/types-engine';

function appendLeafFieldSegment(
  path: SelectionPath,
  leafFieldKey: string | null
): SelectionPath {
  if (!leafFieldKey) return path;
  const last = path[path.length - 1];
  if (last && last.itemId == null && last.fieldKey === leafFieldKey) return path;
  return [...path, { fieldKey: leafFieldKey }];
}

export function buildSelectionPath(
  root: HTMLElement,
  sectionEl: HTMLElement
): SelectionPath {
  const itemSegments: SelectionPath = [];
  let leafFieldKey: string | null = null;
  let cursor: HTMLElement | null = root;

  while (cursor && cursor !== sectionEl) {
    const itemId = cursor.getAttribute?.('data-jp-item-id');
    const itemFieldKey = cursor.getAttribute?.('data-jp-item-field');
    if (itemId && itemFieldKey) {
      itemSegments.push({ fieldKey: itemFieldKey, itemId });
    }

    if (leafFieldKey == null) {
      const fieldKey = cursor.getAttribute?.('data-jp-field');
      if (fieldKey) leafFieldKey = fieldKey;
    }

    cursor = cursor.parentElement;
  }

  itemSegments.reverse();
  return appendLeafFieldSegment(itemSegments, leafFieldKey);
}

END_OF_FILE_CONTENT
echo "Creating core/src/studio/admin/vitest-setup.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/admin/vitest-setup.ts"
import '@testing-library/jest-dom/vitest';

END_OF_FILE_CONTENT
echo "Creating core/src/studio/events.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/events.ts"
export const STUDIO_EVENTS = {
  UPDATE_DRAFTS: 'jsonpages:update-drafts',
  SYNC_SELECTION: 'jsonpages:sync-selection',
  SECTION_SELECT: 'jsonpages:section-select',
  INLINE_FIELD_UPDATE: 'jsonpages:inline-field-update',
  INLINE_FLUSHED: 'jsonpages:inline-flushed',
  REQUEST_SCROLL_TO_SECTION: 'jsonpages:request-scroll-to-section',
  REQUEST_INLINE_FLUSH: 'jsonpages:request-inline-flush',
  ACTIVE_SECTION_CHANGED: 'jsonpages:active-section-changed',
  STAGE_READY: 'jsonpages:stage-ready',
  WEBMCP_TOOL_CALL: 'olonjs:webmcp:tool-call',
  WEBMCP_TOOL_RESULT: 'olonjs:webmcp:tool-result',
} as const;

END_OF_FILE_CONTENT
echo "Creating core/src/studio/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/index.ts"
export { STUDIO_EVENTS } from './events';
export { StudioProvider, useStudio } from './StudioContext';
export * as admin from './admin';

END_OF_FILE_CONTENT
mkdir -p "core/src/studio/orchestration"
echo "Creating core/src/studio/orchestration/section-ops.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/orchestration/section-ops.ts"
import type { PageConfig, Section } from '../../contract/kernel';

export function reorderPageSections(
  currentDraft: PageConfig,
  sectionId: string,
  newIndex: number
): PageConfig {
  const sections = [...currentDraft.sections];
  const currentIndex = sections.findIndex((section) => section.id === sectionId);
  if (currentIndex === -1 || newIndex < 0 || newIndex >= sections.length) {
    return currentDraft;
  }

  const [removed] = sections.splice(currentIndex, 1);
  const insertIndex = newIndex > currentIndex ? newIndex - 1 : newIndex;
  sections.splice(Math.min(insertIndex, sections.length), 0, removed);

  return { ...currentDraft, sections };
}

export function appendDraftSection(
  currentDraft: PageConfig,
  sectionType: string,
  defaultData: Record<string, unknown>
): { draft: PageConfig; section: Section } {
  const section: Section = {
    id: crypto.randomUUID(),
    type: sectionType,
    data: defaultData,
    settings: undefined,
  };

  return {
    draft: {
      ...currentDraft,
      sections: [...currentDraft.sections, section],
    },
    section,
  };
}

END_OF_FILE_CONTENT
echo "Creating core/src/studio/orchestration/useStudioPersistence.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/orchestration/useStudioPersistence.ts"
import { useCallback, useState } from 'react';
import {
  applySiteMenuRefBindingsToDraft,
  resolveRuntimeConfig,
} from '../../contract/config-resolver';
import type { MenuConfig, PageConfig, ProjectState, SiteConfig } from '../../contract/kernel';
import type { JsonPagesConfig } from '../../contract/types-engine';
import { STUDIO_EVENTS } from '../events';

interface UseStudioPersistenceArgs {
  slug: string;
  saveToFile?: (state: ProjectState, slug: string) => Promise<void>;
  hotSave?: (state: ProjectState, slug: string) => Promise<void>;
  authoredSiteConfig: SiteConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
}

export function useStudioPersistence({
  slug,
  saveToFile,
  hotSave,
  authoredSiteConfig,
  themeConfig,
  collections,
  collectionSchemas,
  refDocuments,
}: UseStudioPersistenceArgs) {
  const [saveSuccessFeedback, setSaveSuccessFeedback] = useState(false);
  const [hotSaveSuccessFeedback, setHotSaveSuccessFeedback] = useState(false);
  const [hotSaveInProgress, setHotSaveInProgress] = useState(false);

  const requestInlineFlush = useCallback(async () => {
    const iframe = document.querySelector('iframe');
    if (!iframe?.contentWindow) return;
    const requestId = crypto.randomUUID();
    await new Promise<void>((resolve) => {
      let settled = false;
      const onMessage = (event: MessageEvent) => {
        if (event.origin !== window.location.origin) return;
        if (event.data?.type === STUDIO_EVENTS.INLINE_FLUSHED && event.data?.requestId === requestId) {
          settled = true;
          window.removeEventListener('message', onMessage);
          resolve();
        }
      };
      window.addEventListener('message', onMessage);
      iframe.contentWindow?.postMessage({ type: STUDIO_EVENTS.REQUEST_INLINE_FLUSH, requestId }, '*');
      window.setTimeout(() => {
        if (settled) return;
        window.removeEventListener('message', onMessage);
        resolve();
      }, 400);
    });
  }, []);

  const buildProjectState = useCallback(
    (
      nextDraft: PageConfig,
      nextGlobalDraft: SiteConfig,
      nextMenuDraft: MenuConfig,
      nextCollectionsDraft: JsonPagesConfig['collections'] = collections
    ): ProjectState => {
      const normalizedGlobal = applySiteMenuRefBindingsToDraft(
        authoredSiteConfig,
        nextGlobalDraft,
        nextMenuDraft
      );
      const resolvedSaveRuntime = resolveRuntimeConfig({
        pages: { [slug]: nextDraft },
        siteConfig: normalizedGlobal.site,
        themeConfig,
        menuConfig: normalizedGlobal.menuDraft,
        collections: nextCollectionsDraft,
        collectionSchemas,
        refDocuments,
      });
      const hasCollections =
        Object.keys(resolvedSaveRuntime.collections).length > 0;
      return {
        page: nextDraft,
        site: normalizedGlobal.site,
        menu: normalizedGlobal.menuDraft,
        theme: resolvedSaveRuntime.themeConfig,
        ...(hasCollections ? { collections: resolvedSaveRuntime.collections } : {}),
      };
    },
    [authoredSiteConfig, collections, collectionSchemas, slug, themeConfig, refDocuments]
  );

  const persistProjectState = useCallback(
    async (
      nextDraft: PageConfig,
      nextGlobalDraft: SiteConfig,
      nextMenuDraft: MenuConfig,
      nextCollectionsDraft?: JsonPagesConfig['collections'],
      onPersisted?: () => void
    ) => {
      if (!saveToFile) {
        throw new Error('saveToFile is not configured for this tenant.');
      }

      await saveToFile(buildProjectState(nextDraft, nextGlobalDraft, nextMenuDraft, nextCollectionsDraft), slug);
      onPersisted?.();
      setSaveSuccessFeedback(true);
      if (typeof window !== 'undefined') {
        window.setTimeout(() => setSaveSuccessFeedback(false), 2500);
      }
    },
    [buildProjectState, saveToFile, slug]
  );

  const runHotSave = useCallback(
    async (
      nextDraft: PageConfig,
      nextGlobalDraft: SiteConfig,
      nextMenuDraft: MenuConfig,
      nextCollectionsDraft?: JsonPagesConfig['collections'],
      onPersisted?: () => void
    ) => {
      if (!hotSave) return;

      setHotSaveInProgress(true);
      try {
        await hotSave(buildProjectState(nextDraft, nextGlobalDraft, nextMenuDraft, nextCollectionsDraft), slug);
        onPersisted?.();
        setHotSaveSuccessFeedback(true);
        if (typeof window !== 'undefined') {
          window.setTimeout(() => setHotSaveSuccessFeedback(false), 2500);
        }
      } finally {
        setHotSaveInProgress(false);
      }
    },
    [buildProjectState, hotSave, slug]
  );

  return {
    buildProjectState,
    hotSaveInProgress,
    hotSaveSuccessFeedback,
    persistProjectState,
    requestInlineFlush,
    runHotSave,
    saveSuccessFeedback,
  };
}

END_OF_FILE_CONTENT
echo "Creating core/src/studio/orchestration/useStudioSelectionState.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/orchestration/useStudioSelectionState.ts"
import { useCallback, useState } from 'react';

export interface StudioSelection {
  id: string;
  type: string;
  scope: string;
}

export interface ExpandedSelectionSegment {
  fieldKey: string;
  itemId?: string;
}

export function useStudioSelectionState() {
  const [selected, setSelected] = useState<StudioSelection | null>(null);
  const [expandedItemPath, setExpandedItemPath] = useState<ExpandedSelectionSegment[] | null>(null);
  const [activeSectionId, setActiveSectionId] = useState<string | null>(null);
  const [scrollToSectionId, setScrollToSectionId] = useState<string | null>(null);

  const clearSelection = useCallback(() => {
    setSelected(null);
    setExpandedItemPath(null);
  }, []);

  return {
    activeSectionId,
    clearSelection,
    expandedItemPath,
    scrollToSectionId,
    selected,
    setActiveSectionId,
    setExpandedItemPath,
    setScrollToSectionId,
    setSelected,
  };
}

END_OF_FILE_CONTENT
mkdir -p "core/src/studio/ui"
echo "Creating core/src/studio/ui/button.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/button.tsx"
import * as React from 'react';
import { Slot } from '@radix-ui/react-slot';
import { cn } from '../../lib/utils';

interface ButtonProps extends React.ComponentProps<'button'> {
  variant?: 'default' | 'outline' | 'ghost' | 'destructive';
  size?: 'sm' | 'default' | 'lg' | 'icon' | 'icon-sm' | 'icon-xs';
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'default', size = 'default', asChild = false, ...props }, ref) => {
    const base =
      'inline-flex items-center justify-center gap-1.5 whitespace-nowrap rounded-md font-medium transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 [&_svg]:shrink-0 cursor-pointer';
    const variants: Record<NonNullable<ButtonProps['variant']>, string> = {
      default: 'bg-primary text-primary-foreground shadow-lg shadow-primary/20 hover:bg-primary/90',
      outline: 'border border-zinc-700 bg-zinc-900 text-zinc-200 hover:bg-zinc-800 hover:border-zinc-600',
      ghost: 'text-zinc-500 hover:text-zinc-200 hover:bg-zinc-800',
      destructive: 'bg-destructive/15 text-destructive hover:bg-destructive/25',
    };
    const sizes: Record<NonNullable<ButtonProps['size']>, string> = {
      sm: 'h-7 px-2.5 text-[11px]',
      default: 'h-8 px-3 py-1.5 text-xs',
      lg: 'h-9 px-5 text-sm',
      icon: 'h-8 w-8',
      'icon-sm': 'h-7 w-7',
      'icon-xs': 'h-6 w-6',
    };
    const Comp = asChild ? Slot : 'button';
    return (
      <Comp
        ref={ref}
        type="button"
        className={cn(base, variants[variant], sizes[size], className)}
        {...props}
      />
    );
  }
);

Button.displayName = 'Button';

export { Button };

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/checkbox.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/checkbox.tsx"
import * as React from 'react';
import { cn } from '../../lib/utils';

interface CheckboxProps extends Omit<React.ComponentProps<'input'>, 'type'> {
  checked?: boolean;
  onCheckedChange?: (checked: boolean) => void;
}

function Checkbox({ className, checked, onCheckedChange, ...props }: CheckboxProps) {
  return (
    <input
      type="checkbox"
      checked={checked}
      onChange={(e) => onCheckedChange?.(e.target.checked)}
      className={cn(
        'size-4 rounded border border-zinc-700 bg-zinc-900 text-blue-600 focus:ring-2 focus:ring-blue-600',
        className
      )}
      {...props}
    />
  );
}

export { Checkbox };

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/dialog.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/dialog.tsx"
import * as React from 'react';
import { createPortal } from 'react-dom';
import { cn } from '../../lib/utils';

type DialogContextValue = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
};

const DialogContext = React.createContext<DialogContextValue | null>(null);

function useDialogContext() {
  const ctx = React.useContext(DialogContext);
  if (!ctx) throw new Error('Dialog components must be used within Dialog');
  return ctx;
}

interface DialogProps {
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
  children: React.ReactNode;
}

function Dialog({ open: controlledOpen, onOpenChange, children }: DialogProps) {
  const [uncontrolledOpen, setUncontrolledOpen] = React.useState(false);
  const isControlled = controlledOpen !== undefined;
  const open = isControlled ? controlledOpen : uncontrolledOpen;
  const setOpen = React.useCallback(
    (next: boolean) => {
      if (!isControlled) setUncontrolledOpen(next);
      onOpenChange?.(next);
    },
    [isControlled, onOpenChange]
  );

  const value = React.useMemo(() => ({ open, onOpenChange: setOpen }), [open, setOpen]);
  return (
    <DialogContext.Provider value={value}>
      {children}
    </DialogContext.Provider>
  );
}

interface DialogTriggerProps {
  asChild?: boolean;
  children: React.ReactNode;
}

function DialogTrigger({ asChild, children }: DialogTriggerProps) {
  const { onOpenChange } = useDialogContext();
  const child = React.Children.only(children) as React.ReactElement<{ onClick?: (e: React.MouseEvent) => void }>;
  if (asChild && React.isValidElement(child)) {
    return React.cloneElement(child, {
      onClick: (e: React.MouseEvent) => {
        child.props.onClick?.(e);
        onOpenChange(true);
      },
    });
  }
  return (
    <button type="button" onClick={() => onOpenChange(true)}>
      {children}
    </button>
  );
}

interface DialogContentProps extends React.ComponentProps<'div'> {
  className?: string;
  children?: React.ReactNode;
  /** When true, clicking the backdrop does not close the dialog (e.g. during upload flow). */
  preventCloseOnBackdropClick?: boolean;
}

function DialogContent({ className, children, preventCloseOnBackdropClick, ...props }: DialogContentProps) {
  const { open, onOpenChange } = useDialogContext();

  React.useEffect(() => {
    const onEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onOpenChange(false);
    };
    if (open) {
      document.addEventListener('keydown', onEscape);
      document.body.style.overflow = 'hidden';
    }
    return () => {
      document.removeEventListener('keydown', onEscape);
      document.body.style.overflow = '';
    };
  }, [open, onOpenChange]);

  if (!open) return null;

  const blockDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  return createPortal(
    <>
      <div
        className="fixed inset-0 z-[9998] bg-black/60"
        aria-hidden
        onClick={() => !preventCloseOnBackdropClick && onOpenChange(false)}
        onDragOver={blockDrop}
        onDrop={blockDrop}
      />
      <div
        role="dialog"
        aria-modal
        className={cn(
          'fixed left-1/2 top-1/2 z-[9999] w-[calc(100%-2rem)] max-w-lg -translate-x-1/2 -translate-y-1/2 rounded-lg border border-zinc-700 bg-zinc-900 p-4 shadow-xl',
          className
        )}
        onClick={(e) => e.stopPropagation()}
        {...props}
      >
        {children}
      </div>
    </>,
    document.body
  );
}

function DialogHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return <div className={cn('flex flex-col gap-1.5 pb-4', className)} {...props} />;
}

function DialogFooter({ className, ...props }: React.ComponentProps<'div'>) {
  return <div className={cn('flex justify-end gap-2 pt-4', className)} {...props} />;
}

function DialogTitle({ className, ...props }: React.ComponentProps<'h2'>) {
  return <h2 className={cn('text-sm font-semibold text-white', className)} {...props} />;
}

function DialogDescription({ className, ...props }: React.ComponentProps<'p'>) {
  return <p className={cn('text-xs text-zinc-400', className)} {...props} />;
}

interface DialogCloseProps {
  asChild?: boolean;
  children: React.ReactNode;
}

function DialogClose({ asChild, children }: DialogCloseProps) {
  const { onOpenChange } = useDialogContext();
  const child = React.Children.only(children) as React.ReactElement<{ onClick?: (e: React.MouseEvent) => void }>;
  if (asChild && React.isValidElement(child)) {
    return React.cloneElement(child, {
      onClick: (e: React.MouseEvent) => {
        child.props.onClick?.(e);
        onOpenChange(false);
      },
    });
  }
  return (
    <button type="button" onClick={() => onOpenChange(false)}>
      {children}
    </button>
  );
}

export { Dialog, DialogTrigger, DialogContent, DialogHeader, DialogFooter, DialogTitle, DialogDescription, DialogClose };

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/index.ts"
export { Button } from './button';
export { Checkbox } from './checkbox';
export {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from './dialog';
export { Input } from './input';
export { Label } from './label';
export { Popover, PopoverContent, PopoverTrigger } from './popover';
export { ScrollArea } from './scroll-area';
export {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from './select';
export { Switch } from './switch';
export { Textarea } from './textarea';
export {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from './tooltip';

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/input.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/input.tsx"
import * as React from 'react';
import { cn } from '../../lib/utils';

function Input({ className, type, ...props }: React.ComponentProps<'input'>) {
  return (
    <input
      type={type}
      className={cn(
        'h-8 rounded-lg border border-zinc-800 bg-zinc-900/50 px-2.5 py-1 text-sm outline-none transition-colors focus:ring-2 focus:ring-blue-600',
        className
      )}
      {...props}
    />
  );
}

export { Input };

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/label.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/label.tsx"
import * as React from 'react';
import { cn } from '../../lib/utils';

function Label({ className, ...props }: React.ComponentProps<'label'>) {
  return (
    <label
      className={cn('text-sm font-medium leading-none select-none', className)}
      {...props}
    />
  );
}

export { Label };

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/popover.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/popover.tsx"
import * as React from 'react';
import * as PopoverPrimitive from '@radix-ui/react-popover';
import { cn } from '../../lib/utils';

const Popover = PopoverPrimitive.Root;
const PopoverTrigger = PopoverPrimitive.Trigger;
const PopoverAnchor = PopoverPrimitive.Anchor;

const PopoverContent = React.forwardRef<
  React.ComponentRef<typeof PopoverPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof PopoverPrimitive.Content>
>(({ className, align = 'start', sideOffset = 6, ...props }, ref) => (
  <PopoverPrimitive.Portal>
    <PopoverPrimitive.Content
      ref={ref}
      align={align}
      sideOffset={sideOffset}
      className={cn(
        'z-50 w-[var(--radix-popover-trigger-width)] rounded-lg border border-zinc-700/80 bg-zinc-950 p-1 text-white shadow-xl shadow-black/30',
        'data-[state=open]:animate-in data-[state=closed]:animate-out',
        'data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0',
        'data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95',
        'data-[side=bottom]:slide-in-from-top-2',
        className
      )}
      {...props}
    />
  </PopoverPrimitive.Portal>
));
PopoverContent.displayName = PopoverPrimitive.Content.displayName;

export { Popover, PopoverTrigger, PopoverContent, PopoverAnchor };

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/scroll-area.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/scroll-area.tsx"
import * as React from 'react';
import * as ScrollAreaPrimitive from '@radix-ui/react-scroll-area';
import { cn } from '../../lib/utils';

const ScrollArea = React.forwardRef<
  React.ComponentRef<typeof ScrollAreaPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof ScrollAreaPrimitive.Root>
>(({ className, children, ...props }, ref) => (
  <ScrollAreaPrimitive.Root ref={ref} className={cn('relative overflow-hidden', className)} {...props}>
    <ScrollAreaPrimitive.Viewport className="h-full w-full rounded-[inherit]">
      {children}
    </ScrollAreaPrimitive.Viewport>
    <ScrollAreaPrimitive.Scrollbar
      orientation="vertical"
      className="flex touch-none select-none transition-colors h-full w-1.5 border-l border-l-transparent p-px"
    >
      <ScrollAreaPrimitive.Thumb className="relative flex-1 rounded-full bg-zinc-700 hover:bg-zinc-600" />
    </ScrollAreaPrimitive.Scrollbar>
    <ScrollAreaPrimitive.Corner />
  </ScrollAreaPrimitive.Root>
));
ScrollArea.displayName = ScrollAreaPrimitive.Root.displayName;

export { ScrollArea };

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/select.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/select.tsx"
import * as React from 'react';
import * as SelectPrimitive from '@radix-ui/react-select';
import { ChevronDown, Check } from 'lucide-react';
import { cn } from '../../lib/utils';

const Select = SelectPrimitive.Root;

const SelectGroup = SelectPrimitive.Group;

const SelectValue = SelectPrimitive.Value;

const SelectTrigger = React.forwardRef<
  React.ComponentRef<typeof SelectPrimitive.Trigger>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Trigger>
>(({ className, children, ...props }, ref) => (
  <SelectPrimitive.Trigger
    ref={ref}
    className={cn(
      'flex h-8 w-full items-center justify-between gap-2 rounded-md border border-zinc-800 bg-black px-3 py-1.5 text-left text-xs font-medium text-white outline-none',
      'hover:bg-zinc-900 focus-visible:ring-2 focus-visible:ring-blue-500/80 focus-visible:ring-inset focus-visible:border-zinc-600',
      'disabled:pointer-events-none disabled:opacity-50 [&>span]:line-clamp-1 [&>span]:flex [&>span]:items-center [&>span]:gap-2',
      className
    )}
    style={{ boxShadow: 'none', WebkitBoxShadow: 'none', MozBoxShadow: 'none' }}
    {...props}
  >
    {children}
    <SelectPrimitive.Icon asChild>
      <ChevronDown className="h-3 w-3 shrink-0 text-zinc-400" strokeWidth={2} />
    </SelectPrimitive.Icon>
  </SelectPrimitive.Trigger>
));
SelectTrigger.displayName = SelectPrimitive.Trigger.displayName;

const SelectContent = React.forwardRef<
  React.ComponentRef<typeof SelectPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Content>
>(({ className, children, position = 'popper', ...props }, ref) => (
  <SelectPrimitive.Portal>
    <SelectPrimitive.Content
      ref={ref}
      className={cn(
        'relative z-[9999] max-h-96 min-w-[8rem] overflow-hidden rounded-md border border-zinc-800 bg-zinc-950 text-white shadow-lg',
        'data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95',
        'data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2',
        position === 'popper' &&
          'data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1',
        className
      )}
      position={position}
      {...props}
    >
      <SelectPrimitive.Viewport
        className={cn(
          'p-1',
          position === 'popper' &&
            'h-[var(--radix-select-trigger-height)] w-full min-w-[var(--radix-select-trigger-width)]'
        )}
      >
        {children}
      </SelectPrimitive.Viewport>
    </SelectPrimitive.Content>
  </SelectPrimitive.Portal>
));
SelectContent.displayName = SelectPrimitive.Content.displayName;

const SelectItem = React.forwardRef<
  React.ComponentRef<typeof SelectPrimitive.Item>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Item>
>(({ className, children, ...props }, ref) => (
  <SelectPrimitive.Item
    ref={ref}
    className={cn(
      'relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-xs outline-none',
      'focus:bg-zinc-800 focus:text-white data-[disabled]:pointer-events-none data-[disabled]:opacity-50',
      className
    )}
    {...props}
  >
    <span className="absolute left-2 flex h-3.5 w-3.5 items-center justify-center">
      <SelectPrimitive.ItemIndicator>
        <Check className="h-3 w-3" strokeWidth={2} />
      </SelectPrimitive.ItemIndicator>
    </span>
    <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
  </SelectPrimitive.Item>
));
SelectItem.displayName = SelectPrimitive.Item.displayName;

export { Select, SelectGroup, SelectValue, SelectTrigger, SelectContent, SelectItem };

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/switch.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/switch.tsx"
import * as React from 'react';
import { cn } from '../../lib/utils';

interface SwitchProps extends Omit<React.ComponentProps<'button'>, 'onChange'> {
  checked?: boolean;
  onCheckedChange?: (checked: boolean) => void;
}

const Switch = React.forwardRef<HTMLButtonElement, SwitchProps>(
  ({ className, checked = false, onCheckedChange, ...props }, ref) => {
    const handleClick = () => onCheckedChange?.(!checked);
    return (
      <button
        ref={ref}
        type="button"
        role="switch"
        aria-checked={checked}
        data-state={checked ? 'checked' : 'unchecked'}
        onClick={handleClick}
        className={cn(
          'peer inline-flex h-4 w-7 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent shadow-sm transition-colors',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 focus-visible:ring-offset-zinc-900',
          'disabled:cursor-not-allowed disabled:opacity-50',
          checked ? 'bg-blue-600' : 'bg-zinc-700',
          className
        )}
        {...props}
      >
        <span
          className={cn(
            'pointer-events-none block h-3 w-3 rounded-full bg-white shadow ring-0 transition-transform',
            checked ? 'translate-x-3' : 'translate-x-0.5'
          )}
        />
      </button>
    );
  }
);
Switch.displayName = 'Switch';

export { Switch };

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/textarea.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/textarea.tsx"
import * as React from 'react';
import { cn } from '../../lib/utils';

function Textarea({ className, ...props }: React.ComponentProps<'textarea'>) {
  return (
    <textarea
      className={cn(
        'min-h-16 w-full rounded-lg border border-zinc-800 bg-zinc-900/50 px-2.5 py-2 text-sm outline-none transition-colors focus:ring-2 focus:ring-blue-600 resize-none',
        className
      )}
      {...props}
    />
  );
}

export { Textarea };

END_OF_FILE_CONTENT
echo "Creating core/src/studio/ui/tooltip.tsx..."
cat << 'END_OF_FILE_CONTENT' > "core/src/studio/ui/tooltip.tsx"
import * as React from 'react';
import * as TooltipPrimitive from '@radix-ui/react-tooltip';
import { cn } from '../../lib/utils';

const TooltipProvider = TooltipPrimitive.Provider;
const Tooltip = TooltipPrimitive.Root;
const TooltipTrigger = TooltipPrimitive.Trigger;

const TooltipContent = React.forwardRef<
  React.ComponentRef<typeof TooltipPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof TooltipPrimitive.Content>
>(({ className, sideOffset = 4, ...props }, ref) => (
  <TooltipPrimitive.Portal>
    <TooltipPrimitive.Content
      ref={ref}
      sideOffset={sideOffset}
      className={cn(
        'z-50 rounded-md bg-zinc-800 px-2.5 py-1.5 text-[11px] text-zinc-200 shadow-md',
        'animate-in fade-in-0 zoom-in-95',
        className
      )}
      {...props}
    />
  </TooltipPrimitive.Portal>
));
TooltipContent.displayName = TooltipPrimitive.Content.displayName;

export { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider };

END_OF_FILE_CONTENT
echo "Creating core/src/vite-env.d.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/vite-env.d.ts"
declare module '*.css?inline' {
  const src: string;
  export default src;
}

END_OF_FILE_CONTENT
mkdir -p "core/src/webmcp"
echo "Creating core/src/webmcp/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/webmcp/index.ts"
/**
 * Conceptual public surface for WebMCP/browser bridge concerns.
 *
 * The browser runtime and the published contracts still live in the same
 * package today, but this barrel gives them a clean future seam.
 */
export {
  applyValueAtSelectionPath,
  buildWebMcpToolName,
  buildWebMcpSaveToolName,
  createWebMcpToolInputSchema,
  createWebMcpSaveToolInputSchema,
  ensureWebMcpRuntime,
  parseWebMcpMutationArgs,
  registerWebMcpTool,
  resolveWebMcpMutationData,
  type WebMcpMutationArgs,
} from './runtime';
export {
  buildLlmsTxt,
  buildPageContract,
  buildPageContractHref,
  buildPageManifest,
  buildPageManifestHref,
  buildSiteManifest,
} from '../contract/webmcp-contracts';
export type {
  BuildPageContractInput,
  BuildSiteManifestInput,
  OlonJsPageContract,
  OlonJsPageManifest,
  OlonJsSiteManifestIndex,
  WebMcpSectionInstance,
  WebMcpToolContract,
} from '../contract/webmcp-contracts';

END_OF_FILE_CONTENT
mkdir -p "core/src/webmcp/runtime"
echo "Creating core/src/webmcp/runtime/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/webmcp/runtime/index.ts"
export {
  applyValueAtSelectionPath,
  buildWebMcpToolName,
  buildWebMcpSaveToolName,
  createWebMcpToolInputSchema,
  createWebMcpSaveToolInputSchema,
  ensureWebMcpRuntime,
  parseWebMcpMutationArgs,
  registerWebMcpTool,
  resolveWebMcpMutationData,
  type WebMcpMutationArgs,
} from './webmcp-bridge';

END_OF_FILE_CONTENT
echo "Creating core/src/webmcp/runtime/webmcp-bridge.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/webmcp/runtime/webmcp-bridge.test.ts"
import { describe, expect, it, vi } from 'vitest';
import { z } from 'zod';
import { applyCollectionRefBindingsToDraft } from '../../contract/config-resolver';
import {
  applyValueAtSelectionPath,
  buildWebMcpToolName,
  ensureWebMcpRuntime,
  registerWebMcpTool,
  resolveWebMcpMutationData,
} from './webmcp-bridge';

describe('webmcp runtime bridge', () => {
  const bookCollectionSchemas = {
    libri: z.record(
      z.object({
        id: z.string(),
        title: z.string(),
        author: z.string(),
        summary: z.string().optional(),
      })
    ),
  };

  it('builds deterministic tool names', () => {
    expect(buildWebMcpToolName()).toBe('update-section');
  });

  it('applies scalar updates through a root field path', () => {
    expect(
      resolveWebMcpMutationData(
        { title: 'Before', description: 'Copy' },
        { sectionId: 'hero-main', fieldKey: 'title', value: 'After' }
      )
    ).toEqual({ title: 'After', description: 'Copy' });
  });

  it('applies nested array updates through itemPath', () => {
    const next = applyValueAtSelectionPath(
      {
        ctas: [
          { id: 'cta-1', label: 'Primary', href: '/before' },
          { id: 'cta-2', label: 'Docs', href: '/docs' },
        ],
      },
      [
        { fieldKey: 'ctas', itemId: 'cta-1' },
        { fieldKey: 'href' },
      ],
      '/after'
    );

    expect(next).toEqual({
      ctas: [
        { id: 'cta-1', label: 'Primary', href: '/after' },
        { id: 'cta-2', label: 'Docs', href: '/docs' },
      ],
    });
  });

  it('replaces the full data payload when data is provided', () => {
    const next = resolveWebMcpMutationData(
      { title: 'Old', description: 'Body' },
      {
        sectionId: 'hero-main',
        data: { title: 'New', description: 'Updated' },
      }
    );

    expect(next).toEqual({ title: 'New', description: 'Updated' });
  });

  it('supports agent full-field replacement for a collection record ref while preserving the authored page ref', () => {
    const authoredData = {
      title: 'Libri',
      items: { $ref: '../collections/libri/libri.json' },
    };
    const updatedCollection = {
      dune: {
        id: 'dune',
        title: 'Dune Messiah',
        author: 'Frank Herbert',
      },
      neuromancer: {
        id: 'neuromancer',
        title: 'Neuromancer',
        author: 'William Gibson',
      },
    };

    const nextData = resolveWebMcpMutationData(authoredData, {
      sectionId: 'books-list',
      sectionType: 'books-list',
      fieldKey: 'items',
      value: updatedCollection,
    });

    const result = applyCollectionRefBindingsToDraft(
      authoredData,
      nextData,
      {
        libri: {
          dune: {
            id: 'dune',
            title: 'Dune',
            author: 'Frank Herbert',
          },
        },
      },
      undefined,
      bookCollectionSchemas
    );

    expect(result.normalizedData.items).toEqual({ $ref: '../collections/libri/libri.json' });
    expect(result.collectionsDraft?.libri).toEqual(updatedCollection);
  });

  it('supports agent full-field replacement for collection:current while preserving the authored detail ref', () => {
    const authoredData = {
      item: { $ref: 'collection:current' },
      backLabel: 'Torna ai libri',
    };
    const updatedBook = {
      id: 'dune',
      title: 'Dune Messiah',
      author: 'Frank Herbert',
      summary: 'Updated by an agent.',
    };

    const nextData = resolveWebMcpMutationData(authoredData, {
      sectionId: 'book-detail',
      sectionType: 'book-detail',
      fieldKey: 'item',
      value: updatedBook,
    });

    const result = applyCollectionRefBindingsToDraft(
      authoredData,
      nextData,
      {
        libri: {
          dune: {
            id: 'dune',
            title: 'Dune',
            author: 'Frank Herbert',
          },
        },
      },
      {
        source: 'libri',
        paramKey: 'slug',
        paramValue: 'dune',
        currentItem: {
          id: 'dune',
          title: 'Dune',
          author: 'Frank Herbert',
        },
      },
      bookCollectionSchemas
    );

    expect(result.normalizedData.item).toEqual({ $ref: 'collection:current' });
    expect(result.collectionsDraft?.libri?.dune).toEqual(updatedBook);
  });

  it('installs a testing shim that can execute registered tools', async () => {
    const originalWindow = globalThis.window;
    const originalNavigator = globalThis.navigator;
    Object.defineProperty(globalThis, 'window', {
      value: {} as Window,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(globalThis, 'navigator', {
      value: {} as Navigator,
      configurable: true,
      writable: true,
    });

    ensureWebMcpRuntime();

    try {
      const unregister = registerWebMcpTool({
        name: 'update-section',
        description: 'Update section',
        inputSchema: { type: 'object', properties: {} },
        execute: async () => ({
          content: [{ type: 'text', text: 'ok' }],
          isError: false,
        }),
      });

      const tools = navigator.modelContextProtocol?.listTools?.() ?? [];
      expect(tools.map((tool) => tool.name)).toContain('update-section');

      const result = await navigator.modelContextProtocol?.executeTool?.('update-section', '{}');
      expect(JSON.parse(result ?? '{}')).toMatchObject({
        content: [{ type: 'text', text: 'ok' }],
        isError: false,
      });

      unregister();
    } finally {
      Object.defineProperty(globalThis, 'window', {
        value: originalWindow,
        configurable: true,
        writable: true,
      });
      Object.defineProperty(globalThis, 'navigator', {
        value: originalNavigator,
        configurable: true,
        writable: true,
      });
    }
  });

  it('delegates registration to a pre-existing navigator.modelContext.registerTool with an AbortSignal (Chrome native WebMCP)', () => {
    const originalWindow = globalThis.window;
    const originalNavigator = globalThis.navigator;
    if (globalThis.window) {
      delete (globalThis.window as unknown as { __olonWebMcpControllers__?: unknown }).__olonWebMcpControllers__;
    }

    const nativeRegisterTool = vi.fn();
    const nativeModelContext = { registerTool: nativeRegisterTool };

    Object.defineProperty(globalThis, 'window', {
      value: {} as Window,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(globalThis, 'navigator', {
      value: { modelContext: nativeModelContext } as Navigator,
      configurable: true,
      writable: true,
    });

    try {
      const tool = {
        name: 'update-section',
        description: 'Update section',
        inputSchema: { type: 'object', properties: {} },
        execute: async () => ({ content: [{ type: 'text', text: 'ok' }], isError: false }),
      };

      const unregister = registerWebMcpTool(tool);

      expect(nativeRegisterTool).toHaveBeenCalledTimes(1);
      const [calledTool, calledOptions] = nativeRegisterTool.mock.calls[0] as [
        unknown,
        { signal: AbortSignal },
      ];
      expect(calledTool).toBe(tool);
      expect(calledOptions.signal).toBeInstanceOf(AbortSignal);
      expect(calledOptions.signal.aborted).toBe(false);

      unregister();
      expect(calledOptions.signal.aborted).toBe(true);
    } finally {
      Object.defineProperty(globalThis, 'window', {
        value: originalWindow,
        configurable: true,
        writable: true,
      });
      Object.defineProperty(globalThis, 'navigator', {
        value: originalNavigator,
        configurable: true,
        writable: true,
      });
    }
  });

  it('aborts a prior registration before re-registering the same tool name (React StrictMode safety on Chrome native WebMCP)', () => {
    const originalWindow = globalThis.window;
    const originalNavigator = globalThis.navigator;
    if (globalThis.window) {
      delete (globalThis.window as unknown as { __olonWebMcpControllers__?: unknown }).__olonWebMcpControllers__;
    }

    const registeredNames = new Set<string>();
    const nativeRegisterTool = vi.fn(
      (t: { name: string }, options?: { signal?: AbortSignal }) => {
        if (registeredNames.has(t.name)) {
          throw new Error('InvalidStateError: Duplicate tool name');
        }
        registeredNames.add(t.name);
        options?.signal?.addEventListener('abort', () => {
          registeredNames.delete(t.name);
        });
      }
    );

    Object.defineProperty(globalThis, 'window', {
      value: {} as Window,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(globalThis, 'navigator', {
      value: { modelContext: { registerTool: nativeRegisterTool } } as Navigator,
      configurable: true,
      writable: true,
    });

    try {
      const tool = {
        name: 'update-section',
        description: 'Update section',
        inputSchema: { type: 'object', properties: {} },
        execute: async () => ({ content: [{ type: 'text', text: 'ok' }], isError: false }),
      };

      expect(() => {
        registerWebMcpTool(tool);
        registerWebMcpTool(tool);
      }).not.toThrow();

      expect(nativeRegisterTool).toHaveBeenCalledTimes(2);
      const firstSignal = (nativeRegisterTool.mock.calls[0][1] as { signal: AbortSignal }).signal;
      const secondSignal = (nativeRegisterTool.mock.calls[1][1] as { signal: AbortSignal }).signal;
      expect(firstSignal.aborted).toBe(true);
      expect(secondSignal.aborted).toBe(false);
      expect(registeredNames.has('update-section')).toBe(true);
    } finally {
      Object.defineProperty(globalThis, 'window', {
        value: originalWindow,
        configurable: true,
        writable: true,
      });
      Object.defineProperty(globalThis, 'navigator', {
        value: originalNavigator,
        configurable: true,
        writable: true,
      });
    }
  });
});

END_OF_FILE_CONTENT
echo "Creating core/src/webmcp/runtime/webmcp-bridge.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/webmcp/runtime/webmcp-bridge.ts"
import type { SelectionPath } from '../../contract/types-engine';

export interface WebMcpMutationArgs {
  slug?: string;
  sectionId: string;
  sectionType?: string;
  scope?: 'global' | 'local';
  data?: Record<string, unknown>;
  itemPath?: SelectionPath;
  fieldKey?: string;
  value?: unknown;
}

type WebMcpTool = {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
  execute: (args: unknown) => Promise<unknown> | unknown;
};

type WebMcpToolInfo = Omit<WebMcpTool, 'execute'>;

type WebMcpRegisterToolOptions = { signal?: AbortSignal };

type ModelContextLike = {
  registerTool?: (tool: WebMcpTool, options?: WebMcpRegisterToolOptions) => void;
  unregisterTool?: (name: string) => void;
  readResource?: (uri: string) => Promise<unknown>;
};

type ModelContextProtocolLike = {
  listTools?: () => WebMcpToolInfo[];
  executeTool?: (toolName: string, inputArgsJson: string) => Promise<string>;
  readResource?: (uri: string) => Promise<string>;
};

type WebMcpWindow = Window & {
  __olonWebMcpTools__?: Map<string, WebMcpTool>;
  __olonWebMcpControllers__?: Map<string, AbortController>;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function cloneJson<T>(value: T): T {
  return value == null ? value : (JSON.parse(JSON.stringify(value)) as T);
}

function getToolRegistry(): Map<string, WebMcpTool> | null {
  if (typeof window === 'undefined') return null;
  const webMcpWindow = window as WebMcpWindow;
  if (!webMcpWindow.__olonWebMcpTools__) {
    webMcpWindow.__olonWebMcpTools__ = new Map<string, WebMcpTool>();
  }
  return webMcpWindow.__olonWebMcpTools__;
}

function getControllerRegistry(): Map<string, AbortController> | null {
  if (typeof window === 'undefined') return null;
  const webMcpWindow = window as WebMcpWindow;
  if (!webMcpWindow.__olonWebMcpControllers__) {
    webMcpWindow.__olonWebMcpControllers__ = new Map<string, AbortController>();
  }
  return webMcpWindow.__olonWebMcpControllers__;
}

export function buildWebMcpToolName(): string {
  return 'update-section';
}

export function buildWebMcpSaveToolName(): string {
  return 'save';
}

export function createWebMcpSaveToolInputSchema(): Record<string, unknown> {
  return {
    type: 'object',
    additionalProperties: false,
    properties: {},
  };
}

export function parseWebMcpMutationArgs(rawArgs: unknown): WebMcpMutationArgs {
  if (!isRecord(rawArgs) || typeof rawArgs.sectionId !== 'string') {
    throw new Error('WebMCP mutation requires a sectionId.');
  }

  const parsedArgs: WebMcpMutationArgs = {
    sectionId: rawArgs.sectionId,
  };

  if (typeof rawArgs.slug === 'string') {
    parsedArgs.slug = rawArgs.slug;
  }

  if (typeof rawArgs.sectionType === 'string') {
    parsedArgs.sectionType = rawArgs.sectionType;
  }

  if (rawArgs.scope === 'global' || rawArgs.scope === 'local') {
    parsedArgs.scope = rawArgs.scope;
  }

  if (isRecord(rawArgs.data)) {
    parsedArgs.data = rawArgs.data;
  }

  if (Array.isArray(rawArgs.itemPath)) {
    parsedArgs.itemPath = rawArgs.itemPath
      .filter((segment): segment is SelectionPath[number] => {
        if (!isRecord(segment) || typeof segment.fieldKey !== 'string') {
          return false;
        }
        return segment.itemId == null || typeof segment.itemId === 'string';
      })
      .map((segment) => ({
        fieldKey: segment.fieldKey,
        ...(typeof segment.itemId === 'string' ? { itemId: segment.itemId } : {}),
      }));
  }

  if (typeof rawArgs.fieldKey === 'string') {
    parsedArgs.fieldKey = rawArgs.fieldKey;
  }

  if ('value' in rawArgs) {
    parsedArgs.value = rawArgs.value;
  }

  return parsedArgs;
}

export type WebMcpSectionCatalogEntry = { id: string; type: string };

export function createWebMcpToolInputSchema(
  catalog?: ReadonlyArray<WebMcpSectionCatalogEntry>
): Record<string, unknown> {
  const ids = catalog ? Array.from(new Set(catalog.map((entry) => entry.id))) : [];
  const types = catalog ? Array.from(new Set(catalog.map((entry) => entry.type))) : [];

  const sectionIdSchema: Record<string, unknown> = {
    type: 'string',
    description:
      'The unique ID of the section to update. Pick one from the enum below; these are the only valid IDs for the current page.',
  };
  if (ids.length > 0) sectionIdSchema.enum = ids;

  const sectionTypeSchema: Record<string, unknown> = {
    type: 'string',
    description:
      'The type of the section being updated (e.g. "olon-hero"). Used to pick the correct validation schema.',
  };
  if (types.length > 0) sectionTypeSchema.enum = types;

  return {
    type: 'object',
    additionalProperties: false,
    properties: {
      slug: { type: 'string' },
      sectionId: sectionIdSchema,
      sectionType: sectionTypeSchema,
      scope: { type: 'string', enum: ['local', 'global'], default: 'local' },
      data: {
        type: 'object',
        description: `Full replacement payload validated against the section's schema.`,
      },
      itemPath: {
        type: 'array',
        description: 'Optional root-to-leaf path for targeted field updates.',
        items: {
          type: 'object',
          additionalProperties: false,
          properties: {
            fieldKey: { type: 'string' },
            itemId: { type: 'string' },
          },
          required: ['fieldKey'],
        },
      },
      fieldKey: {
        type: 'string',
        description: 'Shorthand for a top-level scalar field update when itemPath is omitted.',
      },
      value: {
        description: 'Value written to the targeted field or array item.',
      },
    },
    required: ['sectionId'],
    oneOf: [
      { required: ['data'] },
      { required: ['itemPath', 'value'] },
      { required: ['fieldKey', 'value'] },
    ],
  };
}

export function applyValueAtSelectionPath(
  rootData: Record<string, unknown>,
  selectionPath: SelectionPath,
  value: unknown
): Record<string, unknown> {
  if (selectionPath.length === 0) {
    throw new Error('Selection path is empty.');
  }

  const draft = cloneJson(rootData);
  let cursor: unknown = draft;

  for (let index = 0; index < selectionPath.length; index += 1) {
    const segment = selectionPath[index];
    const isLast = index === selectionPath.length - 1;

    if (!isRecord(cursor)) {
      throw new Error(`Cannot navigate path segment "${segment.fieldKey}" on a non-object value.`);
    }

    if (segment.itemId != null) {
      const arrayValue = cursor[segment.fieldKey];
      if (!Array.isArray(arrayValue)) {
        throw new Error(`Field "${segment.fieldKey}" is not an array.`);
      }
      const itemIndex = arrayValue.findIndex(
        (item) => isRecord(item) && String(item.id ?? '') === String(segment.itemId)
      );
      if (itemIndex === -1) {
        throw new Error(`Array item "${segment.itemId}" not found under "${segment.fieldKey}".`);
      }
      if (isLast) {
        arrayValue[itemIndex] = value;
        return draft;
      }
      cursor = arrayValue[itemIndex];
      continue;
    }

    if (isLast) {
      cursor[segment.fieldKey] = value;
      return draft;
    }

    cursor = cursor[segment.fieldKey];
  }

  return draft;
}

export function resolveWebMcpMutationData(
  currentData: Record<string, unknown>,
  args: WebMcpMutationArgs
): Record<string, unknown> {
  if (args.data && isRecord(args.data)) {
    return cloneJson(args.data);
  }

  if (Array.isArray(args.itemPath) && args.itemPath.length > 0) {
    return applyValueAtSelectionPath(currentData, args.itemPath, args.value);
  }

  if (typeof args.fieldKey === 'string' && args.fieldKey.trim().length > 0) {
    return applyValueAtSelectionPath(currentData, [{ fieldKey: args.fieldKey }], args.value);
  }

  throw new Error('WebMCP mutation requires either "data", "itemPath", or "fieldKey".');
}

async function resolveResource(uri: string): Promise<unknown> {
  const baseUrl = window.location.pathname
    .replace(/\/admin(\/.*)?$/, '')
    .replace(/\/$/, '');

  if (uri === 'olon://pages' || uri === 'olon://pages/') {
    const response = await fetch(`${baseUrl}/mcp-manifest.json`);
    if (!response.ok) {
      throw new Error(`Resource not found: ${uri} (at ${baseUrl}/mcp-manifest.json)`);
    }
    const manifestIndex = await response.json();
    return {
      pages: (manifestIndex.pages || []).map((page: unknown) => {
        const typedPage = page as {
          slug?: unknown;
          title?: unknown;
          contractHref?: unknown;
        };
        return {
          slug: typedPage.slug,
          title: typedPage.title,
          contract: typedPage.contractHref,
        };
      }),
    };
  }

  if (uri.startsWith('olon://pages/')) {
    const slug = uri.replace('olon://pages/', '');
    const response = await fetch(`${baseUrl}/pages/${slug}.json`);
    if (!response.ok) {
      throw new Error(`Resource not found: ${uri} (at ${baseUrl}/pages/${slug}.json)`);
    }
    return await response.json();
  }

  throw new Error(`Unsupported URI scheme: ${uri}`);
}

export function ensureWebMcpRuntime(): void {
  if (typeof window === 'undefined' || typeof navigator === 'undefined') return;

  const currentNavigator = navigator as Navigator & {
    modelContext?: ModelContextLike;
    modelContextProtocol?: ModelContextProtocolLike;
  };

  // If a registerTool already exists — Chrome 146+ native WebMCP, or our polyfill from
  // a previous call — leave it intact so tools flow into the registry the WebMCP Inspector
  // reads via navigator.modelContextTesting.
  if (typeof currentNavigator.modelContext?.registerTool === 'function') return;

  const registry = getToolRegistry();
  if (!registry) return;

  if (!currentNavigator.modelContext) {
    currentNavigator.modelContext = {};
  }

  currentNavigator.modelContext.registerTool = (
    tool: WebMcpTool,
    options?: WebMcpRegisterToolOptions
  ) => {
    registry.set(tool.name, tool);
    options?.signal?.addEventListener('abort', () => {
      if (registry.get(tool.name) === tool) {
        registry.delete(tool.name);
      }
    });
  };

  currentNavigator.modelContext.unregisterTool = (name: string) => {
    registry.delete(name);
  };

  currentNavigator.modelContext.readResource = async (uri: string) => resolveResource(uri);

  currentNavigator.modelContextProtocol = {
    listTools: () =>
      Array.from(registry.values()).map(({ execute: _execute, ...toolInfo }) => toolInfo),
    executeTool: async (toolName: string, inputArgsJson: string) => {
      const tool = registry.get(toolName);
      if (!tool) {
        throw new Error(`WebMCP tool "${toolName}" is not registered.`);
      }

      const parsedArgs = inputArgsJson ? JSON.parse(inputArgsJson) : {};
      const result = await tool.execute(parsedArgs);
      return JSON.stringify(result);
    },
    readResource: async (uri: string) => JSON.stringify(await resolveResource(uri)),
  };
}

export function registerWebMcpTool(tool: WebMcpTool): () => void {
  if (typeof window === 'undefined' || typeof navigator === 'undefined') {
    return () => undefined;
  }

  ensureWebMcpRuntime();

  const currentNavigator = navigator as Navigator & {
    modelContext?: ModelContextLike;
  };

  const modelContext = currentNavigator.modelContext;
  if (typeof modelContext?.registerTool !== 'function') {
    return () => undefined;
  }

  // The native Chrome WebMCP API throws InvalidStateError on duplicate tool names
  // and exposes deregistration only via the AbortSignal option passed to registerTool.
  // We track one controller per tool name so a re-registration (React StrictMode
  // double-invocation, HMR, or effect re-run) cleanly aborts the previous one first.
  const controllers = getControllerRegistry();
  controllers?.get(tool.name)?.abort();

  const controller = new AbortController();
  controllers?.set(tool.name, controller);

  modelContext.registerTool(tool, { signal: controller.signal });

  return () => {
    controller.abort();
    if (controllers?.get(tool.name) === controller) {
      controllers.delete(tool.name);
    }
  };
}

END_OF_FILE_CONTENT
echo "Creating core/src/webmcp/webmcp-contracts.test.ts..."
cat << 'END_OF_FILE_CONTENT' > "core/src/webmcp/webmcp-contracts.test.ts"
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { buildPageContract, buildPageManifest, buildSiteManifest } from './index';

describe('webmcp contracts', () => {
  const HeroSchema = z.object({
    title: z.string().describe('ui:text'),
    ctas: z.array(
      z.object({
        id: z.string().optional(),
        label: z.string(),
        href: z.string(),
      })
    ).optional(),
  });

  const FeatureGridSchema = z.object({
    sectionTitle: z.string(),
  });

  const HeaderSchema = z.object({
    logoText: z.string(),
  });

  const ContactFormSchema = z.object({
    title: z.string(),
    submitLabel: z.string(),
  });

  const ContactFormSubmissionSchema = z.object({
    name: z.string().min(1).describe('Full name'),
    email: z.string().email().describe('Email address'),
    notes: z.string().max(1000).optional().describe('Additional notes'),
  });

  it('builds a page contract with only the schemas used on the page', () => {
    const contract = buildPageContract({
      slug: 'home',
      pageConfig: {
        id: 'home-page',
        slug: 'home',
        meta: {
          title: 'Home',
          description: 'Landing page',
        },
        sections: [{ id: 'hero-main', type: 'hero', data: { title: 'Start' } }],
      },
      schemas: {
        hero: HeroSchema,
        'feature-grid': FeatureGridSchema,
        header: HeaderSchema,
      },
      siteConfig: {
        identity: { title: 'Site' },
        header: { id: 'global-header', type: 'header', data: { logoText: 'Olon' } },
      },
    });

    expect(contract.slug).toBe('home');
    expect(contract.sectionTypes).toEqual(['header', 'hero']);
    expect(Object.keys(contract.sectionSchemas)).toEqual(['header', 'hero']);
    expect(contract.sectionInstances).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: 'global-header', type: 'header', scope: 'global' }),
        expect.objectContaining({ id: 'hero-main', type: 'hero', scope: 'local' }),
      ])
    );
    expect(contract.tools).toEqual([
      expect.objectContaining({
        name: 'update-section',
        inputSchema: expect.objectContaining({
          type: 'object',
          required: ['sectionId'],
        }),
      }),
      expect.objectContaining({
        name: 'save',
        inputSchema: expect.objectContaining({
          type: 'object',
        }),
      }),
    ]);
  });

  it('builds a page-scoped manifest for the active page', () => {
    const manifest = buildPageManifest({
      slug: 'design-system',
      pageConfig: {
        id: 'design-system-page',
        slug: 'design-system',
        meta: { title: 'Design System', description: 'Tokens' },
        sections: [{ id: 'ds-main', type: 'feature-grid', data: { sectionTitle: 'Scale' } }],
      },
      schemas: {
        'feature-grid': FeatureGridSchema,
        header: HeaderSchema,
      },
      siteConfig: {
        identity: { title: 'Site' },
        header: { id: 'global-header', type: 'header', data: { logoText: 'Olon' } },
      },
    });

    expect(manifest.slug).toBe('design-system');
    expect(manifest.contractHref).toBe('/schemas/design-system.schema.json');
    expect(manifest.tools).toEqual([
      expect.objectContaining({ name: 'update-section' }),
      expect.objectContaining({ name: 'save' }),
    ]);
    expect(manifest.transport).toMatchObject({
      kind: 'window-message',
      requestType: 'olonjs:webmcp:tool-call',
      resultType: 'olonjs:webmcp:tool-result',
    });
  });

  it('builds a site manifest index with per-page manifest references', () => {
    const manifest = buildSiteManifest({
      pages: {
        home: {
          id: 'home-page',
          slug: 'home',
          meta: { title: 'Home', description: 'Landing page' },
          sections: [{ id: 'hero-main', type: 'hero', data: { title: 'Start' } }],
        },
        'design-system': {
          id: 'design-system-page',
          slug: 'design-system',
          meta: { title: 'Design System', description: 'Tokens' },
          sections: [{ id: 'ds-main', type: 'feature-grid', data: { sectionTitle: 'Scale' } }],
        },
      },
      schemas: {
        hero: HeroSchema,
        'feature-grid': FeatureGridSchema,
      },
      siteConfig: {
        identity: { title: 'Site' },
      },
    });

    expect(manifest.kind).toBe('olonjs-mcp-manifest-index');
    expect(manifest.pages).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          slug: 'home',
          manifestHref: '/mcp-manifests/home.json',
          contractHref: '/schemas/home.schema.json',
        }),
        expect.objectContaining({
          slug: 'design-system',
          manifestHref: '/mcp-manifests/design-system.json',
          contractHref: '/schemas/design-system.schema.json',
        }),
      ])
    );
    expect(manifest.pages.every((page) => Array.isArray(page.sectionTypes))).toBe(true);
  });

  it('emits sectionSubmissionSchemas for sections on the page that have a registered submission schema', () => {
    const contract = buildPageContract({
      slug: 'contact',
      pageConfig: {
        id: 'contact-page',
        slug: 'contact',
        meta: { title: 'Contact', description: 'Get in touch' },
        sections: [
          {
            id: 'cf-main',
            type: 'contact-form',
            data: { title: 'Say hi', submitLabel: 'Send' },
          },
        ],
      },
      schemas: { 'contact-form': ContactFormSchema },
      submissionSchemas: { 'contact-form': ContactFormSubmissionSchema },
      siteConfig: { identity: { title: 'Site' } },
    });

    expect(contract.sectionSubmissionSchemas).toBeDefined();
    expect(Object.keys(contract.sectionSubmissionSchemas!)).toEqual(['contact-form']);

    const submission = contract.sectionSubmissionSchemas!['contact-form'];
    expect(submission).toMatchObject({
      type: 'object',
      properties: expect.objectContaining({
        name: expect.objectContaining({ type: 'string', description: 'Full name' }),
        email: expect.objectContaining({ type: 'string', description: 'Email address' }),
        notes: expect.objectContaining({ type: 'string', description: 'Additional notes' }),
      }),
    });
    expect(submission.required).toEqual(expect.arrayContaining(['name', 'email']));
    expect((submission.required as string[]) ?? []).not.toContain('notes');
  });

  it('omits sectionSubmissionSchemas entirely when no section on the page has one registered', () => {
    const contract = buildPageContract({
      slug: 'home',
      pageConfig: {
        id: 'home-page',
        slug: 'home',
        meta: { title: 'Home', description: 'Landing page' },
        sections: [{ id: 'hero-main', type: 'hero', data: { title: 'Start' } }],
      },
      schemas: { hero: HeroSchema },
      submissionSchemas: { 'contact-form': ContactFormSubmissionSchema },
      siteConfig: { identity: { title: 'Site' } },
    });

    expect(contract.sectionSubmissionSchemas).toBeUndefined();
  });

  it('keeps UI-config sectionSchemas and submission sectionSubmissionSchemas separate for the same section type', () => {
    const contract = buildPageContract({
      slug: 'contact',
      pageConfig: {
        id: 'contact-page',
        slug: 'contact',
        meta: { title: 'Contact', description: 'Get in touch' },
        sections: [
          {
            id: 'cf-main',
            type: 'contact-form',
            data: { title: 'Say hi', submitLabel: 'Send' },
          },
        ],
      },
      schemas: { 'contact-form': ContactFormSchema },
      submissionSchemas: { 'contact-form': ContactFormSubmissionSchema },
      siteConfig: { identity: { title: 'Site' } },
    });

    expect(Object.keys(contract.sectionSchemas)).toEqual(['contact-form']);
    expect(Object.keys(contract.sectionSubmissionSchemas!)).toEqual(['contact-form']);

    const uiProps = (contract.sectionSchemas['contact-form'] as { properties: Record<string, unknown> }).properties;
    const submitProps = (contract.sectionSubmissionSchemas!['contact-form'] as { properties: Record<string, unknown> }).properties;

    expect(Object.keys(uiProps)).toEqual(['title', 'submitLabel']);
    expect(Object.keys(submitProps)).toEqual(['name', 'email', 'notes']);
  });
});

END_OF_FILE_CONTENT
