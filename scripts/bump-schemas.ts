#!/usr/bin/env tsx
/**
 * bump:all — regenerate the public JSON Schema artifacts at olon.js.org/schemas/v1/.
 *
 * Per ADR-0003, Zod is the internal source of truth and JSON Schema is the
 * public contract. This script converts the Zod schemas in
 * `packages/core/src/contract/zod-schemas.ts` into Draft-07 JSON Schemas and
 * writes them deterministically to `apps/olonjs.io/public/schemas/v1/`.
 *
 * `design.schema.json` is hand-authored (see ADR-0003 §AD-5) and intentionally
 * NOT touched by this script.
 */
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import Ajv, { type AnySchema } from 'ajv';
import { zodToJsonSchema } from 'zod-to-json-schema';
import type { ZodTypeAny } from 'zod';

import {
  CollectionDocumentSchema,
  CollectionItemSchema,
  MenuConfigSchema,
  MenuItemSchema,
  PageCollectionBindingSchema,
  PageContractSchema,
  PageMetaSchema,
  SectionSchema,
  SiteConfigSchema,
  SiteIdentitySchema,
  TenantManifestSchema,
} from '../packages/core/src/contract/zod-schemas';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(__dirname, '..');
const OUT_DIR = path.join(ROOT, 'apps', 'olonjs.io', 'public', 'schemas', 'v1');
const BASE_URL = 'https://olon.js.org/schemas/v1';

interface Resource {
  name: string;
  zod: ZodTypeAny;
  title: string;
  description: string;
  definitions?: Record<string, ZodTypeAny>;
  /**
   * Post-conversion rewrites: replace the value at each dotted path with
   * `{ $ref: <url> }`. Paths start from the converted JSON Schema root and
   * traverse via `properties`, `items`, etc. (e.g. `properties.pages.items`).
   * Used to bridge Zod-derived schemas with canonical schemas published
   * separately (e.g. `design.schema.json`, hand-authored per ADR-0003 §AD-5).
   */
  crossRefs?: Record<string, string>;
  examples?: unknown[];
}

const resources: Resource[] = [
  {
    name: 'menu',
    zod: MenuConfigSchema,
    title: 'Olon Menu Configuration',
    description:
      'Navigation menu structure for an Olon site. `main` is the default menu; additional named menus (e.g. `footer`, `sidebar`) may be defined as siblings.',
    definitions: { MenuItem: MenuItemSchema },
    examples: [
      {
        main: [
          { label: 'Home', href: '/' },
          {
            label: 'Docs',
            href: '/docs',
            children: [
              { label: 'Getting started', href: '/docs/getting-started' },
              { label: 'API reference', href: '/docs/api' },
            ],
          },
          { label: 'GitHub', href: 'https://github.com/olonjs/core', external: true },
          { label: 'Get started', href: '#get-started', isCta: true },
        ],
        footer: [
          { label: 'Privacy', href: '/privacy' },
          { label: 'Terms', href: '/terms' },
        ],
      },
    ],
  },
  {
    name: 'site',
    zod: SiteConfigSchema,
    title: 'Olon Site Configuration',
    description:
      'Site-level configuration: identity (name, logo), an optional global header section, and a required global footer section. Header and footer follow the generic Section open shape; their concrete `data` and `settings` schemas are determined by the section `type` and published separately.',
    definitions: { Section: SectionSchema, SiteIdentity: SiteIdentitySchema },
    examples: [
      {
        identity: {
          title: 'Olon',
          logoUrl: '/brand/mark/olon-mark-dark.svg',
        },
        header: {
          id: 'global-header',
          type: 'header',
          data: {
            logoText: 'Olon',
            links: [
              { label: 'Docs', href: '/docs' },
              { label: 'GitHub', href: 'https://github.com/olonjs/core' },
            ],
          },
        },
        footer: {
          id: 'global-footer',
          type: 'footer',
          data: {
            copyright: '© 2026 OlonJS',
          },
        },
      },
    ],
  },
  {
    name: 'collection',
    zod: CollectionDocumentSchema,
    title: 'Olon Collection Document',
    description:
      'COP collection document for structured entities independent from pages. Collections are keyed by stable entity id and may be consumed by page sections through `$ref` or by dynamic routes through `collection:current`.',
    definitions: { CollectionItem: CollectionItemSchema },
    examples: [
      {
        dune: {
          id: 'dune',
          title: 'Dune',
          author: 'Frank Herbert',
          year: 1965,
        },
        neuromancer: {
          id: 'neuromancer',
          title: 'Neuromancer',
          author: 'William Gibson',
          year: 1984,
        },
      },
    ],
  },
  {
    name: 'page',
    zod: PageContractSchema,
    title: 'Olon Page Contract',
    description:
      'Full contract for a single Olon page: identifier, URL slug, SEO metadata, optional COP collection binding, an ordered list of sections, and an opt-out for the site-level global header. Sections follow the generic Section open shape; concrete data is determined by the section `type` and validated against type-specific schemas published separately.',
    definitions: { Section: SectionSchema, PageMeta: PageMetaSchema, PageCollectionBinding: PageCollectionBindingSchema },
    examples: [
      {
        id: 'home-page',
        slug: 'home',
        meta: {
          title: 'OlonJS — the contract layer for the agentic web',
          description:
            'OlonJS is the contract layer for the agentic web. A typed, deterministic JSON contract that AI agents and humans both understand.',
        },
        sections: [
          {
            id: 'home-hero',
            type: 'hero',
            data: { title: 'OlonJS', subtitle: 'The contract layer for the agentic web' },
          },
          {
            id: 'home-features',
            type: 'feature-grid',
            data: { items: [] },
            settings: { container: 'boxed' },
          },
        ],
      },
      {
        id: 'book-detail-page',
        slug: 'libri/[slug]',
        meta: {
          title: 'Dettaglio libro nella collection',
          description:
            'Pagina dinamica che usa il Collection Protocol per risolvere il libro corrente dalla route.',
        },
        collection: {
          source: 'libri',
          paramKey: 'slug',
        },
        sections: [
          {
            id: 'book-detail',
            type: 'book-detail',
            data: { item: { $ref: 'collection:current' } },
          },
        ],
      },
    ],
  },
  {
    name: 'tenant',
    zod: TenantManifestSchema,
    title: 'Olon Tenant Manifest',
    description:
      'Top-level manifest for a complete Olon tenant. Bundles the canonical contracts — design system, site shell, navigation, pages, and optional COP collections — under one document, with the tenant\'s own identity. Each top-level field is a cross-file `$ref` to a separately-published canonical schema (relative to this manifest\'s `$id`), keeping the manifest a thin wrapper rather than an inlined duplicate.',
    definitions: { SiteIdentity: SiteIdentitySchema },
    crossRefs: {
      'properties.design': 'design.schema.json',
      'properties.site': 'site.schema.json',
      'properties.menu': 'menu.schema.json',
      'properties.pages.items': 'page.schema.json',
      'properties.collections.additionalProperties': 'collection.schema.json',
    },
    examples: [
      {
        identity: {
          title: 'Olon',
          logoUrl: '/brand/mark/olon-mark-dark.svg',
        },
        design: {
          name: 'Olon',
          tokens: {
            colors: {
              background: 'hsl(215 28% 7%)',
              foreground: 'hsl(214 33% 84%)',
              primary: 'hsl(222 100% 54%)',
            },
          },
        },
        site: {
          identity: { title: 'Olon' },
          footer: {
            id: 'global-footer',
            type: 'footer',
            data: { copyright: '© 2026 OlonJS' },
          },
        },
        menu: {
          main: [
            { label: 'Home', href: '/' },
            { label: 'Docs', href: '/docs' },
          ],
        },
        pages: [
          {
            id: 'home-page',
            slug: 'home',
            meta: {
              title: 'OlonJS — the contract layer for the agentic web',
              description:
                'OlonJS is the contract layer for the agentic web. A typed, deterministic JSON contract that AI agents and humans both understand.',
            },
            sections: [],
          },
        ],
        collections: {
          libri: {
            dune: {
              id: 'dune',
              title: 'Dune',
              author: 'Frank Herbert',
              year: 1965,
            },
          },
        },
      },
    ],
  },
];

const KEY_ORDER = [
  '$schema',
  '$id',
  '$ref',
  'title',
  'description',
  'type',
  'required',
  'properties',
  'items',
  'additionalProperties',
  'patternProperties',
  'enum',
  'const',
  'oneOf',
  'anyOf',
  'allOf',
  'definitions',
  '$defs',
  'examples',
];

function compareKeys(a: string, b: string): number {
  const ai = KEY_ORDER.indexOf(a);
  const bi = KEY_ORDER.indexOf(b);
  if (ai !== -1 && bi !== -1) return ai - bi;
  if (ai !== -1) return -1;
  if (bi !== -1) return 1;
  return a.localeCompare(b);
}

function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === 'object') {
    const obj = value as Record<string, unknown>;
    return Object.keys(obj)
      .sort(compareKeys)
      .reduce<Record<string, unknown>>((acc, k) => {
        acc[k] = sortKeys(obj[k]);
        return acc;
      }, {});
  }
  return value;
}

function fail(msg: string): never {
  console.error(`[bump-schemas] ERROR: ${msg}`);
  process.exit(1);
}

function applyCrossRefs(
  schema: Record<string, unknown>,
  crossRefs: Record<string, string>,
  resourceName: string,
): void {
  for (const [dottedPath, refUrl] of Object.entries(crossRefs)) {
    const segments = dottedPath.split('.');
    const leaf = segments.pop();
    if (!leaf) fail(`Empty cross-ref path in "${resourceName}".`);
    let parent: Record<string, unknown> = schema;
    for (const seg of segments) {
      const next = parent[seg];
      if (next == null || typeof next !== 'object') {
        fail(`Cross-ref path not found in "${resourceName}": ${dottedPath} (stuck at "${seg}").`);
      }
      parent = next as Record<string, unknown>;
    }
    parent[leaf] = { $ref: refUrl };
  }
}

async function emit(resource: Resource): Promise<void> {
  const converted = zodToJsonSchema(resource.zod, {
    target: 'jsonSchema7',
    $refStrategy: 'root',
    definitions: resource.definitions,
  }) as Record<string, unknown>;

  if (resource.crossRefs) {
    applyCrossRefs(converted, resource.crossRefs, resource.name);
  }

  const envelope = {
    $schema: 'http://json-schema.org/draft-07/schema#',
    $id: `${BASE_URL}/${resource.name}.schema.json`,
    title: resource.title,
    description: resource.description,
    ...converted,
    ...(resource.examples ? { examples: resource.examples } : {}),
  };

  const ajv = new Ajv({ strict: false, allErrors: true });
  if (!ajv.validateSchema(envelope as AnySchema)) {
    fail(
      `Schema "${resource.name}" failed meta-schema validation: ${JSON.stringify(
        ajv.errors,
      )}`,
    );
  }

  const output = JSON.stringify(sortKeys(envelope), null, 2) + '\n';
  const outPath = path.join(OUT_DIR, `${resource.name}.schema.json`);
  await fs.writeFile(outPath, output, 'utf8');
  console.log(`[bump-schemas] OK: ${path.relative(ROOT, outPath)}`);
}

async function main(): Promise<void> {
  await fs.mkdir(OUT_DIR, { recursive: true });
  for (const resource of resources) {
    await emit(resource);
  }
}

main().catch((err) => fail(err instanceof Error ? err.message : String(err)));
