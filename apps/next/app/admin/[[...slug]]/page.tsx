import { AdminStudioDynamic } from '@/components/admin/AdminStudioDynamic';
import { getFileCollections } from '@/lib/loaders/getFileCollections';
import { getFilePages } from '@/lib/loaders/getFilePages';
import { getFileSiteBundle } from '@/lib/loaders/getFileSiteConfig';

export const dynamic = 'force-dynamic';

/**
 * Admin Studio entry — client island only (ADR-0017).
 * Persistence: local save-to-file, or Save2Repo cold save when NEXT_PUBLIC_* cloud env is set.
 * HotSave is out of scope for Next v1.
 *
 * Studio is loaded with next/dynamic ssr:false because JsonPagesEngine uses
 * createBrowserRouter (needs `document`) and Next still SSRs `'use client'` once.
 */
export default function AdminCatchAllPage() {
  const pages = getFilePages();
  const collections = getFileCollections();
  const { siteConfig, menuConfig, themeConfig } = getFileSiteBundle();

  return (
    <AdminStudioDynamic
      initialPages={pages}
      initialSiteConfig={siteConfig}
      initialMenuConfig={menuConfig}
      initialThemeConfig={themeConfig}
      initialCollections={collections}
    />
  );
}
