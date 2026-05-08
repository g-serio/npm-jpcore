'use client';

import { ArrowRight, Play } from 'lucide-react';
import { motion, useReducedMotion, type Variants } from 'motion/react';
import type { CSSProperties } from 'react';
import { resolveAssetUrl, useConfig } from '@olonjs/core';
import { TwoToneHeading } from '@/components/ui/two-tone-heading';
import { cn } from '@/lib/utils';
import type { PremiumHeroData, PremiumHeroSettings } from './types';

const fadeUpVariants: Variants = {
  hidden: { opacity: 0, y: 16 },
  visible: (delay = 0) => ({
    opacity: 1,
    y: 0,
    transition: { type: 'spring', duration: 0.65, bounce: 0.1, delay },
  }),
};

/** Avatar ramps: only `theme.json` colors via `:root` bridge (`index.css`). */
const PRESET_AVATAR: Record<'amber' | 'emerald' | 'blue' | 'rose' | 'violet', CSSProperties> = {
  amber: {
    backgroundImage: 'linear-gradient(to bottom right, var(--warning), var(--warning-border))',
    color: 'var(--warning-foreground)',
  },
  emerald: {
    backgroundImage: 'linear-gradient(to bottom right, var(--success), var(--success-indicator))',
    color: 'var(--success-foreground)',
  },
  blue: {
    backgroundImage: 'linear-gradient(to bottom right, var(--info), var(--primary-500))',
    color: 'var(--info-foreground)',
  },
  rose: {
    backgroundImage: 'linear-gradient(to bottom right, var(--destructive), var(--destructive-border))',
    color: 'var(--destructive-foreground)',
  },
  violet: {
    backgroundImage: 'linear-gradient(to bottom right, var(--primary-300), var(--primary-700))',
    color: 'var(--primary-foreground)',
  },
};

type PremiumHeroViewProps = {
  data: PremiumHeroData;
  settings?: PremiumHeroSettings;
};

export function PremiumHeroView({ data }: PremiumHeroViewProps) {
  const shouldReduceMotion = useReducedMotion();
  const initial = shouldReduceMotion ? 'visible' : 'hidden';
  const { tenantId = 'alpha' } = useConfig();

  const bgUrlRaw = data.backgroundImage?.url?.trim();
  const bgResolved = bgUrlRaw ? resolveAssetUrl(bgUrlRaw, tenantId) : '';
  const bgAlt = data.backgroundImage?.alt?.trim() ?? '';

  const rootStyle = {
    '--local-bg': 'var(--background)',
    '--local-text': 'var(--foreground)',
    '--local-muted': 'var(--muted-foreground)',
    '--local-border': 'var(--border)',
    '--local-radius': 'var(--theme-border-radius-md)',
    backgroundColor: 'var(--local-bg)',
  } as CSSProperties;

  return (
    <section
      aria-label={bgAlt || undefined}
      className="relative flex min-h-screen w-full items-start justify-center overflow-hidden text-[var(--local-text)] pt-24 md:pt-16"
      style={rootStyle}
    >
      {bgResolved && (
        <div
          aria-hidden
          className="absolute inset-0 z-0"
          style={{
            backgroundImage: `url(${JSON.stringify(bgResolved)})`,
            backgroundSize: 'cover',
backgroundRepeat: 'no-repeat',
            mixBlendMode: 'soft-light',
            opacity: 0.5,
          }}
        />
      )}
      {data.backgroundImage && (
        <span aria-hidden className="sr-only">
          <span data-jp-field="backgroundImage.url">{data.backgroundImage.url}</span>
          <span data-jp-field="backgroundImage.alt">{data.backgroundImage.alt}</span>
        </span>
      )}
      <div className="pointer-events-none absolute inset-0 z-[1] overflow-hidden">
        <motion.div
          animate={{ opacity: 1 }}
          className="-translate-x-1/2 absolute top-[-20%] left-1/2 h-[800px] w-[1200px]"
          initial={{ opacity: 0 }}
          style={{
            background:
              'radial-gradient(ellipse at center, color-mix(in hsl, var(--primary) 14%, transparent) 0%, color-mix(in hsl, var(--primary) 5%, transparent) 35%, transparent 70%)',
          }}
          transition={{ duration: 2, ease: 'easeOut' }}
        />
        <div
          className="absolute inset-0 opacity-[0.012] dark:opacity-[0.025]"
          style={{
            backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E")`,
          }}
        />
        <div className="absolute right-0 bottom-0 left-0 h-40 bg-gradient-to-t from-background to-transparent" />
      </div>

      <div className="relative z-10 flex flex-col items-center px-6 pt-[12vh] pb-24 sm:pt-[16vh]">
        <motion.div
          animate="visible"
          className="mb-8 flex items-center gap-2"
          custom={0}
          initial={initial}
          variants={fadeUpVariants}
        >
          <a href="https://www.npmjs.com/package/@olonjs/core">
            <img alt="npm version" src="https://img.shields.io/npm/v/@olonjs/core?color=blue&style=flat" />
          </a>
          <a href="https://github.com/olonjs/npm-jpcore/blob/main/LICENSE">
            <img alt="license" src="https://img.shields.io/badge/license-MIT-green?style=flat" />
          </a>
        </motion.div>

        <motion.div
          animate="visible"
          className="max-w-3xl"
          custom={0}
          initial={initial}
          variants={fadeUpVariants}
        >
          <TwoToneHeading
            align="center"
            as="h1"
            className="text-balance font-semibold text-4xl leading-[1.05] tracking-[-0.035em] sm:text-5xl md:text-6xl lg:text-7xl xl:text-[5.25rem]"
            primaryDataJpField="primaryTitle"
            primaryGradient="primaryLight"
            primaryText={data.primaryTitle}
            secondaryDataJpField="secondaryTitle"
            secondaryGradient="secondary"
            secondaryText={data.secondaryTitle}
          />
        </motion.div>

        <motion.p
          animate="visible"
          className="mt-8 max-w-lg text-pretty text-center text-base text-muted-foreground leading-[1.6] sm:text-lg md:text-xl"
          custom={0.22}
          data-jp-field="subtitle"
          initial={initial}
          variants={fadeUpVariants}
        >
          {data.subtitle}
        </motion.p>

        <motion.div
          animate="visible"
          className="mt-10 flex flex-col items-center gap-3 sm:flex-row sm:gap-4"
          custom={0.34}
          initial={initial}
          variants={fadeUpVariants}
        >
          {data.primaryCta.label && data.primaryCta.href && (
            <a
              className={cn(
                'group relative inline-flex w-full cursor-pointer items-center justify-center gap-2 overflow-hidden rounded-full bg-foreground px-7 py-3.5 font-medium text-background text-sm transition-shadow duration-200 sm:w-auto',
                'shadow-[0px_0px_0px_1px_color-mix(in_hsl,var(--foreground)_10%,transparent),0px_2px_4px_-1px_color-mix(in_hsl,var(--foreground)_10%,transparent),0px_4px_8px_0px_color-mix(in_hsl,var(--foreground)_6%,transparent)]',
                'hover:shadow-[0px_0px_0px_1px_color-mix(in_hsl,var(--foreground)_12%,transparent),0px_4px_8px_-1px_color-mix(in_hsl,var(--foreground)_12%,transparent),0px_6px_12px_0px_color-mix(in_hsl,var(--foreground)_8%,transparent)]'
              )}
              data-jp-field="primaryCta.href"
              href={data.primaryCta.href}
            >
              <span className="relative z-10" data-jp-field="primaryCta.label">
                {data.primaryCta.label}
              </span>
              <ArrowRight
                className="relative z-10 size-4 transition-transform duration-300 group-hover:translate-x-0.5"
                strokeWidth={2}
              />
            </a>
          )}
          {data.secondaryCta.label && data.secondaryCta.href && (
            <a
              className={cn(
                'group inline-flex w-full cursor-pointer items-center justify-center gap-2.5 rounded-full px-6 py-3.5 font-medium text-foreground text-sm backdrop-blur-sm transition-shadow duration-200 sm:w-auto',
                'bg-[color-mix(in_hsl,var(--background)_80%,transparent)]',
                'shadow-[0px_0px_0px_1px_color-mix(in_hsl,var(--foreground)_6%,transparent),0px_1px_2px_-1px_color-mix(in_hsl,var(--foreground)_6%,transparent),0px_2px_4px_0px_color-mix(in_hsl,var(--foreground)_4%,transparent)]',
                'hover:shadow-[0px_0px_0px_1px_color-mix(in_hsl,var(--foreground)_8%,transparent),0px_2px_4px_-1px_color-mix(in_hsl,var(--foreground)_8%,transparent),0px_4px_6px_0px_color-mix(in_hsl,var(--foreground)_6%,transparent)]'
              )}
              data-jp-field="secondaryCta.href"
              href={data.secondaryCta.href}
            >
              <span data-jp-field="secondaryCta.label">{data.secondaryCta.label}</span>
              <span className="flex size-6 items-center justify-center rounded-full bg-foreground transition-transform duration-300 group-hover:scale-105">
                <Play className="ml-0.5 size-2.5 fill-background text-background" />
              </span>
            </a>
          )}
        </motion.div>

        {(data.socialProofCount || data.socialProofPrefix) && <motion.div
          animate="visible"
          className="mt-14 flex select-none items-center gap-4"
          custom={0.5}
          initial={initial}
          variants={fadeUpVariants}
        >
          <div className="-space-x-3 flex">
            {data.avatars.map((avatar, i) => (
              <motion.div
                animate={{ opacity: 1, x: 0 }}
                className={cn(
                  'flex size-10 items-center justify-center rounded-full font-semibold text-xs ring-[2.5px] ring-background',
                  'outline outline-1 outline-offset-[-1px] outline-border'
                )}
                data-jp-item-field="avatars"
                data-jp-item-id={avatar.id}
                initial={shouldReduceMotion ? { opacity: 1 } : { opacity: 0, x: -8 }}
                key={avatar.id}
                style={PRESET_AVATAR[avatar.preset]}
                transition={{ type: 'spring', duration: 0.4, delay: 0.56 + i * 0.05, bounce: 0 }}
              >
                <span data-jp-field="initials">{avatar.initials}</span>
              </motion.div>
            ))}
          </div>
          <div className="flex flex-col gap-0.5">
            <div className="flex items-center gap-0.5">
              {Array.from({ length: 5 }).map((_, i) => (
                <svg className="size-4 fill-current text-[var(--warning)]" key={i} viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
              ))}
            </div>
            <span className="text-muted-foreground text-sm">
              <span data-jp-field="socialProofPrefix">{data.socialProofPrefix}</span>{' '}
              <span className="font-semibold text-foreground tabular-nums" data-jp-field="socialProofCount">
                {data.socialProofCount}
              </span>
            </span>
          </div>
        </motion.div>}
      </div>
    </section>
  );
}
