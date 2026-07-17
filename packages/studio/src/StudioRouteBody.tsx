import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import {
  appendDraftSection,
  reorderPageSections,
  applyCollectionRefBindingsToDraft,
  applyMenuRefBindingsToDraft,
  resolveCollectionContext,
  resolveRuntimeConfig,
  STUDIO_EVENTS,
  buildWebMcpToolName,
  buildWebMcpSaveToolName,
  createWebMcpToolInputSchema,
  createWebMcpSaveToolInputSchema,
  ensureWebMcpRuntime,
  parseWebMcpMutationArgs,
  registerWebMcpTool,
  resolveWebMcpMutationData,
  buildPageContractHref,
  buildPageManifestHref,
  syncHeadLink,
  syncWebMcpJsonLd,
  isRecord,
  normalizeSlugSegments,
  resolvePageMatchFromRegistry,
  resolveSlugFromPathname,
  type JsonPagesConfig,
  type SelectionPath,
  type MenuConfig,
  type PageConfig,
  type ProjectState,
  type Section,
  type SiteConfig,
} from '@olonjs/core';
import { AddSectionLibrary } from './admin/AddSectionLibrary';
import { AdminSidebar, type LayerItem } from './admin/AdminSidebar';
import { StudioStage } from './admin/StudioStage';
import { useStudioPersistence } from './orchestration/useStudioPersistence';
import { useStudioSelectionState } from './orchestration/useStudioSelectionState';

/**
 * Studio orchestration body: draft state, WebMCP tool wiring, save flows,
 * and JSX for Stage + Inspector + Add-section library.
 *
 * Per ADR-0016 D6, this component is deliberately kept free of `ThemeLoader`
 * and `StudioProvider` imports — it receives `mode="studio"` context from
 * whatever wraps it. The bridge in `@olonjs/react` (`StudioRoute`) composes
 * `<ThemeLoader mode="admin"><StudioProvider mode="studio"><StudioRouteBody
 * {...bodyProps} /></StudioProvider></ThemeLoader>` and dynamically imports
 * this package to obtain this component.
 */
export interface StudioRouteBodyProps {
  pageRegistry: Record<string, PageConfig>;
  schemas: JsonPagesConfig['schemas'];
  siteConfig: SiteConfig;
  menuConfig: MenuConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  collections?: JsonPagesConfig['collections'];
  collectionSchemas?: JsonPagesConfig['collectionSchemas'];
  refDocuments?: JsonPagesConfig['refDocuments'];
  addSectionConfig: JsonPagesConfig['addSection'];
  addableSectionTypes: string[];
  webMcp?: JsonPagesConfig['webmcp'];
  saveToFile?: (state: ProjectState, slug: string) => Promise<void>;
  hotSave?: (state: ProjectState, slug: string) => Promise<void>;
  coldSave?: (state: ProjectState, slug: string) => Promise<void>;
  showLocalSave?: boolean;
  showHotSave?: boolean;
  showColdSave?: boolean;
}

export const StudioRouteBody: React.FC<StudioRouteBodyProps> = ({
  pageRegistry,
  schemas,
  siteConfig,
  menuConfig,
  themeConfig,
  collections,
  collectionSchemas,
  refDocuments,
  addSectionConfig,
  addableSectionTypes,
  webMcp,
  saveToFile,
  hotSave,
  coldSave,
  showLocalSave = true,
  showHotSave = false,
  showColdSave = false,
}) => {
  const location = useLocation();
  const slug = resolveSlugFromPathname(location.pathname, 'admin');
  const navigate = useNavigate();
  const pageSlugs = Object.keys(pageRegistry).sort((a, b) =>
    a === 'home' ? -1 : b === 'home' ? 1 : a.localeCompare(b)
  );
  const [draft, setDraft] = useState<PageConfig | null>(null);
  const [hasChanges, setHasChanges] = useState(false);
  const cloneMenuConfig = useCallback((value: unknown): MenuConfig => {
    try {
      return JSON.parse(JSON.stringify(value ?? {})) as MenuConfig;
    } catch {
      return {} as MenuConfig;
    }
  }, []);
  const getInitialMenuDraft = useCallback((): MenuConfig => {
    const refMenu =
      refDocuments?.['src/data/config/menu.json'] ??
      refDocuments?.['config/menu.json'] ??
      refDocuments?.['menu.json'];
    return cloneMenuConfig(refMenu ?? menuConfig);
  }, [cloneMenuConfig, menuConfig, refDocuments]);
  const cloneCollectionsConfig = useCallback((value: unknown): JsonPagesConfig['collections'] => {
    try {
      return JSON.parse(JSON.stringify(value ?? {})) as JsonPagesConfig['collections'];
    } catch {
      return {};
    }
  }, []);
  const getInitialCollectionsDraft = useCallback((): JsonPagesConfig['collections'] => {
    const fromRefs: NonNullable<JsonPagesConfig['collections']> = {};
    for (const [alias, value] of Object.entries(refDocuments ?? {})) {
      const normalizedAlias = alias.replace(/\\/g, '/');
      const match = normalizedAlias.match(/(?:^|\/)collections\/([^/]+)\/\1\.json$/);
      if (match?.[1]) {
        fromRefs[match[1]] = value as Record<string, unknown>;
      }
    }
    return cloneCollectionsConfig({
      ...fromRefs,
      ...(collections ?? {}),
    });
  }, [cloneCollectionsConfig, collections, refDocuments]);
  const [globalDraft, setGlobalDraft] = useState<SiteConfig>(() => {
    try {
      const base = JSON.parse(JSON.stringify(siteConfig ?? {})) as SiteConfig;
      if (!base.identity) base.identity = { title: 'Site' };
      return base;
    } catch {
      return siteConfig;
    }
  });
  const [addSectionLibraryOpen, setAddSectionLibraryOpen] = useState(false);
  const [menuDraft, setMenuDraft] = useState<MenuConfig>(() => getInitialMenuDraft());
  const [collectionsDraft, setCollectionsDraft] = useState<JsonPagesConfig['collections']>(() => getInitialCollectionsDraft());
  const [sidebarWidth, setSidebarWidth] = useState(400);
  const {
    activeSectionId,
    clearSelection,
    expandedItemPath,
    scrollToSectionId,
    selected,
    setActiveSectionId,
    setExpandedItemPath,
    setScrollToSectionId,
    setSelected,
  } = useStudioSelectionState();
  const pageMatch = useMemo(
    () => resolvePageMatchFromRegistry(pageRegistry, slug),
    [pageRegistry, slug]
  );
  const draftRegistrySlug = pageMatch?.registrySlug ?? slug;
  const persistenceSlug = draftRegistrySlug;
  const collectionContext = useMemo(
    () => pageMatch ? resolveCollectionContext(pageMatch.page, pageMatch.params, collectionsDraft) : null,
    [collectionsDraft, pageMatch]
  );
  const resolvedRuntime = useMemo(
    () =>
      resolveRuntimeConfig({
        pages: draft ? { [draftRegistrySlug]: draft } : {},
        siteConfig: globalDraft,
        themeConfig,
        menuConfig: menuDraft,
        collections: collectionsDraft,
        collectionSchemas,
        collectionContext,
        refDocuments,
      }),
    [draft, draftRegistrySlug, globalDraft, themeConfig, menuDraft, collectionsDraft, collectionSchemas, collectionContext, refDocuments]
  );
  const resolvedDraft = draft ? resolvedRuntime.pages[draftRegistrySlug] ?? draft : null;
  const resolvedCollectionContext = resolvedRuntime.collectionContext;
  const draftRef = useRef<PageConfig | null>(draft);
  const globalDraftRef = useRef<SiteConfig>(globalDraft);
  const menuDraftRef = useRef<MenuConfig>(menuDraft);
  const collectionsDraftRef = useRef<JsonPagesConfig['collections']>(collectionsDraft);
  const sidebarMin = 360;
  const sidebarMax = 920;
  const {
    buildProjectState,
    hotSaveInProgress,
    hotSaveSuccessFeedback,
    persistProjectState,
    requestInlineFlush,
    runHotSave,
    saveSuccessFeedback,
  } = useStudioPersistence({
    slug: persistenceSlug,
    saveToFile,
    hotSave,
    authoredSiteConfig: siteConfig,
    themeConfig,
    collections: collectionsDraft,
    collectionSchemas,
    refDocuments,
  });

  const commitCollectionsDraft = useCallback(
    (nextCollectionsDraft: JsonPagesConfig['collections']) => {
      collectionsDraftRef.current = nextCollectionsDraft;
      setCollectionsDraft(nextCollectionsDraft);
      return nextCollectionsDraft;
    },
    []
  );

  useEffect(() => {
    draftRef.current = draft;
  }, [draft]);

  useEffect(() => {
    globalDraftRef.current = globalDraft;
  }, [globalDraft]);

  useEffect(() => {
    menuDraftRef.current = menuDraft;
  }, [menuDraft]);

  useEffect(() => {
    collectionsDraftRef.current = collectionsDraft;
  }, [collectionsDraft]);

  const handleResizeStart = useCallback((e: React.PointerEvent) => {
    e.preventDefault();
    const handleEl = e.currentTarget as HTMLElement;
    handleEl.setPointerCapture(e.pointerId);
    const startX = e.clientX;
    const startWidth = sidebarWidth;
    const onPointerMove = (moveEvent: PointerEvent) => {
      const delta = startX - moveEvent.clientX;
      const next = Math.min(sidebarMax, Math.max(sidebarMin, startWidth + delta));
      setSidebarWidth(next);
    };
    const onPointerUp = () => {
      handleEl.releasePointerCapture(e.pointerId);
      handleEl.removeEventListener('pointermove', onPointerMove);
      handleEl.removeEventListener('pointerup', onPointerUp);
      handleEl.removeEventListener('pointercancel', onPointerUp);
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    };
    document.body.style.cursor = 'col-resize';
    document.body.style.userSelect = 'none';
    handleEl.addEventListener('pointermove', onPointerMove);
    handleEl.addEventListener('pointerup', onPointerUp);
    handleEl.addEventListener('pointercancel', onPointerUp);
  }, [sidebarWidth]);

  const allLayers: LayerItem[] = draft
    ? [
        ...(globalDraft.header ? [{ id: globalDraft.header.id, type: globalDraft.header.type, scope: 'global' as const, title: 'Header' }] : []),
        ...draft.sections.map((s) => ({
          id: s.id,
          type: s.type,
          scope: 'local' as const,
          title: (s.data as Record<string, unknown>)?.title as string | undefined ?? (s.data as Record<string, unknown>)?.titleHighlight as string | undefined,
        })),
        ...(globalDraft.footer ? [{ id: globalDraft.footer.id, type: globalDraft.footer.type, scope: 'global' as const, title: 'Footer' }] : []),
      ]
    : [];

  useEffect(() => {
    const data = resolvePageMatchFromRegistry(pageRegistry, slug)?.page;
    if (data) setDraft(JSON.parse(JSON.stringify(data)));
    clearSelection();
    setHasChanges(false);
  }, [clearSelection, slug, pageRegistry]);

  useEffect(() => {
    setMenuDraft(getInitialMenuDraft());
  }, [getInitialMenuDraft]);

  useEffect(() => {
    setCollectionsDraft(getInitialCollectionsDraft());
  }, [getInitialCollectionsDraft]);

  const getAuthoredGlobalSection = useCallback(
    (site: SiteConfig, sectionId: string): Section | null => {
      if (site.header?.id === sectionId) return site.header;
      if (site.footer?.id === sectionId) return site.footer;
      return null;
    },
    []
  );

  const getResolvedGlobalSection = useCallback(
    (site: SiteConfig, sectionId: string): Section | null => {
      if (site.header?.id === sectionId) return site.header;
      if (site.footer?.id === sectionId) return site.footer;
      return null;
    },
    []
  );

  const applyGlobalSectionUpdate = useCallback(
    (
      sectionId: string,
      nextData: Record<string, unknown>,
      currentGlobalDraft: SiteConfig,
      currentResolvedSite: SiteConfig,
      currentMenuDraft: MenuConfig
    ): { nextGlobalDraft: SiteConfig; nextMenuDraft: MenuConfig } => {
      const authoredSection = getAuthoredGlobalSection(currentGlobalDraft, sectionId);
      const resolvedSection = getResolvedGlobalSection(currentResolvedSite, sectionId);
      if (!authoredSection || !resolvedSection) {
        return { nextGlobalDraft: currentGlobalDraft, nextMenuDraft: currentMenuDraft };
      }

      const { normalizedData, menuDraft: nextMenuDraft } = applyMenuRefBindingsToDraft(
        authoredSection.data,
        nextData,
        currentMenuDraft
      );

      const nextSection = { ...authoredSection, data: normalizedData } as Section;
      const nextGlobalDraft =
        authoredSection.type === 'header'
          ? { ...currentGlobalDraft, header: nextSection }
          : { ...currentGlobalDraft, footer: nextSection };

      return { nextGlobalDraft, nextMenuDraft };
    },
    [getAuthoredGlobalSection, getResolvedGlobalSection]
  );

  const handleResetToFile = useCallback(() => {
    const data = resolvePageMatchFromRegistry(pageRegistry, slug)?.page;
    if (data) setDraft(JSON.parse(JSON.stringify(data)));
    clearSelection();
    setHasChanges(false);
  }, [clearSelection, slug, pageRegistry]);

  const handleReorderSection = useCallback(
    (sectionId: string, newIndex: number, currentDraft: PageConfig) => {
      setDraft(reorderPageSections(currentDraft, sectionId, newIndex));
      setHasChanges(true);
    },
    []
  );

  const executeWebMcpMutation = useCallback(
    async (rawArgs: unknown) => {
      const args = parseWebMcpMutationArgs(rawArgs);
      const normalizedSlug = typeof args.slug === 'string' ? normalizeSlugSegments(args.slug) : slug;
      if (normalizedSlug !== slug) {
        throw new Error(`WebMCP slug mismatch. Active Studio slug is "${slug}", received "${normalizedSlug}".`);
      }

      await requestInlineFlush();

      const currentDraft = draftRef.current;
      const currentGlobalDraft = globalDraftRef.current;
      const currentMenuDraft = menuDraftRef.current;
      const currentCollectionsDraft = collectionsDraftRef.current;
      if (!currentDraft) {
        throw new Error('Studio draft is not ready yet.');
      }

      const scope = args.scope === 'global' ? 'global' : 'local';
      let sectionTypeToUse = args.sectionType;

      if (scope === 'global') {
        const targetSection =
          currentGlobalDraft.header?.id === args.sectionId
            ? currentGlobalDraft.header
            : currentGlobalDraft.footer?.id === args.sectionId
              ? currentGlobalDraft.footer
              : null;

        if (!targetSection) {
          throw new Error(`Global section "${args.sectionId}" was not found.`);
        }

        if (!sectionTypeToUse) {
          sectionTypeToUse = targetSection.type;
        } else if (targetSection.type !== sectionTypeToUse) {
          throw new Error(`Section "${args.sectionId}" is type "${targetSection.type}", not "${sectionTypeToUse}".`);
        }

        const schema = schemas[sectionTypeToUse];
        if (!schema || typeof schema.parse !== 'function') {
          throw new Error(`Missing schema for section type "${sectionTypeToUse}".`);
        }

        const resolvedCurrentSection = getResolvedGlobalSection(resolvedRuntime.siteConfig, args.sectionId);
        const currentData =
          resolvedCurrentSection && isRecord(resolvedCurrentSection.data)
            ? resolvedCurrentSection.data
            : isRecord(targetSection.data)
              ? targetSection.data
              : {};
        const nextData = resolveWebMcpMutationData(currentData, args);
        const parsedData = schema.parse(nextData) as Record<string, unknown>;
        const { nextGlobalDraft, nextMenuDraft } = applyGlobalSectionUpdate(
          args.sectionId,
          parsedData,
          currentGlobalDraft,
          resolvedRuntime.siteConfig,
          currentMenuDraft
        );
        globalDraftRef.current = nextGlobalDraft;
        menuDraftRef.current = nextMenuDraft;
        setGlobalDraft(nextGlobalDraft);
        setMenuDraft(nextMenuDraft);
      } else {
        const targetSection = currentDraft.sections.find((section) => section.id === args.sectionId);
        if (!targetSection) {
          throw new Error(`Local section "${args.sectionId}" was not found in page "${slug}".`);
        }

        if (!sectionTypeToUse) {
          sectionTypeToUse = targetSection.type;
        } else if (targetSection.type !== sectionTypeToUse) {
          throw new Error(`Section "${args.sectionId}" is type "${targetSection.type}", not "${sectionTypeToUse}".`);
        }

        const schema = schemas[sectionTypeToUse];
        if (!schema || typeof schema.parse !== 'function') {
          throw new Error(`Missing schema for section type "${sectionTypeToUse}".`);
        }

        const currentData = isRecord(targetSection.data) ? targetSection.data : {};
        const nextData = resolveWebMcpMutationData(currentData, args);
        const parsedData = schema.parse(nextData) as Record<string, unknown>;
        const collectionResult = applyCollectionRefBindingsToDraft(
          targetSection.data,
          parsedData,
          currentCollectionsDraft,
          resolvedCollectionContext,
          collectionSchemas
        );

        const nextDraft = {
          ...currentDraft,
          sections: currentDraft.sections.map((section) =>
            section.id === args.sectionId ? ({ ...section, data: collectionResult.normalizedData } as Section) : section
          ),
        };
        commitCollectionsDraft(collectionResult.collectionsDraft);
        draftRef.current = nextDraft;
        setDraft(nextDraft);
      }

      setSelected({ id: args.sectionId, type: sectionTypeToUse, scope });
      setExpandedItemPath(Array.isArray(args.itemPath) ? args.itemPath : null);
      setHasChanges(true);

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              ok: true,
              slug,
              sectionId: args.sectionId,
              sectionType: sectionTypeToUse,
              scope,
            }),
          },
        ],
        isError: false,
      };
    },
    [applyGlobalSectionUpdate, collectionSchemas, commitCollectionsDraft, getResolvedGlobalSection, requestInlineFlush, resolvedCollectionContext, resolvedRuntime.siteConfig, schemas, slug]
  );

  const executeWebMcpSave = useCallback(
    async () => {
      await requestInlineFlush();
      const currentDraft = draftRef.current;
      const currentGlobalDraft = globalDraftRef.current;
      const currentMenuDraft = menuDraftRef.current;
      const currentCollectionsDraft = collectionsDraftRef.current;
      if (!currentDraft) {
        throw new Error('Studio draft is not ready yet.');
      }

      if (showHotSave && hotSave) {
        await runHotSave(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft, () => setHasChanges(false));
      } else if (showLocalSave && saveToFile) {
        await persistProjectState(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft, () => setHasChanges(false));
      } else if (showColdSave && coldSave) {
        await coldSave(buildProjectState(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft), persistenceSlug);
        setHasChanges(false);
      } else {
        throw new Error('No save mode is configured for this tenant.');
      }

      return {
        content: [{ type: 'text', text: JSON.stringify({ ok: true, slug: persistenceSlug }) }],
        isError: false,
      };
    },
    [showHotSave, hotSave, showLocalSave, saveToFile, showColdSave, coldSave, requestInlineFlush, runHotSave, persistProjectState, buildProjectState, persistenceSlug]
  );

  const handleWebMcpToolCall = useCallback(
    async (toolName: string, rawArgs: unknown) => {
      if (toolName === buildWebMcpToolName()) return executeWebMcpMutation(rawArgs);
      if (toolName === buildWebMcpSaveToolName()) return executeWebMcpSave();
      throw new Error(`Unknown WebMCP tool "${toolName}".`);
    },
    [executeWebMcpMutation, executeWebMcpSave]
  );

  const handleStudioMessage = useCallback(
    (event: MessageEvent) => {
      if (event.origin !== window.location.origin) return;
      if (event.data.type === STUDIO_EVENTS.SECTION_SELECT) {
        setSelected(event.data.section);
        const itemPath = event.data.itemPath;
        if (Array.isArray(itemPath) && itemPath.length > 0) {
          setExpandedItemPath((itemPath as SelectionPath).map((s) => ({
            fieldKey: s.fieldKey,
            ...(s.itemId != null ? { itemId: String(s.itemId) } : {}),
          })));
        } else {
          setExpandedItemPath(null);
        }
      }
      if (event.data.type === STUDIO_EVENTS.INLINE_FIELD_UPDATE) {
        const sectionId = typeof event.data.sectionId === 'string' ? event.data.sectionId : null;
        const fieldKey = typeof event.data.fieldKey === 'string' ? event.data.fieldKey : null;
        if (sectionId && fieldKey) {
          setDraft((prev) => {
            if (!prev) return prev;
            const nextDraft: PageConfig = {
              ...prev,
              sections: prev.sections.map((section) =>
                section.id === sectionId
                  ? {
                      ...section,
                      data: {
                        ...(section.data as Record<string, unknown>),
                        [fieldKey]: event.data.value,
                      },
                    } as Section
                  : section
              ),
            };
            draftRef.current = nextDraft;
            return nextDraft;
          });
          setHasChanges(true);
        }
      }
      if (event.data.type === STUDIO_EVENTS.ACTIVE_SECTION_CHANGED) {
        setActiveSectionId(event.data.activeSectionId ?? null);
      }
      if (event.data.type === 'jsonpages:section-reorder' && draftRef.current) {
        const { sectionId, newIndex } = event.data as { sectionId?: string; newIndex?: number };
        if (typeof sectionId === 'string' && typeof newIndex === 'number' && newIndex >= 0) {
          handleReorderSection(sectionId, newIndex, draftRef.current);
        }
      }
      if (event.data.type === STUDIO_EVENTS.WEBMCP_TOOL_CALL) {
        const requestId = typeof event.data.requestId === 'string' ? event.data.requestId : crypto.randomUUID();
        const toolName = typeof event.data.toolName === 'string' ? event.data.toolName : '';
        void handleWebMcpToolCall(toolName, event.data.args)
          .then((result) => {
            window.postMessage(
              { type: STUDIO_EVENTS.WEBMCP_TOOL_RESULT, requestId, toolName, result, ok: true },
              window.location.origin
            );
          })
          .catch((error: unknown) => {
            const message = error instanceof Error ? error.message : String(error);
            window.postMessage(
              {
                type: STUDIO_EVENTS.WEBMCP_TOOL_RESULT,
                requestId,
                toolName,
                ok: false,
                error: message,
              },
              window.location.origin
            );
          });
      }
    },
    [handleReorderSection, handleWebMcpToolCall]
  );

  useEffect(() => {
    window.addEventListener('message', handleStudioMessage);
    return () => window.removeEventListener('message', handleStudioMessage);
  }, [handleStudioMessage]);

  useEffect(() => {
    if (!webMcp?.enabled) return;
    ensureWebMcpRuntime();

    const currentDraft = draftRef.current;
    if (!currentDraft) return;

    const currentGlobalDraft = globalDraftRef.current;
    const catalog: Array<{ id: string; type: string }> = [];
    if (currentGlobalDraft?.header?.id && currentGlobalDraft.header?.type) {
      catalog.push({ id: currentGlobalDraft.header.id, type: String(currentGlobalDraft.header.type) });
    }
    if (currentGlobalDraft?.footer?.id && currentGlobalDraft.footer?.type) {
      catalog.push({ id: currentGlobalDraft.footer.id, type: String(currentGlobalDraft.footer.type) });
    }
    for (const section of currentDraft.sections) {
      if (typeof section.id === 'string' && section.id.length > 0) {
        catalog.push({ id: section.id, type: String(section.type) });
      }
    }

    const unregisterUpdate = registerWebMcpTool({
      name: buildWebMcpToolName(),
      description: 'Update a section field in the Studio draft. Does not persist — call save when all updates are complete. Use "sectionType" in input args to ensure correct schema validation.',
      inputSchema: createWebMcpToolInputSchema(catalog),
      execute: (args) => handleWebMcpToolCall(buildWebMcpToolName(), args),
    });

    const unregisterSave = registerWebMcpTool({
      name: buildWebMcpSaveToolName(),
      description: 'Persist all pending draft changes using the active save mode (local file, hot save, or save2repo). Call once after all update-section calls are complete.',
      inputSchema: createWebMcpSaveToolInputSchema(),
      execute: () => handleWebMcpToolCall(buildWebMcpSaveToolName(), {}),
    });

    return () => {
      unregisterUpdate();
      unregisterSave();
    };
  }, [webMcp?.enabled, slug, draft, globalDraft, handleWebMcpToolCall]);

  const handleRequestScrollToSection = useCallback((sectionId: string) => {
    const layer = allLayers.find((l) => l.id === sectionId);
    if (layer) setSelected({ id: layer.id, type: layer.type, scope: layer.scope });
    setExpandedItemPath(null);
    setScrollToSectionId(sectionId);
  }, [allLayers]);

  const handleScrollRequested = useCallback(() => {
    setScrollToSectionId(null);
  }, []);

  const handleDeleteSection = useCallback(
    (sectionId: string) => {
      setDraft((prev) => {
        if (!prev) return prev;
        return { ...prev, sections: prev.sections.filter((s) => s.id !== sectionId) };
      });
      setHasChanges(true);
      setSelected((prev) => (prev?.id === sectionId ? null : prev));
    },
    []
  );

  const handleUpdate = (newData: Record<string, unknown>) => {
    if (!selected || !draft) return;
    if (selected.scope === 'global') {
      const { nextGlobalDraft, nextMenuDraft } = applyGlobalSectionUpdate(
        selected.id,
        newData,
        globalDraft,
        resolvedRuntime.siteConfig,
        menuDraft
      );
      setGlobalDraft(nextGlobalDraft);
      setMenuDraft(nextMenuDraft);
      globalDraftRef.current = nextGlobalDraft;
      menuDraftRef.current = nextMenuDraft;
      setHasChanges(true);
    } else {
      const authoredSection = draft.sections.find((s) => s.id === selected.id);
      const collectionResult = applyCollectionRefBindingsToDraft(
        authoredSection?.data,
        newData,
        collectionsDraft,
        resolvedCollectionContext,
        collectionSchemas
      );
      const updatedSections = draft.sections.map((s) =>
        s.id === selected.id ? ({ ...s, data: collectionResult.normalizedData } as Section) : s
      );
      commitCollectionsDraft(collectionResult.collectionsDraft);
      setDraft({ ...draft, sections: updatedSections });
      setHasChanges(true);
    }
  };

  const handleUpdateSection = useCallback(
    (sectionId: string, scope: 'global' | 'local', _sectionType: string, newData: Record<string, unknown>) => {
      if (scope === 'global') {
        const { nextGlobalDraft, nextMenuDraft } = applyGlobalSectionUpdate(
          sectionId,
          newData,
          globalDraft,
          resolvedRuntime.siteConfig,
          menuDraft
        );
        setGlobalDraft(nextGlobalDraft);
        setMenuDraft(nextMenuDraft);
        globalDraftRef.current = nextGlobalDraft;
        menuDraftRef.current = nextMenuDraft;
        setHasChanges(true);
      } else if (draft) {
        const authoredSection = draft.sections.find((s) => s.id === sectionId);
        const collectionResult = applyCollectionRefBindingsToDraft(
          authoredSection?.data,
          newData,
          collectionsDraft,
          resolvedCollectionContext,
          collectionSchemas
        );
        const updatedSections = draft.sections.map((s) =>
          s.id === sectionId ? ({ ...s, data: collectionResult.normalizedData } as Section) : s
        );
        commitCollectionsDraft(collectionResult.collectionsDraft);
        setDraft({ ...draft, sections: updatedSections });
        setHasChanges(true);
      }
    },
    [applyGlobalSectionUpdate, collectionSchemas, collectionsDraft, commitCollectionsDraft, draft, globalDraft, menuDraft, resolvedCollectionContext, resolvedRuntime.siteConfig]
  );

  const handleSaveToFile = async () => {
    if (!saveToFile) return;
    await requestInlineFlush();
    const currentDraft = draftRef.current;
    const currentGlobalDraft = globalDraftRef.current;
    const currentMenuDraft = menuDraftRef.current;
    const currentCollectionsDraft = collectionsDraftRef.current;
    if (!currentDraft) return;
    persistProjectState(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft, () => setHasChanges(false)).catch((err) => {
      console.error('[JsonPages] saveToFile failed', err);
      const msg = err instanceof Error ? err.message : String(err);
      alert(`Save to file failed: ${msg}`);
    });
  };

  const handleHotSave = async () => {
    if (!hotSave) return;
    await requestInlineFlush();
    const currentDraft = draftRef.current;
    const currentGlobalDraft = globalDraftRef.current;
    const currentMenuDraft = menuDraftRef.current;
    const currentCollectionsDraft = collectionsDraftRef.current;
    if (!currentDraft) return;
    runHotSave(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft, () => setHasChanges(false)).catch((err) => {
      console.error('[JsonPages] hotSave failed', err);
      const msg = err instanceof Error ? err.message : String(err);
      alert(`Hot save failed: ${msg}`);
    });
  };

  const handleColdSave = async () => {
    if (!coldSave) return;
    await requestInlineFlush();
    const currentDraft = draftRef.current;
    const currentGlobalDraft = globalDraftRef.current;
    const currentMenuDraft = menuDraftRef.current;
    const currentCollectionsDraft = collectionsDraftRef.current;
    if (!currentDraft) return;
    coldSave(buildProjectState(currentDraft, currentGlobalDraft, currentMenuDraft, currentCollectionsDraft), persistenceSlug)
      .then(() => setHasChanges(false))
      .catch((err) => {
        console.error('[JsonPages] coldSave failed', err);
        const msg = err instanceof Error ? err.message : String(err);
        alert(`Save2Repo failed: ${msg}`);
      });
  };

  const handleAddSection = (sectionType: string) => {
    if (!draft) return;
    const defaultData = addSectionConfig?.getDefaultSectionData?.(sectionType) ?? {};
    const { draft: nextDraft, section } = appendDraftSection(draft, sectionType, defaultData);
    setDraft(nextDraft);
    setHasChanges(true);
    setSelected({ id: section.id, type: sectionType, scope: 'local' });
  };

  useEffect(() => {
    const currentPage = resolvedDraft ?? draft;
    const title = typeof currentPage?.meta?.title === 'string' ? currentPage.meta.title : slug;
    const description = typeof currentPage?.meta?.description === 'string' ? currentPage.meta.description : '';
    syncHeadLink('mcp-manifest', buildPageManifestHref(slug));
    syncHeadLink('olon-contract', buildPageContractHref(slug));
    syncWebMcpJsonLd(title, description, `/admin${slug === 'home' ? '' : `/${slug}`}`);
  }, [draft, resolvedDraft, slug]);

  if (!draft) return <div>Loading Studio...</div>;

  const sidebarData =
    selected?.scope === 'global'
      ? {
          sections: [resolvedRuntime.siteConfig.header, resolvedRuntime.siteConfig.footer].filter(
            (s): s is Section => s != null
          ),
        }
      : (resolvedDraft ?? draft);

  const allSectionsData: Section[] = [
    ...(resolvedRuntime.siteConfig.header ? [resolvedRuntime.siteConfig.header] : []),
    ...((resolvedDraft ?? draft)?.sections ?? []),
    ...(resolvedRuntime.siteConfig.footer ? [resolvedRuntime.siteConfig.footer] : []),
  ];

  return (
    <div className="flex flex-col h-screen w-screen bg-background text-foreground overflow-hidden">
      <div className="flex flex-1 min-h-0 overflow-hidden">
        <main className="flex-1 min-w-0 relative bg-zinc-900/50 overflow-hidden">
          <StudioStage
            draft={resolvedDraft ?? draft}
            globalDraft={resolvedRuntime.siteConfig}
            menuConfig={resolvedRuntime.menuConfig}
            themeConfig={resolvedRuntime.themeConfig}
            slug={slug}
            selectedId={selected?.id}
            scrollToSectionId={scrollToSectionId}
            onScrollRequested={handleScrollRequested}
          />
        </main>
        <div
          className="flex shrink-0 relative h-full z-10"
          style={{ width: sidebarWidth, minWidth: sidebarMin, maxWidth: sidebarMax }}
        >
          <div
            role="separator"
            aria-label="Resize inspector"
            className="absolute left-0 top-0 bottom-0 w-1.5 cursor-col-resize hover:bg-primary/40 active:bg-primary/60 transition-colors shrink-0"
            style={{ zIndex: 9999 }}
            onPointerDown={handleResizeStart}
          />
          <AdminSidebar
            selectedSection={selected}
            pageData={sidebarData}
            allSectionsData={allSectionsData}
            schemas={schemas}
            collections={collectionsDraft}
            collectionSource={resolvedCollectionContext?.source}
            onUpdate={handleUpdate}
            onUpdateSection={handleUpdateSection}
            onClose={clearSelection}
            expandedItemPath={expandedItemPath}
            onReorderSection={
              draft
                ? (sectionId, newIndex) => handleReorderSection(sectionId, newIndex, draft)
                : undefined
            }
            allLayers={allLayers}
            activeSectionId={activeSectionId}
            onRequestScrollToSection={handleRequestScrollToSection}
            onDeleteSection={draft ? handleDeleteSection : undefined}
            onAddSection={
              addableSectionTypes.length > 0
                ? () => setAddSectionLibraryOpen(true)
                : undefined
            }
            hasChanges={hasChanges}
            onSaveToFile={saveToFile != null ? handleSaveToFile : undefined}
            saveSuccessFeedback={saveSuccessFeedback}
            onHotSave={hotSave != null ? handleHotSave : undefined}
            onColdSave={coldSave != null ? handleColdSave : undefined}
            hotSaveSuccessFeedback={hotSaveSuccessFeedback}
            hotSaveInProgress={hotSaveInProgress}
            showLocalSave={showLocalSave}
            showHotSave={showHotSave}
            showColdSave={showColdSave}
            onResetToFile={handleResetToFile}
            pageSlugs={pageSlugs}
            currentSlug={slug}
            onPageChange={
              pageSlugs.length > 1
                ? (s) => {
                    const nextSlug = normalizeSlugSegments(s);
                    navigate(nextSlug === 'home' ? '/admin' : `/admin/${nextSlug}`);
                  }
                : undefined
            }
          />
        </div>
      </div>
      <AddSectionLibrary
        open={addSectionLibraryOpen}
        onClose={() => setAddSectionLibraryOpen(false)}
        sectionTypes={addableSectionTypes}
        sectionTypeLabels={addSectionConfig?.sectionTypeLabels}
        onSelect={handleAddSection}
      />
    </div>
  );
};
