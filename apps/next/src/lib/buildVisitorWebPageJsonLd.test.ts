import { describe, expect, it } from 'vitest';
import { buildVisitorWebPageJsonLd } from './buildVisitorWebPageJsonLd';

describe('buildVisitorWebPageJsonLd', () => {
  it('builds Schema.org WebPage for home at /', () => {
    expect(
      buildVisitorWebPageJsonLd({
        title: 'Home',
        description: 'Welcome',
        slug: 'home',
      }),
    ).toEqual({
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: 'Home',
      description: 'Welcome',
      url: '/',
    });
  });

  it('builds Schema.org WebPage for nested slug paths', () => {
    expect(
      buildVisitorWebPageJsonLd({
        title: 'Dune',
        description: 'Book',
        slug: 'libri/dune',
      }),
    ).toEqual({
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: 'Dune',
      description: 'Book',
      url: '/libri/dune',
    });
  });
});
