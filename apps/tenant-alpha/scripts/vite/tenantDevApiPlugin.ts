/**
 * Dev-only Vite middleware: local CMS APIs + WebMCP / page JSON parity.
 * Not used in production builds (configureServer only).
 */
import type { Plugin, ViteDevServer } from 'vite';
import path from 'path';
import fs from 'fs';
import type { IncomingMessage, ServerResponse } from 'http';

const IMAGE_EXT = new Set(['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.avif']);
const IMAGE_MIMES = new Set([
  'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml', 'image/avif',
]);
const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5MB

export type TenantDevApiPluginOptions = {
  rootDir: string;
};

function safeFilename(original: string, mimeType: string | undefined) {
  const base = (original.replace(/\.[^.]+$/, '').replace(/[^a-zA-Z0-9-_]/g, '_').slice(0, 128)) || 'image';
  const ext = original.includes('.')
    ? path.extname(original).toLowerCase()
    : (mimeType?.startsWith('image/')
      ? `.${(mimeType.split('/')[1] || 'png').replace('jpeg', 'jpg')}`
      : '.png');
  return `${Date.now()}-${base}${IMAGE_EXT.has(ext) ? ext : '.png'}`;
}

function listImagesInDir(dir: string, urlPrefix: string) {
  const list: Array<{ id: string; url: string; alt: string; tags: string[] }> = [];
  if (!fs.existsSync(dir)) return list;
  for (const name of fs.readdirSync(dir)) {
    if (IMAGE_EXT.has(path.extname(name).toLowerCase())) {
      list.push({ id: name, url: `${urlPrefix}/${name}`, alt: name, tags: [] });
    }
  }
  return list;
}

function sendJson(res: ServerResponse, status: number, body: unknown) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

function safeDataSlugPath(rootDir: string, rawSlug: string, fallback: string) {
  const slug = String(rawSlug || fallback)
    .replace(/\\/g, '/')
    .replace(/^\/+|\/+$/g, '');
  const segments = slug
    .split('/')
    .map((segment) => segment.replace(/[^a-zA-Z0-9_[\]-]/g, '_'))
    .filter(Boolean);
  const candidate = path.resolve(rootDir, `${segments.join(path.sep) || fallback}.json`);
  const isInsideRoot = candidate.startsWith(`${rootDir}${path.sep}`) || candidate === rootDir;
  if (!isInsideRoot) throw new Error('Invalid data path');
  return candidate;
}

function isTenantPageJsonRequest(req: IncomingMessage, pathname: string) {
  if (req.method !== 'GET' || !pathname.endsWith('.json')) return false;
  const viteOrStaticPrefixes = ['/api/', '/assets/', '/src/', '/node_modules/', '/public/', '/@'];
  return !viteOrStaticPrefixes.some((prefix) => pathname.startsWith(prefix));
}

function normalizeManifestSlug(raw: string) {
  return decodeURIComponent(raw || '')
    .replace(/^\/+|\/+$/g, '')
    .replace(/\\/g, '/')
    .replace(/(\.schema)?\.json$/i, '');
}

function applyDevSliceFilters(
  page: { sections?: Array<{ data?: Record<string, unknown> }> },
  authored: { sections?: Array<{ data?: Record<string, unknown> }> } | undefined,
  params: Record<string, string>,
) {
  if (!authored?.sections || !page?.sections) return page;
  const at = (o: unknown, p: string) =>
    p.split('.').reduce<unknown>((a, k) => (a as Record<string, unknown> | undefined)?.[k], o);
  return {
    ...page,
    sections: page.sections.map((section, i) => {
      const src = authored.sections?.[i]?.data as Record<string, { $sliceFilter?: Record<string, unknown> }> | undefined;
      if (!src || !section.data) return section;
      const data = { ...section.data };
      for (const [key, ref] of Object.entries(src)) {
        if (!ref?.$sliceFilter || typeof data[key] !== 'object' || data[key] === null) continue;
        const filter = Object.fromEntries(
          Object.entries(ref.$sliceFilter)
            .map(([k, v]) => [
              k,
              typeof v === 'string' ? v : params[(v as { $routeParam?: string })?.$routeParam ?? ''] ?? '',
            ])
            .filter(([, v]) => v),
        );
        data[key] = Object.fromEntries(
          Object.entries(data[key] as Record<string, unknown>).filter(([, item]) =>
            Object.entries(filter).every(([p, v]) => String(at(item, p) ?? '') === v),
          ),
        );
      }
      return { ...section, data };
    }),
  };
}

async function loadWebMcpBuilders() {
  const moduleUrl = import.meta.resolve('@olonjs/core');
  return import(moduleUrl);
}

export function tenantDevApiPlugin(options: TenantDevApiPluginOptions): Plugin {
  const { rootDir } = options;
  const ASSETS_IMAGES_DIR = path.resolve(rootDir, 'public', 'assets', 'images');
  const DATA_CONFIG_DIR = path.resolve(rootDir, 'src', 'data', 'config');
  const DATA_PAGES_DIR = path.resolve(rootDir, 'src', 'data', 'pages');
  const DATA_COLLECTIONS_DIR = path.resolve(rootDir, 'src', 'data', 'collections');

  return {
    name: 'upload-asset-api',
    configureServer(server: ViteDevServer) {
      server.middlewares.use((req, res, next) => {
        const pathname = (req.url || '').split('?')[0];
        const isPageJsonRequest = isTenantPageJsonRequest(req, pathname);

        const handleManifestRequest = async () => {
          const core = await loadWebMcpBuilders();
          const { buildPageContract, buildPageManifest, buildSiteManifest, buildLlmsTxt } = core.webmcp;
          const runtime = await server.ssrLoadModule('/src/runtime.ts');
          const buildState = runtime.getWebMcpBuildState();

          if (req.method === 'GET' && pathname === '/llms.txt') {
            res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
            res.end(buildLlmsTxt({
              pages: buildState.pages,
              schemas: buildState.schemas,
              siteConfig: buildState.siteConfig,
            }));
            return true;
          }

          if (req.method === 'GET' && pathname === '/mcp-manifest.json') {
            sendJson(res, 200, buildSiteManifest({
              pages: buildState.pages,
              schemas: buildState.schemas,
              submissionSchemas: buildState.submissionSchemas,
              siteConfig: buildState.siteConfig,
            }));
            return true;
          }

          const pageManifestMatch = pathname.match(/^\/mcp-manifests\/(.+)\.json$/i);
          if (pageManifestMatch && req.method === 'GET') {
            const slug = normalizeManifestSlug(pageManifestMatch[1]);
            const resolved = core.resolvePublicPageDocument({
              slug,
              pages: buildState.pages,
              siteConfig: buildState.siteConfig,
              themeConfig: buildState.themeConfig,
              menuConfig: buildState.menuConfig,
              collections: buildState.collections,
              collectionSchemas: buildState.collectionSchemas,
              refDocuments: buildState.refDocuments,
            });
            if (!resolved) {
              sendJson(res, 404, { error: 'Page manifest not found' });
              return true;
            }

            sendJson(res, 200, buildPageManifest({
              slug,
              pageConfig: resolved.page,
              schemas: buildState.schemas,
              submissionSchemas: buildState.submissionSchemas,
              siteConfig: buildState.siteConfig,
            }));
            return true;
          }

          const schemaMatch = pathname.match(/^\/schemas\/(.+)\.schema\.json$/i);
          if (schemaMatch && req.method === 'GET') {
            const slug = normalizeManifestSlug(schemaMatch[1]);
            const resolved = core.resolvePublicPageDocument({
              slug,
              pages: buildState.pages,
              siteConfig: buildState.siteConfig,
              themeConfig: buildState.themeConfig,
              menuConfig: buildState.menuConfig,
              collections: buildState.collections,
              collectionSchemas: buildState.collectionSchemas,
              refDocuments: buildState.refDocuments,
            });
            if (!resolved) {
              sendJson(res, 404, { error: 'Schema contract not found' });
              return true;
            }

            sendJson(res, 200, buildPageContract({
              slug,
              pageConfig: resolved.page,
              schemas: buildState.schemas,
              submissionSchemas: buildState.submissionSchemas,
              siteConfig: buildState.siteConfig,
            }));
            return true;
          }
          return false;
        };

        if (
          req.method === 'GET' &&
          (
            pathname === '/mcp-manifest.json'
            || pathname === '/llms.txt'
            || /^\/mcp-manifests\/.+\.json$/i.test(pathname)
            || /^\/schemas\/.+\.schema\.json$/i.test(pathname)
          )
        ) {
          void handleManifestRequest()
            .then((handled) => {
              if (!handled) {
                // Avoid Vite SPA fallback to index.html for known manifest URLs.
                sendJson(res, 404, { error: 'Manifest or schema not found' });
              }
            })
            .catch((error) => {
              sendJson(res, 500, { error: error?.message || 'Manifest generation failed' });
            });
          return;
        }

        if (isPageJsonRequest) {
          const normalizedPath = decodeURIComponent(pathname).replace(/\\/g, '/');
          // Optional "/pages/" prefix mirrors production public paths.
          const slug = normalizedPath
            .replace(/^\/+/, '')
            .replace(/^pages\//i, '')
            .replace(/\.json$/i, '')
            .replace(/^\/+|\/+$/g, '');
          if (!slug) {
            sendJson(res, 404, { error: 'Page JSON not found' });
            return;
          }
          void (async () => {
            const core = await loadWebMcpBuilders();
            const runtime = await server.ssrLoadModule('/src/runtime.ts');
            const buildState = runtime.getWebMcpBuildState();
            const resolved = core.resolvePublicPageDocument({
              slug,
              pages: buildState.pages,
              siteConfig: buildState.siteConfig,
              themeConfig: buildState.themeConfig,
              menuConfig: buildState.menuConfig,
              collections: buildState.collections,
              collectionSchemas: buildState.collectionSchemas,
              refDocuments: buildState.refDocuments,
            });
            if (!resolved) {
              sendJson(res, 404, { error: 'Page JSON not found' });
              return;
            }
            const authored = buildState.pages[resolved.pageMatch.registrySlug];
            sendJson(res, 200, applyDevSliceFilters(resolved.page, authored, resolved.pageMatch.params ?? {}));
          })().catch((error) => {
            sendJson(res, 500, { error: error?.message || 'Page JSON resolution failed' });
          });
          return;
        }
        if (req.method === 'GET' && req.url === '/api/list-assets') {
          try {
            sendJson(res, 200, listImagesInDir(ASSETS_IMAGES_DIR, '/assets/images'));
          } catch (e) {
            sendJson(res, 500, { error: (e as Error)?.message || 'List failed' });
          }
          return;
        }
        if (req.method === 'POST' && pathname === '/api/save-to-file') {
          const chunks: Buffer[] = [];
          req.on('data', (chunk) => chunks.push(chunk));
          req.on('end', () => {
            try {
              const raw = Buffer.concat(chunks).toString('utf8');
              if (!raw.trim()) {
                sendJson(res, 400, { error: 'Empty body' });
                return;
              }
              const body = JSON.parse(raw);
              const { projectState, slug } = body;
              if (!projectState || typeof slug !== 'string') {
                sendJson(res, 400, { error: 'Missing projectState or slug' });
                return;
              }
              if (!fs.existsSync(DATA_CONFIG_DIR)) fs.mkdirSync(DATA_CONFIG_DIR, { recursive: true });
              if (!fs.existsSync(DATA_PAGES_DIR)) fs.mkdirSync(DATA_PAGES_DIR, { recursive: true });
              if (!fs.existsSync(DATA_COLLECTIONS_DIR)) fs.mkdirSync(DATA_COLLECTIONS_DIR, { recursive: true });
              if (projectState.site != null) {
                fs.writeFileSync(path.join(DATA_CONFIG_DIR, 'site.json'), JSON.stringify(projectState.site, null, 2), 'utf8');
              }
              if (projectState.menu != null) {
                fs.writeFileSync(path.join(DATA_CONFIG_DIR, 'menu.json'), JSON.stringify(projectState.menu, null, 2), 'utf8');
              }
              if (projectState.theme != null) {
                fs.writeFileSync(path.join(DATA_CONFIG_DIR, 'theme.json'), JSON.stringify(projectState.theme, null, 2), 'utf8');
              }
              if (projectState.page != null) {
                const pagePath = safeDataSlugPath(DATA_PAGES_DIR, slug, 'page');
                fs.mkdirSync(path.dirname(pagePath), { recursive: true });
                fs.writeFileSync(pagePath, JSON.stringify(projectState.page, null, 2), 'utf8');
              }
              if (projectState.collections && typeof projectState.collections === 'object') {
                for (const [source, collection] of Object.entries(projectState.collections)) {
                  const sourceSlug = String(source).replace(/[^a-zA-Z0-9-_]/g, '_');
                  if (!sourceSlug) continue;
                  const collectionDir = path.join(DATA_COLLECTIONS_DIR, sourceSlug);
                  fs.mkdirSync(collectionDir, { recursive: true });
                  fs.writeFileSync(path.join(collectionDir, `${sourceSlug}.json`), JSON.stringify(collection, null, 2), 'utf8');
                }
              }
              sendJson(res, 200, { ok: true });
            } catch (e) {
              sendJson(res, 500, { error: (e as Error)?.message || 'Save to file failed' });
            }
          });
          req.on('error', () => sendJson(res, 500, { error: 'Request error' }));
          return;
        }
        if (req.method !== 'POST' || pathname !== '/api/upload-asset') return next();
        const chunks: Buffer[] = [];
        req.on('data', (chunk) => chunks.push(chunk));
        req.on('end', () => {
          try {
            const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
            const { filename, mimeType, data } = body;
            if (!filename || typeof data !== 'string') {
              sendJson(res, 400, { error: 'Missing filename or data' });
              return;
            }
            const buf = Buffer.from(data, 'base64');
            if (buf.length > MAX_FILE_SIZE_BYTES) {
              sendJson(res, 413, { error: 'File too large. Max 5MB.' });
              return;
            }
            if (mimeType && !IMAGE_MIMES.has(mimeType)) {
              sendJson(res, 400, { error: 'Invalid file type' });
              return;
            }
            const name = safeFilename(filename, mimeType);
            if (!fs.existsSync(ASSETS_IMAGES_DIR)) fs.mkdirSync(ASSETS_IMAGES_DIR, { recursive: true });
            fs.writeFileSync(path.join(ASSETS_IMAGES_DIR, name), buf);
            sendJson(res, 200, { url: `/assets/images/${name}` });
          } catch (e) {
            sendJson(res, 500, { error: (e as Error)?.message || 'Upload failed' });
          }
        });
        req.on('error', () => sendJson(res, 500, { error: 'Request error' }));
      });
    },
  };
}
