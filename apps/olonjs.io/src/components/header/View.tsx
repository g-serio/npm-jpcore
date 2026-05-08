'use client';

import { Menu, X } from 'lucide-react';
import {
  AnimatePresence,
  motion,
  useMotionValueEvent,
  useReducedMotion,
  useScroll,
  type Variants,
} from 'motion/react';
import type { MenuItem } from '@olonjs/core';
import { resolveAssetUrl, useConfig } from '@olonjs/core';
import { scroller } from 'react-scroll';
import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties } from 'react';
import useMeasure from 'react-use-measure';
import { cn } from '@/lib/utils';
import type { HeaderData, HeaderSettings } from './types';

const APPLE_EASE = [0.22, 1, 0.36, 1] as const;

const logoVariants: Variants = {
  hidden: { opacity: 0, x: -8, filter: 'blur(6px)' },
  visible: {
    opacity: 1,
    x: 0,
    filter: 'blur(0px)',
    transition: { duration: 0.5, ease: APPLE_EASE },
  },
};

const linkContainerVariants: Variants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.06, delayChildren: 0.15 },
  },
};

const linkItemVariants: Variants = {
  hidden: { opacity: 0, y: 10, filter: 'blur(6px)' },
  visible: {
    opacity: 1,
    y: 0,
    filter: 'blur(0px)',
    transition: { duration: 0.45, ease: APPLE_EASE },
  },
};

const actionsVariants: Variants = {
  hidden: { opacity: 0, x: 8, filter: 'blur(6px)' },
  visible: {
    opacity: 1,
    x: 0,
    filter: 'blur(0px)',
    transition: { duration: 0.5, delay: 0.4, ease: APPLE_EASE },
  },
};

const mobileMenuVariants: Variants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.05, delayChildren: 0.05 },
  },
  exit: { opacity: 0, transition: { duration: 0.15 } },
};

const mobileLinkVariants: Variants = {
  hidden: { opacity: 0, y: 16 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.35, ease: APPLE_EASE },
  },
  exit: {
    opacity: 0,
    y: -8,
    transition: { duration: 0.2 },
  },
};

type HeaderViewProps = {
  data: HeaderData;
  settings?: HeaderSettings;
  menu?: MenuItem[];
};

export function HeaderView({ data, menu }: HeaderViewProps) {
  const { tenantId = 'alpha' } = useConfig();
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  /** v1.6: resolved list may arrive on `data.menu` (Inspector path) and/or `menu` prop — Appendix A.2.1. */
  const safeMenu = menu ?? data.menu ?? [];
  const [activeLink, setActiveLink] = useState<string>(
    safeMenu[0]?.href ?? '#'
  );
  const prefersReduced = useReducedMotion();
  const { scrollY } = useScroll();
  const navRef = useRef<HTMLElement>(null);
  const [mobileContentRef, { height: mobileHeight }] = useMeasure();

  const logoUrl = data.logoMark?.url?.trim();
  const resolvedLogo = logoUrl ? resolveAssetUrl(logoUrl, tenantId) : '';
  const monogram = (data.brandText?.trim()?.[0] ?? 'A').toUpperCase();

  useMotionValueEvent(scrollY, 'change', (latest) => {
    setScrolled(latest > 20);
  });

  const closeMobile = useCallback(() => setMobileOpen(false), []);

  const handleNavClick = useCallback(
    (href: string) => {
      if (href.startsWith('#') && href.length > 1) {
        scroller.scrollTo(href.slice(1), {
          smooth: 'easeInOutQuart',
          duration: 600,
          offset: -90,
        });
      }
      setActiveLink(href);
    },
    []
  );

  useEffect(() => {
    const hashes = safeMenu.map((m) => m.href).filter((h) => h.startsWith('#') && h.length > 1);
    const targets = hashes
      .map((h) => ({ href: h, el: document.getElementById(h.slice(1)) }))
      .filter((t): t is { href: string; el: HTMLElement } => Boolean(t.el));
    if (targets.length === 0) return;

    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio);
        if (visible[0]) {
          const match = targets.find((t) => t.el === visible[0].target);
          if (match) setActiveLink(match.href);
        }
      },
      { rootMargin: '-30% 0px -60% 0px', threshold: [0, 0.1, 0.5, 1] }
    );
    targets.forEach((t) => observer.observe(t.el));
    return () => observer.disconnect();
  }, [safeMenu]);

  useEffect(() => {
    if (!mobileOpen) return;
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') closeMobile();
    };
    document.addEventListener('keydown', handleKey);
    return () => document.removeEventListener('keydown', handleKey);
  }, [mobileOpen, closeMobile]);

  useEffect(() => {
    if (!mobileOpen) return;
    const handleClick = (e: MouseEvent) => {
      if (navRef.current && !navRef.current.contains(e.target as Node)) {
        closeMobile();
      }
    };
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, [mobileOpen, closeMobile]);

  const navStyle = useMemo(
    () =>
      ({
        '--local-bg': 'var(--background)',
        '--local-text': 'var(--foreground)',
        '--local-muted': 'var(--muted-foreground)',
        '--local-radius': 'var(--theme-border-radius-md, 0.5rem)',
      }) as CSSProperties,
    []
  );

  return (
    <motion.nav
      ref={navRef}
      className="fixed top-0 right-0 left-0 z-50 bg-[var(--local-bg)] text-[var(--local-text)]"
      initial={prefersReduced ? false : 'hidden'}
      animate="visible"
      style={navStyle}
    >
      <div className="mx-auto max-w-5xl px-4 pt-3 sm:px-6">
        <motion.div
          animate={{
            backgroundColor: scrolled
              ? 'hsl(var(--background) / 0.8)'
              : 'hsl(var(--background) / 0)',
          }}
          className={cn(
            'rounded-full px-4 transition-[backdrop-filter,box-shadow] duration-300 sm:px-5',
            scrolled && [
              'backdrop-blur-xl',
              'shadow-[0px_0px_0px_1px_rgba(0,0,0,0.06),0px_1px_2px_-1px_rgba(0,0,0,0.06),0px_2px_4px_0px_rgba(0,0,0,0.04)]',
              'dark:shadow-[0px_0px_0px_1px_rgba(255,255,255,0.08),0px_1px_2px_-1px_rgba(255,255,255,0.04),0px_2px_4px_0px_rgba(0,0,0,0.2)]',
            ]
          )}
          transition={{ duration: 0.4, ease: APPLE_EASE }}
        >
          <div className="flex h-14 items-center justify-between">
            <motion.a
              className="flex shrink-0 items-center gap-2"
              href="/"
              variants={logoVariants}
            >
              {resolvedLogo ? (
                <img
                  alt={data.logoMark?.alt ?? ''}
                  className="size-7 rounded-lg object-cover"
                  data-jp-field="logoMark.url"
                  src={resolvedLogo}
                />
              ) : (
                <div className="flex size-7 items-center justify-center rounded-lg bg-foreground">
                  <span className="font-bold text-background text-xs">{monogram}</span>
                </div>
              )}
              <span
                className="font-semibold text-foreground tracking-tight"
                data-jp-field="brandText"
              >
                {data.brandText}
              </span>
            </motion.a>

            <motion.div
              className="hidden items-center gap-1 md:flex"
              variants={linkContainerVariants}
            >
              {safeMenu.map((link) => (
                <motion.a
                  className="relative rounded-full px-3.5 py-1.5 text-[14px] text-muted-foreground transition-colors duration-200 hover:text-foreground"
                  data-jp-field="href"
                  data-jp-item-field="menu"
                  data-jp-item-id={link.href}
                  href={link.href}
                  key={link.href}
                  onClick={(e) => {
                    if (link.href.startsWith('#')) e.preventDefault();
                    handleNavClick(link.href);
                  }}
                  variants={linkItemVariants}
                >
                  {activeLink === link.href && (
                    <motion.span
                      className="absolute inset-0 rounded-full bg-muted/60"
                      layoutId="header-nav-active"
                      transition={{ type: 'spring', bounce: 0.15, duration: 0.5 }}
                    />
                  )}
                  <span className="relative z-10" data-jp-field="label">
                    {link.label}
                  </span>
                </motion.a>
              ))}
            </motion.div>

            <motion.div
              className="hidden items-center gap-2 md:flex"
              variants={actionsVariants}
            >
              {data.signIn ? (
                <a
                  className="rounded-full px-3.5 py-1.5 text-[14px] text-muted-foreground transition-colors duration-200 hover:text-foreground"
                  data-jp-field="signIn.href"
                  href={data.signIn.href}
                >
                  <span data-jp-field="signIn.label">{data.signIn.label}</span>
                </a>
              ) : null}
              <motion.a
                className="inline-flex items-center rounded-full bg-foreground px-4 py-1.5 text-[14px] font-medium text-background transition-shadow duration-300 hover:shadow-[0_8px_30px_rgb(0,0,0,0.12)] dark:hover:shadow-[0_8px_30px_rgb(255,255,255,0.08)]"
                data-jp-field="primaryCta.href"
                href={data.primaryCta.href}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
              >
                <span data-jp-field="primaryCta.label">{data.primaryCta.label}</span>
              </motion.a>
            </motion.div>

            <motion.button
              aria-label={mobileOpen ? 'Close menu' : 'Open menu'}
              className="flex size-9 cursor-pointer items-center justify-center rounded-lg text-foreground md:hidden"
              onClick={() => setMobileOpen((prev) => !prev)}
              type="button"
              variants={actionsVariants}
              whileTap={{ scale: 0.95 }}
            >
              <AnimatePresence mode="popLayout" initial={false}>
                <motion.div
                  animate={{ opacity: 1, rotate: 0 }}
                  exit={{ opacity: 0, rotate: 90 }}
                  initial={{ opacity: 0, rotate: -90 }}
                  key={mobileOpen ? 'close' : 'open'}
                  transition={{ duration: 0.2 }}
                >
                  {mobileOpen ? <X className="size-5" /> : <Menu className="size-5" />}
                </motion.div>
              </AnimatePresence>
            </motion.button>
          </div>
        </motion.div>

        <AnimatePresence>
          {mobileOpen && (
            <motion.div
              animate={{ height: mobileHeight, opacity: 1 }}
              className="overflow-hidden md:hidden"
              exit={{ height: 0, opacity: 0 }}
              initial={{ height: 0, opacity: 0 }}
              transition={{ duration: 0.35, ease: APPLE_EASE }}
            >
              <div ref={mobileContentRef}>
                <motion.div
                  animate="visible"
                  className={cn(
                    'mt-2 flex flex-col gap-1 rounded-2xl p-3',
                    'bg-background/90 backdrop-blur-xl',
                    'shadow-[0px_0px_0px_1px_rgba(0,0,0,0.06),0px_2px_4px_-1px_rgba(0,0,0,0.08),0px_4px_16px_0px_rgba(0,0,0,0.06)]',
                    'dark:shadow-[0px_0px_0px_1px_rgba(255,255,255,0.08),0px_2px_4px_-1px_rgba(255,255,255,0.04),0px_4px_16px_0px_rgba(0,0,0,0.25)]'
                  )}
                  exit="exit"
                  initial="hidden"
                  variants={mobileMenuVariants}
                >
                  {safeMenu.map((link) => (
                    <motion.a
                      className="rounded-xl px-4 py-2.5 text-[15px] text-foreground transition-colors hover:bg-muted/50"
                      data-jp-field="href"
                      data-jp-item-field="menu"
                      data-jp-item-id={link.href}
                      href={link.href}
                      key={`m-${link.href}`}
                      onClick={(e) => {
                        if (link.href.startsWith('#')) e.preventDefault();
                        handleNavClick(link.href);
                        closeMobile();
                      }}
                      variants={mobileLinkVariants}
                    >
                      <span data-jp-field="label">{link.label}</span>
                    </motion.a>
                  ))}
                  <motion.div
                    className="mt-1 border-border/40 border-t pt-3"
                    variants={mobileLinkVariants}
                  >
                    {data.signIn ? (
                      <a
                        className="block rounded-xl px-4 py-2.5 text-[15px] text-muted-foreground transition-colors hover:text-foreground"
                        data-jp-field="signIn.href"
                        href={data.signIn.href}
                        onClick={closeMobile}
                      >
                        <span data-jp-field="signIn.label">{data.signIn.label}</span>
                      </a>
                    ) : null}
                    <a
                      className="mt-1 block rounded-xl bg-foreground px-4 py-2.5 text-center text-[15px] font-medium text-background"
                      data-jp-field="primaryCta.href"
                      href={data.primaryCta.href}
                      onClick={closeMobile}
                    >
                      <span data-jp-field="primaryCta.label">{data.primaryCta.label}</span>
                    </a>
                  </motion.div>
                </motion.div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </motion.nav>
  );
}
