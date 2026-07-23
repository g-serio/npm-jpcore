import type { CSSProperties } from 'react';
import type { FormDemoData, FormDemoSettings } from './types';

/** Stub View — Task 8 adds FormDemoClient leaf. */
export function FormDemoView({
  data,
}: {
  data: FormDemoData;
  settings?: FormDemoSettings;
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
      <h1 data-jp-field="title">{data.title ?? 'Form demo'}</h1>
    </section>
  );
}
