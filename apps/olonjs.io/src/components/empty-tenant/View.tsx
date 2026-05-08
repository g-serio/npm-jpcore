import type { CSSProperties } from 'react';
import type { EmptyTenantData } from './types';

type EmptyTenantViewProps = {
  data?: EmptyTenantData;
};

export function EmptyTenantView({ data }: EmptyTenantViewProps) {
  const title = data?.title?.trim() || 'Your tenant is empty.';
  const description = data?.description?.trim() || 'Create your first page to start building your site.';

  const rootStyle = {
    '--local-bg': 'var(--background)',
    '--local-text': 'var(--foreground)',
    '--local-muted': 'var(--muted-foreground)',
    '--local-border': 'var(--border)',
    '--local-radius': 'var(--theme-border-radius-md, 0.5rem)',
  } as CSSProperties;

  return (
    <main className="flex min-h-screen items-center justify-center bg-[var(--local-bg)] px-6 text-[var(--local-text)]" style={rootStyle}>
      <section className="w-full max-w-xl rounded-[var(--local-radius)] border border-[var(--local-border)] bg-card p-8 text-card-foreground shadow-sm">
        <h1 className="text-2xl font-semibold tracking-tight" data-jp-field="title">
          {title}
        </h1>
        <p className="mt-3 text-sm text-muted-foreground" data-jp-field="description">
          {description}
        </p>
      </section>
    </main>
  );
}
