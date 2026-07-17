import React, { useState, useEffect } from 'react';
import { StudioProvider } from '../studio-mode/StudioContext';
import {
  STUDIO_EVENTS,
  resolveHeaderMenuItems,
  buildSelectionPath,
  type PageConfig,
  type SiteConfig,
  type MenuConfig,
  type SelectionPath,
} from '@olonjs/core';
import { PageRenderer } from '../rendering/PageRenderer';
import { themeManager } from '../theme/theme-manager';

const INTERACTIVE_SELECTION_GUARD =
  '[data-jp-ignore-select="true"],[data-jp-interactive="true"],.ProseMirror,[contenteditable="true"],button,input,textarea,select,[role="button"],[role="menuitem"]';
const IDAC_SELECTION_MARKER =
  '[data-jp-field],[data-jp-item-id],[data-jp-item-field]';

export const PreviewEntry: React.FC = () => {
  const [draft, setDraft] = useState<PageConfig | null>(null);
  const [globalDraft, setGlobalDraft] = useState<SiteConfig | null>(null);
  const [menuConfig, setMenuConfig] = useState<MenuConfig>({ main: [] });
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [scrollToSectionId, setScrollToSectionId] = useState<string | null>(null);

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin || event.source !== window.parent) return;

      if (event.data.type === STUDIO_EVENTS.UPDATE_DRAFTS) {
        setDraft(event.data.draft);
        setGlobalDraft(event.data.globalDraft);
        if (event.data.menuConfig) {
          setMenuConfig(event.data.menuConfig as MenuConfig);
        }
        if (event.data.themeConfig) {
           themeManager.setTheme(event.data.themeConfig);
        }
      }

      if (event.data.type === STUDIO_EVENTS.SYNC_SELECTION) {
        setSelectedId(event.data.selectedId);
      }

      if (event.data.type === STUDIO_EVENTS.REQUEST_SCROLL_TO_SECTION) {
        setScrollToSectionId(event.data.sectionId ?? null);
      }

      if (event.data.type === STUDIO_EVENTS.REQUEST_INLINE_FLUSH) {
        const requestId = typeof event.data.requestId === 'string' ? event.data.requestId : null;
        window.dispatchEvent(new CustomEvent(STUDIO_EVENTS.REQUEST_INLINE_FLUSH, { detail: { requestId } }));
        setTimeout(() => {
          window.parent.postMessage(
            { type: STUDIO_EVENTS.INLINE_FLUSHED, requestId },
            window.location.origin
          );
        }, 0);
      }

    };

    window.addEventListener('message', handleMessage);
    window.parent.postMessage({ type: STUDIO_EVENTS.STAGE_READY }, '*');
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  /**
   * 📍 DOCUMENT-LEVEL CLICK (iframe event propagation fix)
   * Capture clicks at document root so we always receive them regardless of
   * React tree or pointer-events. Find section + item/field and notify parent.
   */
  useEffect(() => {
    const hasIdacSelectionMarker = (target: HTMLElement): boolean =>
      !!target.closest(IDAC_SELECTION_MARKER);

    const shouldIgnoreSelectionTarget = (target: HTMLElement): boolean => {
      if (target.closest('[data-jp-ignore-select="true"]')) return true;

      // Interactive controls are ignored unless explicitly annotated with IDAC markers.
      if (target.closest(INTERACTIVE_SELECTION_GUARD) && !hasIdacSelectionMarker(target)) {
        return true;
      }

      // Keep in-iframe links non-navigable, but allow inspector selection when IDAC is present.
      if (target.closest('a[href]') && !hasIdacSelectionMarker(target)) return true;
      return false;
    };

    const handleDocumentClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      if (shouldIgnoreSelectionTarget(target)) {
        if (target.closest('a[href]')) e.preventDefault();
        return;
      }
      const x = e.clientX;
      const y = e.clientY;
      let sectionEl: HTMLElement | null = null;
      let el: HTMLElement | null = target;
      while (el && el !== document.body) {
        const id = el.getAttribute?.('data-section-id');
        const type = el.getAttribute?.('data-section-type');
        const scope = el.getAttribute?.('data-section-scope');
        if (id && type && scope) {
          sectionEl = el;
          break;
        }
        el = el.parentElement;
      }
      if (!sectionEl) return;
      e.preventDefault();
      e.stopPropagation();
      const sectionId = sectionEl.getAttribute('data-section-id');
      const sectionType = sectionEl.getAttribute('data-section-type');
      const sectionScope = sectionEl.getAttribute('data-section-scope');
      if (!sectionId || !sectionType || !sectionScope) return;
      const section = { id: sectionId, type: sectionType, scope: sectionScope };
      // Click directly on section container (out of item scope) → restore section-level view
      if (target === sectionEl) {
        window.parent.postMessage({ type: STUDIO_EVENTS.SECTION_SELECT, section }, '*');
        return;
      }

      const rootAtPoint = (document.elementFromPoint(x, y) as HTMLElement) ?? target;
      if (!rootAtPoint || !sectionEl.contains(rootAtPoint)) {
        window.parent.postMessage({ type: STUDIO_EVENTS.SECTION_SELECT, section }, '*');
        return;
      }
      // Section container click: restore section-level view, out of item scope
      if (rootAtPoint === sectionEl) {
        window.parent.postMessage({ type: STUDIO_EVENTS.SECTION_SELECT, section }, '*');
        return;
      }
      // Collect deterministic root-to-leaf path for both array items and scalar fields.
      let itemPath: SelectionPath = buildSelectionPath(rootAtPoint, sectionEl);

      if (itemPath.length === 0 && rootAtPoint) {
        let best: HTMLElement | null = null;
        const visit = (node: HTMLElement) => {
          const rect = node.getBoundingClientRect();
          if (rect.left <= x && x <= rect.right && rect.top <= y && y <= rect.bottom) {
            for (let i = 0; i < node.children.length; i++) visit(node.children[i] as HTMLElement);
            if (node.getAttribute?.('data-jp-item-id') || node.getAttribute?.('data-jp-field')) best = node;
          }
        };
        visit(rootAtPoint);
        if (best) {
          itemPath = buildSelectionPath(best as HTMLElement, sectionEl);
        }
      }
      const payload: Record<string, unknown> = { type: STUDIO_EVENTS.SECTION_SELECT, section };
      if (itemPath.length > 0) {
        payload.itemPath = itemPath;
      }
      window.parent.postMessage(payload, '*');
    };

    document.addEventListener('click', handleDocumentClick, true);
    return () => document.removeEventListener('click', handleDocumentClick, true);
  }, []);

  /** Clear scrollToSectionId after triggering scroll (must run unconditionally for Rules of Hooks). */
  useEffect(() => {
    if (!scrollToSectionId) return;
    const t = setTimeout(() => setScrollToSectionId(null), 600);
    return () => clearTimeout(t);
  }, [scrollToSectionId]);

  if (!draft || !globalDraft) {
    return (
      <div className="flex items-center justify-center h-screen w-full bg-zinc-950 text-zinc-500 font-mono text-xs uppercase tracking-widest animate-pulse">
        Waiting for Studio Signal...
      </div>
    );
  }

  const currentMenuConfig: MenuConfig = {
    ...menuConfig,
    main: resolveHeaderMenuItems(globalDraft.header?.data, menuConfig.main ?? []),
  };

  const handleActiveSectionChange = (sectionId: string | null) => {
    window.parent.postMessage({
      type: STUDIO_EVENTS.ACTIVE_SECTION_CHANGED,
      activeSectionId: sectionId,
    }, '*');
  };

  return (
    <StudioProvider mode="studio">
      <div className="jp-ice-active">
        <PageRenderer
          pageConfig={draft}
          siteConfig={globalDraft}
          menuConfig={currentMenuConfig}
          selectedId={selectedId}
          scrollToSectionId={scrollToSectionId}
          onActiveSectionChange={handleActiveSectionChange}
        />
      </div>
    </StudioProvider>
  );
};
