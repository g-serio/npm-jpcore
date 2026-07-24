import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import { getFileSiteBundle } from '@/lib/loaders/getFileSiteConfig';
import { serializeThemeRootCss } from '@/lib/css/serializeThemeRootCss';
import './globals.css';

export const metadata: Metadata = {
  title: 'OlonJS Next Starter',
  description: 'RSC visitors + admin client island (ADR-0017)',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  const { themeConfig } = getFileSiteBundle();
  const themeCss = serializeThemeRootCss(themeConfig);

  return (
    <html lang="en">
      <head>
        {themeCss ? (
          <style id="olon-theme-vars" dangerouslySetInnerHTML={{ __html: themeCss }} />
        ) : null}
      </head>
      <body className="min-h-screen bg-background text-foreground antialiased">{children}</body>
    </html>
  );
}
