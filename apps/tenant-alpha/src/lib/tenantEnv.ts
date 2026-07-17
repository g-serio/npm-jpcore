import { normalizeBasePath } from '@olonjs/core';
import { readCloudEnvFromVite, resolveCloudPolicy, type CloudPolicy } from '@olonjs/react';

/** Single Vite → policy path. Prefer `cloudPolicy` over ad-hoc env reads. */
export const cloudPolicy: CloudPolicy = resolveCloudPolicy(
  readCloudEnvFromVite(import.meta.env as Record<string, unknown>),
);

/** Aliases of `cloudPolicy.apiUrl` / `apiKey` for DNA helpers. */
export const CLOUD_API_URL = cloudPolicy.apiUrl;
export const CLOUD_API_KEY = cloudPolicy.apiKey;
export const APP_BASE_PATH = normalizeBasePath(import.meta.env.BASE_URL || '/');
export const TENANT_ID = 'alpha';
