import { describe, expect, it, vi } from 'vitest';
import { z } from 'zod';
import { applyCollectionRefBindingsToDraft } from '../../contract/config-resolver';
import {
  applyValueAtSelectionPath,
  buildWebMcpToolName,
  ensureWebMcpRuntime,
  registerWebMcpTool,
  resolveWebMcpMutationData,
} from './webmcp-bridge';

describe('webmcp runtime bridge', () => {
  const bookCollectionSchemas = {
    libri: z.record(
      z.object({
        id: z.string(),
        title: z.string(),
        author: z.string(),
        summary: z.string().optional(),
      })
    ),
  };

  it('builds deterministic tool names', () => {
    expect(buildWebMcpToolName()).toBe('update-section');
  });

  it('applies scalar updates through a root field path', () => {
    expect(
      resolveWebMcpMutationData(
        { title: 'Before', description: 'Copy' },
        { sectionId: 'hero-main', fieldKey: 'title', value: 'After' }
      )
    ).toEqual({ title: 'After', description: 'Copy' });
  });

  it('applies nested array updates through itemPath', () => {
    const next = applyValueAtSelectionPath(
      {
        ctas: [
          { id: 'cta-1', label: 'Primary', href: '/before' },
          { id: 'cta-2', label: 'Docs', href: '/docs' },
        ],
      },
      [
        { fieldKey: 'ctas', itemId: 'cta-1' },
        { fieldKey: 'href' },
      ],
      '/after'
    );

    expect(next).toEqual({
      ctas: [
        { id: 'cta-1', label: 'Primary', href: '/after' },
        { id: 'cta-2', label: 'Docs', href: '/docs' },
      ],
    });
  });

  it('replaces the full data payload when data is provided', () => {
    const next = resolveWebMcpMutationData(
      { title: 'Old', description: 'Body' },
      {
        sectionId: 'hero-main',
        data: { title: 'New', description: 'Updated' },
      }
    );

    expect(next).toEqual({ title: 'New', description: 'Updated' });
  });

  it('supports agent full-field replacement for a collection record ref while preserving the authored page ref', () => {
    const authoredData = {
      title: 'Libri',
      items: { $ref: '../collections/libri/libri.json' },
    };
    const updatedCollection = {
      dune: {
        id: 'dune',
        title: 'Dune Messiah',
        author: 'Frank Herbert',
      },
      neuromancer: {
        id: 'neuromancer',
        title: 'Neuromancer',
        author: 'William Gibson',
      },
    };

    const nextData = resolveWebMcpMutationData(authoredData, {
      sectionId: 'books-list',
      sectionType: 'books-list',
      fieldKey: 'items',
      value: updatedCollection,
    });

    const result = applyCollectionRefBindingsToDraft(
      authoredData,
      nextData,
      {
        libri: {
          dune: {
            id: 'dune',
            title: 'Dune',
            author: 'Frank Herbert',
          },
        },
      },
      undefined,
      bookCollectionSchemas
    );

    expect(result.normalizedData.items).toEqual({ $ref: '../collections/libri/libri.json' });
    expect(result.collectionsDraft?.libri).toEqual(updatedCollection);
  });

  it('supports agent full-field replacement for collection:current while preserving the authored detail ref', () => {
    const authoredData = {
      item: { $ref: 'collection:current' },
      backLabel: 'Torna ai libri',
    };
    const updatedBook = {
      id: 'dune',
      title: 'Dune Messiah',
      author: 'Frank Herbert',
      summary: 'Updated by an agent.',
    };

    const nextData = resolveWebMcpMutationData(authoredData, {
      sectionId: 'book-detail',
      sectionType: 'book-detail',
      fieldKey: 'item',
      value: updatedBook,
    });

    const result = applyCollectionRefBindingsToDraft(
      authoredData,
      nextData,
      {
        libri: {
          dune: {
            id: 'dune',
            title: 'Dune',
            author: 'Frank Herbert',
          },
        },
      },
      {
        source: 'libri',
        paramKey: 'slug',
        paramValue: 'dune',
        currentItem: {
          id: 'dune',
          title: 'Dune',
          author: 'Frank Herbert',
        },
      },
      bookCollectionSchemas
    );

    expect(result.normalizedData.item).toEqual({ $ref: 'collection:current' });
    expect(result.collectionsDraft?.libri?.dune).toEqual(updatedBook);
  });

  it('installs a testing shim on document.modelContext', async () => {
    const originalWindow = globalThis.window;
    const originalDocument = globalThis.document;
    Object.defineProperty(globalThis, 'window', {
      value: {} as Window,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(globalThis, 'document', {
      value: {} as Document,
      configurable: true,
      writable: true,
    });

    ensureWebMcpRuntime();

    try {
      const unregister = registerWebMcpTool({
        name: 'update-section',
        description: 'Update section',
        inputSchema: { type: 'object', properties: {} },
        execute: async () => ({
          content: [{ type: 'text', text: 'ok' }],
          isError: false,
        }),
      });

      expect(document.modelContext?.registerTool).toEqual(expect.any(Function));
      expect(document.modelContextProtocol?.listTools).toEqual(expect.any(Function));

      const tools = document.modelContextProtocol?.listTools?.() ?? [];
      expect(tools.map((tool) => tool.name)).toContain('update-section');

      const result = await document.modelContextProtocol?.executeTool?.('update-section', '{}');
      expect(JSON.parse(result ?? '{}')).toMatchObject({
        content: [{ type: 'text', text: 'ok' }],
        isError: false,
      });

      unregister();
    } finally {
      Object.defineProperty(globalThis, 'window', {
        value: originalWindow,
        configurable: true,
        writable: true,
      });
      Object.defineProperty(globalThis, 'document', {
        value: originalDocument,
        configurable: true,
        writable: true,
      });
    }
  });

  it('delegates registration to a pre-existing document.modelContext.registerTool with an AbortSignal (Chrome native WebMCP)', () => {
    const originalWindow = globalThis.window;
    const originalDocument = globalThis.document;
    if (globalThis.window) {
      delete (globalThis.window as unknown as { __olonWebMcpControllers__?: unknown }).__olonWebMcpControllers__;
    }

    const nativeRegisterTool = vi.fn();
    const nativeModelContext = { registerTool: nativeRegisterTool };

    Object.defineProperty(globalThis, 'window', {
      value: {} as Window,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(globalThis, 'document', {
      value: { modelContext: nativeModelContext } as Document,
      configurable: true,
      writable: true,
    });

    try {
      const tool = {
        name: 'update-section',
        description: 'Update section',
        inputSchema: { type: 'object', properties: {} },
        execute: async () => ({ content: [{ type: 'text', text: 'ok' }], isError: false }),
      };

      const unregister = registerWebMcpTool(tool);

      expect(nativeRegisterTool).toHaveBeenCalledTimes(1);
      const [calledTool, calledOptions] = nativeRegisterTool.mock.calls[0] as [
        unknown,
        { signal: AbortSignal },
      ];
      expect(calledTool).toBe(tool);
      expect(calledOptions.signal).toBeInstanceOf(AbortSignal);
      expect(calledOptions.signal.aborted).toBe(false);

      unregister();
      expect(calledOptions.signal.aborted).toBe(true);
    } finally {
      Object.defineProperty(globalThis, 'window', {
        value: originalWindow,
        configurable: true,
        writable: true,
      });
      Object.defineProperty(globalThis, 'document', {
        value: originalDocument,
        configurable: true,
        writable: true,
      });
    }
  });

  it('aborts a prior registration before re-registering the same tool name (React StrictMode safety on Chrome native WebMCP)', () => {
    const originalWindow = globalThis.window;
    const originalDocument = globalThis.document;
    if (globalThis.window) {
      delete (globalThis.window as unknown as { __olonWebMcpControllers__?: unknown }).__olonWebMcpControllers__;
    }

    const registeredNames = new Set<string>();
    const nativeRegisterTool = vi.fn(
      (t: { name: string }, options?: { signal?: AbortSignal }) => {
        if (registeredNames.has(t.name)) {
          throw new Error('InvalidStateError: Duplicate tool name');
        }
        registeredNames.add(t.name);
        options?.signal?.addEventListener('abort', () => {
          registeredNames.delete(t.name);
        });
      }
    );

    Object.defineProperty(globalThis, 'window', {
      value: {} as Window,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(globalThis, 'document', {
      value: { modelContext: { registerTool: nativeRegisterTool } } as Document,
      configurable: true,
      writable: true,
    });

    try {
      const tool = {
        name: 'update-section',
        description: 'Update section',
        inputSchema: { type: 'object', properties: {} },
        execute: async () => ({ content: [{ type: 'text', text: 'ok' }], isError: false }),
      };

      expect(() => {
        registerWebMcpTool(tool);
        registerWebMcpTool(tool);
      }).not.toThrow();

      expect(nativeRegisterTool).toHaveBeenCalledTimes(2);
      const firstSignal = (nativeRegisterTool.mock.calls[0][1] as { signal: AbortSignal }).signal;
      const secondSignal = (nativeRegisterTool.mock.calls[1][1] as { signal: AbortSignal }).signal;
      expect(firstSignal.aborted).toBe(true);
      expect(secondSignal.aborted).toBe(false);
      expect(registeredNames.has('update-section')).toBe(true);
    } finally {
      Object.defineProperty(globalThis, 'window', {
        value: originalWindow,
        configurable: true,
        writable: true,
      });
      Object.defineProperty(globalThis, 'document', {
        value: originalDocument,
        configurable: true,
        writable: true,
      });
    }
  });
});
