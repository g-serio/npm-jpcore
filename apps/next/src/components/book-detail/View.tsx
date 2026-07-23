import type { CSSProperties } from 'react';
import type { BookDetailData, BookDetailSettings } from './types';

export function BookDetailView({
  data,
}: {
  data: BookDetailData;
  settings?: BookDetailSettings;
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
      <h1>{data.item.title}</h1>
    </section>
  );
}
