import { buildThemeVariableMap, type ThemeConfig } from '@olonjs/core';

/** Publish theme.json as `:root{--theme-*}` (CIP / alpha entry-ssg parity). */
export function serializeThemeRootCss(theme: ThemeConfig): string {
  const mappings = buildThemeVariableMap(theme);
  const entries = Object.entries(mappings);
  if (entries.length === 0) return '';
  return `:root{${entries.map(([name, value]) => `${name}:${value}`).join(';')}}`;
}
