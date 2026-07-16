import { useCallback, useState } from 'react';
import {
  applySiteMenuRefBindingsToDraft,
  resolveRuntimeConfig,
  STUDIO_EVENTS,
  type JsonPagesConfig,
  type MenuConfig,
  type PageConfig,
  type ProjectState,
  type SiteConfig,
} from '@olonjs/core';

interface UseStudioPersistenceArgs {
  slug: string;
  saveToFile?: (state: ProjectState, slug: string) => Promise<void>;
  hotSave?: (state: ProjectState, slug: string) => Promise<void>;
  authoredSiteConfig: SiteConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
}

export function useStudioPersistence({
  slug,
  saveToFile,
  hotSave,
  authoredSiteConfig,
  themeConfig,
  collections,
  collectionSchemas,
  refDocuments,
}: UseStudioPersistenceArgs) {
  const [saveSuccessFeedback, setSaveSuccessFeedback] = useState(false);
  const [hotSaveSuccessFeedback, setHotSaveSuccessFeedback] = useState(false);
  const [hotSaveInProgress, setHotSaveInProgress] = useState(false);

  const requestInlineFlush = useCallback(async () => {
    const iframe = document.querySelector('iframe');
    if (!iframe?.contentWindow) return;
    const requestId = crypto.randomUUID();
    await new Promise<void>((resolve) => {
      let settled = false;
      const onMessage = (event: MessageEvent) => {
        if (event.origin !== window.location.origin) return;
        if (event.data?.type === STUDIO_EVENTS.INLINE_FLUSHED && event.data?.requestId === requestId) {
          settled = true;
          window.removeEventListener('message', onMessage);
          resolve();
        }
      };
      window.addEventListener('message', onMessage);
      iframe.contentWindow?.postMessage({ type: STUDIO_EVENTS.REQUEST_INLINE_FLUSH, requestId }, '*');
      window.setTimeout(() => {
        if (settled) return;
        window.removeEventListener('message', onMessage);
        resolve();
      }, 400);
    });
  }, []);

  const buildProjectState = useCallback(
    (
      nextDraft: PageConfig,
      nextGlobalDraft: SiteConfig,
      nextMenuDraft: MenuConfig,
      nextCollectionsDraft: JsonPagesConfig['collections'] = collections
    ): ProjectState => {
      const normalizedGlobal = applySiteMenuRefBindingsToDraft(
        authoredSiteConfig,
        nextGlobalDraft,
        nextMenuDraft
      );
      const resolvedSaveRuntime = resolveRuntimeConfig({
        pages: { [slug]: nextDraft },
        siteConfig: normalizedGlobal.site,
        themeConfig,
        menuConfig: normalizedGlobal.menuDraft,
        collections: nextCollectionsDraft,
        collectionSchemas,
        refDocuments,
      });
      const hasCollections =
        Object.keys(resolvedSaveRuntime.collections).length > 0;
      return {
        page: nextDraft,
        site: normalizedGlobal.site,
        menu: normalizedGlobal.menuDraft,
        theme: resolvedSaveRuntime.themeConfig,
        ...(hasCollections ? { collections: resolvedSaveRuntime.collections } : {}),
      };
    },
    [authoredSiteConfig, collections, collectionSchemas, slug, themeConfig, refDocuments]
  );

  const persistProjectState = useCallback(
    async (
      nextDraft: PageConfig,
      nextGlobalDraft: SiteConfig,
      nextMenuDraft: MenuConfig,
      nextCollectionsDraft?: JsonPagesConfig['collections'],
      onPersisted?: () => void
    ) => {
      if (!saveToFile) {
        throw new Error('saveToFile is not configured for this tenant.');
      }

      await saveToFile(buildProjectState(nextDraft, nextGlobalDraft, nextMenuDraft, nextCollectionsDraft), slug);
      onPersisted?.();
      setSaveSuccessFeedback(true);
      if (typeof window !== 'undefined') {
        window.setTimeout(() => setSaveSuccessFeedback(false), 2500);
      }
    },
    [buildProjectState, saveToFile, slug]
  );

  const runHotSave = useCallback(
    async (
      nextDraft: PageConfig,
      nextGlobalDraft: SiteConfig,
      nextMenuDraft: MenuConfig,
      nextCollectionsDraft?: JsonPagesConfig['collections'],
      onPersisted?: () => void
    ) => {
      if (!hotSave) return;

      setHotSaveInProgress(true);
      try {
        await hotSave(buildProjectState(nextDraft, nextGlobalDraft, nextMenuDraft, nextCollectionsDraft), slug);
        onPersisted?.();
        setHotSaveSuccessFeedback(true);
        if (typeof window !== 'undefined') {
          window.setTimeout(() => setHotSaveSuccessFeedback(false), 2500);
        }
      } finally {
        setHotSaveInProgress(false);
      }
    },
    [buildProjectState, hotSave, slug]
  );

  return {
    buildProjectState,
    hotSaveInProgress,
    hotSaveSuccessFeedback,
    persistProjectState,
    requestInlineFlush,
    runHotSave,
    saveSuccessFeedback,
  };
}
