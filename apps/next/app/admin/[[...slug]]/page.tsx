import { AdminStudioClient } from '@/components/admin/AdminStudioClient';
import { getFileCollections } from '@/lib/loaders/getFileCollections';
import { getFilePages } from '@/lib/loaders/getFilePages';
import { getFileSiteBundle } from '@/lib/loaders/getFileSiteConfig';

export const dynamic = 'force-dynamic';

/**
 * Admin Studio entry — client island only (ADR-0017).
 * Server loads JSP JSON seeds; persistence is local save-to-file for Task 9.
 */
export default function AdminCatchAllPage() {
  const pages = getFilePages();
  const collections = getFileCollections();
  const { siteConfig, menuConfig, themeConfig } = getFileSiteBundle();

  return (
    <AdminStudioClient
      initialPages={pages}
      initialSiteConfig={siteConfig}
      initialMenuConfig={menuConfig}
      initialThemeConfig={themeConfig}
      initialCollections={collections}
      showLocalSave
      showColdSave={false}
    />
  );
}
