/**
 * Next bake — agentic WebMCP artifacts only (no Vite / no HTML SSG).
 * Invoked by scripts/bake.mjs via tsx.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  resolvePageMatchFromRegistry,
  resolvePublicPageDocument,
  webmcp,
} from '@olonjs/core';
import { CollectionRegistry } from '../src/lib/CollectionRegistry';
import { SECTION_SCHEMAS, SECTION_SUBMISSION_SCHEMAS } from '../src/lib/schemas';
import { getFileCollections } from '../src/lib/loaders/getFileCollections';
import { getFilePages } from '../src/lib/loaders/getFilePages';
import { getFileSiteBundle } from '../src/lib/loaders/getFileSiteConfig';

const {
  buildPageContract,
  buildPageManifest,
  buildPageManifestHref,
  buildSiteManifest,
  buildLlmsTxt,
} = webmcp;

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const publicDir = path.join(root, 'public');
const pagesDir = path.join(root, 'src', 'data', 'pages');
const collectionsDir = path.join(root, 'src', 'data', 'collections');

async function writePublic(relativePath: string, content: string): Promise<void> {
  const target = path.join(publicDir, relativePath);
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, content, 'utf-8');
}

async function writePublicJson(relativePath: string, value: unknown): Promise<void> {
  await writePublic(relativePath, `${JSON.stringify(value, null, 2)}\n`);
}

async function readJsonFile(filePath: string): Promise<unknown> {
  return JSON.parse(await fs.readFile(filePath, 'utf-8'));
}

async function listJsonFilesRecursive(dir: string): Promise<string[]> {
  const items = await fs.readdir(dir, { withFileTypes: true });
  const files: string[] = [];
  for (const item of items) {
    const fullPath = path.join(dir, item.name);
    if (item.isDirectory()) {
      files.push(...(await listJsonFilesRecursive(fullPath)));
      continue;
    }
    if (item.isFile() && item.name.toLowerCase().endsWith('.json')) files.push(fullPath);
  }
  return files;
}

function toCanonicalSlug(relativeJsonPath: string): string {
  const slug = relativeJsonPath.replace(/\\/g, '/').replace(/\.json$/i, '').replace(/^\/+|\/+$/g, '');
  if (!slug) throw new Error('[bake] Invalid page slug: empty path segment');
  return slug;
}

async function expandCollectionTarget(slug: string, pageFilePath: string): Promise<string[]> {
  let pageConfig: Record<string, unknown>;
  try {
    pageConfig = (await readJsonFile(pageFilePath)) as Record<string, unknown>;
  } catch {
    return [slug];
  }

  const binding = pageConfig?.collection as { source?: string; paramKey?: string } | undefined;
  if (!binding || typeof binding.source !== 'string' || typeof binding.paramKey !== 'string') {
    return [slug];
  }

  const token = `[${binding.paramKey}]`;
  const authoredSlug =
    typeof pageConfig.slug === 'string'
      ? String(pageConfig.slug).replace(/\\/g, '/').replace(/^\/+|\/+$/g, '')
      : '';
  const routePattern =
    authoredSlug.includes(token) ? authoredSlug : slug.includes(token) ? slug : '';
  if (!routePattern) return [slug];

  const collectionPath = path.resolve(collectionsDir, binding.source, `${binding.source}.json`);
  let collection: Record<string, unknown>;
  try {
    collection = (await readJsonFile(collectionPath)) as Record<string, unknown>;
  } catch {
    return [slug];
  }

  if (!collection || typeof collection !== 'object' || Array.isArray(collection)) return [slug];
  const itemIds = Object.keys(collection).sort((a, b) => a.localeCompare(b));
  return itemIds.length > 0
    ? itemIds.map((itemId) => routePattern.replace(token, itemId))
    : [slug];
}

async function discoverSlugs(): Promise<string[]> {
  let files: string[] = [];
  try {
    files = await listJsonFilesRecursive(pagesDir);
  } catch {
    files = [];
  }

  const rawSlugs = (
    await Promise.all(
      files.map(async (fullPath) => {
        const slug = toCanonicalSlug(path.relative(pagesDir, fullPath));
        return expandCollectionTarget(slug, fullPath);
      }),
    )
  ).flat();

  return Array.from(new Set(rawSlugs)).sort((a, b) => a.localeCompare(b));
}

async function main(): Promise<void> {
  console.log('\n[bake] Next agentic artifacts (no Vite SSG)...');

  const pages = getFilePages(root);
  const collections = getFileCollections(root);
  const { siteConfig, themeConfig, menuConfig } = getFileSiteBundle(root);
  const collectionSchemas = CollectionRegistry as unknown as Record<string, unknown>;
  const schemas = SECTION_SCHEMAS as unknown as Record<string, unknown>;
  const submissionSchemas = SECTION_SUBMISSION_SCHEMAS as unknown as Record<string, unknown>;
  const refDocuments = {
    'menu.json': menuConfig,
    'config/menu.json': menuConfig,
    'src/data/config/menu.json': menuConfig,
  };

  const slugs = await discoverSlugs();
  if (slugs.length === 0) {
    throw new Error('[bake] No pages discovered under src/data/pages');
  }
  console.log(`[bake] Targets: ${slugs.join(', ')}`);

  const pagesForManifest: Record<string, (typeof pages)[string]> = { ...pages };

  for (const slug of slugs) {
    const pageConfig = resolvePageMatchFromRegistry(pages, slug)?.page;
    if (!pageConfig) continue;

    const resolvedPageDocument = resolvePublicPageDocument({
      slug,
      pages,
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      collectionSchemas: collectionSchemas as never,
      refDocuments,
    });
    const publicPageConfig = resolvedPageDocument?.page ?? pageConfig;
    pagesForManifest[slug] = publicPageConfig;

    await writePublicJson(`pages/${slug}.json`, publicPageConfig);

    const contract = buildPageContract({
      slug,
      pageConfig: publicPageConfig,
      schemas: schemas as never,
      submissionSchemas: submissionSchemas as never,
      siteConfig,
    });
    await writePublicJson(`schemas/${slug}.schema.json`, contract);

    const pageManifest = buildPageManifest({
      slug,
      pageConfig: publicPageConfig,
      schemas: schemas as never,
      siteConfig,
    });
    await writePublicJson(buildPageManifestHref(slug).replace(/^\//, ''), pageManifest);
  }

  await writePublicJson('config/site.json', siteConfig);

  const mcpManifest = buildSiteManifest({
    pages: pagesForManifest,
    schemas: schemas as never,
    siteConfig,
  });
  await writePublicJson('mcp-manifest.json', mcpManifest);

  const llmsTxtContent = buildLlmsTxt({
    pages: pagesForManifest,
    schemas: schemas as never,
    siteConfig,
  });
  await writePublic('llms.txt', `${llmsTxtContent}\n`);

  console.log('[bake] Wrote public/mcp-manifest.json, mcp-manifests/, schemas/, pages/, llms.txt, config/site.json');
  console.log('[bake] OK\n');
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exit(1);
});
