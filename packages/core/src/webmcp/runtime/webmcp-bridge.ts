import type { SelectionPath } from '../../contract/types-engine';

export interface WebMcpMutationArgs {
  slug?: string;
  sectionId: string;
  sectionType?: string;
  scope?: 'global' | 'local';
  data?: Record<string, unknown>;
  itemPath?: SelectionPath;
  fieldKey?: string;
  value?: unknown;
}

type WebMcpTool = {
  name: string;
  description: string;
  inputSchema: Record<string, unknown>;
  execute: (args: unknown) => Promise<unknown> | unknown;
};

type WebMcpToolInfo = Omit<WebMcpTool, 'execute'>;

type WebMcpRegisterToolOptions = { signal?: AbortSignal };

type ModelContextLike = {
  registerTool?: (tool: WebMcpTool, options?: WebMcpRegisterToolOptions) => void;
  unregisterTool?: (name: string) => void;
  readResource?: (uri: string) => Promise<unknown>;
};

type ModelContextProtocolLike = {
  listTools?: () => WebMcpToolInfo[];
  executeTool?: (toolName: string, inputArgsJson: string) => Promise<string>;
  readResource?: (uri: string) => Promise<string>;
};

type WebMcpWindow = Window & {
  __olonWebMcpTools__?: Map<string, WebMcpTool>;
  __olonWebMcpControllers__?: Map<string, AbortController>;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function cloneJson<T>(value: T): T {
  return value == null ? value : (JSON.parse(JSON.stringify(value)) as T);
}

function getToolRegistry(): Map<string, WebMcpTool> | null {
  if (typeof window === 'undefined') return null;
  const webMcpWindow = window as WebMcpWindow;
  if (!webMcpWindow.__olonWebMcpTools__) {
    webMcpWindow.__olonWebMcpTools__ = new Map<string, WebMcpTool>();
  }
  return webMcpWindow.__olonWebMcpTools__;
}

function getControllerRegistry(): Map<string, AbortController> | null {
  if (typeof window === 'undefined') return null;
  const webMcpWindow = window as WebMcpWindow;
  if (!webMcpWindow.__olonWebMcpControllers__) {
    webMcpWindow.__olonWebMcpControllers__ = new Map<string, AbortController>();
  }
  return webMcpWindow.__olonWebMcpControllers__;
}

export function buildWebMcpToolName(): string {
  return 'update-section';
}

export function buildWebMcpSaveToolName(): string {
  return 'save';
}

export function createWebMcpSaveToolInputSchema(): Record<string, unknown> {
  return {
    type: 'object',
    additionalProperties: false,
    properties: {},
  };
}

export function parseWebMcpMutationArgs(rawArgs: unknown): WebMcpMutationArgs {
  if (!isRecord(rawArgs) || typeof rawArgs.sectionId !== 'string') {
    throw new Error('WebMCP mutation requires a sectionId.');
  }

  const parsedArgs: WebMcpMutationArgs = {
    sectionId: rawArgs.sectionId,
  };

  if (typeof rawArgs.slug === 'string') {
    parsedArgs.slug = rawArgs.slug;
  }

  if (typeof rawArgs.sectionType === 'string') {
    parsedArgs.sectionType = rawArgs.sectionType;
  }

  if (rawArgs.scope === 'global' || rawArgs.scope === 'local') {
    parsedArgs.scope = rawArgs.scope;
  }

  if (isRecord(rawArgs.data)) {
    parsedArgs.data = rawArgs.data;
  }

  if (Array.isArray(rawArgs.itemPath)) {
    parsedArgs.itemPath = rawArgs.itemPath
      .filter((segment): segment is SelectionPath[number] => {
        if (!isRecord(segment) || typeof segment.fieldKey !== 'string') {
          return false;
        }
        return segment.itemId == null || typeof segment.itemId === 'string';
      })
      .map((segment) => ({
        fieldKey: segment.fieldKey,
        ...(typeof segment.itemId === 'string' ? { itemId: segment.itemId } : {}),
      }));
  }

  if (typeof rawArgs.fieldKey === 'string') {
    parsedArgs.fieldKey = rawArgs.fieldKey;
  }

  if ('value' in rawArgs) {
    parsedArgs.value = rawArgs.value;
  }

  return parsedArgs;
}

export type WebMcpSectionCatalogEntry = { id: string; type: string };

export function createWebMcpToolInputSchema(
  catalog?: ReadonlyArray<WebMcpSectionCatalogEntry>
): Record<string, unknown> {
  const ids = catalog ? Array.from(new Set(catalog.map((entry) => entry.id))) : [];
  const types = catalog ? Array.from(new Set(catalog.map((entry) => entry.type))) : [];

  const sectionIdSchema: Record<string, unknown> = {
    type: 'string',
    description:
      'The unique ID of the section to update. Pick one from the enum below; these are the only valid IDs for the current page.',
  };
  if (ids.length > 0) sectionIdSchema.enum = ids;

  const sectionTypeSchema: Record<string, unknown> = {
    type: 'string',
    description:
      'The type of the section being updated (e.g. "olon-hero"). Used to pick the correct validation schema.',
  };
  if (types.length > 0) sectionTypeSchema.enum = types;

  return {
    type: 'object',
    additionalProperties: false,
    properties: {
      slug: { type: 'string' },
      sectionId: sectionIdSchema,
      sectionType: sectionTypeSchema,
      scope: { type: 'string', enum: ['local', 'global'], default: 'local' },
      data: {
        type: 'object',
        description: `Full replacement payload validated against the section's schema.`,
      },
      itemPath: {
        type: 'array',
        description: 'Optional root-to-leaf path for targeted field updates.',
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
      fieldKey: {
        type: 'string',
        description: 'Shorthand for a top-level scalar field update when itemPath is omitted.',
      },
      value: {
        description: 'Value written to the targeted field or array item.',
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

export function applyValueAtSelectionPath(
  rootData: Record<string, unknown>,
  selectionPath: SelectionPath,
  value: unknown
): Record<string, unknown> {
  if (selectionPath.length === 0) {
    throw new Error('Selection path is empty.');
  }

  const draft = cloneJson(rootData);
  let cursor: unknown = draft;

  for (let index = 0; index < selectionPath.length; index += 1) {
    const segment = selectionPath[index];
    const isLast = index === selectionPath.length - 1;

    if (!isRecord(cursor)) {
      throw new Error(`Cannot navigate path segment "${segment.fieldKey}" on a non-object value.`);
    }

    if (segment.itemId != null) {
      const arrayValue = cursor[segment.fieldKey];
      if (!Array.isArray(arrayValue)) {
        throw new Error(`Field "${segment.fieldKey}" is not an array.`);
      }
      const itemIndex = arrayValue.findIndex(
        (item) => isRecord(item) && String(item.id ?? '') === String(segment.itemId)
      );
      if (itemIndex === -1) {
        throw new Error(`Array item "${segment.itemId}" not found under "${segment.fieldKey}".`);
      }
      if (isLast) {
        arrayValue[itemIndex] = value;
        return draft;
      }
      cursor = arrayValue[itemIndex];
      continue;
    }

    if (isLast) {
      cursor[segment.fieldKey] = value;
      return draft;
    }

    cursor = cursor[segment.fieldKey];
  }

  return draft;
}

export function resolveWebMcpMutationData(
  currentData: Record<string, unknown>,
  args: WebMcpMutationArgs
): Record<string, unknown> {
  if (args.data && isRecord(args.data)) {
    return cloneJson(args.data);
  }

  if (Array.isArray(args.itemPath) && args.itemPath.length > 0) {
    return applyValueAtSelectionPath(currentData, args.itemPath, args.value);
  }

  if (typeof args.fieldKey === 'string' && args.fieldKey.trim().length > 0) {
    return applyValueAtSelectionPath(currentData, [{ fieldKey: args.fieldKey }], args.value);
  }

  throw new Error('WebMCP mutation requires either "data", "itemPath", or "fieldKey".');
}

async function resolveResource(uri: string): Promise<unknown> {
  const baseUrl = window.location.pathname
    .replace(/\/admin(\/.*)?$/, '')
    .replace(/\/$/, '');

  if (uri === 'olon://pages' || uri === 'olon://pages/') {
    const response = await fetch(`${baseUrl}/mcp-manifest.json`);
    if (!response.ok) {
      throw new Error(`Resource not found: ${uri} (at ${baseUrl}/mcp-manifest.json)`);
    }
    const manifestIndex = await response.json();
    return {
      pages: (manifestIndex.pages || []).map((page: unknown) => {
        const typedPage = page as {
          slug?: unknown;
          title?: unknown;
          contractHref?: unknown;
        };
        return {
          slug: typedPage.slug,
          title: typedPage.title,
          contract: typedPage.contractHref,
        };
      }),
    };
  }

  if (uri.startsWith('olon://pages/')) {
    const slug = uri.replace('olon://pages/', '');
    const response = await fetch(`${baseUrl}/pages/${slug}.json`);
    if (!response.ok) {
      throw new Error(`Resource not found: ${uri} (at ${baseUrl}/pages/${slug}.json)`);
    }
    return await response.json();
  }

  throw new Error(`Unsupported URI scheme: ${uri}`);
}

export function ensureWebMcpRuntime(): void {
  if (typeof window === 'undefined' || typeof navigator === 'undefined') return;

  const currentNavigator = navigator as Navigator & {
    modelContext?: ModelContextLike;
    modelContextProtocol?: ModelContextProtocolLike;
  };

  // If a registerTool already exists — Chrome 146+ native WebMCP, or our polyfill from
  // a previous call — leave it intact so tools flow into the registry the WebMCP Inspector
  // reads via navigator.modelContextTesting.
  if (typeof currentNavigator.modelContext?.registerTool === 'function') return;

  const registry = getToolRegistry();
  if (!registry) return;

  if (!currentNavigator.modelContext) {
    currentNavigator.modelContext = {};
  }

  currentNavigator.modelContext.registerTool = (
    tool: WebMcpTool,
    options?: WebMcpRegisterToolOptions
  ) => {
    registry.set(tool.name, tool);
    options?.signal?.addEventListener('abort', () => {
      if (registry.get(tool.name) === tool) {
        registry.delete(tool.name);
      }
    });
  };

  currentNavigator.modelContext.unregisterTool = (name: string) => {
    registry.delete(name);
  };

  currentNavigator.modelContext.readResource = async (uri: string) => resolveResource(uri);

  currentNavigator.modelContextProtocol = {
    listTools: () =>
      Array.from(registry.values()).map(({ execute: _execute, ...toolInfo }) => toolInfo),
    executeTool: async (toolName: string, inputArgsJson: string) => {
      const tool = registry.get(toolName);
      if (!tool) {
        throw new Error(`WebMCP tool "${toolName}" is not registered.`);
      }

      const parsedArgs = inputArgsJson ? JSON.parse(inputArgsJson) : {};
      const result = await tool.execute(parsedArgs);
      return JSON.stringify(result);
    },
    readResource: async (uri: string) => JSON.stringify(await resolveResource(uri)),
  };
}

export function registerWebMcpTool(tool: WebMcpTool): () => void {
  if (typeof window === 'undefined' || typeof navigator === 'undefined') {
    return () => undefined;
  }

  ensureWebMcpRuntime();

  const currentNavigator = navigator as Navigator & {
    modelContext?: ModelContextLike;
  };

  const modelContext = currentNavigator.modelContext;
  if (typeof modelContext?.registerTool !== 'function') {
    return () => undefined;
  }

  // The native Chrome WebMCP API throws InvalidStateError on duplicate tool names
  // and exposes deregistration only via the AbortSignal option passed to registerTool.
  // We track one controller per tool name so a re-registration (React StrictMode
  // double-invocation, HMR, or effect re-run) cleanly aborts the previous one first.
  const controllers = getControllerRegistry();
  controllers?.get(tool.name)?.abort();

  const controller = new AbortController();
  controllers?.set(tool.name, controller);

  modelContext.registerTool(tool, { signal: controller.signal });

  return () => {
    controller.abort();
    if (controllers?.get(tool.name) === controller) {
      controllers.delete(tool.name);
    }
  };
}
