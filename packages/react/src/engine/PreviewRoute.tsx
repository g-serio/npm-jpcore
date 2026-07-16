import React from 'react';
import { PreviewEntry } from './PreviewEntry';
import { ThemeLoader } from '../theme/ThemeLoader';

export interface PreviewRouteProps {
  tenantCss: string;
  adminCss: string;
}

export const PreviewRoute: React.FC<PreviewRouteProps> = ({ tenantCss, adminCss }) => (
  <ThemeLoader mode="tenant" tenantCss={tenantCss} adminCss={adminCss}>
    <PreviewEntry />
  </ThemeLoader>
);
