import { describe, expect, it } from 'vitest';
import type { PageConfig, SiteConfig } from '@olonjs/core';
import { resolveVisitorShell } from './resolveVisitorShell';

const site = {
  identity: { title: 'T' },
  header: { id: 'h', type: 'header', data: { logoText: 'Olon' } },
  footer: { id: 'f', type: 'footer', data: { brandText: 'OlonJS' } },
} as unknown as SiteConfig;

describe('resolveVisitorShell', () => {
  it('always returns footer when present on site', () => {
    const page = { id: 'p', slug: 'home', sections: [], 'global-header': false } as PageConfig;
    const shell = resolveVisitorShell(page, site);
    expect(shell.footer?.id).toBe('f');
    expect(shell.header).toBeNull();
  });

  it('shows header when global-header is absent (default true)', () => {
    const page = { id: 'p', slug: 'home', sections: [] } as PageConfig;
    const shell = resolveVisitorShell(page, site);
    expect(shell.header?.id).toBe('h');
    expect(shell.footer?.id).toBe('f');
  });

  it('shows header when global-header is true', () => {
    const page = { id: 'p', slug: 'home', sections: [], 'global-header': true } as PageConfig;
    expect(resolveVisitorShell(page, site).header?.id).toBe('h');
  });
});
