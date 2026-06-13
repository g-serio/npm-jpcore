import type { JsonPagesConfig } from './types-engine';
import type { MenuConfig, MenuItem, PageConfig, Section, SiteConfig, ThemeConfig } from './kernel';

export type RefDocuments = NonNullable<JsonPagesConfig['refDocuments']>;
type CollectionDocuments = NonNullable<JsonPagesConfig['collections']>;

interface RuntimeResolutionInput {
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: MenuConfig;
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  collectionContext?: CollectionResolutionContext | null;
  refDocuments?: JsonPagesConfig['refDocuments'];
}

interface RuntimeResolutionResult {
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: MenuConfig;
  collections: CollectionDocuments;
  collectionContext: CollectionResolutionContext | null;
}

interface ResolveContext {
  documents: Map<string, unknown>;
  cache: Map<string, unknown>;
  stack: string[];
  collectionContext?: CollectionResolutionContext | null;
}

export interface CollectionResolutionContext {
  source: string;
  paramKey: string;
  paramValue: string;
  currentItem: unknown;
}

export interface MenuRefBinding {
  fieldKey: string;
  path: string[];
}

export interface CollectionRefBinding {
  fieldKey: string;
  source: string;
  itemId?: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (!isRecord(value)) return false;
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

function isRefObject(value: unknown): value is Record<string, unknown> & { $ref: string } {
  return isRecord(value) && typeof value.$ref === 'string' && value.$ref.trim().length > 0;
}

function decodePointerSegment(segment: string): string {
  return segment.replace(/~1/g, '/').replace(/~0/g, '~');
}

function readJsonPointer(document: unknown, pointer: string): unknown {
  if (!pointer || pointer === '#') return document;
  const normalized = pointer.startsWith('#') ? pointer.slice(1) : pointer;
  if (!normalized) return document;
  if (normalized === '/') return document;

  let current: unknown = document;
  for (const rawSegment of normalized.replace(/^\//, '').split('/')) {
    const segment = decodePointerSegment(rawSegment);
    if (Array.isArray(current)) {
      const index = Number(segment);
      if (!Number.isInteger(index) || index < 0 || index >= current.length) return undefined;
      current = current[index];
      continue;
    }
    if (!isRecord(current) || !(segment in current)) return undefined;
    current = current[segment];
  }
  return current;
}

function normalizePath(input: string): string {
  const trimmed = input.trim().replace(/\\/g, '/');
  const withoutLeading = trimmed.replace(/^\/+/, '');
  const segments = withoutLeading.split('/');
  const normalized: string[] = [];

  for (const segment of segments) {
    if (!segment || segment === '.') continue;
    if (segment === '..') {
      if (normalized.length > 0) normalized.pop();
      continue;
    }
    normalized.push(segment);
  }

  return normalized.join('/');
}

function getDirname(path: string): string {
  const normalized = normalizePath(path);
  const idx = normalized.lastIndexOf('/');
  return idx === -1 ? '' : normalized.slice(0, idx);
}

function resolveDocumentCandidates(docPath: string, currentDocumentPath: string): string[] {
  const candidates = new Set<string>();
  const direct = normalizePath(docPath);
  if (direct) candidates.add(direct);

  const currentDir = getDirname(currentDocumentPath);
  const relative = normalizePath(currentDir ? `${currentDir}/${docPath}` : docPath);
  if (relative) candidates.add(relative);

  return Array.from(candidates);
}

function cloneUnknown<T>(value: T): T {
  if (Array.isArray(value)) {
    return value.map((item) => cloneUnknown(item)) as T;
  }
  if (isPlainObject(value)) {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, cloneUnknown(item)])
    ) as T;
  }
  return value;
}

function registerDocumentAliases(documents: Map<string, unknown>, aliases: string[], value: unknown): void {
  for (const alias of aliases) {
    const normalized = normalizePath(alias);
    if (!normalized) continue;
    documents.set(normalized, value);
  }
}

export function validateCollectionDocuments(
  collections?: JsonPagesConfig['collections'],
  collectionSchemas?: JsonPagesConfig['collectionSchemas']
): CollectionDocuments {
  const validatedCollections: CollectionDocuments = {};

  for (const [source, collection] of Object.entries(collections ?? {})) {
    const schema = collectionSchemas?.[source];
    if (!schema) {
      throw new Error(`[JsonPages] Missing collection schema for "${source}".`);
    }

    try {
      validatedCollections[source] = schema.parse(collection) as CollectionDocuments[string];
    } catch (error) {
      const detail = error instanceof Error && error.message ? `: ${error.message}` : '';
      throw new Error(`[JsonPages] Invalid collection "${source}"${detail}`);
    }
  }

  return validatedCollections;
}

function rebaseCollectionContext(
  collectionContext: CollectionResolutionContext | null | undefined,
  collections: CollectionDocuments
): CollectionResolutionContext | null {
  if (!collectionContext) return null;
  const collection = collections[collectionContext.source];
  if (!isRecord(collection)) return null;
  const currentItem = collection[collectionContext.paramValue];
  if (currentItem === undefined) return null;
  return {
    ...collectionContext,
    currentItem,
  };
}

function buildDocuments({
  pages,
  siteConfig,
  themeConfig,
  menuConfig,
  collections,
  refDocuments,
}: RuntimeResolutionInput): Map<string, unknown> {
  const documents = new Map<string, unknown>();

  for (const [alias, value] of Object.entries(refDocuments ?? {})) {
    registerDocumentAliases(documents, [alias], value);
  }

  registerDocumentAliases(documents, ['site.json', 'config/site.json', 'src/data/config/site.json'], siteConfig);
  registerDocumentAliases(documents, ['theme.json', 'config/theme.json', 'src/data/config/theme.json'], themeConfig);
  registerDocumentAliases(documents, ['menu.json', 'config/menu.json', 'src/data/config/menu.json'], menuConfig);

  for (const [slug, page] of Object.entries(pages)) {
    const safeSlug = slug.replace(/^\/+|\/+$/g, '') || 'home';
    registerDocumentAliases(documents, [`pages/${safeSlug}.json`, `src/data/pages/${safeSlug}.json`], page);
  }

  for (const [slug, collection] of Object.entries(collections ?? {})) {
    const safeSlug = slug.replace(/^\/+|\/+$/g, '');
    if (!safeSlug) continue;
    registerDocumentAliases(documents, [
      `collections/${safeSlug}/${safeSlug}.json`,
      `src/data/collections/${safeSlug}/${safeSlug}.json`,
    ], collection);
  }

  return documents;
}

function resolveRefTarget(
  ref: string,
  currentDocumentPath: string,
  context: ResolveContext
): { value: unknown; documentPath: string } | null {
  if (ref.trim() === 'collection:current') {
    const currentItem = context.collectionContext?.currentItem;
    if (currentItem === undefined) return null;
    const source = context.collectionContext?.source ?? 'current';
    const paramValue = context.collectionContext?.paramValue ?? 'current';
    return {
      value: currentItem,
      documentPath: `collections/${source}/${source}.json`,
    };
  }

  const [rawDocumentPath, rawPointer = ''] = ref.split('#');
  const pointer = rawPointer ? `/${rawPointer.replace(/^\//, '')}` : '';

  if (!rawDocumentPath) {
    const normalizedCurrent = normalizePath(currentDocumentPath);
    const currentDocument = context.documents.get(normalizedCurrent);
    if (currentDocument === undefined) return null;
    const currentValue = readJsonPointer(currentDocument, pointer);
    if (currentValue === undefined) return null;
    return { value: currentValue, documentPath: normalizedCurrent };
  }

  for (const candidate of resolveDocumentCandidates(rawDocumentPath, currentDocumentPath)) {
    const documentValue = context.documents.get(candidate);
    if (documentValue === undefined) continue;
    const targetValue = readJsonPointer(documentValue, pointer);
    if (targetValue === undefined) continue;
    return { value: targetValue, documentPath: candidate };
  }

  return null;
}

function resolveNode(
  value: unknown,
  currentDocumentPath: string,
  context: ResolveContext
): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => resolveNode(item, currentDocumentPath, context));
  }

  if (!isPlainObject(value)) {
    return value;
  }

  if (isRefObject(value)) {
    const refKey = `${normalizePath(currentDocumentPath)}::${value.$ref}`;
    if (context.stack.includes(refKey)) {
      console.warn('[JsonPages] Circular $ref skipped', value.$ref);
      return cloneUnknown(value);
    }
    if (context.cache.has(refKey)) {
      const cached = cloneUnknown(context.cache.get(refKey));
      const siblingEntries = Object.entries(value).filter(([key]) => key !== '$ref');
      if (siblingEntries.length === 0) return cached;
      const resolvedSiblings = Object.fromEntries(
        siblingEntries.map(([key, item]) => [key, resolveNode(item, currentDocumentPath, context)])
      );
      return isPlainObject(cached) ? { ...cached, ...resolvedSiblings } : cached;
    }

    const resolvedTarget = resolveRefTarget(value.$ref, currentDocumentPath, context);
    if (!resolvedTarget) {
      console.warn('[JsonPages] Unresolved $ref', value.$ref);
      return Object.fromEntries(
        Object.entries(value).map(([key, item]) => [key, resolveNode(item, currentDocumentPath, context)])
      );
    }

    context.stack.push(refKey);
    const resolvedValue = resolveNode(resolvedTarget.value, resolvedTarget.documentPath, context);
    context.stack.pop();
    context.cache.set(refKey, cloneUnknown(resolvedValue));

    const siblingEntries = Object.entries(value).filter(([key]) => key !== '$ref');
    if (siblingEntries.length === 0) return resolvedValue;

    const resolvedSiblings = Object.fromEntries(
      siblingEntries.map(([key, item]) => [key, resolveNode(item, currentDocumentPath, context)])
    );
    return isPlainObject(resolvedValue)
      ? { ...resolvedValue, ...resolvedSiblings }
      : resolvedValue;
  }

  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [key, resolveNode(item, currentDocumentPath, context)])
  );
}

function resolveDocument(
  value: unknown,
  entryPath: string,
  documents: Map<string, unknown>,
  collectionContext?: CollectionResolutionContext | null
): unknown {
  return resolveNode(value, entryPath, {
    documents,
    cache: new Map<string, unknown>(),
    stack: [],
    collectionContext,
  });
}

export function resolveCollectionContext(
  page: PageConfig,
  params: Record<string, string | undefined>,
  collections?: JsonPagesConfig['collections']
): CollectionResolutionContext | null {
  const binding = page.collection;
  if (!binding) return null;

  const source = String(binding.source);
  const paramKey = binding.paramKey;
  const paramValue = params[paramKey];
  if (!paramValue) return null;

  const collection = collections?.[source];
  if (!isRecord(collection)) return null;

  const currentItem = collection[paramValue];
  if (currentItem === undefined) return null;

  return {
    source,
    paramKey,
    paramValue,
    currentItem,
  };
}

function isMenuItemShape(value: unknown): value is MenuItem {
  return isRecord(value) && typeof value.label === 'string' && typeof value.href === 'string';
}

function parseMenuRefPointer(value: unknown): string[] | null {
  if (!isRefObject(value)) return null;
  const rawRef = value.$ref.trim();
  const [rawDocPath, rawPointer = ''] = rawRef.split('#');
  if (!/menu\.json$/i.test(rawDocPath)) return null;
  const pointer = rawPointer.replace(/^\//, '');
  if (!pointer) return null;
  const segments = pointer
    .split('/')
    .map(decodePointerSegment)
    .filter(Boolean);
  return segments.length > 0 ? segments : null;
}

export function getMenuRefBindings(sectionData: unknown): MenuRefBinding[] {
  if (!isRecord(sectionData)) return [];
  return Object.entries(sectionData)
    .map(([fieldKey, value]) => {
      const path = parseMenuRefPointer(value);
      return path ? { fieldKey, path } : null;
    })
    .filter((binding): binding is MenuRefBinding => binding != null);
}

function writeValueAtPath(target: unknown, path: string[], value: unknown): unknown {
  if (path.length === 0) return value;

  const [head, ...tail] = path;
  const source = isRecord(target) ? target : {};
  return {
    ...source,
    [head]: writeValueAtPath(source[head], tail, value),
  };
}

function preserveAuthoredRefs(authoredValue: unknown, nextValue: unknown): unknown {
  if (isRefObject(nextValue)) return cloneUnknown(nextValue);
  if (isRefObject(authoredValue)) return cloneUnknown(authoredValue);

  if (Array.isArray(nextValue)) {
    const authoredArray = Array.isArray(authoredValue) ? authoredValue : [];
    return nextValue.map((item, index) => preserveAuthoredRefs(authoredArray[index], item));
  }

  if (isPlainObject(nextValue)) {
    const authoredRecord = isRecord(authoredValue) ? authoredValue : {};
    return Object.fromEntries(
      Object.entries(nextValue).map(([key, item]) => [
        key,
        preserveAuthoredRefs(authoredRecord[key], item),
      ])
    );
  }

  return nextValue;
}

export function applyMenuRefBindingsToDraft(
  authoredSectionData: unknown,
  nextData: Record<string, unknown>,
  menuDraft: MenuConfig
): { normalizedData: Record<string, unknown>; menuDraft: MenuConfig } {
  const bindings = getMenuRefBindings(authoredSectionData);
  if (bindings.length === 0) {
    return { normalizedData: nextData, menuDraft };
  }

  const authoredData = isRecord(authoredSectionData) ? authoredSectionData : {};
  const normalizedData: Record<string, unknown> = { ...nextData };
  let nextMenuDraft = menuDraft;

  for (const binding of bindings) {
    if (authoredData[binding.fieldKey] !== undefined) {
      normalizedData[binding.fieldKey] = authoredData[binding.fieldKey];
    }
    const resolvedMenuValue = nextData[binding.fieldKey];
    if (Array.isArray(resolvedMenuValue)) {
      nextMenuDraft = writeValueAtPath(nextMenuDraft, binding.path, resolvedMenuValue) as MenuConfig;
    }
  }

  return { normalizedData, menuDraft: nextMenuDraft };
}

function parseCollectionRef(value: unknown, collectionContext?: CollectionResolutionContext | null): Omit<CollectionRefBinding, 'fieldKey'> | null {
  if (!isRefObject(value)) return null;
  const rawRef = value.$ref.trim();
  if (rawRef === 'collection:current') {
    if (!collectionContext) return null;
    return {
      source: collectionContext.source,
      itemId: collectionContext.paramValue,
    };
  }

  const [rawDocPath, rawPointer = ''] = rawRef.split('#');
  const normalizedPath = normalizePath(rawDocPath);
  const match = normalizedPath.match(/(?:^|\/)collections\/([^/]+)\/\1\.json$/);
  if (!match?.[1]) return null;

  const pointer = rawPointer.replace(/^\//, '');
  const itemId = pointer ? decodePointerSegment(pointer.split('/')[0]) : undefined;
  return {
    source: match[1],
    ...(itemId ? { itemId } : {}),
  };
}

export function getCollectionRefBindings(
  sectionData: unknown,
  collectionContext?: CollectionResolutionContext | null
): CollectionRefBinding[] {
  if (!isRecord(sectionData)) return [];
  return Object.entries(sectionData)
    .map(([fieldKey, value]) => {
      const binding = parseCollectionRef(value, collectionContext);
      return binding ? { fieldKey, ...binding } : null;
    })
    .filter((binding): binding is CollectionRefBinding => binding != null);
}

export function applyCollectionRefBindingsToDraft(
  authoredSectionData: unknown,
  nextData: Record<string, unknown>,
  collectionsDraft: JsonPagesConfig['collections'] | undefined,
  collectionContext?: CollectionResolutionContext | null,
  collectionSchemas?: JsonPagesConfig['collectionSchemas']
): { normalizedData: Record<string, unknown>; collectionsDraft: JsonPagesConfig['collections'] } {
  const bindings = getCollectionRefBindings(authoredSectionData, collectionContext);
  if (bindings.length === 0) {
    return { normalizedData: nextData, collectionsDraft };
  }

  const authoredData = isRecord(authoredSectionData) ? authoredSectionData : {};
  const normalizedData: Record<string, unknown> = { ...nextData };
  const nextCollectionsDraft = cloneUnknown(collectionsDraft ?? {}) as NonNullable<JsonPagesConfig['collections']>;

  for (const binding of bindings) {
    if (authoredData[binding.fieldKey] !== undefined) {
      normalizedData[binding.fieldKey] = authoredData[binding.fieldKey];
    }

    const resolvedValue = nextData[binding.fieldKey];
    if (binding.itemId) {
      const sourceCollection = isRecord(nextCollectionsDraft[binding.source])
        ? nextCollectionsDraft[binding.source]
        : {};
      const authoredItem = sourceCollection[binding.itemId];
      nextCollectionsDraft[binding.source] = {
        ...sourceCollection,
        [binding.itemId]: preserveAuthoredRefs(authoredItem, resolvedValue),
      };
      continue;
    }

    if (isRecord(resolvedValue)) {
      nextCollectionsDraft[binding.source] = preserveAuthoredRefs(
        nextCollectionsDraft[binding.source],
        resolvedValue
      ) as CollectionDocuments[string];
    }
  }

  return {
    normalizedData,
    collectionsDraft: validateCollectionDocuments(nextCollectionsDraft, collectionSchemas),
  };
}

function applySectionDataMenuRefBindings(
  authoredSection: Section | undefined,
  nextSection: Section | undefined,
  menuDraft: MenuConfig
): { section: Section | undefined; menuDraft: MenuConfig } {
  if (!authoredSection || !nextSection || !isRecord(nextSection.data)) {
    return { section: nextSection, menuDraft };
  }

  const { normalizedData, menuDraft: nextMenuDraft } = applyMenuRefBindingsToDraft(
    authoredSection.data,
    nextSection.data,
    menuDraft
  );

  return {
    section: { ...nextSection, data: normalizedData } as Section,
    menuDraft: nextMenuDraft,
  };
}

export function applySiteMenuRefBindingsToDraft(
  authoredSite: SiteConfig,
  nextSite: SiteConfig,
  menuDraft: MenuConfig
): { site: SiteConfig; menuDraft: MenuConfig } {
  let nextMenuDraft = menuDraft;

  const headerResult = applySectionDataMenuRefBindings(
    authoredSite.header,
    nextSite.header,
    nextMenuDraft
  );
  nextMenuDraft = headerResult.menuDraft;

  const footerResult = applySectionDataMenuRefBindings(
    authoredSite.footer,
    nextSite.footer,
    nextMenuDraft
  );
  nextMenuDraft = footerResult.menuDraft;

  return {
    site: {
      ...nextSite,
      ...(headerResult.section ? { header: headerResult.section } : {}),
      footer: footerResult.section ?? nextSite.footer,
    },
    menuDraft: nextMenuDraft,
  };
}

function getSectionDataMenuCandidate(sectionData: unknown): MenuItem[] | null {
  if (!isRecord(sectionData)) return null;
  const menu = sectionData.menu;
  if (Array.isArray(menu) && menu.every(isMenuItemShape)) return menu as MenuItem[];
  return null;
}

export function resolveHeaderMenuItems(headerData: unknown, fallbackMain: MenuItem[]): MenuItem[] {
  const candidate = getSectionDataMenuCandidate(headerData);
  return candidate ?? (Array.isArray(fallbackMain) ? fallbackMain : []);
}

export function resolveSectionMenuItems(section: Section, fallbackMain: MenuItem[]): MenuItem[] | undefined {
  const candidate = getSectionDataMenuCandidate(section.data as unknown);
  if (candidate) return candidate;
  if (section.type === 'header') return Array.isArray(fallbackMain) ? fallbackMain : [];
  return undefined;
}

export function resolveRuntimeConfig(input: RuntimeResolutionInput): RuntimeResolutionResult {
  const collections = validateCollectionDocuments(input.collections, input.collectionSchemas);
  const collectionContext = rebaseCollectionContext(input.collectionContext, collections);
  const documents = buildDocuments({
    ...input,
    collections,
  });

  return {
    pages: Object.fromEntries(
      Object.entries(input.pages).map(([slug, page]) => [
        slug,
        resolveDocument(
          page,
          `pages/${slug.replace(/^\/+|\/+$/g, '') || 'home'}.json`,
          documents,
          collectionContext
        ),
      ])
    ) as Record<string, PageConfig>,
    siteConfig: resolveDocument(input.siteConfig, 'config/site.json', documents) as SiteConfig,
    themeConfig: resolveDocument(input.themeConfig, 'config/theme.json', documents) as ThemeConfig,
    menuConfig: resolveDocument(input.menuConfig, 'config/menu.json', documents) as MenuConfig,
    collections,
    collectionContext,
  };
}
