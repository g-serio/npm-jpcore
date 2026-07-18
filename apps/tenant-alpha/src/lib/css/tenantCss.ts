import { useEffect, useState } from 'react';
import type { ThemeConfig } from '@/types';

const REMOTE_CSS_LINK_ATTR = 'data-jp-tenant-remote-css';
const TENANT_SHELL_STYLE_ATTR = 'data-jp-tenant-shell-css';

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

/**
 * Font tokens come from theme.json via core `buildThemeVariableMap` — no branded DNA fallbacks.
 * Warn in DEV when typography.fontFamily is missing or incomplete.
 */
export function warnIfThemeFontsMissing(theme: ThemeConfig | unknown): void {
  if (typeof import.meta !== 'undefined' && import.meta.env && !import.meta.env.DEV) return;

  if (!isObjectRecord(theme)) {
    console.warn('[tenantCss] missing theme.json / themeConfig — font tokens will not be published by core');
    return;
  }

  const tokens = isObjectRecord(theme.tokens) ? theme.tokens : null;
  const typography = tokens && isObjectRecord(tokens.typography) ? tokens.typography : null;
  const fontFamily = typography && isObjectRecord(typography.fontFamily) ? typography.fontFamily : null;

  if (!fontFamily) {
    console.warn(
      '[tenantCss] missing theme.tokens.typography.fontFamily in theme.json — expected primary/display/mono',
    );
    return;
  }

  const missing = (['primary', 'display', 'mono'] as const).filter(
    (key) => typeof fontFamily[key] !== 'string' || !String(fontFamily[key]).trim(),
  );
  if (missing.length > 0) {
    console.warn(
      `[tenantCss] incomplete theme.tokens.typography.fontFamily — missing: ${missing.join(', ')}`,
    );
  }
}

function isRemoteStylesheetHref(value: string): boolean {
  return /^https?:\/\//i.test(value.trim());
}

export function extractLeadingRemoteCssImports(cssText: string): { hrefs: string[]; rest: string } {
  const hrefs = new Set<string>();
  const leadingTriviaPattern = /^(?:\s+|\/\*[\s\S]*?\*\/)*/;
  // Vite/Tailwind may emit `@import url("...")` or compacted `@import"https://..."`.
  const importPattern =
    /^@import(?:\s*url\(\s*(?:'([^']+)'|"([^"]+)"|([^'")\s][^)]*))\s*\)|\s*(['"])([^'"]+)\4)\s*([^;]*);/i;
  let rest = cssText;

  for (;;) {
    const trivia = rest.match(leadingTriviaPattern);
    if (trivia && trivia[0]) {
      rest = rest.slice(trivia[0].length);
    }

    const match = rest.match(importPattern);
    if (!match) break;

    const href = (match[1] ?? match[2] ?? match[3] ?? match[5] ?? '').trim();
    const trailingDirectives = (match[6] ?? '').trim();

    if (!isRemoteStylesheetHref(href) || trailingDirectives.length > 0) {
      break;
    }

    hrefs.add(href);
    rest = rest.slice(match[0].length);
  }

  return { hrefs: Array.from(hrefs), rest };
}

export function setTenantPreviewReady(ready: boolean): void {
  if (typeof window !== 'undefined') {
    (window as Window & { __TENANT_PREVIEW_READY__?: boolean }).__TENANT_PREVIEW_READY__ = ready;
  }
  if (typeof document !== 'undefined' && document.body) {
    document.body.dataset.previewReady = ready ? '1' : '0';
  }
}

export function useInjectedTenantCss(css: string): void {
  useEffect(() => {
    if (typeof document === 'undefined' || !css.trim()) return;

    let style = document.querySelector(`style[${TENANT_SHELL_STYLE_ATTR}]`) as HTMLStyleElement | null;
    if (!style) {
      style = document.createElement('style');
      style.setAttribute(TENANT_SHELL_STYLE_ATTR, '1');
      document.head.appendChild(style);
    }
    style.textContent = css;
  }, [css]);
}

function ensureFontPreconnects(): void {
  if (typeof document === 'undefined') return;

  const targets = [
    { href: 'https://fonts.googleapis.com', crossOrigin: null },
    { href: 'https://fonts.gstatic.com', crossOrigin: 'anonymous' },
  ] as const;

  targets.forEach(({ href, crossOrigin }) => {
    const existing = Array.from(document.querySelectorAll('link[rel="preconnect"]')).find(
      (link) => (link as HTMLLinkElement).href === href,
    );
    if (existing) return;

    const link = document.createElement('link');
    link.rel = 'preconnect';
    link.href = href;
    if (crossOrigin) link.crossOrigin = crossOrigin;
    document.head.appendChild(link);
  });
}

export function ensureRemoteStylesheetLinks(hrefs: string[]): void {
  if (typeof document === 'undefined') return;

  ensureFontPreconnects();

  hrefs.forEach((href) => {
    const existing = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).find(
      (link) => (link as HTMLLinkElement).href === href,
    ) as HTMLLinkElement | undefined;
    if (existing) return;

    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    link.setAttribute(REMOTE_CSS_LINK_ATTR, href);
    document.head.appendChild(link);
  });
}

export function waitForTenantFonts(hrefs: string[]): Promise<void> {
  if (typeof document === 'undefined') return Promise.resolve();

  ensureRemoteStylesheetLinks(hrefs);
  if (hrefs.length === 0 || !document.fonts?.ready) return Promise.resolve();

  return document.fonts.ready.then(() => undefined);
}

export function useTenantFontsReady(hrefs: string[]): boolean {
  const [ready, setReady] = useState(false);
  const hrefKey = hrefs.join('\0');

  useEffect(() => {
    let cancelled = false;
    setReady(false);

    void waitForTenantFonts(hrefs).then(() => {
      if (!cancelled) setReady(true);
    });

    return () => {
      cancelled = true;
    };
  }, [hrefKey, hrefs]);

  return ready;
}

export function useRemoteStylesheetLinks(hrefs: string[]): void {
  const hrefKey = hrefs.join('\0');

  useEffect(() => {
    ensureRemoteStylesheetLinks(hrefs);

    if (typeof document === 'undefined') return undefined;

    const createdLinks = Array.from(
      document.querySelectorAll(`link[${REMOTE_CSS_LINK_ATTR}]`),
    ) as HTMLLinkElement[];

    return () => {
      createdLinks.forEach((link) => {
        if (link.getAttribute(REMOTE_CSS_LINK_ATTR) !== link.href) return;
        link.parentNode?.removeChild(link);
      });
    };
  }, [hrefKey, hrefs]);
}
