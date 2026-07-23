export type ServerCloudBootSource = 'local' | 'static' | 'live';

export type ServerCloudPolicy = {
  bootSource: ServerCloudBootSource;
  apiUrl: string;
  apiKey: string;
  save2RepoEnabled: boolean;
};

/**
 * Server-safe cloud policy (mirrors `@olonjs/react` resolveCloudPolicy).
 * Do not import `@olonjs/react` from Route Handlers — its package entry is client-bound.
 */
export function readServerCloudPolicy(
  env: Record<string, string | undefined> = process.env,
): ServerCloudPolicy {
  const apiUrl =
    (env.NEXT_PUBLIC_OLONJS_CLOUD_URL ?? env.NEXT_PUBLIC_JSONPAGES_CLOUD_URL ?? '').trim();
  const apiKey =
    (env.NEXT_PUBLIC_OLONJS_API_KEY ?? env.NEXT_PUBLIC_JSONPAGES_API_KEY ?? '').trim();
  const save2RepoRaw =
    env.NEXT_PUBLIC_OLONJS_SAVE2REPO ?? env.NEXT_PUBLIC_SAVE2REPO ?? '';
  const save2RepoFlag = save2RepoRaw === 'true';
  const isCloudMode = Boolean(apiUrl && apiKey);
  const save2RepoEnabled = isCloudMode && save2RepoFlag;

  let bootSource: ServerCloudBootSource = 'local';
  if (isCloudMode) {
    bootSource = save2RepoEnabled ? 'static' : 'live';
  }

  return { bootSource, apiUrl, apiKey, save2RepoEnabled };
}

/** Prefer …/api/v1, keep raw base as fallback (mirrors `@olonjs/react` buildApiCandidates). */
export function buildServerApiCandidates(raw: string): string[] {
  const base = raw.trim().replace(/\/+$/, '');
  if (!base) return [];
  const withApi = /\/api\/v1$/i.test(base) ? base : `${base}/api/v1`;
  return Array.from(new Set([withApi, base]));
}
