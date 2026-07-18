import { useEffect, useRef } from 'react';
import type { Dispatch, SetStateAction } from 'react';
import { applyLegacyCloudPayload, fetchLegacyCloudContentPayload } from '@/lib/cloud/cloudContentClient';
import { cloudFingerprint, readCachedPages, writeCachedCloudContent } from '@/lib/cloud/cloudCache';
import { isAdminPath, patchHistoryNavigation } from '@/lib/spp';
import { APP_BASE_PATH } from '@/lib/env/tenantEnv';
import type { PageConfig, SiteConfig } from '@/types';

const MAX_RETRIES = 2;

type UseAdminStudioContentOptions = {
  enabled: boolean;
  apiCandidates: string[];
  apiKey: string;
  setPages: Dispatch<SetStateAction<Record<string, PageConfig>>>;
  setSiteConfig: Dispatch<SetStateAction<SiteConfig>>;
  /** Fired when /admin may paint — after cache hit and/or network attempt settles. */
  onSettled?: () => void;
};

/** Studio `/admin` sync via legacy `/content` — never mixed into visitor `/render` bootstrap. */
export function useAdminStudioContent({
  enabled,
  apiCandidates,
  apiKey,
  setPages,
  setSiteConfig,
  onSettled,
}: UseAdminStudioContentOptions) {
  const loadedRef = useRef(false);
  const inFlightRef = useRef<Promise<void> | null>(null);
  const settledRef = useRef(false);

  useEffect(() => {
    settledRef.current = false;
    loadedRef.current = false;

    if (!enabled) return;

    const settle = () => {
      if (settledRef.current) return;
      settledRef.current = true;
      onSettled?.();
    };

    if (apiCandidates.length === 0 || !apiKey.trim()) {
      settle();
      return;
    }

    const syncIfAdmin = () => {
      if (!isAdminPath(window.location.pathname, APP_BASE_PATH)) return;
      if (loadedRef.current || inFlightRef.current) return;

      const controller = new AbortController();
      const fingerprint = cloudFingerprint(apiCandidates[0]!, apiKey);

      // Paint from cache immediately when present — then refresh from network.
      const { cachedPages, cachedSite } = readCachedPages(fingerprint);
      if (cachedPages && Object.keys(cachedPages).length > 0) {
        setPages(cachedPages);
        if (cachedSite) setSiteConfig(cachedSite);
        settle();
      }

      inFlightRef.current = fetchLegacyCloudContentPayload(
        apiCandidates,
        apiKey,
        controller.signal,
        MAX_RETRIES,
      )
        .then((payload) => {
          const { remotePages, remoteSite } = applyLegacyCloudPayload(payload, {
            setPages,
            setSiteConfig,
          });
          writeCachedCloudContent({
            keyFingerprint: fingerprint,
            savedAt: Date.now(),
            siteConfig: remoteSite ?? null,
            pages: (remotePages ?? {}) as Record<string, unknown>,
          });
          loadedRef.current = true;
        })
        .catch((error: unknown) => {
          if (import.meta.env.DEV) {
            console.warn('[admin-studio] legacy content sync failed', error);
          }
        })
        .finally(() => {
          inFlightRef.current = null;
          settle();
        });
    };

    syncIfAdmin();
    const unpatch = patchHistoryNavigation(syncIfAdmin);
    return () => {
      unpatch();
      inFlightRef.current = null;
    };
  }, [enabled, apiCandidates, apiKey, setPages, setSiteConfig, onSettled]);
}
