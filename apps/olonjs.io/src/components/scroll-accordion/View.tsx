'use client';

import { ArrowRight } from 'lucide-react';
import { useCallback, useEffect, useRef, useState, type CSSProperties } from 'react';
import { resolveAssetUrl } from '@olonjs/core';
import { useConfig } from '@olonjs/react';
import { Button } from '@/components/ui/button';
import type { ScrollAccordionData, ScrollAccordionSettings } from './types';

/** Pinned accordion rows stack under the fixed site nav (leave room below header). */
const STICKY_TOP_BASE = 90;
const HEADER_HEIGHT = 72;
const CONTENT_HEIGHT = 400;

type ScrollAccordionViewProps = {
  data: ScrollAccordionData;
  settings?: ScrollAccordionSettings;
};

export function ScrollAccordionView({ data }: ScrollAccordionViewProps) {
  const { tenantId = 'alpha' } = useConfig();
  const items = data.items;
  const total = items.length;
  const [activeIndex, setActiveIndex] = useState(0);
  const sectionRefs = useRef<(HTMLDivElement | null)[]>([]);

  const handleScroll = useCallback(() => {
    let next = 0;
    sectionRefs.current.forEach((section, index) => {
      if (!section) return;
      const rect = section.getBoundingClientRect();
      const stickyOffset = STICKY_TOP_BASE + index * HEADER_HEIGHT;
      if (rect.top <= stickyOffset + 10) {
        next = index;
      }
    });
    setActiveIndex(next);
  }, []);

  useEffect(() => {
    window.addEventListener('scroll', handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener('scroll', handleScroll);
  }, [handleScroll, total]);

  const rootStyle = {
    '--local-bg': 'var(--background)',
    '--local-text': 'var(--foreground)',
    '--local-muted': 'var(--muted-foreground)',
    '--local-primary': 'var(--primary)',
    '--local-border': 'var(--border)',
    '--local-radius': 'var(--theme-border-radius-md, 0.5rem)',
  } as CSSProperties;

  /** Layout matches `src/app/scroll-accordion.tsx`: sticky shell + inner solid bg, per-row z-index. */
  return (
    <section className="bg-[var(--local-bg)] text-[var(--local-text)]" style={rootStyle}>
      <div className="mx-auto max-w-5xl px-6">
        {(data.eyebrow || data.heading || data.description) && (
          <div className="pb-16 pt-16 md:pt-24">
            {data.eyebrow && (
              <p
                className="mb-4 text-xs font-semibold tracking-widest uppercase text-[var(--local-primary)]"
                data-jp-field="eyebrow"
              >
                {data.eyebrow}
              </p>
            )}
            {data.heading && (
              <h2
                className="text-balance text-4xl leading-tight font-semibold md:w-2/3"
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

        {items.map((item, index) => {
          const isActive = activeIndex === index;
          const isPast = index < activeIndex;
          const isLast = index === total - 1;

          return (
            <div
              className="sticky"
              data-jp-item-field="items"
              data-jp-item-id={item.id}
              key={item.id}
              ref={(el) => {
                sectionRefs.current[index] = el;
              }}
              style={{
                top: STICKY_TOP_BASE + index * HEADER_HEIGHT,
                zIndex: index + 1,
              }}
            >
              <div className="bg-[var(--local-bg)]">
                <div className="border-foreground/20 border-t border-dashed">
                <div className="flex items-baseline gap-6 py-5 md:gap-12">
                  <span
                    className="w-16 shrink-0 font-mono text-foreground/50 text-xs md:w-28 md:text-sm"
                    data-jp-field="number"
                  >
                    {item.number}
                  </span>
                  <div
                    className="flex items-center gap-4"
                    style={{
                      opacity: isPast ? 0.35 : 1,
                      transition: 'opacity 300ms ease-out',
                    }}
                  >
                    {item.icon?.url && (
                      <img
                        src={resolveAssetUrl(item.icon.url, tenantId)}
                        alt={item.icon.alt ?? ''}
                        className="size-10 shrink-0 object-contain md:size-12"
                        data-jp-field="icon.url"
                        loading="lazy"
                        decoding="async"
                      />
                    )}
                    <h2
                      className="font-medium text-2xl tracking-tight md:text-4xl lg:text-[2.75rem]"
                      data-jp-field="title"
                    >
                      {item.title}
                    </h2>
                  </div>
                </div>
              </div>

              <div
                className="flex gap-6 md:gap-12"
                style={{
                  height: isLast ? 'auto' : CONTENT_HEIGHT,
                  minHeight: isLast ? 300 : undefined,
                }}
              >
                <div className="w-16 shrink-0 md:w-28" />
                <div
                  className="pt-6"
                  style={{
                    opacity: isActive ? 1 : 0,
                    transition: 'opacity 350ms ease-out',
                    transitionDelay: isActive ? '50ms' : '0ms',
                  }}
                >
                  <p
                    className="max-w-md text-base text-foreground/70 leading-relaxed md:max-w-lg md:text-lg md:leading-relaxed"
                    data-jp-field="description"
                  >
                    {item.description}
                  </p>
                  {item.cta.label && item.cta.href && (
                    <Button
                      asChild
                      className="mt-8 rounded-full border-foreground/30 px-6 py-5 font-medium text-xs uppercase tracking-[0.12em] hover:border-foreground/60 hover:bg-transparent active:scale-[0.98] md:mt-10 md:px-8"
                      variant="outline"
                    >
                      <a data-jp-field="cta.href" href={item.cta.href}>
                        <span data-jp-field="cta.label">{item.cta.label}</span>
                        <ArrowRight className="ml-3 h-4 w-4" />
                      </a>
                    </Button>
                  )}
                </div>
              </div>
              </div>
            </div>
          );
        })}

        <div
          className="sticky border-foreground/20 border-t border-dashed"
          style={{
            top: STICKY_TOP_BASE + total * HEADER_HEIGHT,
            zIndex: total + 1,
          }}
        />
      </div>
     
    </section>
  );
}
