import type { CSSProperties } from 'react';
import type { BooksListData, BooksListSettings } from './types';

export function BooksListView({
  data,
}: {
  data: BooksListData;
  settings?: BooksListSettings;
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
