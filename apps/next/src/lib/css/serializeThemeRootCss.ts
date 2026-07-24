import { buildThemeVariableMap, type ThemeConfig } from '@olonjs/core';

/** SSG/RSC parity with tenant-alpha `entry-ssg` — publish theme.json as `:root{--theme-*}`. */
export function serializeThemeRootCss(theme: ThemeConfig): string {
  const mappings = buildThemeVariableMap(theme);
  const entries = Object.entries(mappings);
  if (entries.length === 0) return '';
  const serialized = entries.map(([name, value]) => `${name}:${value}`).join(';');
  return `:root{${serialized}}`;
}
