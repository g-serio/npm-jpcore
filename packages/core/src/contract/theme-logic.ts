import type { ThemeConfig } from './kernel';

type ThemeLeafValue = string | number;
interface ThemeNode {
  [key: string]: ThemeLeafValue | ThemeNode;
}

function toKebabCase(value: string): string {
  return value.replace(/([a-z0-9])([A-Z])/g, '$1-$2').replace(/[_\s]+/g, '-').toLowerCase();
}

function flattenThemeNode(
  node: ThemeNode,
  path: string[] = [],
  result: Record<string, string> = {}
): Record<string, string> {
  Object.entries(node).forEach(([key, value]) => {
    const nextPath = [...path, toKebabCase(key)];
    if (typeof value === 'string' || typeof value === 'number') {
      result[`--theme-${nextPath.join('-')}`] = String(value);
      return;
    }

    if (value && typeof value === 'object' && !Array.isArray(value)) {
      flattenThemeNode(value as ThemeNode, nextPath, result);
    }
  });

  return result;
}

function addAlias(
  mappings: Record<string, string>,
  alias: string,
  sourceVariableName: string,
  sourceValue: string | undefined
): void {
  if (!sourceValue) return;
  mappings[alias] = `var(${sourceVariableName})`;
}

/**
 * Pure theme-token flattening logic (zero DOM, zero React, zero module-scope
 * state). Split from `runtime/theme/theme-manager.ts`'s stateful singleton
 * half per ADR-0016 D4 — this module is destined for `@olonjs/core` and can
 * be imported by any framework binding without coupling concerns.
 */
export function buildThemeVariableMap(theme: ThemeConfig): Record<string, string> {
  const dynamicMappings = flattenThemeNode(theme.tokens as unknown as ThemeNode);
  const mappings = { ...dynamicMappings };

  addAlias(mappings, '--theme-primary', '--theme-colors-primary', dynamicMappings['--theme-colors-primary']);
  addAlias(mappings, '--theme-secondary', '--theme-colors-secondary', dynamicMappings['--theme-colors-secondary']);
  addAlias(mappings, '--theme-accent', '--theme-colors-accent', dynamicMappings['--theme-colors-accent']);
  addAlias(mappings, '--theme-background', '--theme-colors-background', dynamicMappings['--theme-colors-background']);
  addAlias(mappings, '--theme-surface', '--theme-colors-surface', dynamicMappings['--theme-colors-surface']);
  addAlias(mappings, '--theme-surface-alt', '--theme-colors-surface-alt', dynamicMappings['--theme-colors-surface-alt']);
  addAlias(mappings, '--theme-text', '--theme-colors-text', dynamicMappings['--theme-colors-text']);
  addAlias(mappings, '--theme-text-muted', '--theme-colors-text-muted', dynamicMappings['--theme-colors-text-muted']);
  addAlias(mappings, '--theme-border', '--theme-colors-border', dynamicMappings['--theme-colors-border']);
  addAlias(
    mappings,
    '--theme-font-primary',
    '--theme-typography-font-family-primary',
    dynamicMappings['--theme-typography-font-family-primary']
  );
  addAlias(
    mappings,
    '--theme-font-mono',
    '--theme-typography-font-family-mono',
    dynamicMappings['--theme-typography-font-family-mono']
  );
  addAlias(
    mappings,
    '--theme-font-display',
    '--theme-typography-font-family-display',
    dynamicMappings['--theme-typography-font-family-display']
  );
  addAlias(mappings, '--theme-radius-sm', '--theme-border-radius-sm', dynamicMappings['--theme-border-radius-sm']);
  addAlias(mappings, '--theme-radius-md', '--theme-border-radius-md', dynamicMappings['--theme-border-radius-md']);
  addAlias(mappings, '--theme-radius-lg', '--theme-border-radius-lg', dynamicMappings['--theme-border-radius-lg']);

  return mappings;
}
