import React, { useLayoutEffect } from 'react';

export interface ThemeLoaderProps {
  mode: 'tenant' | 'admin';
  tenantCss: string;
  adminCss: string;
  children: React.ReactNode;
}

export const ThemeLoader: React.FC<ThemeLoaderProps> = ({ mode, tenantCss, adminCss, children }) => {
  useLayoutEffect(() => {
    const styleId = `jp-theme-${mode}`;
    const css = mode === 'tenant' ? tenantCss : adminCss;

    if (!document.getElementById(styleId) && css) {
      const style = document.createElement('style');
      style.id = styleId;
      style.innerHTML = css;
      document.head.appendChild(style);
    }

    return () => {
      const style = document.getElementById(styleId);
      if (style) style.remove();
    };
  }, [mode, tenantCss, adminCss]);

  return <>{children}</>;
};
