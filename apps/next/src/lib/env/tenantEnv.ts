import { resolveCloudPolicy, type CloudEnvInput, type CloudPolicy } from '@olonjs/react';

/**
 * Read Next.js public env → CloudEnvInput.
 * Prefer NEXT_PUBLIC_OLONJS_* ; also accept NEXT_PUBLIC_JSONPAGES_* and
 * NEXT_PUBLIC_SAVE2REPO (alpha-style flag name under the Next public prefix).
 *
 * CRITICAL: default path MUST use direct `process.env.NEXT_PUBLIC_*` property
 * access so the Next client bundler can inline values at build time.
 * Indexing via `const env = process.env; env.NEXT_PUBLIC_…` stays empty in the
 * browser → Studio always thinks it is Local → save-to-file → EROFS on Vercel.
 *
 * Pass `env` only in unit tests.
 */
export function readCloudEnvFromNext(
  env?: Record<string, string | undefined>,
): CloudEnvInput {
  if (env) {
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

  const apiUrl = (
    process.env.NEXT_PUBLIC_OLONJS_CLOUD_URL ??
    process.env.NEXT_PUBLIC_JSONPAGES_CLOUD_URL ??
    ''
  ).trim();
  const apiKey = (
    process.env.NEXT_PUBLIC_OLONJS_API_KEY ??
    process.env.NEXT_PUBLIC_JSONPAGES_API_KEY ??
    ''
  ).trim();
  const save2RepoRaw =
    process.env.NEXT_PUBLIC_OLONJS_SAVE2REPO ?? process.env.NEXT_PUBLIC_SAVE2REPO ?? '';

  return {
    apiUrl,
    apiKey,
    save2RepoFlag: save2RepoRaw === 'true',
  };
}

/** Resolve policy (call from client components; do not cache across env shapes in tests). */
export function getCloudPolicy(env?: Record<string, string | undefined>): CloudPolicy {
  return resolveCloudPolicy(readCloudEnvFromNext(env));
}

/** Module policy for the Next admin island (build-time inlined NEXT_PUBLIC_*). */
export const cloudPolicy: CloudPolicy = getCloudPolicy();

export const CLOUD_API_URL = cloudPolicy.apiUrl;
export const CLOUD_API_KEY = cloudPolicy.apiKey;
export const TENANT_ID = 'next';
