import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { AddSectionLibrary } from '../../studio/admin/AddSectionLibrary';
import { AdminSidebar, type LayerItem } from '../../studio/admin/AdminSidebar';
import { StudioStage } from '../../studio/admin/StudioStage';
import { appendDraftSection, reorderPageSections } from '../../studio/orchestration/section-ops';
import { useStudioPersistence } from '../../studio/orchestration/useStudioPersistence';
import { useStudioSelectionState } from '../../studio/orchestration/useStudioSelectionState';
import { resolveRuntimeConfig } from '../../contract/config-resolver';
import type { JsonPagesConfig, SelectionPath } from '../../contract/types-engine';
import type { MenuConfig, PageConfig, ProjectState, Section, SiteConfig } from '../../contract/kernel';
import { StudioProvider } from '../../studio/StudioContext';
import { ThemeLoader } from '../theme/ThemeLoader';
import { STUDIO_EVENTS } from '../../studio/events';
import {
  buildWebMcpToolName,
  buildWebMcpSaveToolName,
  createWebMcpToolInputSchema,
  createWebMcpSaveToolInputSchema,
  ensureWebMcpRuntime,
  parseWebMcpMutationArgs,
  registerWebMcpTool,
  resolveWebMcpMutationData,
} from '../../webmcp';
import {
  buildPageContractHref,
  buildPageManifestHref,
  syncHeadLink,
  syncWebMcpJsonLd,
} from './head-sync';
import {
  isRecord,
  normalizeSlugSegments,
  resolvePageFromRegistry,
  resolveSlugFromPathname,
} from './route-utils';

export interface StudioRouteProps {
  pageRegistry: Record<string, PageConfig>;
  schemas: JsonPagesConfig['schemas'];
  siteConfig: SiteConfig;
  menuConfig: MenuConfig;
  themeConfig: JsonPagesConfig['themeConfig'];
  refDocuments?: JsonPagesConfig['refDocuments'];
  tenantCss: string;
  adminCss: string;
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

export const StudioRoute: React.FC<StudioRouteProps> = ({
  pageRegistry,
  schemas,
  siteConfig,
  menuConfig,
  themeConfig,
  refDocuments,
  tenantCss,
  adminCss,
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
  const resolvedRuntime = useMemo(
    () =>
      resolveRuntimeConfig({
        pages: draft ? { [slug]: draft } : {},
        siteConfig: globalDraft,
        themeConfig,
        menuConfig: menuDraft,
        refDocuments,
      }),
    [draft, globalDraft, themeConfig, menuDraft, refDocuments, slug]
  );
  const resolvedDraft = draft ? resolvedRuntime.pages[slug] ?? draft : null;
  const draftRef = useRef<PageConfig | null>(draft);
  const globalDraftRef = useRef<SiteConfig>(globalDraft);
  const menuDraftRef = useRef<MenuConfig>(menuDraft);
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
    slug,
    saveToFile,
    hotSave,
    themeConfig,
    refDocuments,
  });

  useEffect(() => {
    draftRef.current = draft;
  }, [draft]);

  useEffect(() => {
    globalDraftRef.current = globalDraft;
  }, [globalDraft]);

  useEffect(() => {
    menuDraftRef.current = menuDraft;
  }, [menuDraft]);

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
    const data = resolvePageFromRegistry(pageRegistry, slug);
    if (data) setDraft(JSON.parse(JSON.stringify(data)));
    clearSelection();
    setHasChanges(false);
  }, [clearSelection, slug, pageRegistry]);

  useEffect(() => {
    setMenuDraft(getInitialMenuDraft());
  }, [getInitialMenuDraft]);

  const decodePointerSegment = useCallback((segment: string) => segment.replace(/~1/g, '/').replace(/~0/g, '~'), []);

  const isRefObject = useCallback(
    (value: unknown): value is Record<string, unknown> & { $ref: string } =>
      isRecord(value) && typeof value.$ref === 'string' && value.$ref.trim().length > 0,
    []
  );

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

  const getMenuBindingPointer = useCallback(
    (sectionData: unknown): string[] | null => {
      if (!isRecord(sectionData) || !isRefObject(sectionData.menu)) return null;
      const rawRef = sectionData.menu.$ref.trim();
      const [rawDocPath, rawPointer = ''] = rawRef.split('#');
      if (!/menu\.json$/i.test(rawDocPath)) return null;
      const pointer = rawPointer.replace(/^\//, '');
      if (!pointer) return null;
      const segments = pointer
        .split('/')
        .map(decodePointerSegment)
        .filter(Boolean);
      return segments.length > 0 ? segments : null;
    },
    [decodePointerSegment, isRefObject]
  );

  const writeValueAtPath = useCallback((target: unknown, path: string[], value: unknown): unknown => {
    if (path.length === 0) return value;

    const [head, ...tail] = path;
    const source = isRecord(target) ? target : {};
    return {
      ...source,
      [head]: writeValueAtPath(source[head], tail, value),
    };
  }, []);

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

      let nextMenuDraft = currentMenuDraft;
      const menuPointer = getMenuBindingPointer(authoredSection.data);
      const resolvedMenuValue = nextData.menu;
      const authoredData = isRecord(authoredSection.data) ? authoredSection.data : {};

      const normalizedData: Record<string, unknown> = menuPointer
        ? {
            ...nextData,
            ...(authoredData.menu !== undefined ? { menu: authoredData.menu } : {}),
          }
        : nextData;

      if (menuPointer && Array.isArray(resolvedMenuValue)) {
        nextMenuDraft = writeValueAtPath(currentMenuDraft, menuPointer, resolvedMenuValue) as MenuConfig;
      }

      const nextSection = { ...authoredSection, data: normalizedData } as Section;
      const nextGlobalDraft =
        authoredSection.type === 'header'
          ? { ...currentGlobalDraft, header: nextSection }
          : { ...currentGlobalDraft, footer: nextSection };

      return { nextGlobalDraft, nextMenuDraft };
    },
    [getAuthoredGlobalSection, getMenuBindingPointer, getResolvedGlobalSection, writeValueAtPath]
  );

  const handleResetToFile = useCallback(() => {
    const data = resolvePageFromRegistry(pageRegistry, slug);
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

        const nextDraft = {
          ...currentDraft,
          sections: currentDraft.sections.map((section) =>
            section.id === args.sectionId ? ({ ...section, data: parsedData } as Section) : section
          ),
        };
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
    [applyGlobalSectionUpdate, getResolvedGlobalSection, requestInlineFlush, resolvedRuntime.siteConfig, schemas, slug]
  );

  const executeWebMcpSave = useCallback(
    async () => {
      await requestInlineFlush();
      const currentDraft = draftRef.current;
      const currentGlobalDraft = globalDraftRef.current;
      const currentMenuDraft = menuDraftRef.current;
      if (!currentDraft) {
        throw new Error('Studio draft is not ready yet.');
      }

      if (showHotSave && hotSave) {
        await runHotSave(currentDraft, currentGlobalDraft, currentMenuDraft, () => setHasChanges(false));
      } else if (showLocalSave && saveToFile) {
        await persistProjectState(currentDraft, currentGlobalDraft, currentMenuDraft, () => setHasChanges(false));
      } else if (showColdSave && coldSave) {
        await coldSave(buildProjectState(currentDraft, currentGlobalDraft, currentMenuDraft), slug);
        setHasChanges(false);
      } else {
        throw new Error('No save mode is configured for this tenant.');
      }

      return {
        content: [{ type: 'text', text: JSON.stringify({ ok: true, slug }) }],
        isError: false,
      };
    },
    [showHotSave, hotSave, showLocalSave, saveToFile, showColdSave, coldSave, requestInlineFlush, runHotSave, persistProjectState, buildProjectState, slug]
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
    setHasChanges(true);
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
    } else {
      const updatedSections = draft.sections.map((s) =>
        s.id === selected.id ? ({ ...s, data: newData } as Section) : s
      );
      setDraft({ ...draft, sections: updatedSections });
    }
  };

  const handleUpdateSection = useCallback(
    (sectionId: string, scope: 'global' | 'local', _sectionType: string, newData: Record<string, unknown>) => {
      setHasChanges(true);
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
      } else if (draft) {
        const updatedSections = draft.sections.map((s) =>
          s.id === sectionId ? ({ ...s, data: newData } as Section) : s
        );
        setDraft({ ...draft, sections: updatedSections });
      }
    },
    [applyGlobalSectionUpdate, draft, globalDraft, menuDraft, resolvedRuntime.siteConfig]
  );

  const handleSaveToFile = async () => {
    if (!saveToFile) return;
    await requestInlineFlush();
    const currentDraft = draftRef.current;
    const currentGlobalDraft = globalDraftRef.current;
    const currentMenuDraft = menuDraftRef.current;
    if (!currentDraft) return;
    persistProjectState(currentDraft, currentGlobalDraft, currentMenuDraft, () => setHasChanges(false)).catch((err) => {
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
    if (!currentDraft) return;
    runHotSave(currentDraft, currentGlobalDraft, currentMenuDraft, () => setHasChanges(false)).catch((err) => {
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
    if (!currentDraft) return;
    coldSave(buildProjectState(currentDraft, currentGlobalDraft, currentMenuDraft), slug)
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
    <ThemeLoader mode="admin" tenantCss={tenantCss} adminCss={adminCss}>
      <StudioProvider mode="studio">
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
      </StudioProvider>
    </ThemeLoader>
  );
};
