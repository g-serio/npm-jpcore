import React, { useEffect, useState } from 'react';
import { StudioProvider } from '../studio-mode/StudioContext';
import { ThemeLoader } from '../theme/ThemeLoader';
import type { StudioRouteBodyProps } from '@olonjs/studio';

/**
 * Thin composition bridge: wires up the react-bound `ThemeLoader` /
 * `StudioProvider` context around `@olonjs/studio`'s `StudioRouteBody`.
 *
 * Per ADR-0016 D2/D6, `@olonjs/studio` is never a static import anywhere in
 * this package — only the `import type` above (erased at compile time) and
 * the dynamic `import('@olonjs/studio')` below. This is the single bridge
 * point where the optional Studio dependency actually loads, and it only
 * loads when a consumer's router mounts this component (i.e. navigates to
 * `/admin`).
 */
export interface StudioRouteProps extends StudioRouteBodyProps {
  tenantCss: string;
  adminCss: string;
}

type StudioModule = typeof import('@olonjs/studio');

let studioModulePromise: Promise<StudioModule> | null = null;
function loadStudioModule(): Promise<StudioModule> {
  if (!studioModulePromise) {
    studioModulePromise = import('@olonjs/studio');
  }
  return studioModulePromise;
}

export const StudioRoute: React.FC<StudioRouteProps> = ({ tenantCss, adminCss, ...bodyProps }) => {
  const [studioModule, setStudioModule] = useState<StudioModule | null>(null);

  useEffect(() => {
    let cancelled = false;
    loadStudioModule().then((mod) => {
      if (!cancelled) setStudioModule(mod);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  // Tenant override (`themeCss.admin`) wins if supplied; otherwise fall back
  // to the Studio-authored skin, which only exists once the dynamic import
  // resolves. Visitor-only bundles never pay for this CSS at all.
  const resolvedAdminCss = adminCss || studioModule?.adminSkinCss || '';

  return (
    <ThemeLoader mode="admin" tenantCss={tenantCss} adminCss={resolvedAdminCss}>
      <StudioProvider mode="studio">
        {studioModule ? (
          <studioModule.StudioRouteBody {...bodyProps} />
        ) : (
          <div className="flex items-center justify-center h-screen w-screen bg-zinc-950 text-zinc-500 font-mono text-xs uppercase tracking-widest animate-pulse">
            Loading Studio...
          </div>
        )}
      </StudioProvider>
    </ThemeLoader>
  );
};
