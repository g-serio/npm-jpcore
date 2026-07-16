import { expect, test } from 'vitest';

import type { ThemeConfig } from '@olonjs/core';
import { themeManager } from './theme-manager';

type DeepPartial<T> = {
  [K in keyof T]?: T[K] extends object ? DeepPartial<T[K]> : T[K];
};

function createTheme(
  overrides: DeepPartial<ThemeConfig['tokens']> = {}
): ThemeConfig {
  return {
    name: 'Test Theme',
    tokens: {
      colors: {
        primary: '#111111',
        secondary: '#222222',
        accent: '#333333',
        background: '#444444',
        surface: '#555555',
        surfaceAlt: '#666666',
        text: '#777777',
        textMuted: '#888888',
        border: '#999999',
        ...overrides.colors,
      },
      typography: {
        fontFamily: {
          primary: 'Inter, sans-serif',
          mono: 'JetBrains Mono, monospace',
          display: 'Bricolage Grotesque, sans-serif',
          ...overrides.typography?.fontFamily,
        },
      },
      borderRadius: {
        sm: '4px',
        md: '8px',
        lg: '12px',
        ...overrides.borderRadius,
      },
    },
  };
}

class FakeStyle {
  private values = new Map<string, string>();

  setProperty(name: string, value: string): void {
    this.values.set(name, value);
  }

  removeProperty(name: string): void {
    this.values.delete(name);
  }

  getPropertyValue(name: string): string {
    return this.values.get(name) ?? '';
  }
}

test('themeManager.setTheme removes stale dynamic tokens before applying next theme', () => {
  const fakeStyle = new FakeStyle();
  const previousDocument = Reflect.get(globalThis, 'document');

  Reflect.set(globalThis, 'document', {
    documentElement: {
      style: fakeStyle,
    },
  });

  try {
    themeManager.setTheme(
      createTheme({
        colors: {
          pi: '#314159',
        },
      })
    );
    expect(fakeStyle.getPropertyValue('--theme-colors-pi')).toBe('#314159');
    expect(fakeStyle.getPropertyValue('--theme-font-display')).toBe('var(--theme-typography-font-family-display)');

    themeManager.setTheme(createTheme());
    expect(fakeStyle.getPropertyValue('--theme-colors-pi')).toBe('');
    expect(fakeStyle.getPropertyValue('--theme-font-display')).toBe('var(--theme-typography-font-family-display)');
  } finally {
    if (previousDocument === undefined) {
      Reflect.deleteProperty(globalThis, 'document');
    } else {
      Reflect.set(globalThis, 'document', previousDocument);
    }
  }
});
