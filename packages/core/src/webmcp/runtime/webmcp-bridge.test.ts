import { describe, expect, it, vi } from 'vitest';
import {
  applyValueAtSelectionPath,
  buildWebMcpToolName,
  ensureWebMcpRuntime,
  registerWebMcpTool,
  resolveWebMcpMutationData,
} from './webmcp-bridge';

describe('webmcp runtime bridge', () => {
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

  it('installs a testing shim that can execute registered tools', async () => {
    const originalWindow = globalThis.window;
    const originalNavigator = globalThis.navigator;
    Object.defineProperty(globalThis, 'window', {
      value: {} as Window,
      configurable: true,
      writable: true,
    });
    Object.defineProperty(globalThis, 'navigator', {
      value: {} as Navigator,
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

      const tools = navigator.modelContextProtocol?.listTools?.() ?? [];
      expect(tools.map((tool) => tool.name)).toContain('update-section');

      const result = await navigator.modelContextProtocol?.executeTool?.('update-section', '{}');
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
      Object.defineProperty(globalThis, 'navigator', {
        value: originalNavigator,
        configurable: true,
        writable: true,
      });
    }
  });

  it('delegates registration to a pre-existing navigator.modelContext.registerTool with an AbortSignal (Chrome native WebMCP)', () => {
    const originalWindow = globalThis.window;
    const originalNavigator = globalThis.navigator;
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
    Object.defineProperty(globalThis, 'navigator', {
      value: { modelContext: nativeModelContext } as Navigator,
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
      Object.defineProperty(globalThis, 'navigator', {
        value: originalNavigator,
        configurable: true,
        writable: true,
      });
    }
  });

  it('aborts a prior registration before re-registering the same tool name (React StrictMode safety on Chrome native WebMCP)', () => {
    const originalWindow = globalThis.window;
    const originalNavigator = globalThis.navigator;
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
    Object.defineProperty(globalThis, 'navigator', {
      value: { modelContext: { registerTool: nativeRegisterTool } } as Navigator,
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
      Object.defineProperty(globalThis, 'navigator', {
        value: originalNavigator,
        configurable: true,
        writable: true,
      });
    }
  });
});
