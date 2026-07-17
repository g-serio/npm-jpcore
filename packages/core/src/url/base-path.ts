const ABSOLUTE_URL_RE = /^[a-zA-Z][a-zA-Z\d+\-.]*:/;

export function normalizeBasePath(value?: string): string {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (!raw || raw === '/') return '/';

  const withLeadingSlash = raw.startsWith('/') ? raw : `/${raw}`;
  const withoutTrailingSlashes = withLeadingSlash.replace(/\/+$/, '');
  return withoutTrailingSlashes.length > 0 ? `${withoutTrailingSlashes}/` : '/';
}

export function withBasePath(pathname: string, basePath?: string): string {
  const value = pathname.trim();
  if (!value) return normalizeBasePath(basePath);
  if (ABSOLUTE_URL_RE.test(value) || value.startsWith('#')) return value;

  const normalizedBasePath = normalizeBasePath(basePath);
  const normalizedPath = value.startsWith('/') ? value : `/${value}`;
  if (normalizedBasePath === '/') return normalizedPath;

  const withoutLeadingSlash = normalizedPath.replace(/^\/+/, '');
  return `${normalizedBasePath}${withoutLeadingSlash}`;
}
