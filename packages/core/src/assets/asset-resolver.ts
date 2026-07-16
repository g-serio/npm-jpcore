/**
 * Centralized asset resolution for tenant-scoped static assets.
 */
import { withBasePath } from '../url';

const FILE_EXTENSION_RE = /\.(jpg|jpeg|png|gif|svg|pdf|webp|mp4|webm|ogg)$/i;
const WINDOWS_PATH_RE = /^[a-zA-Z]:[\\/]/;
const ABSOLUTE_URL_RE = /^[a-zA-Z][a-zA-Z\d+\-.]*:/;

const isAbsoluteUrl = (path: string): boolean => ABSOLUTE_URL_RE.test(path);

export const isTransientAssetUrl = (path: string): boolean => {
  const value = path.trim();
  return value.startsWith('data:') || value.startsWith('blob:');
};

export const isCanonicalAssetUrl = (path: string): boolean => {
  const value = path.trim();
  if (!value || value.startsWith('#') || isTransientAssetUrl(value)) return false;
  if (value.startsWith('public/') || value.startsWith('public\\')) return false;
  if (WINDOWS_PATH_RE.test(value) || value.startsWith('\\\\')) return false;
  if (isAbsoluteUrl(value)) return true;
  return value.startsWith('/assets/') || value.startsWith('/uploaded-assets/');
};

export const resolveAssetUrl = (
  path: string,
  tenantId: string = 'default',
  basePath: string = '/'
): string => {
  const value = path.trim();
  if (!value) return value;

  if (isAbsoluteUrl(value) || value.startsWith('#')) {
    return value;
  }

  if (value.startsWith('/assets/') || value.startsWith('/uploaded-assets/')) return withBasePath(value, basePath);
  if (value.startsWith('assets/')) return withBasePath(`/${value}`, basePath);

  const hasFileExtension = FILE_EXTENSION_RE.test(value);
  if (!hasFileExtension) {
    return withBasePath(value.startsWith('/') ? value : `/${value}`, basePath);
  }

  const cleanPath = value.replace(/^\//, '');
  return withBasePath(`/assets/${tenantId}/${cleanPath}`, basePath);
};
