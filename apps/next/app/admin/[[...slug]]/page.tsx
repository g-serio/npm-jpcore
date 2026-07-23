import { AdminStudioWithCloud } from '@/components/admin/AdminStudioWithCloud';
import { getFileCollections } from '@/lib/loaders/getFileCollections';
import { getFilePages } from '@/lib/loaders/getFilePages';
import { getFileSiteBundle } from '@/lib/loaders/getFileSiteConfig';

export const dynamic = 'force-dynamic';

/**
 * Admin Studio entry — client island only (ADR-0017).
 * Persistence: local save-to-file, or Save2Repo cold save when NEXT_PUBLIC_* cloud env is set.
 * HotSave is out of scope for Next v1.
 */
export default function AdminCatchAllPage() {
  const pages = getFilePages();
  const collections = getFileCollections();
  const { siteConfig, menuConfig, themeConfig } = getFileSiteBundle();

  return (
    <AdminStudioWithCloud
      initialPages={pages}
      initialSiteConfig={siteConfig}
      initialMenuConfig={menuConfig}
      initialThemeConfig={themeConfig}
      initialCollections={collections}
    />
  );
}
