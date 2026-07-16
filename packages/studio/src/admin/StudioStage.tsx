import React, { useEffect, useRef, useCallback } from 'react';
import { STUDIO_EVENTS, type PageConfig, type SiteConfig, type ThemeConfig, type MenuConfig } from '@olonjs/core';

interface StudioStageProps {
  draft: PageConfig;
  globalDraft: SiteConfig;
  menuConfig: MenuConfig;
  themeConfig: ThemeConfig;
  slug: string;
  selectedId?: string | null;
  scrollToSectionId?: string | null;
  onScrollRequested?: () => void;
}

/**
 * 📺 STUDIO STAGE (Full Preview Mode)
 * Manages the Iframe and the PostMessage protocol.
 * NOW INCLUDES: Handshake Listener to fix the "Waiting..." race condition.
 */
export const StudioStage: React.FC<StudioStageProps> = ({
  draft,
  globalDraft,
  menuConfig,
  themeConfig,
  slug,
  selectedId,
  scrollToSectionId,
  onScrollRequested,
}) => {
  const iframeRef = useRef<HTMLIFrameElement>(null);

  /**
   * 📤 TRANSMITTER
   * Encapsulated function to send the current state to the Iframe.
   */
  const sendDataToStage = useCallback(() => {
    if (iframeRef.current?.contentWindow) {
      iframeRef.current.contentWindow.postMessage({
        type: STUDIO_EVENTS.UPDATE_DRAFTS,
        draft,
        globalDraft,
        menuConfig,
        themeConfig,
      }, '*');
    }
  }, [draft, globalDraft, menuConfig, themeConfig]);

  /**
   * 🔄 SYNC 1: Reactivity
   * Send data whenever the draft changes in the Inspector.
   */
  useEffect(() => {
    sendDataToStage();
  }, [sendDataToStage]);

  /**
   * 🤝 SYNC 2: The Handshake (Fixes the Race Condition)
   * Listen for the Iframe saying "I am ready" and send data immediately.
   */
  useEffect(() => {
    const handleHandshake = (event: MessageEvent) => {
      if (event.data.type === STUDIO_EVENTS.STAGE_READY) {
        // console.log("🤝 Handshake received from Stage. Transmitting data...");
        sendDataToStage();
      }
    };

    window.addEventListener('message', handleHandshake);
    return () => window.removeEventListener('message', handleHandshake);
  }, [sendDataToStage]);

  /**
   * 🎯 SYNC 3: Selection
   * Independent channel for high-frequency selection updates.
   */
  useEffect(() => {
    if (iframeRef.current?.contentWindow) {
      iframeRef.current.contentWindow.postMessage({
        type: STUDIO_EVENTS.SYNC_SELECTION,
        selectedId
      }, '*');
    }
  }, [selectedId]);

  useEffect(() => {
    if (!scrollToSectionId || !iframeRef.current?.contentWindow) return;
    iframeRef.current.contentWindow.postMessage({
      type: STUDIO_EVENTS.REQUEST_SCROLL_TO_SECTION,
      sectionId: scrollToSectionId,
    }, '*');
    onScrollRequested?.();
  }, [scrollToSectionId, onScrollRequested]);

  return (
    <div className="w-full h-full bg-background overflow-hidden">
      <iframe
        ref={iframeRef}
        src={`/admin/preview/${slug}`}
        className="w-full h-full border-none"
        title="JsonPages Stage"
      />
    </div>
  );
};

