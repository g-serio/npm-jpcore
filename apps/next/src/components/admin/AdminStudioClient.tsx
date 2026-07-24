'use client';

import { useCallback, useMemo, useState, type ReactNode } from 'react';
import type {
  JsonPagesConfig,
  MenuConfig,
  PageConfig,
  ProjectState,
  SiteConfig,
  ThemeConfig,
} from '@olonjs/core';
import { AdminIsland } from '@olonjs/next/client';
import { addSectionConfig } from '@/lib/addSectionConfig';
import { hydrateLocalProjectState } from '@/lib/admin/hydrateLocalProjectState';
import { CollectionRegistry } from '@/lib/CollectionRegistry';
import { ComponentRegistry } from '@/lib/ComponentRegistry';
import { iconMap } from '@/lib/IconResolver';
import { SECTION_SCHEMAS } from '@/lib/schemas';

export type AdminStudioClientProps = {
  tenantId?: string;
  initialPages: Record<string, PageConfig>;
  initialSiteConfig: SiteConfig;
  initialMenuConfig: MenuConfig;
  initialThemeConfig: ThemeConfig;
  initialCollections: NonNullable<JsonPagesConfig['collections']>;
  /** When false (Save2Repo cloud), hide local disk save. Default true for T9. */
  showLocalSave?: boolean;
  /** Save2Repo cold save — wired in Task 10. */
  showColdSave?: boolean;
  coldSave?: (state: ProjectState, slug: string) => Promise<void>;
  /** Optional drawer / overlays (cold-save UI). */
  children?: ReactNode;
};

/**
 * Tenant-wired admin island: protocol registries + local persistence.
 * HotSave is intentionally omitted (out of scope for Next v1).
 */
export function AdminStudioClient({
  tenantId = 'next',
  initialPages,
  initialSiteConfig,
  initialMenuConfig,
  initialThemeConfig,
  initialCollections,
  showLocalSave = true,
  showColdSave = false,
  coldSave,
  children,
}: AdminStudioClientProps) {
  const [pages, setPages] = useState(initialPages);
  const [siteConfig, setSiteConfig] = useState(initialSiteConfig);
  const [menuConfig, setMenuConfig] = useState(initialMenuConfig);
  const [themeConfig, setThemeConfig] = useState(initialThemeConfig);
  const [collections, setCollections] = useState(initialCollections);

  const saveToFile = useCallback(
    async (state: ProjectState, slug: string): Promise<void> => {
      const res = await fetch('/api/save-to-file', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ projectState: state, slug }),
      });
      const body = (await res.json().catch(() => ({}))) as { error?: string };
      if (!res.ok) throw new Error(body.error ?? `Save to file failed: ${res.status}`);
      hydrateLocalProjectState({
        state,
        slug,
        setPages,
        setSiteConfig,
        setMenuConfig,
        setThemeConfig,
        setCollections,
      });
    },
    [],
  );

  const refDocuments = useMemo(
    () => ({
      'menu.json': menuConfig,
      'config/menu.json': menuConfig,
      'src/data/config/menu.json': menuConfig,
    }),
    [menuConfig],
  );

  const config: JsonPagesConfig = useMemo(
    () => ({
      tenantId,
      basePath: '/',
      registry: ComponentRegistry as JsonPagesConfig['registry'],
      schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
      collectionSchemas: CollectionRegistry as unknown as JsonPagesConfig['collectionSchemas'],
      pages,
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      refDocuments,
      // Visitor theme lives in app/globals.css; engine still requires themeCss.
      themeCss: { tenant: '' },
      iconRegistry: iconMap,
      addSection: addSectionConfig,
      persistence: {
        saveToFile,
        ...(coldSave ? { coldSave } : {}),
        showLocalSave,
        showHotSave: false,
        showColdSave,
      },
    }),
    [
      tenantId,
      pages,
      siteConfig,
      themeConfig,
      menuConfig,
      collections,
      refDocuments,
      saveToFile,
      coldSave,
      showLocalSave,
      showColdSave,
    ],
  );

  return <AdminIsland config={config}>{children}</AdminIsland>;
}
