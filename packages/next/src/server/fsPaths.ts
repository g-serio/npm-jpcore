import path from 'node:path';

/**
 * Resolve a page JSON path under rootDir without leaving that root.
 * Mirrors tenant-alpha Vite plugin sanitization.
 */
export function safeDataSlugPath(rootDir: string, rawSlug: string, fallback: string): string {
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
