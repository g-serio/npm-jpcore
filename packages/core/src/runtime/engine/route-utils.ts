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
