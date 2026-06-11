import type { JsonPagesConfig } from './types-engine';
import type { MenuConfig, MenuItem, PageConfig, Section, SiteConfig, ThemeConfig } from './kernel';

export type RefDocuments = NonNullable<JsonPagesConfig['refDocuments']>;

interface RuntimeResolutionInput {
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: MenuConfig;
  refDocuments?: JsonPagesConfig['refDocuments'];
}

interface RuntimeResolutionResult {
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: MenuConfig;
}

interface ResolveContext {
  documents: Map<string, unknown>;
  cache: Map<string, unknown>;
  stack: string[];
}

export interface MenuRefBinding {
  fieldKey: string;
  path: string[];
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

function buildDocuments({
  pages,
  siteConfig,
  themeConfig,
  menuConfig,
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

  return documents;
}

function resolveRefTarget(
  ref: string,
  currentDocumentPath: string,
  context: ResolveContext
): { value: unknown; documentPath: string } | null {
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

function resolveDocument<T>(value: T, entryPath: string, documents: Map<string, unknown>): T {
  return resolveNode(value, entryPath, {
    documents,
    cache: new Map<string, unknown>(),
    stack: [],
  }) as T;
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
  const documents = buildDocuments(input);

  return {
    pages: Object.fromEntries(
      Object.entries(input.pages).map(([slug, page]) => [
        slug,
        resolveDocument(page, `pages/${slug.replace(/^\/+|\/+$/g, '') || 'home'}.json`, documents),
      ])
    ) as Record<string, PageConfig>,
    siteConfig: resolveDocument(input.siteConfig, 'config/site.json', documents),
    themeConfig: resolveDocument(input.themeConfig, 'config/theme.json', documents),
    menuConfig: resolveDocument(input.menuConfig, 'config/menu.json', documents),
  };
}
