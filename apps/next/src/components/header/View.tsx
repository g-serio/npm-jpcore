import type { CSSProperties } from 'react';
import type { HeaderData, HeaderSettings } from './types';

export function HeaderView({
  data,
}: {
  data: HeaderData;
  settings?: HeaderSettings;
}) {
  return (
    <header
      style={
        {
          '--local-bg': 'var(--background)',
          '--local-text': 'var(--foreground)',
          '--local-primary': 'var(--primary)',
        } as CSSProperties
      }
      className="border-b border-black/10 bg-[var(--local-bg)] px-6 py-4 text-[var(--local-text)]"
    >
      <div className="mx-auto flex max-w-5xl items-center justify-between gap-6">
        <a href="/" className="flex items-baseline gap-1 font-semibold tracking-tight">
          <span data-jp-field="logoText">{data.logoText}</span>
          {data.badge ? (
            <span data-jp-field="badge" className="text-[var(--local-primary)]">
              {data.badge}
            </span>
          ) : null}
        </a>
        <nav className="flex flex-wrap items-center gap-4 text-sm">
          {(data.links ?? []).map((link, index) => (
            <a
              key={`${link.href}-${index}`}
              href={link.href}
              data-jp-item-id={link.id ?? String(index)}
              data-jp-item-field="links"
              className="opacity-80 hover:opacity-100"
            >
              {link.label}
            </a>
          ))}
        </nav>
      </div>
    </header>
  );
}
