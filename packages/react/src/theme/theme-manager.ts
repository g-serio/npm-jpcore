import type { ThemeConfig } from '@olonjs/core';
import { buildThemeVariableMap } from '@olonjs/core';

export { buildThemeVariableMap };

const appliedThemeProperties = new Set<string>();

export const themeManager = {
  setTheme: (theme: ThemeConfig): void => {
    const root = document.documentElement;
    const mappings = buildThemeVariableMap(theme);

    appliedThemeProperties.forEach((property) => {
      root.style.removeProperty(property);
    });
    appliedThemeProperties.clear();

    Object.entries(mappings).forEach(([key, value]) => {
      root.style.setProperty(key, value);
      appliedThemeProperties.add(key);
    });
  },
};
