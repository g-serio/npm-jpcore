'use client';

import { resolveAssetUrl } from '@olonjs/core';
import { useConfig } from '@olonjs/react';
import type { CSSProperties } from 'react';
import { OSSSection } from '@/app/sticky-section';
import { iconMap } from '@/lib/IconResolver';
import type { StickySectionData, StickySectionSettings } from './types';

type StickySectionViewProps = {
  data: StickySectionData;
  settings?: StickySectionSettings;
};

const statIconClass = 'size-5 shrink-0 text-muted-foreground';

export function StickySectionView({ data, settings }: StickySectionViewProps) {
  const { tenantId = 'alpha' } = useConfig();
  const stickyTopPx = settings?.stickyTopPx ?? 90;

  const rootStyle = {
    '--local-bg': 'var(--background)',
    '--local-text': 'var(--foreground)',
    '--local-muted': 'var(--muted-foreground)',
    '--local-border': 'var(--border)',
    '--local-radius': 'var(--theme-border-radius-md, 0.5rem)',
  } as CSSProperties;

  const projects = data.projects.map((p) => {
    const Icon = iconMap[p.iconVariant as keyof typeof iconMap] ?? null;
    const id = p.id ?? p.name;
    return {
      id,
      name: p.name,
      tagline: p.tagline,
      description: p.description,
      stars: p.stars,
      starsLabel: p.starsLabel,
      contributors: p.contributors,
      contributorsLabel: p.contributorsLabel,
      exploreUrl: p.exploreUrl,
      image: resolveAssetUrl(p.image.url, tenantId),
      imageAlt: p.image.alt,
      iconVariant: p.iconVariant,
      statIcon: Icon ? <Icon aria-hidden className={statIconClass} /> : null,
      icon: Icon ? <Icon aria-hidden className="size-6" strokeWidth={1.5} /> : null,
    };
  });

  /** Layout shell matches `ScrollAccordionView`: section bg + `max-w-5xl` column (not full bleed). */
  return (
    <section className="bg-[var(--local-bg)]" style={rootStyle}>
      <div className="mx-auto max-w-5xl px-6">
        {(data.eyebrow || data.heading || data.description) && (
          <div className="pb-16 pt-16 md:pt-24">
            {data.eyebrow && (
              <p
                className="mb-4 text-xs font-semibold tracking-widest uppercase text-[var(--local-muted)]"
                data-jp-field="eyebrow"
              >
                {data.eyebrow}
              </p>
            )}
            {data.heading && (
              <h2
                className="text-balance text-4xl leading-tight font-semibold text-[var(--local-text)]"
                data-jp-field="heading"
              >
                {data.heading}
              </h2>
            )}
            {data.description && (
              <p
                className="mt-6 max-w-2xl text-[var(--local-muted)] leading-relaxed"
                data-jp-field="description"
              >
                {data.description}
              </p>
            )}
          </div>
        )}
        <OSSSection projects={projects} stickyNavOffsetPx={stickyTopPx} />
      </div>
    </section>
  );
}
