import { describe, expect, it } from 'vitest';
import type { ThemeConfig } from '@olonjs/core';
import { serializeThemeRootCss } from './serializeThemeRootCss';

describe('serializeThemeRootCss', () => {
  it('emits :root --theme-* from theme.json (no CSS color literals as source)', () => {
    const theme = {
      name: 'test',
      tokens: {
        colors: { background: 'hsl(10 20% 30%)', foreground: 'hsl(0 0% 100%)' },
        typography: { fontFamily: { primary: 'Inter, sans-serif' } },
        borderRadius: {},
      },
    } as ThemeConfig;

    const css = serializeThemeRootCss(theme);
    expect(css).toContain('--theme-colors-background:hsl(10 20% 30%)');
    expect(css).toContain('--theme-colors-foreground:hsl(0 0% 100%)');
    expect(css).not.toContain('hsl(215 28% 7%)');
  });
});
