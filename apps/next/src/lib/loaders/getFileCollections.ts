import fs from 'node:fs';
import path from 'node:path';
import type { JsonPagesConfig } from '@olonjs/core';
import { resolveLocalDataRoots } from '@olonjs/next/server';

type CollectionDocuments = NonNullable<JsonPagesConfig['collections']>;

/** Collection documents from src/data/collections/<source>/<source>.json. */
export function getFileCollections(appRoot = process.cwd()): CollectionDocuments {
  const { collectionsDir } = resolveLocalDataRoots(appRoot);
  const collections: CollectionDocuments = {};
  if (!fs.existsSync(collectionsDir)) return collections;

  for (const source of fs.readdirSync(collectionsDir, { withFileTypes: true })) {
    if (!source.isDirectory()) continue;
    const sourceName = source.name.trim();
    if (!sourceName) continue;
    const filePath = path.join(collectionsDir, sourceName, `${sourceName}.json`);
    if (!fs.existsSync(filePath)) continue;
    const raw = JSON.parse(fs.readFileSync(filePath, 'utf8')) as unknown;
    if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) continue;
    collections[sourceName] = raw as CollectionDocuments[string];
  }
  return collections;
}
