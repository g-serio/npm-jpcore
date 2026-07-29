import { z } from 'zod';
import type { PageConfig, SiteConfig } from './kernel';
import type { JsonPagesConfig } from './types-engine';

const WEBMCP_TOOL_REQUEST_TYPE = 'olonjs:webmcp:tool-call';
const WEBMCP_TOOL_RESULT_TYPE = 'olonjs:webmcp:tool-result';

export interface WebMcpToolContract {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
}

export interface WebMcpSectionInstance {
  id: string;
  type: string;
  scope: 'global' | 'local';
  label: string;
}

export interface OlonJsPageContract {
  version: '1.0.0';
  kind: 'olonjs-page-contract';
  slug: string;
  title: string;
  description: string;
  manifestHref: string;
  systemPrompt: string;
  sectionTypes: string[];
  sectionInstances: WebMcpSectionInstance[];
  sectionSchemas: Record<string, Record<string, unknown>>;
  /**
   * Optional JSON Schema representations of submission payloads for form-capable
   * sections present on this page. Keyed by section type.
   *
   * Emitted only for section types that (a) actually appear on this page AND
   * (b) have an entry in `JsonPagesConfig.submissionSchemas`. Absent (not `{}`)
   * when no section on the page qualifies, to keep the contract tight.
   *
   * MCP agents consuming this contract can discover form shapes directly from
   * reading the page, without requiring a separate tool call.
   *
   * See `docs/decisions/ADR-0002-form-submission-schemas.md` (emission contract).
   */
  sectionSubmissionSchemas?: Record<string, Record<string, unknown>>;
  tools: WebMcpToolContract[];
}

export interface OlonJsPageManifest {
  version: '1.0.0';
  kind: 'olonjs-page-mcp-manifest';
  generatedAt: string;
  slug: string;
  title: string;
  description: string;
  contractHref: string;
  transport: {
    kind: 'window-message';
    requestType: string;
    resultType: string;
    target: 'window';
  };
  capabilities: {
    resources: Array<{
      uri: string;
      name: string;
      mimeType: string;
      description: string;
    }>;
  };
  sectionTypes: string[];
  sectionInstances: WebMcpSectionInstance[];
  tools: Array<Pick<WebMcpToolContract, 'name' | 'description'>>;
}

export interface OlonJsSiteManifestIndex {
  version: '1.0.0';
  kind: 'olonjs-mcp-manifest-index';
  generatedAt: string;
  pages: Array<{
    slug: string;
    title: string;
    description: string;
    manifestHref: string;
    contractHref: string;
    sectionTypes: string[];
  }>;
  collections?: Array<{
    source: string;
    dataHref: string;
    contractHref: string;
  }>;
}

export interface OlonJsCollectionContract {
  version: '1.0.0';
  kind: 'olonjs-collection-contract';
  source: string;
  dataHref: string;
  contractHref: string;
  recordKeyMustMatchItemId: true;
  itemSchema: Record<string, unknown>;
}

export interface BuildCollectionContractInput {
  source: string;
  schema: z.ZodTypeAny;
}

export interface BuildPageContractInput {
  slug: string;
  pageConfig: PageConfig;
  schemas: JsonPagesConfig['schemas'];
  submissionSchemas?: JsonPagesConfig['submissionSchemas'];
  siteConfig: SiteConfig;
}

export interface BuildSiteManifestInput {
  pages: Record<string, PageConfig>;
  schemas: JsonPagesConfig['schemas'];
  submissionSchemas?: JsonPagesConfig['submissionSchemas'];
  siteConfig: SiteConfig;
  collectionSchemas?: Record<string, z.ZodTypeAny>;
}

function cloneJson<T>(value: T): T {
  return value == null ? value : (JSON.parse(JSON.stringify(value)) as T);
}

function getTypeName(schema: z.ZodTypeAny): z.ZodFirstPartyTypeKind | undefined {
  return schema?._def?.typeName as z.ZodFirstPartyTypeKind | undefined;
}

function unwrapSchema(schema: z.ZodTypeAny) {
  let current: z.ZodTypeAny = schema;
  let isOptional = false;
  let isNullable = false;
  let defaultValue: unknown;

  for (;;) {
    const typeName = getTypeName(current);
    if (typeName === z.ZodFirstPartyTypeKind.ZodOptional) {
      isOptional = true;
      current = (current as z.ZodOptional<z.ZodTypeAny>)._def.innerType;
      continue;
    }
    if (typeName === z.ZodFirstPartyTypeKind.ZodDefault) {
      isOptional = true;
      if (defaultValue === undefined) {
        try {
          defaultValue = (current as z.ZodDefault<z.ZodTypeAny>)._def.defaultValue();
        } catch {
          defaultValue = undefined;
        }
      }
      current = (current as z.ZodDefault<z.ZodTypeAny>)._def.innerType;
      continue;
    }
    if (typeName === z.ZodFirstPartyTypeKind.ZodNullable) {
      isNullable = true;
      current = (current as z.ZodNullable<z.ZodTypeAny>)._def.innerType;
      continue;
    }
    break;
  }

  return { schema: current, isOptional, isNullable, defaultValue };
}

function withSchemaMetadata(
  schema: z.ZodTypeAny,
  jsonSchema: Record<string, unknown>,
  meta: ReturnType<typeof unwrapSchema>
): Record<string, unknown> {
  const next = cloneJson(jsonSchema) ?? {};
  if (schema.description && next.description == null) {
    next.description = schema.description;
  }
  if (meta.defaultValue !== undefined && next.default == null) {
    next.default = meta.defaultValue;
  }
  if (meta.isNullable) {
    return { anyOf: [next, { type: 'null' }] };
  }
  return next;
}

function unionToEnum(options: readonly z.ZodTypeAny[]): Record<string, unknown> | null {
  const values: unknown[] = [];
  let primitiveType: 'string' | 'number' | 'boolean' | null = null;

  for (const option of options) {
    const unwrapped = unwrapSchema(option).schema;
    const typeName = getTypeName(unwrapped);

    if (typeName === z.ZodFirstPartyTypeKind.ZodLiteral) {
      const literal = (unwrapped as z.ZodLiteral<unknown>)._def.value;
      values.push(literal);
      const literalType = typeof literal;
      if (literalType === 'string' || literalType === 'number' || literalType === 'boolean') {
        primitiveType = primitiveType ?? literalType;
        continue;
      }
      return null;
    }

    if (typeName === z.ZodFirstPartyTypeKind.ZodEnum) {
      values.push(...(unwrapped as z.ZodEnum<[string, ...string[]]>)._def.values);
      primitiveType = primitiveType ?? 'string';
      continue;
    }

    return null;
  }

  if (values.length === 0) return null;
  if (primitiveType === 'number') return { type: 'number', enum: values };
  if (primitiveType === 'boolean') return { type: 'boolean', enum: values };
  return { type: 'string', enum: values.map((value) => String(value)) };
}

function zodToJsonSchema(schema: z.ZodTypeAny): Record<string, unknown> {
  const meta = unwrapSchema(schema);
  const current = meta.schema;
  const typeName = getTypeName(current);

  switch (typeName) {
    case z.ZodFirstPartyTypeKind.ZodObject: {
      const shape = (current as z.AnyZodObject)._def.shape();
      const properties: Record<string, unknown> = {};
      const required: string[] = [];

      for (const [key, childSchema] of Object.entries(shape)) {
        const child = childSchema as z.ZodTypeAny;
        const childMeta = unwrapSchema(child);
        properties[key] = zodToJsonSchema(child);
        if (!childMeta.isOptional) required.push(key);
      }

      const objectSchema: Record<string, unknown> = {
        type: 'object',
        properties,
        additionalProperties: false,
      };
      if (required.length > 0) objectSchema.required = required;
      return withSchemaMetadata(schema, objectSchema, meta);
    }

    case z.ZodFirstPartyTypeKind.ZodString:
      return withSchemaMetadata(schema, { type: 'string' }, meta);

    case z.ZodFirstPartyTypeKind.ZodBoolean:
      return withSchemaMetadata(schema, { type: 'boolean' }, meta);

    case z.ZodFirstPartyTypeKind.ZodNumber: {
      const checks = Array.isArray((current as z.ZodNumber)._def.checks)
        ? (current as z.ZodNumber)._def.checks
        : [];
      const isInteger = checks.some((check) => check.kind === 'int');
      return withSchemaMetadata(schema, { type: isInteger ? 'integer' : 'number' }, meta);
    }

    case z.ZodFirstPartyTypeKind.ZodArray:
      return withSchemaMetadata(
        schema,
        { type: 'array', items: zodToJsonSchema((current as z.ZodArray<z.ZodTypeAny>)._def.type) },
        meta
      );

    case z.ZodFirstPartyTypeKind.ZodEnum:
      return withSchemaMetadata(
        schema,
        { type: 'string', enum: [...(current as z.ZodEnum<[string, ...string[]]>)._def.values] },
        meta
      );

    case z.ZodFirstPartyTypeKind.ZodLiteral: {
      const literal = (current as z.ZodLiteral<unknown>)._def.value;
      const primitiveType = literal === null ? 'null' : typeof literal;
      const literalSchema: Record<string, unknown> = { const: literal };
      if (primitiveType !== 'object') {
        literalSchema.type = primitiveType;
      }
      return withSchemaMetadata(schema, literalSchema, meta);
    }

    case z.ZodFirstPartyTypeKind.ZodRecord:
      return withSchemaMetadata(
        schema,
        {
          type: 'object',
          additionalProperties: zodToJsonSchema(
            (current as z.ZodRecord<z.ZodString, z.ZodTypeAny>)._def.valueType
          ),
        },
        meta
      );

    case z.ZodFirstPartyTypeKind.ZodUnion: {
      const options = (current as z.ZodUnion<readonly [z.ZodTypeAny, z.ZodTypeAny, ...z.ZodTypeAny[]]>)._def.options;
      const enumSchema = unionToEnum(options);
      if (enumSchema) return withSchemaMetadata(schema, enumSchema, meta);
      return withSchemaMetadata(
        schema,
        { anyOf: options.map((option) => zodToJsonSchema(option)) },
        meta
      );
    }

    default:
      return withSchemaMetadata(schema, {}, meta);
  }
}

function buildMutationInputSchema(): Record<string, unknown> {
  return {
    type: 'object',
    additionalProperties: false,
    properties: {
      slug: {
        type: 'string',
        description: 'Canonical page slug currently open in Studio.',
      },
      sectionId: {
        type: 'string',
        description: 'Concrete section instance id inside the current draft.',
      },
      sectionType: {
        type: 'string',
        description: 'Section type being updated (for example "hero" or "header"). Used to select the correct validation schema.',
      },
      scope: {
        type: 'string',
        enum: ['local', 'global'],
        default: 'local',
      },
      data: {
        type: 'object',
        description: 'Full replacement payload validated against the schema declared for sectionType.',
      },
      itemPath: {
        type: 'array',
        description: 'Optional root-to-leaf selection path for targeted field mutation.',
        items: {
          type: 'object',
          additionalProperties: false,
          properties: {
            fieldKey: { type: 'string' },
            itemId: { type: 'string' },
          },
          required: ['fieldKey'],
        },
      },
      value: {
        description: 'Value written to the final field targeted by itemPath.',
      },
      fieldKey: {
        type: 'string',
        description: 'Shorthand for a top-level scalar field update when itemPath is omitted.',
      },
    },
    required: ['sectionId'],
    oneOf: [
      { required: ['data'] },
      { required: ['itemPath', 'value'] },
      { required: ['fieldKey', 'value'] },
    ],
  };
}

function inferSectionLabel(section: { type?: string; data?: unknown }): string {
  const data = section.data && typeof section.data === 'object' ? (section.data as Record<string, unknown>) : {};
  if (typeof data.title === 'string' && data.title.trim()) return data.title.trim();
  if (typeof data.sectionTitle === 'string' && data.sectionTitle.trim()) return data.sectionTitle.trim();
  if (typeof data.label === 'string' && data.label.trim()) return data.label.trim();
  return section.type ?? 'section';
}

function buildToolName(): 'update-section' {
  return 'update-section';
}

export function buildPageContractHref(slug: string): string {
  return `/schemas/${slug}.schema.json`;
}

export function buildPageManifestHref(slug: string): string {
  return `/mcp-manifests/${slug}.json`;
}

function getPageSections(pageConfig: PageConfig, siteConfig: SiteConfig) {
  const pageSections = Array.isArray(pageConfig?.sections) ? pageConfig.sections : [];
  const globalSections: Array<(typeof pageSections)[number] & { scope: 'global' }> = [];

  if (siteConfig.header && pageConfig['global-header'] !== false) {
    globalSections.push({ ...siteConfig.header, scope: 'global' });
  }
  if (siteConfig.footer) {
    globalSections.push({ ...siteConfig.footer, scope: 'global' });
  }

  return [
    ...globalSections,
    ...pageSections.map((section) => ({ ...section, scope: 'local' as const })),
  ];
}

export function buildPageContract({
  slug,
  pageConfig,
  schemas,
  submissionSchemas,
  siteConfig,
}: BuildPageContractInput): OlonJsPageContract {
  const title = typeof pageConfig.meta?.title === 'string' ? pageConfig.meta.title : slug;
  const description = typeof pageConfig.meta?.description === 'string' ? pageConfig.meta.description : '';
  const pageSections = getPageSections(pageConfig, siteConfig);
  const sectionTypes = Array.from(new Set(pageSections.map((section) => String(section.type)).filter(Boolean)));

  const sectionSchemas = Object.fromEntries(
    sectionTypes
      .filter((sectionType) => schemas?.[sectionType] != null)
      .map((sectionType) => {
        const schema = schemas[sectionType] as z.ZodTypeAny;
        return [sectionType, zodToJsonSchema(schema)];
      })
  ) as Record<string, Record<string, unknown>>;

  const submissionSchemasEmitted = Object.fromEntries(
    sectionTypes
      .filter((sectionType) => submissionSchemas?.[sectionType] != null)
      .map((sectionType) => {
        const schema = submissionSchemas![sectionType] as z.ZodTypeAny;
        return [sectionType, zodToJsonSchema(schema)];
      })
  ) as Record<string, Record<string, unknown>>;

  const sectionInstances: WebMcpSectionInstance[] = pageSections.map((section) => ({
    id: section.id,
    type: String(section.type),
    scope: section.scope === 'global' ? 'global' : 'local',
    label: inferSectionLabel(section),
  }));

  const tools: WebMcpToolContract[] =
    sectionTypes.filter((sectionType) => sectionSchemas[sectionType] != null).length > 0
      ? [
          {
            name: buildToolName(),
            description:
              'Update a section field in the Studio draft. Does not persist — call save when all updates are complete. Use sectionType to select the matching schema from sectionSchemas.',
            inputSchema: buildMutationInputSchema(),
          },
          {
            name: 'save',
            description:
              'Persist all pending draft changes using the active save mode (local file, hot save, or save2repo). Call once after all update-section calls are complete.',
            inputSchema: { type: 'object', additionalProperties: false, properties: {} },
          },
        ]
      : [];

  const contract: OlonJsPageContract = {
    version: '1.0.0',
    kind: 'olonjs-page-contract',
    slug,
    title,
    description,
    manifestHref: buildPageManifestHref(slug),
    systemPrompt: `You are operating the "${title}" page in OlonJS Studio. Use only the declared tools and keep mutations valid against the section schema.`,
    sectionTypes,
    sectionInstances,
    sectionSchemas,
    tools,
  };

  if (Object.keys(submissionSchemasEmitted).length > 0) {
    contract.sectionSubmissionSchemas = submissionSchemasEmitted;
  }

  return contract;
}

export function buildPageManifest(input: BuildPageContractInput): OlonJsPageManifest {
  const contract = buildPageContract(input);
  return {
    version: '1.0.0',
    kind: 'olonjs-page-mcp-manifest',
    generatedAt: new Date().toISOString(),
    slug: input.slug,
    title: contract.title,
    description: contract.description,
    contractHref: buildPageContractHref(input.slug),
    transport: {
      kind: 'window-message',
      requestType: WEBMCP_TOOL_REQUEST_TYPE,
      resultType: WEBMCP_TOOL_RESULT_TYPE,
      target: 'window',
    },
    capabilities: {
      resources: [
        {
          uri: `olon://pages/${input.slug}`,
          name: `${contract.title} Data`,
          mimeType: 'application/json',
          description: `Structured content for the ${input.slug} page.`,
        },
        {
          uri: 'olon://pages',
          name: 'Site Map',
          mimeType: 'application/json',
          description: 'Structured content for the map of this site',
        },
      ],
    },
    sectionTypes: contract.sectionTypes,
    sectionInstances: contract.sectionInstances,
    tools: contract.tools.map(({ name, description }) => ({
      name,
      description,
    })),
  };
}

export function buildSiteManifest({
  pages,
  schemas,
  submissionSchemas,
  siteConfig,
  collectionSchemas,
}: BuildSiteManifestInput): OlonJsSiteManifestIndex {
  const pageEntries = Object.entries(pages ?? {}).sort(([a], [b]) => a.localeCompare(b));
  const manifest: OlonJsSiteManifestIndex = {
    version: '1.0.0',
    kind: 'olonjs-mcp-manifest-index',
    generatedAt: new Date().toISOString(),
    pages: pageEntries.map(([slug, pageConfig]) => {
      const pageManifest = buildPageManifest({ slug, pageConfig, schemas, submissionSchemas, siteConfig });
      return {
        slug,
        title: pageManifest.title,
        description: pageManifest.description,
        manifestHref: buildPageManifestHref(slug),
        contractHref: buildPageContractHref(slug),
        sectionTypes: pageManifest.sectionTypes,
      };
    }),
  };

  if (collectionSchemas && Object.keys(collectionSchemas).length > 0) {
    manifest.collections = Object.keys(collectionSchemas)
      .sort()
      .map((source) => ({
        source,
        dataHref: `/collections/${source}/${source}.json`,
        contractHref: buildCollectionContractHref(source),
      }));
  }

  return manifest;
}

export function buildCollectionContractHref(source: string): string {
  return `/schemas/collections/${source}.schema.json`;
}

export function buildCollectionContract({ source, schema }: BuildCollectionContractInput): OlonJsCollectionContract {
  const meta = unwrapSchema(schema);
  const current = meta.schema;
  const typeName = getTypeName(current);

  let valueSchema: z.ZodTypeAny;
  if (typeName === z.ZodFirstPartyTypeKind.ZodRecord) {
    valueSchema = (current as z.ZodRecord<z.ZodString, z.ZodTypeAny>)._def.valueType;
  } else {
    valueSchema = schema;
  }

  return {
    version: '1.0.0',
    kind: 'olonjs-collection-contract',
    source,
    dataHref: `/collections/${source}/${source}.json`,
    contractHref: buildCollectionContractHref(source),
    recordKeyMustMatchItemId: true,
    itemSchema: zodToJsonSchema(valueSchema),
  };
}

export function assertCollectionRecordKeys(
  source: string,
  collection: Record<string, unknown>
): void {
  for (const [key, item] of Object.entries(collection)) {
    if (item == null || typeof item !== 'object') {
      throw new Error(`[${source}] invalid item at key "${key}": expected an object`);
    }
    const id = (item as Record<string, unknown>).id;
    if (id !== key) {
      throw new Error(
        `[${source}] record key "${key}" must equal item.id but got "${String(id ?? 'undefined')}"`
      );
    }
  }
}

export function buildLlmsTxt(input: BuildSiteManifestInput): string {
  const siteTitle = input.siteConfig.identity?.title || 'OlonJS Site';
  const manifestIndex = buildSiteManifest(input);

  let markdown = `# ${siteTitle}\n\n`;

  if (manifestIndex.pages.some((page) => page.slug === 'home')) {
    const homePage = manifestIndex.pages.find((page) => page.slug === 'home');
    if (homePage?.description) {
      markdown += `${homePage.description}\n\n`;
    }
  }

  markdown += '> **AI Agents:** This site is built with OlonJS. It exposes a native Model Context Protocol (MCP) manifest for direct structural interaction. \n';
  markdown += '> To read the site map or access structured content, use the URI `olon://pages` or `olon://pages/[slug]`.\n';
  markdown += '> Endpoint: `/mcp-manifest.json`\n\n';
  markdown += '## Pages\n\n';

  for (const page of manifestIndex.pages) {
    const urlPath = page.slug === 'home' ? '/' : `/${page.slug}`;
    markdown += `- **[${page.title}](${urlPath})** (\`${page.slug}\`)\n`;
    if (page.description) {
      markdown += `  ${page.description}\n`;
    }
    markdown += `  *Contract:* \`${page.contractHref}\` | *Manifest:* \`${page.manifestHref}\`\n\n`;
  }

  return markdown.trim();
}
