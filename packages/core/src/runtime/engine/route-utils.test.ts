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
