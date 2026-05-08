'use client';

import { motion, useReducedMotion, type Variants } from 'motion/react';
import type { CSSProperties, SVGProps } from 'react';
import { resolveAssetUrl, useConfig } from '@olonjs/core';
import { TwoToneHeading } from '@/components/ui/two-tone-heading';
import type { FooterData, FooterSettings } from './types';

const APPLE_EASE = [0.22, 1, 0.36, 1] as const;

const columnVariants: Variants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.08, delayChildren: 0.1 },
  },
};

const itemVariants: Variants = {
  hidden: { opacity: 0, y: 12 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: APPLE_EASE },
  },
};

type FooterViewProps = {
  data: FooterData;
  settings?: FooterSettings;
};

function SocialGlyph({
  icon,
  ...props
}: { icon: 'github' | 'x' | 'discord' } & SVGProps<SVGSVGElement>) {
  if (icon === 'github') {
    return (
      <svg fill="currentColor" viewBox="0 0 24 24" {...props}>
        <path
          clipRule="evenodd"
          d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
          fillRule="evenodd"
        />
      </svg>
    );
  }
  if (icon === 'x') {
    return (
      <svg fill="currentColor" viewBox="0 0 24 24" {...props}>
        <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
      </svg>
    );
  }
  return (
    <svg fill="currentColor" viewBox="0 0 24 24" {...props}>
      <path d="M20.317 4.37a19.791 19.791 0 00-4.885-1.515.074.074 0 00-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 00-5.487 0 12.64 12.64 0 00-.617-1.25.077.077 0 00-.079-.037A19.736 19.736 0 003.677 4.37a.07.07 0 00-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 00.031.057 19.9 19.9 0 005.993 3.03.078.078 0 00.084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 00-.041-.106 13.107 13.107 0 01-1.872-.892.077.077 0 01-.008-.128 10.2 10.2 0 00.372-.292.074.074 0 01.077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 01.078.01c.12.098.246.198.373.292a.077.077 0 01-.006.127 12.299 12.299 0 01-1.873.892.077.077 0 00-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 00.084.028 19.839 19.839 0 006.002-3.03.077.077 0 00.032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 00-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.095 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.095 2.157 2.42 0 1.333-.947 2.418-2.157 2.418z" />
    </svg>
  );
}

export function FooterView({ data }: FooterViewProps) {
  const { tenantId = 'alpha' } = useConfig();
  const year = data.copyrightYear ?? new Date().getFullYear();
  const prefersReduced = useReducedMotion();

  const logoUrl = data.logoMark?.url?.trim();
  const resolvedLogo = logoUrl ? resolveAssetUrl(logoUrl, tenantId) : '';
  const monogram = (data.brandText?.trim()?.[0] ?? 'A').toUpperCase();

  const rootStyle = {
    '--local-bg': 'var(--background)',
    '--local-text': 'var(--foreground)',
    '--local-muted': 'var(--muted-foreground)',
    '--local-border': 'var(--border)',
  } as CSSProperties;

  return (
    <footer
      className="relative w-full overflow-hidden bg-[var(--local-bg)] text-[var(--local-text)]"
      style={rootStyle}
    >
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.015] dark:opacity-[0.03]"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E")`,
        }}
      />

      <div className="relative z-10 mx-auto max-w-6xl px-6">
        <div className="border-[var(--local-border)]/40 border-t" />

        <motion.div
          className="grid gap-10 py-16 sm:grid-cols-2 lg:grid-cols-4 lg:gap-8 lg:py-20"
          initial={prefersReduced ? false : 'hidden'}
          variants={columnVariants}
          viewport={{ once: true, margin: '-80px' }}
          whileInView="visible"
        >
          <motion.div className="flex flex-col gap-5 sm:col-span-2 lg:col-span-1" variants={itemVariants}>
            <div className="flex items-center gap-2.5">
              {resolvedLogo ? (
                <img
                  alt={data.logoMark?.alt ?? ''}
                  className="size-8 rounded-lg object-cover"
                  data-jp-field="logoMark.url"
                  src={resolvedLogo}
                />
              ) : (
                <div className="flex size-8 items-center justify-center rounded-lg bg-foreground">
                  <span className="font-bold text-background text-sm">{monogram}</span>
                </div>
              )}
              <span className="font-semibold text-lg tracking-tight" data-jp-field="brandText">
                {data.brandText}
              </span>
            </div>
            <TwoToneHeading
              align="left"
              as="p"
              className="max-w-[240px] text-[14px] leading-relaxed"
              primaryDataJpField="taglinePrimary"
              primaryGradient="helper"
              primaryText={data.taglinePrimary}
              secondaryDataJpField="taglineSecondary"
              secondaryGradient="helper"
              secondaryText={data.taglineSecondary}
              size="xs"
            />
            <div className="flex items-center gap-3">
              {data.socialLinks.map((social) => (
                <a
                  aria-label={social.name}
                  className="flex size-8 items-center justify-center rounded-lg text-muted-foreground transition-colors duration-200 hover:bg-muted/50 hover:text-foreground"
                  data-jp-field="href"
                  data-jp-item-field="socialLinks"
                  data-jp-item-id={social.id}
                  href={social.href}
                  key={social.id}
                  rel="noopener noreferrer"
                  target="_blank"
                >
                  <SocialGlyph className="size-4" icon={social.icon} />
                  <span className="sr-only" data-jp-field="name">
                    {social.name}
                  </span>
                </a>
              ))}
            </div>
          </motion.div>

          {data.columns.map((column) => (
            <motion.div
              className="flex flex-col gap-4"
              data-jp-item-field="columns"
              data-jp-item-id={column.id}
              key={column.id}
              variants={itemVariants}
            >
              <h3 className="font-medium text-sm" data-jp-field="title">
                {column.title}
              </h3>
              <ul className="flex flex-col gap-2.5">
                {column.links.map((link) => (
                  <li data-jp-item-field="links" data-jp-item-id={link.id} key={link.id}>
                    <a
                      className="text-[14px] text-muted-foreground transition-colors duration-200 hover:text-foreground"
                      data-jp-field="href"
                      href={link.href}
                    >
                      <span data-jp-field="label">{link.label}</span>
                    </a>
                  </li>
                ))}
              </ul>
            </motion.div>
          ))}
        </motion.div>

        <motion.div
          className="flex flex-col items-center justify-between gap-4 border-[var(--local-border)]/40 border-t py-6 sm:flex-row"
          initial={prefersReduced ? false : { opacity: 0 }}
          transition={{ duration: 0.6, delay: 0.4, ease: APPLE_EASE }}
          viewport={{ once: true, margin: '-40px' }}
          whileInView={{ opacity: 1 }}
        >
          <span className="text-[13px] text-muted-foreground">
            &copy; <span data-jp-field="copyrightYear">{year}</span>{' '}
            <span data-jp-field="copyrightSuffix">{data.copyrightSuffix}</span>
          </span>
          <nav className="flex flex-wrap items-center gap-4">
            {data.legalLinks.map((link) => (
              <a
                className="text-[13px] text-muted-foreground transition-colors duration-200 hover:text-foreground"
                data-jp-field="href"
                data-jp-item-field="legalLinks"
                data-jp-item-id={link.id ?? `legal-${link.href}`}
                href={link.href}
                key={link.id ?? link.href}
              >
                <span data-jp-field="label">{link.label}</span>
              </a>
            ))}
          </nav>
        </motion.div>
      </div>
    </footer>
  );
}
