/**
 * Internal Zod source of truth for the OlonJS public contract (ADR-0003).
 *
 * These schemas are the SOT for the JSON Schema artifacts published at
 * https://olon.js.org/schemas/v1/. They are NOT re-exported from the package
 * (Zod is internal authoring; JSON Schema is the public contract surface).
 *
 * The generator script (`scripts/bump-schemas.ts`) imports from this file
 * directly via relative path and emits Draft-07 JSON Schemas.
 *
 * ## Authoring gotchas (see ADR-0013)
 *
 * 1. **Field-level `.describe()` on `definitions`-registered schemas breaks
 *    the $ref.** `zod-to-json-schema` matches by reference identity. `.optional()`
 *    wraps the schema and preserves the inner reference (emits clean `$ref`).
 *    `.describe()` *clones* the schema with a new description, breaking identity:
 *    the lib decomposes the clone inline and emits per-property `$ref` like
 *    `#/definitions/Name/properties/<field>`. Always chain through `.optional()`
 *    when adding field-level descriptions to schemas registered in `definitions`,
 *    or place the description on the schema definition itself.
 *
 * 2. **Cross-ref placeholders must be required-by-default.** For top-level fields
 *    of `TenantManifestSchema` that the generator rewrites to cross-file `$ref`,
 *    use `z.object({}).passthrough()` (or any non-undefined-accepting type) —
 *    NOT `z.unknown()`. `z.unknown()` accepts `undefined` and produces
 *    non-required fields in the output JSON Schema.
 *
 * Fix order, per ADR-0003 §AD-3: if the generated JSON Schema is verbose,
 * semantically off, or harder to read than necessary, fix THIS file — never
 * the .schema.json output.
 */
import { z } from 'zod';
import type { MenuItem } from './kernel';

export const MenuItemSchema: z.ZodType<MenuItem> = z.lazy(() =>
  z
    .object({
      id: z.string().optional().describe('Stable identifier for this menu entry. Must be unique within its parent list when present. Optional in source data; the persistence layer assigns one if absent.'),
      label: z.string().describe('Visible link text. Plain text, no markdown.'),
      href: z.string().describe('Target URL. Accepts absolute (https://…), root-relative (/path), anchor (#id), mailto: and tel: schemes.'),
      icon: z.string().optional().describe('An icon slug from the theme\'s icon set (e.g. `arrow-right`), or an absolute URL to a custom asset. SVG is preferred for resolution independence.'),
      external: z.boolean().optional().describe('When true, the link points outside the current site and should typically open in a new tab.'),
      isCta: z.boolean().optional().describe('When true, this item is rendered with call-to-action emphasis rather than as a plain link.'),
      children: z.array(MenuItemSchema).optional().describe('Sub-items rendered as a nested menu. Recursive; depth is not limited by the contract.'),
    })
    .describe('A single navigation entry. Items may nest recursively via `children`.'),
);

export const MenuConfigSchema = z
  .object({
    main: z.array(MenuItemSchema).optional().describe('The default top-level menu. Conventionally the primary navigation.'),
  })
  .catchall(z.array(MenuItemSchema))
  .describe('Navigation menus, keyed by menu name. `main` is the default; additional named menus (footer, sidebar, …) sit alongside.');

export const SectionSchema = z
  .object({
    id: z.string().describe('Stable identifier for this section instance. Must be unique within its parent page or shell. Used as the addressable anchor for in-page navigation and for agent-driven section selection.'),
    type: z.string().describe('Section type identifier. Resolves to a concrete section schema published separately by the theme or tenant.'),
    data: z.record(z.string(), z.unknown()).describe('Section content payload. Shape is determined by the section type and validated against the type-specific schema, not by this contract.'),
    settings: z
      .record(z.string(), z.unknown())
      .optional()
      .describe('Optional rendering settings (padding, theme variant, container width, …). Shape is determined by the section type.'),
  })
  .describe('A page section: a self-contained, agent-addressable unit of content. The contract treats `data` and `settings` as open records; concrete shapes live in section-type schemas.');

export const SiteIdentitySchema = z
  .object({
    title: z.string().describe('Human-readable site name. Used in page titles, social previews, and the default header brand.'),
    logoUrl: z.string().optional().describe('URL of the site logo, root-relative (`/brand/logo.svg`) or absolute. SVG is preferred for resolution independence; the theme decides aspect-ratio handling (wordmark vs. square mark).'),
  })
  .describe('Brand identity for a site: human-readable name and logo URL. Used by themes for the document title, header brand, social cards, and PWA manifests.');

export const SiteConfigSchema = z
  .object({
    identity: SiteIdentitySchema,
    header: SectionSchema.optional(),
    footer: SectionSchema,
  })
  .describe('Site-level configuration: brand identity, an optional global header section (rendered above every page unless the page opts out via `global-header: false`), and a required global footer section (rendered below every page).');

export const PageMetaSchema = z
  .object({
    title: z
      .string()
      .min(10)
      .describe('Page title used in `<title>`, social cards, and search results. Minimum 10 characters; aim for 30–60 for optimal display in search results.'),
    description: z
      .string()
      .min(50)
      .describe('Page description for SEO and social cards. Minimum 50 characters; aim for 120–160.'),
  })
  .describe('Page metadata for SEO, social previews, and the document `<head>`.');

export const PageContractSchema = z
  .object({
    id: z
      .string()
      .regex(/^[a-z0-9-]+-page$/)
      .describe('Stable page identifier. Convention: kebab-case ending in `-page` (e.g. `home-page`, `docs-getting-started-page`).'),
    slug: z
      .string()
      .regex(/^[a-z0-9-/]+$/)
      .describe('URL path segment(s). Kebab-case; slashes allowed for nested routes (e.g. `docs/getting-started`).'),
    meta: PageMetaSchema,
    sections: z
      .array(SectionSchema)
      .describe('Ordered list of page sections rendered top-to-bottom. Each section follows the open Section shape; concrete data is determined by the section `type`.'),
    'global-header': z
      .boolean()
      .default(true)
      .describe('When `false`, this page opts out of the site-level global header. Defaults to `true` when omitted.'),
  })
  .describe('Full contract for a single page: identity, URL slug, SEO metadata, ordered sections, and global-header opt-out.');

/**
 * Cross-ref placeholders for TenantManifestSchema.
 *
 * `design`, `site`, `menu`, `page` are top-level canonical schemas with their
 * own `$id`. Inlining their full Zod here would duplicate them in
 * `tenant.schema.json`. Instead we emit `z.unknown()` placeholders and let the
 * generator rewrite the corresponding properties to cross-file `$ref` pointers
 * (see `crossRefs` on the tenant resource in `scripts/bump-schemas.ts`).
 *
 * This keeps Zod as the structural SOT and the manifest as a thin wrapper.
 */
export const TenantManifestSchema = z
  .object({
    identity: SiteIdentitySchema,
    design: z.object({}).passthrough(),
    site: z.object({}).passthrough(),
    menu: z.object({}).passthrough(),
    pages: z.array(z.object({}).passthrough()),
  })
  .describe(
    'Top-level Olon tenant manifest. Bundles a tenant\'s complete public contract: brand identity, design system tokens, site shell, navigation, and full page list. Each top-level field references a separately-published canonical schema; this manifest is the entry point for agents discovering or validating a complete Olon tenant.',
  );
