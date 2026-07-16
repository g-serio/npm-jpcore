/**
 * Canonical contract surface for OlonJS core.
 *
 * `src/contract/` is the transition target for protocol, structural
 * types, config resolution, and agent-facing contracts. Legacy paths
 * under `src/lib/` remain compatibility shims during the migration.
 */
export * from './kernel';
export * from './types-engine';
export * from './config-resolver';
export * from './webmcp-contracts';
export * from './theme-logic';
export * from './section-ops';
export * from './selection-path';
export * from './studio-events';
