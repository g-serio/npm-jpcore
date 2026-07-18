import { renderToString } from 'react-dom/server';
import { StaticRouter } from 'react-router-dom/server';
import { ConfigProvider, PageRenderer, StudioProvider } from '@olonjs/react';
import { buildThemeVariableMap, contract, resolvePageMatchFromRegistry, resolveRuntimeConfig } from '@olonjs/core';
import type { JsonPagesConfig, PageConfig, SiteConfig, ThemeConfig } from '@/types';
import { ThemeProvider } from '@/components/ThemeProvider';
import { ComponentRegistry } from '@/lib/ComponentRegistry';
import { SECTION_SCHEMAS } from '@/lib/schemas';
import { extractLeadingRemoteCssImports } from '@/lib/css/tenantCss';
import { collectionSchemas, collections, menuConfig, pages, refDocuments, siteConfig, themeConfig } from '@/runtime';
import tenantCss from '@/index.css?inline';

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function normalizeSlug(input: string): string {
  return input.trim().toLowerCase().replace(/\\/g, '/').replace(/^\/+|\/+$/g, '');
}

function getSortedSlugs(): string[] {
  return Object.keys(pages).sort((a, b) => a.localeCompare(b));
}

function resolvePage(slug: string): { slug: string; registrySlug: string; page: PageConfig; params: Record<string, string> } {
  const normalized = normalizeSlug(slug);
  const pageMatch = resolvePageMatchFromRegistry(pages, normalized);
  if (pageMatch) {
    return {
      slug: normalized || pageMatch.registrySlug,
      registrySlug: pageMatch.registrySlug,
      page: pageMatch.page,
      params: pageMatch.params,
    };
  }

  const slugs = getSortedSlugs();
  if (slugs.length === 0) {
    throw new Error('[SSG_CONFIG_ERROR] No pages found under src/data/pages');
  }

  const home = slugs.find((item) => item === 'home');
  const fallbackSlug = home ?? slugs[0];
  return { slug: fallbackSlug, registrySlug: fallbackSlug, page: pages[fallbackSlug], params: {} };
}

function buildThemeCssFromSot(theme: ThemeConfig): string {
  const mappings = buildThemeVariableMap(theme);
  const entries = Object.entries(mappings);
  if (entries.length === 0) return '';
  const serialized = entries.map(([name, value]) => `${name}:${value}`).join(';');
  return `:root{${serialized}}`;
}

function resolveTenantId(): string {
  const site: Record<string, unknown> = isRecord(siteConfig) ? siteConfig : {};
  const identityRaw = site['identity'];
  const identity: Record<string, unknown> = isRecord(identityRaw) ? identityRaw : {};
  const titleRaw = typeof identity.title === 'string' ? identity.title : '';
  const title = titleRaw.trim();
  if (title.length > 0) {
    const normalized = title.toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, '');
    if (normalized.length > 0) return normalized;
  }

  const slugs = getSortedSlugs();
  if (slugs.length === 0) {
    throw new Error('[SSG_CONFIG_ERROR] Cannot resolve tenantId without site.identity.title or pages');
  }
  return slugs[0].replace(/\//g, '-');
}

export function render(slug: string): string {
  const resolved = resolvePage(slug);
  const location = resolved.slug === 'home' ? '/' : `/${resolved.slug}`;
  const collectionContext = contract.resolveCollectionContext(resolved.page, resolved.params, collections);
  const resolvedRuntime = resolveRuntimeConfig({
    pages: { [resolved.registrySlug]: resolved.page },
    siteConfig,
    themeConfig,
    menuConfig,
    collections,
    collectionSchemas,
    collectionContext,
    refDocuments,
  });
  const resolvedPage = resolvedRuntime.pages[resolved.registrySlug] ?? resolved.page;

  return renderToString(
    <StaticRouter location={location}>
      <ConfigProvider
        config={{
          registry: ComponentRegistry as JsonPagesConfig['registry'],
          schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
          tenantId: resolveTenantId(),
        }}
      >
        <StudioProvider mode="visitor">
          <ThemeProvider>
            <PageRenderer
              pageConfig={resolvedPage}
              siteConfig={resolvedRuntime.siteConfig}
              menuConfig={resolvedRuntime.menuConfig}
            />
          </ThemeProvider>
        </StudioProvider>
      </ConfigProvider>
    </StaticRouter>
  );
}

export function getCss(): string {
  const themeCss = buildThemeCssFromSot(themeConfig);
  const { rest } = extractLeadingRemoteCssImports(tenantCss);
  if (!themeCss) return rest;
  // rest first: any leftover @import must precede :root (ADR-001)
  return `${rest}\n${themeCss}`;
}

export function getRemoteStylesheets(): string[] {
  return extractLeadingRemoteCssImports(tenantCss).hrefs;
}

export function getPageMeta(slug: string): { title: string; description: string } {
  const resolved = resolvePage(slug);
  const rawMeta = isRecord((resolved.page as unknown as { meta?: unknown }).meta)
    ? ((resolved.page as unknown as { meta?: Record<string, unknown> }).meta as Record<string, unknown>)
    : {};

  const title = typeof rawMeta.title === 'string' ? rawMeta.title : resolved.slug;
  const description = typeof rawMeta.description === 'string' ? rawMeta.description : '';
  return { title, description };
}

export function getWebMcpBuildState(): {
  pages: Record<string, PageConfig>;
  schemas: JsonPagesConfig['schemas'];
  collections: JsonPagesConfig['collections'];
  collectionSchemas: JsonPagesConfig['collectionSchemas'];
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: JsonPagesConfig['menuConfig'];
  refDocuments: JsonPagesConfig['refDocuments'];
} {
  return {
    pages,
    schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
    collections,
    collectionSchemas,
    siteConfig,
    themeConfig,
    menuConfig,
    refDocuments,
  };
}
