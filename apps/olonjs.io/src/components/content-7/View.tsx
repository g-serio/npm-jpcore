'use client';

import { ChevronRight } from 'lucide-react';
import { resolveAssetUrl } from '@olonjs/core';
import { useConfig } from '@olonjs/react';
import type { CSSProperties } from 'react';
import { cn } from '@/lib/utils';
import type { Content7Data, Content7Settings } from './types';

type Content7ViewProps = {
  data: Content7Data;
  settings?: Content7Settings;
};

function tileFrameClass(variant: 'elevated' | 'surface') {
  if (variant === 'surface') {
    return cn(
      'bg-[var(--local-card)] ring-[var(--local-border)] rounded-xl border border-transparent shadow ring-1'
    );
  }
  return cn(
    'bg-[var(--local-tile)] ring-[var(--local-border)] rounded-xl border border-transparent p-6 shadow ring-1'
  );
}

export function Content7View({ data }: Content7ViewProps) {
  const { tenantId = 'alpha' } = useConfig();

  const rootStyle = {
    '--local-bg': 'var(--background)',
    '--local-text': 'var(--foreground)',
    '--local-muted': 'var(--muted-foreground)',
    '--local-primary': 'var(--primary)',
    '--local-border': 'var(--border)',
    '--local-card': 'var(--card)',
    '--local-tile': 'var(--card)',
  } as CSSProperties;

  return (
    <section
      className="bg-[var(--local-bg)] py-16 text-[var(--local-text)] @container md:py-24"
      style={rootStyle}
    >
      <div className="mx-auto max-w-5xl px-6">
        {data.eyebrow && (
          <p
            className="mb-4 text-xs font-semibold tracking-widest uppercase text-[var(--local-primary)]"
            data-jp-field="eyebrow"
          >
            {data.eyebrow}
          </p>
        )}

        <h2 className="text-[var(--local-muted)] text-balance text-4xl leading-tight font-semibold md:w-2/3">
          <span data-jp-field="headingLead">{data.headingLead}</span>{' '}
          <strong className="font-semibold text-[var(--local-text)]" data-jp-field="headingEmphasis">
            {data.headingEmphasis}
          </strong>
        </h2>

        {data.description && (
          <p
            className="mt-6 max-w-2xl text-[var(--local-muted)] leading-relaxed"
            data-jp-field="description"
          >
            {data.description}
          </p>
        )}

        <div className="@3xl:grid-cols-3 @xl:grid-cols-2 mt-12 grid gap-6">
          {data.cards.map((card) => (
            <div
              key={card.id}
              className="row-span-4 grid grid-rows-subgrid gap-4"
              data-jp-item-field="cards"
              data-jp-item-id={card.id}
            >
              <div
                className={cn(
                  'flex h-36 items-center justify-center overflow-hidden',
                  tileFrameClass(card.tileVariant ?? 'elevated')
                )}
              >
                <img
                  src={resolveAssetUrl(card.image.url, tenantId)}
                  alt={card.image.alt}
                  className={cn(
                    'h-full w-full object-contain p-4',
                    card.tileVariant === 'surface' && 'rounded-xl'
                  )}
                  data-jp-field="image.url"
                  loading="lazy"
                  decoding="async"
                />
              </div>
              <h3
                className="text-base font-semibold text-[var(--local-text)]"
                data-jp-field="eyebrow"
              >
                {card.eyebrow}
              </h3>
              <p className="text-[var(--local-muted)]">
                <span data-jp-field="copyLead">{card.copyLead}</span>{' '}
                <strong
                  className="font-semibold text-[var(--local-text)]"
                  data-jp-field="copyEmphasis"
                >
                  {card.copyEmphasis}
                </strong>{' '}
                <span data-jp-field="copyTrail">{card.copyTrail}</span>
              </p>
              {card.readLink.label && card.readLink.href && (
                <a
                  href={card.readLink.href}
                  className="flex items-center gap-1 text-sm text-[var(--local-primary)] transition-colors duration-200 hover:text-[var(--local-text)]"
                  data-jp-field="readLink.href"
                >
                  <span data-jp-field="readLink.label">{card.readLink.label}</span>
                  <ChevronRight className="size-3.5 translate-y-px" aria-hidden />
                </a>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
