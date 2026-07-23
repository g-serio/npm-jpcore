import fs from 'node:fs';
import path from 'node:path';
import { safeDataSlugPath } from './fsPaths';

const IMAGE_EXT = new Set(['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.avif']);
const IMAGE_MIMES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/svg+xml',
  'image/avif',
]);
export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

export type LocalDataRoots = {
  configDir: string;
  pagesDir: string;
  collectionsDir: string;
  assetsImagesDir: string;
};

export function resolveLocalDataRoots(appRoot: string): LocalDataRoots {
  return {
    configDir: path.resolve(appRoot, 'src', 'data', 'config'),
    pagesDir: path.resolve(appRoot, 'src', 'data', 'pages'),
    collectionsDir: path.resolve(appRoot, 'src', 'data', 'collections'),
    assetsImagesDir: path.resolve(appRoot, 'public', 'assets', 'images'),
  };
}

export type ProjectStateLike = {
  site?: unknown;
  menu?: unknown;
  theme?: unknown;
  page?: unknown;
  collections?: Record<string, unknown>;
};

export function saveProjectStateToDisk(
  roots: LocalDataRoots,
  projectState: ProjectStateLike,
  slug: string,
): void {
  for (const dir of [roots.configDir, roots.pagesDir, roots.collectionsDir]) {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  }
  if (projectState.site != null) {
    fs.writeFileSync(path.join(roots.configDir, 'site.json'), JSON.stringify(projectState.site, null, 2), 'utf8');
  }
  if (projectState.menu != null) {
    fs.writeFileSync(path.join(roots.configDir, 'menu.json'), JSON.stringify(projectState.menu, null, 2), 'utf8');
  }
  if (projectState.theme != null) {
    fs.writeFileSync(path.join(roots.configDir, 'theme.json'), JSON.stringify(projectState.theme, null, 2), 'utf8');
  }
  if (projectState.page != null) {
    const pagePath = safeDataSlugPath(roots.pagesDir, slug, 'page');
    fs.mkdirSync(path.dirname(pagePath), { recursive: true });
    fs.writeFileSync(pagePath, JSON.stringify(projectState.page, null, 2), 'utf8');
  }
  if (projectState.collections && typeof projectState.collections === 'object') {
    for (const [source, collection] of Object.entries(projectState.collections)) {
      const sourceSlug = String(source).replace(/[^a-zA-Z0-9-_]/g, '_');
      if (!sourceSlug) continue;
      const collectionDir = path.join(roots.collectionsDir, sourceSlug);
      fs.mkdirSync(collectionDir, { recursive: true });
      fs.writeFileSync(path.join(collectionDir, `${sourceSlug}.json`), JSON.stringify(collection, null, 2), 'utf8');
    }
  }
}

export function listLocalImages(assetsImagesDir: string, urlPrefix = '/assets/images') {
  const list: Array<{ id: string; url: string; alt: string; tags: string[] }> = [];
  if (!fs.existsSync(assetsImagesDir)) return list;
  for (const name of fs.readdirSync(assetsImagesDir)) {
    if (IMAGE_EXT.has(path.extname(name).toLowerCase())) {
      list.push({ id: name, url: `${urlPrefix}/${name}`, alt: name, tags: [] });
    }
  }
  return list;
}

function safeFilename(original: string, mimeType: string | undefined) {
  const base =
    original.replace(/\.[^.]+$/, '').replace(/[^a-zA-Z0-9-_]/g, '_').slice(0, 128) || 'image';
  const ext = original.includes('.')
    ? path.extname(original).toLowerCase()
    : mimeType?.startsWith('image/')
      ? `.${(mimeType.split('/')[1] || 'png').replace('jpeg', 'jpg')}`
      : '.png';
  return `${Date.now()}-${base}${IMAGE_EXT.has(ext) ? ext : '.png'}`;
}

export function saveUploadedImage(options: {
  assetsImagesDir: string;
  filename: string;
  mimeType?: string;
  base64Data: string;
}): { url: string } {
  const { assetsImagesDir, filename, mimeType, base64Data } = options;
  const buf = Buffer.from(base64Data, 'base64');
  if (buf.length > MAX_UPLOAD_BYTES) {
    throw new Error('File too large. Max 5MB.');
  }
  if (mimeType && !IMAGE_MIMES.has(mimeType)) {
    throw new Error('Invalid file type');
  }
  const name = safeFilename(filename, mimeType);
  if (!fs.existsSync(assetsImagesDir)) fs.mkdirSync(assetsImagesDir, { recursive: true });
  fs.writeFileSync(path.join(assetsImagesDir, name), buf);
  return { url: `/assets/images/${name}` };
}
