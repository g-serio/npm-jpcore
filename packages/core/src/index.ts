/**
 * @olonjs/core - Public API
 *
 * Pure TypeScript engine — zero React, zero DOM-framework dependency.
 * Protocol types, config/collection resolution, theme-token logic,
 * WebMCP contracts + browser bridge, asset/base-path/routing helpers,
 * and the DNA surface (schemas tenants must not fork). Consumed by both
 * `@olonjs/react` (rendering bindings) and `@olonjs/studio` (editor UI),
 * which otherwise share no dependency on each other.
 */

// Conceptual namespaced surfaces.
export * as contract from './contract';
export * as kernel from './kernel';
export * as webmcp from './webmcp';

// Flat surface.
export * from './contract';
export * from './lib/utils';
export * from './dna';
export * from './assets';
export * from './url';
export * from './routing';
export {
  applyValueAtSelectionPath,
  buildWebMcpToolName,
  buildWebMcpSaveToolName,
  createWebMcpToolInputSchema,
  createWebMcpSaveToolInputSchema,
  ensureWebMcpRuntime,
  parseWebMcpMutationArgs,
  registerWebMcpTool,
  resolveModelContext,
  resolveWebMcpMutationData,
  type WebMcpMutationArgs,
} from './webmcp';
