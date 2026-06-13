import { describe, expect, it } from 'vitest';
import {
  applyCollectionRefBindingsToDraft,
  applyMenuRefBindingsToDraft,
  applySiteMenuRefBindingsToDraft,
  getMenuRefBindings,
  resolveCollectionContext,
  resolveSectionMenuItems,
  resolveRuntimeConfig,
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
});
