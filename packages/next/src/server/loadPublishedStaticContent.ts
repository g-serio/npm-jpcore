import { withBasePath, type PageConfig, type SiteConfig } from '@olonjs/core';

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function asString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim() ? value : fallback;
}

/** Alpha `normalizeRouteSlug` / `normalizeSlugForCache` parity. */
export function normalizePublishedSlug(value: string): string {
  return (
    value
      .toLowerCase()
      .replace(/[^a-z0-9/_[\]-]/g, '-')
      .replace(/^\/+|\/+$/g, '') || 'home'
  );
}

function coercePageConfig(slug: string, value: unknown): PageConfig | null {
  let input = value;
  if (typeof input === 'string') {
    try {
      input = JSON.parse(input) as unknown;
    } catch {
      return null;
    }
  }
  if (!isObjectRecord(input) || !Array.isArray(input.sections)) return null;
  const inputMeta = isObjectRecord(input.meta) ? input.meta : {};
  const normalizedSlug = asString(input.slug, slug);
  return {
    id: asString(input.id, `${normalizedSlug}-page`),
    slug: normalizedSlug,
    meta: {
      title: asString(inputMeta.title, normalizedSlug),
      description: asString(inputMeta.description, ''),
    },
    sections: input.sections as PageConfig['sections'],
    ...(isObjectRecord(input.collection)
      ? { collection: input.collection as unknown as PageConfig['collection'] }
      : {}),
    ...(typeof input['global-header'] === 'boolean'
      ? { 'global-header': input['global-header'] }
      : {}),
  };
}

function coerceSiteConfig(value: unknown): SiteConfig | null {
  let input = value;
  if (typeof input === 'string') {
    try {
      input = JSON.parse(input) as unknown;
    } catch {
      return null;
    }
  }
  if (!isObjectRecord(input) || !isObjectRecord(input.identity)) return null;
  return input as unknown as SiteConfig;
}

function normalizePageRegistry(value: unknown): Record<string, PageConfig> {
  if (!isObjectRecord(value)) return {};
  const normalized: Record<string, PageConfig> = {};
  for (const [registrySlug, rawPageValue] of Object.entries(value)) {
    const canonicalSlug = normalizePublishedSlug(registrySlug);
    const direct = coercePageConfig(canonicalSlug, rawPageValue);
    if (direct) {
      normalized[canonicalSlug] = { ...direct, slug: canonicalSlug };
    }
  }
  return normalized;
}

function joinBaseUrl(baseUrl: string, pathname: string): string {
  const base = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
  const path = withBasePath(pathname, '/');
  return `${base}${path.startsWith('/') ? path : `/${path}`}`;
}

export type LoadPublishedStaticContentInput = {
  knownSlugs: string[];
  /** Absolute origin + optional base path, e.g. `https://cdn.example/` or `http://localhost:3000/`. */
  baseUrl: string;
  fetchImpl?: typeof fetch;
};

/**
 * Save2Repo static boot parity — fetch published `config/site.json` + `pages/{slug}.json`.
 */
export async function loadPublishedStaticContent(
  input: LoadPublishedStaticContentInput,
): Promise<{ pages: Record<string, PageConfig>; siteConfig: SiteConfig }> {
  const fetchImpl = input.fetchImpl ?? fetch;
  const siteHref = joinBaseUrl(input.baseUrl, '/config/site.json');
  const siteResponse = await fetchImpl(siteHref, { cache: 'no-store' });
  if (!siteResponse.ok) {
    throw new Error(`Static site config unavailable: ${siteResponse.status}`);
  }

  const sitePayload = (await siteResponse.json().catch(() => null)) as unknown;
  const nextSite = coerceSiteConfig(sitePayload);
  if (!nextSite) {
    throw new Error('Static site config is invalid.');
  }

  const pageEntries = await Promise.all(
    input.knownSlugs.map(async (slug) => {
      const href = joinBaseUrl(input.baseUrl, `/pages/${normalizePublishedSlug(slug)}.json`);
      const response = await fetchImpl(href, { cache: 'no-store' });
      if (!response.ok) {
        throw new Error(`Static page unavailable for slug "${slug}": ${response.status}`);
      }
      return [slug, (await response.json().catch(() => null)) as unknown] as const;
    }),
  );

  const nextPages = normalizePageRegistry(Object.fromEntries(pageEntries));
  if (Object.keys(nextPages).length === 0) {
    throw new Error('Static published pages are empty.');
  }

  return { pages: nextPages, siteConfig: nextSite };
}
