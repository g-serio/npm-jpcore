import { resolveCloudPolicy, type CloudEnvInput, type CloudPolicy } from '@olonjs/react';

/**
 * Read Next.js public env → CloudEnvInput.
 * Prefer NEXT_PUBLIC_OLONJS_* ; also accept NEXT_PUBLIC_JSONPAGES_* and
 * NEXT_PUBLIC_SAVE2REPO (alpha-style flag name under the Next public prefix).
 *
 * Note: `import.meta.env` / VITE_* are not available in the Next client bundle
 * unless mirrored via next.config — do not call readCloudEnvFromVite here.
 */
export function readCloudEnvFromNext(
  env: Record<string, string | undefined> = typeof process !== 'undefined' ? process.env : {},
): CloudEnvInput {
  const apiUrl =
    (env.NEXT_PUBLIC_OLONJS_CLOUD_URL ?? env.NEXT_PUBLIC_JSONPAGES_CLOUD_URL ?? '').trim();
  const apiKey =
    (env.NEXT_PUBLIC_OLONJS_API_KEY ?? env.NEXT_PUBLIC_JSONPAGES_API_KEY ?? '').trim();
  const save2RepoRaw =
    env.NEXT_PUBLIC_OLONJS_SAVE2REPO ?? env.NEXT_PUBLIC_SAVE2REPO ?? '';
  return {
    apiUrl,
    apiKey,
    save2RepoFlag: save2RepoRaw === 'true',
  };
}

/** Single policy path for the Next admin island. */
export const cloudPolicy: CloudPolicy = resolveCloudPolicy(readCloudEnvFromNext());

export const CLOUD_API_URL = cloudPolicy.apiUrl;
export const CLOUD_API_KEY = cloudPolicy.apiKey;
export const TENANT_ID = 'next';
