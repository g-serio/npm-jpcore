import type { CSSProperties } from 'react';
import type { FooterData, FooterSettings } from './types';

export function FooterView({
  data,
}: {
  data: FooterData;
  settings?: FooterSettings;
}) {
  return (
    <footer
      style={
        {
          '--local-bg': 'var(--background)',
          '--local-text': 'var(--foreground)',
        } as CSSProperties
      }
      className="bg-[var(--local-bg)] px-6 py-8 text-[var(--local-text)]"
    >
      <p data-jp-field="brandText">{data.brandText}</p>
    </footer>
  );
}
