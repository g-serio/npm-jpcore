import type { CSSProperties } from 'react';
import type { EmptyTenantData, EmptyTenantSettings } from './types';

export function EmptyTenantView({
  data,
}: {
  data: EmptyTenantData;
  settings?: EmptyTenantSettings;
}) {
  return (
    <section
      style={
        {
          '--local-bg': 'var(--background)',
          '--local-text': 'var(--foreground)',
        } as CSSProperties
      }
      className="bg-[var(--local-bg)] px-6 py-12 text-[var(--local-text)]"
    >
      <h1 data-jp-field="title">{data.title ?? 'Empty tenant'}</h1>
    </section>
  );
}
