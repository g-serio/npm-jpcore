import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { JsonPagesConfig } from '@olonjs/core';
import { buildApiCandidates } from '@/lib/spp';
import type { CloudLoadFailure, ContentMode } from '@/lib/cloud/types';
import { getHydratedData } from '@/lib/cloud/draftStorage';
import { CLOUD_API_KEY, CLOUD_API_URL, cloudPolicy } from '@/lib/env/tenantEnv';
import type { MenuConfig, PageConfig, SiteConfig, ThemeConfig } from '@/types';
import { bootLive } from './bootLive';
import { bootLocal } from './bootLocal';
import { bootStatic } from './bootStatic';
import type { BootstrapContentSetters } from './types';

const EMPTY_COLLECTIONS = {} as NonNullable<JsonPagesConfig['collections']>;

type UseTenantBootstrapOptions = {
  tenantId: string;
  filePages: Record<string, PageConfig>;
  fileSiteConfig: SiteConfig;
  menuConfigSeed: MenuConfig;
  themeConfigSeed: ThemeConfig;
};

/**
 * Tenant content bootstrap — thin dispatcher on `cloudPolicy.bootSource`.
 * Paths: `bootLocal` | `bootStatic` | `bootLive`.
 */
export function useTenantBootstrap({
  tenantId,
  filePages,
  fileSiteConfig,
  menuConfigSeed,
  themeConfigSeed,
}: UseTenantBootstrapOptions) {
  const { isCloudMode, bootSource } = cloudPolicy;

  const localInitialData = useMemo(
    () => (isCloudMode ? null : getHydratedData(tenantId, filePages, fileSiteConfig)),
    [isCloudMode, tenantId, filePages, fileSiteConfig],
  );
  const localInitialPages = useMemo(() => {
    if (!localInitialData) return {};
    return localInitialData.pages;
  }, [localInitialData]);

  const [pages, setPages] = useState<Record<string, PageConfig>>(localInitialPages);
  const [siteConfig, setSiteConfig] = useState<SiteConfig>(localInitialData?.siteConfig ?? fileSiteConfig);
  const [menuConfig, setMenuConfig] = useState<MenuConfig>(menuConfigSeed);
  const [themeConfig, setThemeConfig] = useState<ThemeConfig>(themeConfigSeed);
  const [collections, setCollections] = useState<NonNullable<JsonPagesConfig['collections']>>(EMPTY_COLLECTIONS);
  const [contentMode, setContentMode] = useState<ContentMode>('cloud');
  const [contentFallback, setContentFallback] = useState<CloudLoadFailure | null>(null);
  const [showTopProgress, setShowTopProgress] = useState(false);
  const [hasInitialCloudResolved, setHasInitialCloudResolved] = useState(!isCloudMode);
  const [bootstrapRunId, setBootstrapRunId] = useState(0);

  const contentLoadInFlight = useRef<Promise<void> | null>(null);
  const sppRenderInFlightRef = useRef<string | null>(null);
  const sppBootstrappedRef = useRef(false);

  const cloudApiCandidates = useMemo(
    () => (isCloudMode && CLOUD_API_URL ? buildApiCandidates(CLOUD_API_URL) : []),
    [isCloudMode],
  );

  const isTenantEmpty = Object.keys(pages).length === 0;

  /** Live /admin: call when useAdminStudioContent has settled. */
  const markCloudContentReady = useCallback(() => {
    setShowTopProgress(false);
    setHasInitialCloudResolved(true);
  }, []);

  const retryBootstrap = () => {
    contentLoadInFlight.current = null;
    setContentMode('cloud');
    setContentFallback(null);
    setHasInitialCloudResolved(false);
    setShowTopProgress(true);
    setBootstrapRunId((prev) => prev + 1);
  };

  useEffect(() => {
    const setters: BootstrapContentSetters = {
      setPages,
      setSiteConfig,
      setMenuConfig,
      setCollections,
      setContentMode,
      setContentFallback,
      setShowTopProgress,
      setHasInitialCloudResolved,
    };

    if (!isCloudMode || !CLOUD_API_URL || !CLOUD_API_KEY) {
      bootLocal(setters);
      return;
    }

    if (bootSource === 'static') {
      return bootStatic({ filePages, contentLoadInFlight, setters });
    }

    if (bootSource === 'live') {
      return bootLive({
        cloudApiCandidates,
        contentLoadInFlight,
        sppRenderInFlightRef,
        sppBootstrappedRef,
        setters,
      });
    }
  }, [isCloudMode, bootSource, cloudApiCandidates, filePages, bootstrapRunId]);

  const shouldRenderEngine = !isCloudMode || hasInitialCloudResolved;

  return {
    pages,
    siteConfig,
    menuConfig,
    themeConfig,
    enginePages: pages,
    collections,
    setPages,
    setSiteConfig,
    setMenuConfig,
    setThemeConfig,
    setCollections,
    cloudApiCandidates,
    isCloudMode,
    bootSource,
    contentMode,
    contentFallback,
    showTopProgress,
    hasInitialCloudResolved,
    shouldRenderEngine,
    isTenantEmpty,
    markCloudContentReady,
    retryBootstrap,
  };
}
