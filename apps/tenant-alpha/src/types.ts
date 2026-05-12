import type { EmptyTenantData, EmptyTenantSettings } from '@/components/empty-tenant';
import type { FormDemoData, FormDemoSettings } from '@/components/form-demo';

export type SectionComponentPropsMap = {
  'empty-tenant': { data: EmptyTenantData; settings?: EmptyTenantSettings };
  'form-demo': { data: FormDemoData; settings?: FormDemoSettings };
};

declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    'empty-tenant': EmptyTenantData;
    'form-demo': FormDemoData;
  }
  export interface SectionSettingsRegistry {
    'empty-tenant': EmptyTenantSettings;
    'form-demo': FormDemoSettings;
  }
}

export * from '@olonjs/core';
