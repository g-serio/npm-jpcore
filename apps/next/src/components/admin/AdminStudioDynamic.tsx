'use client';

import dynamic from 'next/dynamic';
import type { ComponentProps } from 'react';
import type { AdminStudioWithCloud } from '@/components/admin/AdminStudioWithCloud';

/**
 * BrowserRouter / createBrowserRouter need `document`.
 * Next still SSRs `'use client'` trees once — disable SSR for the Studio island.
 */
export const AdminStudioDynamic = dynamic(
  () =>
    import('@/components/admin/AdminStudioWithCloud').then((m) => ({
      default: m.AdminStudioWithCloud,
    })),
  {
    ssr: false,
    loading: () => (
      <main className="flex min-h-screen items-center justify-center bg-background text-muted-foreground">
        Loading Studio…
      </main>
    ),
  },
);

export type AdminStudioDynamicProps = ComponentProps<typeof AdminStudioWithCloud>;
