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
