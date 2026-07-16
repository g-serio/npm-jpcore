/**
 * Studio-owned context for cross-cutting render inputs (icon registry,
 * asset library, tenant id) that the widget tree (FormFactory ->
 * InputRegistry -> image-picker) needs at arbitrary depth.
 *
 * Per ADR-0016 D6/D7, `@olonjs/studio` must depend only on `@olonjs/core` —
 * it cannot reach into `@olonjs/react`'s `ConfigContext` or
 * `IconRegistryContext` (different module instances would break React
 * context identity across the package boundary anyway, per ADR-0012).
 * Instead, the bridge in `@olonjs/react` (`StudioRoute`) passes these
 * values as explicit props into this package's top-level `StudioRoute`,
 * which provides them locally via this context.
 */
import React, { createContext, useContext, type ReactNode } from 'react';
import type { AssetsConfig } from '@olonjs/core';
import type { LucideIcon } from 'lucide-react';

export type IconRegistry = Record<string, LucideIcon>;

export interface StudioAssetsContextValue {
  icons: IconRegistry;
  assets?: AssetsConfig;
  tenantId: string;
}

const DEFAULT_VALUE: StudioAssetsContextValue = { icons: {}, tenantId: 'default' };

const StudioAssetsContext = createContext<StudioAssetsContextValue>(DEFAULT_VALUE);

export const StudioAssetsProvider: React.FC<{
  value: StudioAssetsContextValue;
  children: ReactNode;
}> = ({ value, children }) => (
  <StudioAssetsContext.Provider value={value}>{children}</StudioAssetsContext.Provider>
);

export const useStudioAssets = (): StudioAssetsContextValue => useContext(StudioAssetsContext);
