import { resolvePageMatchFromRegistry, type PageConfig } from '@olonjs/core';

export type VisitorLoadInput = {
  pages: Record<string, PageConfig>;
  slug: string;
};

export type VisitorLoadResult =
  | { kind: 'empty' }
  | { kind: 'not-found' }
  | {
      kind: 'page';
      slug: string;
      registrySlug: string;
      page: PageConfig;
      params: Record<string, string>;
    };

/**
 * Visitor page loader for RSC hosts (ADR-0017).
 * Empty registry → empty tenant; unknown slug → not-found (no home fallback).
 */
export function loadVisitorPage(input: VisitorLoadInput): VisitorLoadResult {
  const pages = input.pages ?? {};
  if (Object.keys(pages).length === 0) return { kind: 'empty' };

  const match = resolvePageMatchFromRegistry(pages, input.slug || 'home');
  if (!match) return { kind: 'not-found' };

  return {
    kind: 'page',
    slug: match.requestedSlug,
    registrySlug: match.registrySlug,
    page: match.page,
    params: match.params,
  };
}
