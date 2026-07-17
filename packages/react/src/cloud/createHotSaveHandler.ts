import type { ProjectState } from '@olonjs/core';

export type HotSaveHandler = (state: ProjectState, slug: string) => Promise<void>;

export type CreateHotSaveHandlerOptions = {
  apiUrl: string;
  apiKey: string;
  /** Injected for tests; defaults to global fetch. */
  fetchImpl?: typeof fetch;
  /**
   * DNA hook after a successful hot save (e.g. local cloud cache).
   * Not required for the HTTP contract itself.
   */
  onSuccess?: (ctx: {
    state: ProjectState;
    slug: string;
    apiUrl: string;
    apiKey: string;
  }) => void | Promise<void>;
};

/**
 * Studio HotSave — POST `{apiUrl}/hotSave` with Bearer key.
 *
 * Explicit: this only performs the live write. UI visibility is
 * `CloudPolicy.showHotSave` / `hotSaveEnabled` (credentials ⇒ on, including dual Save2Repo).
 */
export function createHotSaveHandler(options: CreateHotSaveHandlerOptions): HotSaveHandler {
  const { apiUrl, apiKey, fetchImpl = fetch, onSuccess } = options;

  return async (state: ProjectState, slug: string): Promise<void> => {
    const url = apiUrl.trim();
    const key = apiKey.trim();
    if (!url || !key) {
      throw new Error('Cloud mode is not configured for hot save.');
    }

    const apiBase = url.replace(/\/+$/, '');
    const res = await fetchImpl(`${apiBase}/hotSave`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        slug,
        page: state.page,
        siteConfig: state.site,
        collections: state.collections,
      }),
    });

    const body = (await res.json().catch(() => ({}))) as { error?: string; code?: string };
    if (!res.ok) {
      throw new Error(body.error || body.code || `Hot save failed: ${res.status}`);
    }

    await onSuccess?.({ state, slug, apiUrl: url, apiKey: key });
  };
}
