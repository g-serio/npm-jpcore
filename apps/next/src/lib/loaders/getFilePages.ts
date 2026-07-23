import fs from 'node:fs';
import path from 'node:path';
import type { PageConfig } from '@olonjs/core';
import { resolveLocalDataRoots } from '@olonjs/next/server';

function slugFromRelative(relPath: string): string {
  const withoutExt = relPath.replace(/\.json$/i, '');
  const canonical = withoutExt
    .split(/[/\\]/)
    .map((segment) => segment.trim())
    .filter(Boolean)
    .join('/');
  return canonical || 'home';
}

function walkJsonFiles(dir: string, baseDir: string, out: string[]): void {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const abs = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walkJsonFiles(abs, baseDir, out);
      continue;
    }
    if (entry.isFile() && entry.name.toLowerCase().endsWith('.json')) {
      out.push(path.relative(baseDir, abs));
    }
  }
}

/** Page registry from nested JSON under src/data/pages (JSP). */
export function getFilePages(appRoot = process.cwd()): Record<string, PageConfig> {
  const { pagesDir } = resolveLocalDataRoots(appRoot);
  const relFiles: string[] = [];
  walkJsonFiles(pagesDir, pagesDir, relFiles);
  relFiles.sort((a, b) => a.localeCompare(b));

  const bySlug = new Map<string, PageConfig>();
  for (const rel of relFiles) {
    const abs = path.join(pagesDir, rel);
    const raw = JSON.parse(fs.readFileSync(abs, 'utf8')) as unknown;
    if (raw == null || typeof raw !== 'object') continue;
    const slug = slugFromRelative(rel);
    bySlug.set(slug, raw as PageConfig);
  }

  const slugs = Array.from(bySlug.keys()).sort((a, b) =>
    a === 'home' ? -1 : b === 'home' ? 1 : a.localeCompare(b),
  );
  const record: Record<string, PageConfig> = {};
  for (const slug of slugs) {
    const config = bySlug.get(slug);
    if (config) record[slug] = config;
  }
  return record;
}
