import { buildApiCandidates } from '@olonjs/react';

import { cloudPolicy } from '@/lib/env/tenantEnv';

export { buildApiCandidates };

/**
 * Browser-runtime SPP cloud slices.
 * Credentials ⇒ cloud usable. Save2Repo does not mean “cloud off”
 * (boot may still be static; live slices remain available).
 * SSG/bake: local JSON only (SPP §3).
 */
export function getSppCloudConfig(): {
  enabled: boolean;
  apiBases: string[];
  apiKey: string;
} {
  if (import.meta.env.SSR || !cloudPolicy.isCloudMode) {
    return { enabled: false, apiBases: [], apiKey: '' };
  }

  return {
    enabled: true,
    apiBases: buildApiCandidates(cloudPolicy.apiUrl),
    apiKey: cloudPolicy.apiKey,
  };
}
