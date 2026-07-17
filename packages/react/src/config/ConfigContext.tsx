/**
 * Inversion of Control: registry and schemas are provided by the Engine from Tenant config.
 * SectionRenderer consumes this; it does not import ComponentRegistry or SECTION_SCHEMAS.
 */
import React, { createContext, useContext } from 'react';
import type { AssetsConfig, JsonPagesConfig } from '@olonjs/core';

type Registry = JsonPagesConfig['registry'];
type Schemas = JsonPagesConfig['schemas'];

export interface ConfigContextValue {
  registry: Registry;
  schemas: Schemas;
  tenantId?: string;
  basePath?: string;
  assets?: AssetsConfig;
  overlayDisabledSectionTypes?: string[];
}

const ConfigContext = createContext<ConfigContextValue | undefined>(undefined);

export const ConfigProvider: React.FC<{
  config: Pick<
    JsonPagesConfig,
    'registry' | 'schemas' | 'tenantId' | 'basePath' | 'assets' | 'overlayDisabledSectionTypes'
  >;
  children: React.ReactNode;
}> = ({ config, children }) => (
  <ConfigContext.Provider
    value={{
      registry: config.registry,
      schemas: config.schemas,
      tenantId: config.tenantId,
      basePath: config.basePath,
      assets: config.assets,
      overlayDisabledSectionTypes: config.overlayDisabledSectionTypes,
    }}
  >
    {children}
  </ConfigContext.Provider>
);

export function useConfig(): ConfigContextValue {
  const context = useContext(ConfigContext);
  if (context === undefined) {
    throw new Error('useConfig must be used within ConfigProvider');
  }
  return context;
}
