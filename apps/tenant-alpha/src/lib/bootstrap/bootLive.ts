import type { MutableRefObject } from 'react';
import { logBootstrapEvent, toCloudLoadFailure } from '@/lib/cloud/bootstrapTelemetry';
import { cloudFingerprint, readCachedPages, writeCachedCloudContent } from '@/lib/cloud/cloudCache';
import type { CloudLoadFailure } from '@/lib/cloud/types';
import {
  fetchRenderProjection,
  isAdminPath,
  normalizeRenderPath,
  patchHistoryNavigation,
  resolveRegistrySlugFromRender,
  type RenderProjectionResponse,
} from '@/lib/spp';
import { APP_BASE_PATH, CLOUD_API_KEY, CLOUD_API_URL } from '@/lib/env/tenantEnv';
import { applyCachedBootstrap } from './applyCachedBootstrap';
import type { BootstrapContentSetters, BootstrapInFlightRef } from './types';

const MAX_BOOTSTRAP_RETRIES = 2;

type BootLiveParams = {
  cloudApiCandidates: string[];
  contentLoadInFlight: BootstrapInFlightRef;
  sppRenderInFlightRef: MutableRefObject<string | null>;
  sppBootstrappedRef: MutableRefObject<boolean>;
  setters: BootstrapContentSetters;
};

/**
 * Live cloud boot via SPP `/render`.
 * On `/admin`, defer paint — content sync is `useAdminStudioContent` + `markCloudContentReady`.
 */
export function bootLive({
  cloudApiCandidates,
  contentLoadInFlight,
  sppRenderInFlightRef,
  sppBootstrappedRef,
  setters,
}: BootLiveParams): (() => void) | void {
  if (contentLoadInFlight.current) return;

  const {
    setPages,
    setSiteConfig,
    setMenuConfig,
    setCollections,
    setContentMode,
    setContentFallback,
    setShowTopProgress,
    setHasInitialCloudResolved,
  } = setters;

  if (isAdminPath(window.location.pathname, APP_BASE_PATH)) {
    setContentMode('cloud');
    setContentFallback(null);
    setShowTopProgress(true);
    setHasInitialCloudResolved(false);
    return;
  }

  const controller = new AbortController();
  const startedAt = Date.now();
  const primaryApiBase = cloudApiCandidates[0] ?? CLOUD_API_URL.trim().replace(/\/+$/, '');
  const fingerprint = cloudFingerprint(primaryApiBase, CLOUD_API_KEY);
  const { cached, cachedSite } = readCachedPages(fingerprint);

  sppBootstrappedRef.current = false;
  setContentMode('cloud');
  setContentFallback(null);
  setShowTopProgress(true);
  setHasInitialCloudResolved(false);
  logBootstrapEvent('boot.start', {
    mode: 'spp-render',
    apiCandidates: cloudApiCandidates.length,
  });

  const applyRenderPayload = (result: RenderProjectionResponse) => {
    if (!result.page) return;
    const registrySlug = resolveRegistrySlugFromRender(result.page);
    setPages((prev) => ({ ...prev, [registrySlug]: result.page! }));
    if (result.context?.siteConfig) setSiteConfig(result.context.siteConfig);
    if (result.context?.menuConfig) setMenuConfig(result.context.menuConfig);
    writeCachedCloudContent({
      keyFingerprint: fingerprint,
      savedAt: Date.now(),
      siteConfig: result.context?.siteConfig ?? cachedSite ?? null,
      pages: {
        ...(cached?.pages ?? {}),
        [registrySlug]: result.page,
      },
      collections: cached?.collections,
    });
  };

  const loadRenderPath = async (pathname: string, options?: { initial?: boolean }) => {
    if (controller.signal.aborted) return;
    if (isAdminPath(pathname, APP_BASE_PATH)) return;

    const renderPath = normalizeRenderPath(pathname, APP_BASE_PATH);
    const inFlightKey = renderPath;
    if (sppRenderInFlightRef.current === inFlightKey) return;
    sppRenderInFlightRef.current = inFlightKey;

    try {
      const result = await fetchRenderProjection(
        cloudApiCandidates,
        CLOUD_API_KEY,
        renderPath,
        { signal: controller.signal, maxRetryAttempts: MAX_BOOTSTRAP_RETRIES },
      );

      if (!result.ok) {
        if (options?.initial) {
          throw {
            reasonCode: result.code || 'RENDER_FAILED',
            message: result.error || 'Render projection failed',
            correlationId: result.correlationId,
          } satisfies CloudLoadFailure;
        }
        logBootstrapEvent('boot.spp_render.route_error', {
          path: renderPath,
          code: result.code ?? null,
        });
        return;
      }

      applyRenderPayload(result);

      if (options?.initial) {
        sppBootstrappedRef.current = true;
        setContentMode('cloud');
        setContentFallback(null);
        setHasInitialCloudResolved(true);
        logBootstrapEvent('boot.spp_render.success', {
          elapsedMs: Date.now() - startedAt,
          projectionMode: result.diagnostics?.projectionMode ?? null,
          correlationId: result.correlationId ?? null,
        });
      } else {
        logBootstrapEvent('boot.spp_render.route_success', {
          path: renderPath,
          correlationId: result.correlationId ?? null,
        });
      }
    } finally {
      if (sppRenderInFlightRef.current === inFlightKey) {
        sppRenderInFlightRef.current = null;
      }
    }
  };

  const run = async () => {
    try {
      await loadRenderPath(window.location.pathname, { initial: true });
    } catch (error: unknown) {
      if (controller.signal.aborted) return;
      const failure = toCloudLoadFailure(error);
      const { cachedPages, cachedSite: fallbackSite } = readCachedPages(fingerprint);
      const hasCachedFallback = applyCachedBootstrap({
        cachedPages,
        cachedSite: fallbackSite,
        cachedCollections: cached?.collections,
        setPages,
        setSiteConfig,
        setCollections,
      });
      if (hasCachedFallback) {
        setContentMode('cloud');
        setContentFallback({
          reasonCode: 'RENDER_FAILED',
          message: failure.message,
          correlationId: failure.correlationId,
        });
        setHasInitialCloudResolved(true);
      } else {
        setContentMode('error');
        setContentFallback(failure);
        setHasInitialCloudResolved(true);
      }
      logBootstrapEvent('boot.spp_render.error', {
        reasonCode: failure.reasonCode,
        correlationId: failure.correlationId ?? null,
      });
    } finally {
      setShowTopProgress(false);
    }
  };

  let inFlight: Promise<void> | null = null;
  inFlight = run().finally(() => {
    if (contentLoadInFlight.current === inFlight) {
      contentLoadInFlight.current = null;
    }
  });
  contentLoadInFlight.current = inFlight;

  const unpatchHistory = patchHistoryNavigation(() => {
    if (!sppBootstrappedRef.current) return;
    void loadRenderPath(window.location.pathname);
  });

  return () => {
    controller.abort();
    unpatchHistory();
    contentLoadInFlight.current = null;
  };
}
