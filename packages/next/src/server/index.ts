/**
 * @olonjs/next/server — host binding for Next.js (loaders, route handlers, visitor helpers).
 * No React client runtime here.
 */
export { OLONJS_NEXT_SERVER } from './packageInfo';
export { safeDataSlugPath } from './fsPaths';
export {
  MAX_UPLOAD_BYTES,
  listLocalImages,
  resolveLocalDataRoots,
  saveProjectStateToDisk,
  saveUploadedImage,
  type LocalDataRoots,
  type ProjectStateLike,
} from './localPersistence';
