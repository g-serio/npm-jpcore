/**
 * Engine contract: Core must not import from src/components or src/data.
 */
import type React from 'react';
import type { LucideIcon } from 'lucide-react';
import type { CollectionDocument, MenuConfig, PageConfig, ProjectState, SiteConfig, ThemeConfig } from './kernel';

export interface SelectionPathSegment {
  fieldKey: string;
  itemId?: string;
}

export type SelectionPath = SelectionPathSegment[];

export interface PersistenceConfig {
  saveToFile?: (state: ProjectState, slug: string) => Promise<void>;
  hotSave?: (state: ProjectState, slug: string) => Promise<void>;
  coldSave?: (state: ProjectState, slug: string) => Promise<void>;
  showLocalSave?: boolean;
  showHotSave?: boolean;
  showColdSave?: boolean;
  flushUploadedAssets?: (urls: string[]) => Promise<Record<string, string>>;
}

export interface ThemeCssConfig {
  tenant: string;
  admin?: string;
}

export interface AddSectionConfig {
  addableSectionTypes?: string[];
  sectionTypeLabels?: Record<string, string>;
  getDefaultSectionData?: (sectionType: string) => Record<string, unknown>;
}

export interface LibraryImageEntry {
  id: string;
  url: string;
  alt: string;
  tags?: string[];
}

export interface AssetsConfig {
  assetsBaseUrl?: string;
  assetsManifest?: LibraryImageEntry[];
  /**
   * Uploads an image and returns the final canonical URL that must be persisted in JSON.
   *
   * Valid examples:
   * - /assets/images/foo.png
   * - /assets/tenant-a/foo.png
   * - https://cdn.example.com/foo.png
   *
   * Invalid examples:
   * - public/assets/foo.png
   * - C:\\foo\\bar.png
   * - data:image/png;base64,...
   */
  onAssetUpload?: (file: File) => Promise<string>;
}

export interface WebMcpConfig {
  enabled?: boolean;
  namespace?: string;
}

type SchemaLike = { parse: (v: unknown) => unknown; shape?: Record<string, unknown> };

export interface JsonPagesConfig {
  tenantId: string;
  basePath?: string;
  registry: Record<string, React.ComponentType<unknown>>;
  schemas: Record<string, SchemaLike>;
  /**
   * Optional registry of Zod submission schemas for sections that can be filled
   * by external agents (e.g. MCP-connected AI clients).
   *
   * Keyed by the same section-type strings used in `schemas`. Each value is a
   * Zod schema describing the section's *submission payload* (what the user
   * fills in) — distinct from `schemas` entries, which describe the section's
   * *UI configuration* (how the tenant author configures the section).
   *
   * When a section type appears on a page AND has an entry here, its JSON
   * Schema representation is emitted on the page contract as
   * `sectionSubmissionSchemas` (see `OlonJsPageContract`).
   *
   * The shape mirrors `schemas` (duck-typed on `{ parse, shape? }`) so core
   * does not force `zod` on consumers at the type level. In practice tenants
   * pass `z.object(...)` instances; the JSON Schema serializer casts to
   * `z.ZodTypeAny` at its own boundary.
   *
   * See `docs/decisions/ADR-0002-form-submission-schemas.md` for rationale,
   * tenant convention, and the full emission contract.
   */
  submissionSchemas?: Record<string, SchemaLike>;
  collectionSchemas?: Record<string, SchemaLike>;
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
  themeConfig: ThemeConfig;
  menuConfig: MenuConfig;
  collections?: Record<string, CollectionDocument<unknown>>;
  refDocuments?: Record<string, unknown>;
  persistence?: Partial<PersistenceConfig>;
  themeCss: ThemeCssConfig;
  NotFoundComponent?: React.ComponentType;
  addSection?: AddSectionConfig;
  assets?: AssetsConfig;
  overlayDisabledSectionTypes?: string[];
  webmcp?: WebMcpConfig;
  iconRegistry?: Record<string, LucideIcon>;
}
