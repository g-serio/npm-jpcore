function normalizeApiBase(raw: string): string {
  return raw.trim().replace(/\/+$/, '');
}

/**
 * Prefer …/api/v1, keep raw base as fallback candidate.
 */
export function buildApiCandidates(raw: string): string[] {
  const base = normalizeApiBase(raw);
  if (!base) return [];
  const withApi = /\/api\/v1$/i.test(base) ? base : `${base}/api/v1`;
  return Array.from(new Set([withApi, base]));
}
