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
