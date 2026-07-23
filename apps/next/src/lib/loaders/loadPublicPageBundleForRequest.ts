import type { PublicPageContentBundle } from '@olonjs/next/server';
import {
  buildServerApiCandidates,
  type ServerCloudBootSource,
} from '@/lib/env/serverCloudPolicy';
import { loadLivePublicPageBundle } from './loadLivePublicPageBundle';
import { loadLocalPublicPageBundle } from './loadLocalPublicPageBundle';
import { loadStaticPublicPageBundle } from './loadStaticPublicPageBundle';

export type LoadPublicPageBundleForRequestInput = {
  bootSource: ServerCloudBootSource;
  slug: string;
  /** Absolute request URL (used for Static same-origin base). */
  requestUrl: string;
  appRoot?: string;
  apiUrl?: string;
  apiKey?: string;
  fetchImpl?: typeof fetch;
};

/**
 * Select Local / Static / Live content bundle from server cloud policy bootSource.
 */
export async function loadPublicPageBundleForRequest(
  input: LoadPublicPageBundleForRequestInput,
): Promise<PublicPageContentBundle> {
  const appRoot = input.appRoot ?? process.cwd();

  if (input.bootSource === 'static') {
    const origin = new URL(input.requestUrl).origin;
    return loadStaticPublicPageBundle({
      baseUrl: `${origin}/`,
      appRoot,
      fetchImpl: input.fetchImpl,
    });
  }

  if (input.bootSource === 'live') {
    const apiUrl = (input.apiUrl ?? '').trim();
    const apiKey = (input.apiKey ?? '').trim();
    if (!apiUrl || !apiKey) {
      throw new Error('Live public page JSON requires cloud API URL and key');
    }
    return loadLivePublicPageBundle({
      slug: input.slug,
      apiBases: buildServerApiCandidates(apiUrl),
      apiKey,
      appRoot,
      fetchImpl: input.fetchImpl,
    });
  }

  return loadLocalPublicPageBundle(appRoot);
}
