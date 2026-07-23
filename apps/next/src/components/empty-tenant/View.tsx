import type { EmptyTenantData, EmptyTenantSettings } from './types';

type EmptyTenantViewProps = {
  data?: EmptyTenantData;
  settings?: EmptyTenantSettings;
};

/** Server empty-tenant UI when the page registry has no pages. */
export function EmptyTenantView({ data }: EmptyTenantViewProps) {
  const title = data?.title?.trim() || 'Your tenant is empty.';
  const description =
    data?.description?.trim() || 'Create your first page to start building your site.';

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-6 text-foreground">
      <section className="w-full max-w-xl rounded-xl border border-border bg-card p-8 shadow-sm">
        <h1 data-jp-field="title" className="text-2xl font-semibold tracking-tight">
          {title}
        </h1>
        <p data-jp-field="description" className="mt-3 text-sm text-muted-foreground">
          {description}
        </p>
      </section>
    </main>
  );
}
