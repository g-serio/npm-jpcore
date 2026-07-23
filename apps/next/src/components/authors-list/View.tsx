import type { CSSProperties } from 'react';
import type { AuthorsListData, AuthorsListSettings } from './types';

export function AuthorsListView({
  data,
}: {
  data: AuthorsListData;
  settings?: AuthorsListSettings;
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
      <h1 data-jp-field="title">{data.title}</h1>
    </section>
  );
}
