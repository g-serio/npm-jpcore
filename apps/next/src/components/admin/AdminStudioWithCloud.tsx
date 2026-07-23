'use client';

import { lazy, Suspense, useCallback } from 'react';
import type {
  JsonPagesConfig,
  MenuConfig,
  PageConfig,
  ProjectState,
  SiteConfig,
  ThemeConfig,
} from '@olonjs/core';
import { AdminStudioClient } from '@/components/admin/AdminStudioClient';
import { useCloudSave } from '@/lib/admin/useCloudSave';
import { cloudPolicy, TENANT_ID } from '@/lib/env/tenantEnv';

const ColdSaveDrawer = lazy(() =>
  import('@/components/admin/ColdSaveDrawer').then((m) => ({ default: m.ColdSaveDrawer })),
);

export type AdminStudioWithCloudProps = {
  initialPages: Record<string, PageConfig>;
  initialSiteConfig: SiteConfig;
  initialMenuConfig: MenuConfig;
  initialThemeConfig: ThemeConfig;
  initialCollections: NonNullable<JsonPagesConfig['collections']>;
};

/**
 * Admin island + optional Save2Repo cold save (no HotSave).
 * Local save when cloud credentials are absent; cold save when Save2Repo is enabled.
 */
export function AdminStudioWithCloud(props: AdminStudioWithCloudProps) {
  const { cloudSaveUi, runCloudSave, closeCloudDrawer, retryCloudSave } = useCloudSave({
    apiUrl: cloudPolicy.apiUrl,
    apiKey: cloudPolicy.apiKey,
  });

  const coldSave = useCallback(
    async (state: ProjectState, slug: string) => {
      await runCloudSave({ state, slug }, true);
    },
    [runCloudSave],
  );

  const mountDrawer =
    cloudPolicy.showColdSave && (cloudSaveUi.isOpen || cloudSaveUi.phase !== 'idle');

  return (
    <AdminStudioClient
      tenantId={TENANT_ID}
      {...props}
      showLocalSave={cloudPolicy.showLocalSave}
      showColdSave={cloudPolicy.showColdSave}
      coldSave={cloudPolicy.showColdSave ? coldSave : undefined}
    >
      {mountDrawer ? (
        <Suspense fallback={null}>
          <ColdSaveDrawer
            isOpen={cloudSaveUi.isOpen}
            phase={cloudSaveUi.phase}
            currentStepId={cloudSaveUi.currentStepId}
            doneSteps={cloudSaveUi.doneSteps}
            progress={cloudSaveUi.progress}
            errorMessage={cloudSaveUi.errorMessage}
            deployUrl={cloudSaveUi.deployUrl}
            onClose={closeCloudDrawer}
            onRetry={retryCloudSave}
          />
        </Suspense>
      ) : null}
    </AdminStudioClient>
  );
}
