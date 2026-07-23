/**
 * @olonjs/next — Next.js host binding for OlonJS (ADR-0017).
 * Prefer subpath imports: `@olonjs/next/server`, `@olonjs/next/client`.
 */
export { OLONJS_NEXT_SERVER } from './server/packageInfo';
export { OLONJS_NEXT_CLIENT } from './client/packageInfo';
export { safeDataSlugPath } from './server/fsPaths';
export {
  MAX_UPLOAD_BYTES,
  listLocalImages,
  resolveLocalDataRoots,
  saveProjectStateToDisk,
  saveUploadedImage,
} from './server/localPersistence';
