import type React from 'react';
import type { FooterData, FooterSettings } from './types';

type FooterViewProps = {
  data: FooterData;
  settings?: FooterSettings;
};

export function FooterView({ data, settings }: FooterViewProps) {
  const links = data.links ?? [];

  return (
    <footer
      style={{
        '--local-bg': 'var(--background)',
        '--local-text': 'var(--foreground)',
        '--local-muted': 'var(--muted-foreground)',
        '--local-border': 'var(--border)',
      } as React.CSSProperties}
      className="border-t border-[var(--local-border)] bg-[var(--local-bg)] px-6 py-10 text-[var(--local-text)]"
    >
      <div className="mx-auto flex w-full max-w-5xl flex-col gap-8 md:flex-row md:items-end md:justify-between">
        <div className="max-w-md">
          <div className="flex items-center gap-3">
            {settings?.showLogo !== false && (
              <span className="flex h-9 w-9 items-center justify-center rounded-lg border border-[var(--local-border)] text-sm font-semibold">
                O
              </span>
            )}
            <p data-jp-field="brandText" className="text-lg font-semibold tracking-tight">
              {data.brandText}
            </p>
          </div>
          {data.description && (
            <p data-jp-field="description" className="mt-3 text-sm leading-6 text-[var(--local-muted)]">
              {data.description}
            </p>
          )}
          <p data-jp-field="copyright" className="mt-4 text-xs text-[var(--local-muted)]">
            {data.copyright}
          </p>
        </div>

        <nav data-jp-field="links" className="flex flex-wrap gap-4 text-sm">
          {links.map((link) => (
            <a
              key={link.id}
              data-jp-item-id={link.id}
              data-jp-item-field="links"
              href={link.href}
              target={link.external ? '_blank' : undefined}
              rel={link.external ? 'noreferrer' : undefined}
              className="text-[var(--local-muted)] transition-colors hover:text-[var(--local-text)]"
            >
              {link.label}
            </a>
          ))}
          {data.designSystemHref && (
            <a
              data-jp-field="designSystemHref"
              href={data.designSystemHref}
              className="text-[var(--local-muted)] transition-colors hover:text-[var(--local-text)]"
            >
              Design system
            </a>
          )}
        </nav>
      </div>
    </footer>
  );
}
