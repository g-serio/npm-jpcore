/**
 * Schema.org WebPage JSON-LD for Next visitor RSC (parity with tenant-alpha bake HTML injection).
 */
export type VisitorWebPageJsonLd = {
  '@context': 'https://schema.org';
  '@type': 'WebPage';
  name: string;
  description: string;
  url: string;
};

export function buildVisitorWebPageJsonLd(input: {
  title: string;
  description?: string;
  slug: string;
}): VisitorWebPageJsonLd {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: input.title,
    description: input.description ?? '',
    url: input.slug === 'home' ? '/' : `/${input.slug}`,
  };
}
