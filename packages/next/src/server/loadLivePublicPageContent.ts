import type { MenuConfig, PageConfig, SiteConfig } from '@olonjs/core';

export type LivePublicPageContent = {
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  menuConfig: MenuConfig;
};

type RenderProjectionResponse = {
  ok?: boolean;
  error?: string;
  code?: string;
  route?: {
    path: string;
    template: string;
    params: Record<string, string>;
  };
  context?: {
    siteConfig: SiteConfig;
    menuConfig: MenuConfig;
  };
  page?: PageConfig;
};

/** Map public JSON slug → SPP `render?path=` (bootLive parity). */
export function slugToRenderPath(slug: string): string {
  const normalized =
    slug
      .trim()
      .replace(/^\/+/, '')
      .replace(/\.json$/i, '')
      .replace(/\/+$/, '') || 'home';
  return normalized === 'home' ? '/' : `/${normalized}`;
}

function resolveRegistrySlug(page: PageConfig, routeTemplate?: string): string {
  if (routeTemplate?.trim()) return routeTemplate.trim();
  const slug = typeof page.slug === 'string' ? page.slug.trim() : '';
  if (slug.includes('[')) return slug;
  if (slug) return slug;
  return 'home';
}

export type LoadLivePublicPageContentInput = {
  slug: string;
  apiBases: string[];
  apiKey: string;
  fetchImpl?: typeof fetch;
  signal?: AbortSignal;
};

/**
 * Live boot parity — single-page SPP `GET {apiBase}/render?path=…`.
 */
export async function loadLivePublicPageContent(
  input: LoadLivePublicPageContentInput,
): Promise<LivePublicPageContent> {
  const fetchImpl = input.fetchImpl ?? fetch;
  const path = slugToRenderPath(input.slug);
  const query = new URLSearchParams({ path });
  let lastError = 'Live render unavailable';

  for (const apiBase of input.apiBases) {
    const href = `${apiBase.replace(/\/+$/, '')}/render?${query.toString()}`;
    const res = await fetchImpl(href, {
      method: 'GET',
      cache: 'no-store',
      headers: { Authorization: `Bearer ${input.apiKey}` },
      signal: input.signal,
    });

    const contentType = (res.headers.get('content-type') || '').toLowerCase();
    if (!contentType.includes('application/json')) {
      lastError = `Live render unavailable: non-JSON from ${apiBase}`;
      continue;
    }

    const parsed = (await res.json().catch(() => ({}))) as RenderProjectionResponse;
    if (!res.ok || !parsed.ok || !parsed.page || !parsed.context?.siteConfig) {
      const detail =
        parsed.error || parsed.code || `HTTP_${res.status}`;
      lastError = `Live render unavailable: ${detail}`;
      continue;
    }

    const registrySlug = resolveRegistrySlug(parsed.page, parsed.route?.template);
    return {
      pages: { [registrySlug]: parsed.page },
      siteConfig: parsed.context.siteConfig,
      menuConfig: parsed.context.menuConfig ?? ({} as MenuConfig),
    };
  }

  throw new Error(lastError);
}
