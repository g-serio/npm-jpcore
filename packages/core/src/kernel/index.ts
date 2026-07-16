/**
 * Conceptual public surface for OlonJS kernel/contract concerns.
 *
 * This barrel is intentionally package-local for now: it lets us
 * converge imports around the future split without breaking the current
 * @olonjs/core entrypoint.
 */
export * from '../contract/kernel';
export * from '../contract/types-engine';
export {
  applyMenuRefBindingsToDraft,
  applySiteMenuRefBindingsToDraft,
  getMenuRefBindings,
  resolveHeaderMenuItems,
  resolveRuntimeConfig,
  resolveSectionMenuItems,
} from '../contract/config-resolver';
