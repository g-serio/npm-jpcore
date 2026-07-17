import { useCallback, useEffect, useMemo, useState } from 'react';
import type { LibraryImageEntry } from '@olonjs/core';
import { buildApiCandidates } from '@olonjs/react';

import { cloudPolicy } from '@/lib/tenantEnv';

function normalizeApiBase(raw: string): string {
  return raw.trim().replace(/\/+$/, '');
}

/** Asset library — cloud list when `cloudPolicy.isCloudMode`, else local `/api/list-assets`. */
export function useAssetsManifest(isCloudMode: boolean = cloudPolicy.isCloudMode) {
  const [assetsManifest, setAssetsManifest] = useState<LibraryImageEntry[]>([]);
  const cloudApiCandidates = useMemo(
    () => (isCloudMode && cloudPolicy.apiUrl ? buildApiCandidates(cloudPolicy.apiUrl) : []),
    [isCloudMode],
  );

  const loadAssetsManifest = useCallback(async (): Promise<void> => {
    if (isCloudMode && cloudPolicy.apiUrl && cloudPolicy.apiKey) {
      const apiBases =
        cloudApiCandidates.length > 0
          ? cloudApiCandidates
          : [normalizeApiBase(cloudPolicy.apiUrl)];
      for (const apiBase of apiBases) {
        try {
          const res = await fetch(`${apiBase}/assets/list?limit=200`, {
            method: 'GET',
            headers: { Authorization: `Bearer ${cloudPolicy.apiKey}` },
          });
          const body = (await res.json().catch(() => ({}))) as { items?: LibraryImageEntry[] };
          if (!res.ok) continue;
          const items = Array.isArray(body.items) ? body.items : [];
          setAssetsManifest(items);
          return;
        } catch {
          // try next candidate
        }
      }
      setAssetsManifest([]);
      return;
    }

    fetch('/api/list-assets')
      .then((r) => (r.ok ? r.json() : []))
      .then((list: LibraryImageEntry[]) => setAssetsManifest(Array.isArray(list) ? list : []))
      .catch(() => setAssetsManifest([]));
  }, [isCloudMode, cloudApiCandidates]);

  useEffect(() => {
    void loadAssetsManifest();
  }, [loadAssetsManifest]);

  return { assetsManifest, loadAssetsManifest, cloudApiCandidates };
}
