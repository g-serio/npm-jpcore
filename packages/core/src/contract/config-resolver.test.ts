import { describe, expect, it } from 'vitest';
import {
  applyMenuRefBindingsToDraft,
  applySiteMenuRefBindingsToDraft,
  getMenuRefBindings,
  resolveSectionMenuItems,
  resolveRuntimeConfig,
} from './config-resolver';
import type { MenuConfig, Section, SiteConfig, ThemeConfig } from './kernel';

const themeConfig: ThemeConfig = {
  name: 'test',
  tokens: {
    colors: {},
    typography: { fontFamily: {} },
    borderRadius: {},
  },
};

describe('config-resolver menu refs', () => {
  it('resolves footer menu fields from menu.json like any other section data ref', () => {
    const siteConfig: SiteConfig = {
      identity: { title: 'Test' },
      footer: {
        id: 'global-footer',
        type: 'footer',
        data: {
          legalLinks: { $ref: 'menu.json#/footerLegal' },
        },
      },
    };
    const menuConfig: MenuConfig = {
      footerLegal: [{ label: 'Privacy', href: '/privacy' }],
    };

    const resolved = resolveRuntimeConfig({
      pages: {},
      siteConfig,
      themeConfig,
      menuConfig,
    });

    expect(resolved.siteConfig.footer.data).toEqual({
      legalLinks: [{ label: 'Privacy', href: '/privacy' }],
    });
  });

  it('discovers every section data field bound to menu.json', () => {
    expect(
      getMenuRefBindings({
        menu: { $ref: 'menu.json#/main' },
        legalLinks: { $ref: '../config/menu.json#/footer/legal' },
        theme: { $ref: 'theme.json#/tokens' },
      })
    ).toEqual([
      { fieldKey: 'menu', path: ['main'] },
      { fieldKey: 'legalLinks', path: ['footer', 'legal'] },
    ]);
  });

  it('writes edited resolved menu fields into menuDraft and preserves authored refs', () => {
    const authoredData = {
      brandText: 'OlonJS',
      legalLinks: { $ref: 'menu.json#/footerLegal' },
    };
    const nextData = {
      brandText: 'OlonJS',
      legalLinks: [
        { label: 'Privacy', href: '/privacy' },
        { label: 'Terms', href: '/terms' },
      ],
    };
    const menuDraft: MenuConfig = {
      main: [{ label: 'Home', href: '/' }],
      footerLegal: [{ label: 'Old', href: '/old' }],
    };

    const result = applyMenuRefBindingsToDraft(authoredData, nextData, menuDraft);

    expect(result.normalizedData).toEqual(authoredData);
    expect(result.menuDraft).toEqual({
      main: [{ label: 'Home', href: '/' }],
      footerLegal: [
        { label: 'Privacy', href: '/privacy' },
        { label: 'Terms', href: '/terms' },
      ],
    });
  });

  it('rebases resolved global site data onto authored menu refs before persistence', () => {
    const authoredSite: SiteConfig = {
      identity: { title: 'Test' },
      footer: {
        id: 'global-footer',
        type: 'footer',
        data: {
          socialLinks: { $ref: 'menu.json#/footerSocial' },
          legalLinks: { $ref: 'menu.json#/footerLegal' },
        },
      },
    };
    const resolvedSite: SiteConfig = {
      identity: { title: 'Test' },
      footer: {
        id: 'global-footer',
        type: 'footer',
        data: {
          socialLinks: [{ label: 'GitHub', href: 'https://github.com/olonjs', icon: 'github' }],
          legalLinks: [{ label: 'Privacy', href: '/privacy' }],
        },
      },
    };

    const result = applySiteMenuRefBindingsToDraft(authoredSite, resolvedSite, {
      footerSocial: [],
      footerLegal: [],
    });

    expect(result.site.footer.data).toEqual(authoredSite.footer.data);
    expect(result.menuDraft).toEqual({
      footerSocial: [{ label: 'GitHub', href: 'https://github.com/olonjs', icon: 'github' }],
      footerLegal: [{ label: 'Privacy', href: '/privacy' }],
    });
  });

  it('resolves section menu props from any section data.menu, not only headers', () => {
    const footerSection: Section = {
      id: 'global-footer',
      type: 'footer',
      data: {
        menu: [{ label: 'Privacy', href: '/privacy' }],
      },
    };

    expect(resolveSectionMenuItems(footerSection, [{ label: 'Home', href: '/' }])).toEqual([
      { label: 'Privacy', href: '/privacy' },
    ]);
  });
});
