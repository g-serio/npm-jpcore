import { logBootstrapEvent, toCloudLoadFailure } from '@/lib/cloud/bootstrapTelemetry';
import { loadPublishedStaticContent } from '@/lib/cloud/staticContent';
import { APP_BASE_PATH } from '@/lib/env/tenantEnv';
import type { PageConfig } from '@/types';
import type { BootstrapContentSetters, BootstrapInFlightRef } from './types';

type BootStaticParams = {
  filePages: Record<string, PageConfig>;
  contentLoadInFlight: BootstrapInFlightRef;
  setters: Pick<
    BootstrapContentSetters,
    | 'setPages'
    | 'setSiteConfig'
    | 'setContentMode'
    | 'setContentFallback'
    | 'setShowTopProgress'
    | 'setHasInitialCloudResolved'
  >;
};

/** Save2Repo boot: published static JSON under public/. */
export function bootStatic({
  filePages,
  contentLoadInFlight,
  setters,
}: BootStaticParams): (() => void) | void {
  if (contentLoadInFlight.current) return;

  const {
    setPages,
    setSiteConfig,
    setContentMode,
    setContentFallback,
    setShowTopProgress,
    setHasInitialCloudResolved,
  } = setters;

  setContentMode('cloud');
  setContentFallback(null);
  setShowTopProgress(true);
  setHasInitialCloudResolved(false);
  logBootstrapEvent('boot.start', {
    mode: 'save2repo-static',
    pageCount: Object.keys(filePages).length,
  });

  let inFlight: Promise<void> | null = null;
  inFlight = loadPublishedStaticContent(Object.keys(filePages), APP_BASE_PATH)
    .then(({ pages: nextPages, siteConfig: nextSite }) => {
      setPages(nextPages);
      setSiteConfig(nextSite);
      setContentMode('cloud');
      setContentFallback(null);
      setHasInitialCloudResolved(true);
      logBootstrapEvent('boot.save2repo.success', {
        mode: 'save2repo-static',
        pageCount: Object.keys(nextPages).length,
      });
    })
    .catch((error: unknown) => {
      const failure = toCloudLoadFailure(error);
      setContentMode('error');
      setContentFallback(failure);
      setHasInitialCloudResolved(true);
      logBootstrapEvent('boot.save2repo.error', {
        mode: 'save2repo-static',
        reasonCode: failure.reasonCode,
        correlationId: failure.correlationId ?? null,
      });
    })
    .finally(() => {
      setShowTopProgress(false);
      if (contentLoadInFlight.current === inFlight) {
        contentLoadInFlight.current = null;
      }
    });

  contentLoadInFlight.current = inFlight;
  return () => {
    contentLoadInFlight.current = null;
  };
}
