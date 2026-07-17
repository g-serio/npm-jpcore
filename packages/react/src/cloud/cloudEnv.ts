import type { CloudEnvInput } from './cloudPolicy';

function readString(env: Record<string, unknown>, key: string): string {
  const value = env[key];
  return typeof value === 'string' ? value.trim() : '';
}

/** Vite `import.meta.env` bag (caller-supplied; no ImportMeta in this package). */
export type ViteCloudEnvBag = Record<string, unknown>;

/**
 * Map Vite env bag → CloudEnvInput.
 * Caller passes `import.meta.env` from the app (keeps this package free of ImportMeta coupling).
 */
export function readCloudEnvFromVite(env: ViteCloudEnvBag): CloudEnvInput {
  const apiUrl =
    readString(env, 'VITE_OLONJS_CLOUD_URL') || readString(env, 'VITE_JSONPAGES_CLOUD_URL');
  const apiKey =
    readString(env, 'VITE_OLONJS_API_KEY') || readString(env, 'VITE_JSONPAGES_API_KEY');
  const save2RepoFlag = env.VITE_SAVE2REPO === 'true';
  return { apiUrl, apiKey, save2RepoFlag };
}
