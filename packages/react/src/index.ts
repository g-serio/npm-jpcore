/**
 * @olonjs/react — public entry point.
 *
 * React rendering bindings for the OlonJS engine: `JsonPagesEngine` (full,
 * visitor + admin + preview routes) and `OlonJSEngine` (visitor-only,
 * zero `@olonjs/studio` reference anywhere in its import graph). Depends
 * on `@olonjs/core`; the only edge to `@olonjs/studio` is the dynamic
 * import inside `StudioRoute` (see `engine/StudioRoute.tsx`).
 */
export * from './engine';
export * from './rendering';
export * from './theme';
export * from './config';
export { StudioProvider, useStudio } from './studio-mode/StudioContext';
export { IconRegistryContext, useIconRegistry, type IconRegistry } from './icons/IconRegistryContext';
export { DefaultNotFound } from './lib/DefaultNotFound';
export { OlonFormsContext, useFormState, type FormState, type FormStatus } from './dna/lib/OlonFormsContext';
export {
  resolveCloudPolicy,
  readCloudEnvFromVite,
  buildApiCandidates,
  createHotSaveHandler,
  type CloudBootSource,
  type CloudEnvInput,
  type CloudPolicy,
  type ViteCloudEnvBag,
  type CreateHotSaveHandlerOptions,
  type HotSaveHandler,
} from './cloud';
