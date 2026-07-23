import fs from 'node:fs';
import path from 'node:path';
import type { MenuConfig, SiteConfig, ThemeConfig } from '@olonjs/core';
import { resolveLocalDataRoots } from '@olonjs/next/server';

function readJson<T>(filePath: string, fallback: T): T {
  if (!fs.existsSync(filePath)) return fallback;
  return JSON.parse(fs.readFileSync(filePath, 'utf8')) as T;
}

export function getFileSiteBundle(appRoot = process.cwd()): {
  siteConfig: SiteConfig;
  menuConfig: MenuConfig;
  themeConfig: ThemeConfig;
} {
  const { configDir } = resolveLocalDataRoots(appRoot);
  return {
    siteConfig: readJson(
      path.join(configDir, 'site.json'),
      {
        identity: { title: 'OlonJS' },
        footer: { id: 'footer', type: 'footer', data: { brandText: 'OlonJS' } },
      } as unknown as SiteConfig,
    ),
    menuConfig: readJson<MenuConfig>(path.join(configDir, 'menu.json'), {}),
    themeConfig: readJson(path.join(configDir, 'theme.json'), {
      name: 'default',
      tokens: { colors: {}, typography: { fontFamily: {} }, borderRadius: {} },
    } as ThemeConfig),
  };
}
