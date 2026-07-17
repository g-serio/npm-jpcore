import React, { useState, useEffect, useRef, useDeferredValue, useMemo } from 'react';
import { z } from 'zod';
import {
  DndContext,
  DragOverlay,
  PointerSensor,
  TouchSensor,
  KeyboardSensor,
  useSensor,
  useSensors,
  closestCenter,
  type DragEndEvent,
  type DragStartEvent,
} from '@dnd-kit/core';
import { restrictToVerticalAxis } from '@dnd-kit/modifiers';
import {
  SortableContext,
  verticalListSortingStrategy,
  useSortable,
  sortableKeyboardCoordinates,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { cn, type PageConfig, type Section, type JsonPagesConfig } from '@olonjs/core';
import { FormFactory } from './FormFactory';
import { Layers, ChevronUp, GripVertical, Settings, Trash2, AlertCircle, X, Plus, Save } from 'lucide-react';
import { Button } from '../ui/button';
import { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider } from '../ui/tooltip';
import { PageSelector } from './PageSelector';

interface SelectedSectionInfo {
  id: string;
  type: string;
  scope: string;
}

export interface LayerItem {
  id: string;
  type: string;
  scope: string;
  title?: string;
}

/** Used by the section-settings modal to update a section without changing Inspector selection. */
export type OnUpdateSection = (
  sectionId: string,
  scope: 'global' | 'local',
  sectionType: string,
  newData: Record<string, unknown>
) => void;

interface AdminSidebarProps {
  selectedSection: SelectedSectionInfo | null;
  pageData: PageConfig | { sections: Section[] };
  /** All sections (header + page sections + footer) for resolving modal section data. */
  allSectionsData?: Section[];
  /** Section schemas, keyed by section type (caller already has these via its own config). */
  schemas: JsonPagesConfig['schemas'];
  collections?: JsonPagesConfig['collections'];
  collectionSource?: string;
  onUpdate: (newData: Record<string, unknown>) => void;
  /** Update a section by id/scope (e.g. from settings modal). When provided with allSectionsData, gear opens modal. */
  onUpdateSection?: OnUpdateSection;
  onClose: () => void;
  /** Root-to-leaf path for deep focus (e.g. silos -> blocks). When null, no canvas selection. */
  expandedItemPath?: Array<{ fieldKey: string; itemId?: string }> | null;
  onReorderSection?: (sectionId: string, newIndex: number) => void;
  allLayers?: LayerItem[];
  activeSectionId?: string | null;
  onRequestScrollToSection?: (sectionId: string) => void;
  onDeleteSection?: (sectionId: string) => void;
  /** When provided, shows an "Add section" button in the inspector header that opens the section library. */
  onAddSection?: () => void;
  /** Whether there are unsaved changes for the current draft. */
  hasChanges?: boolean;
  /** Save to file (writes JSON to repo via server). */
  onSaveToFile?: () => void;
  /** Hot Save callback (typically cloud save2edge). */
  onHotSave?: () => void;
  /** Cold Save callback (typically save2repo / deploy pipeline). */
  onColdSave?: () => void;
  /** When true, show "Salvato" in the status bar (e.g. for 2s after save-to-file succeeds). */
  saveSuccessFeedback?: boolean;
  /** When true, show "Saved" feedback for hot save (e.g. for 2s after success). */
  hotSaveSuccessFeedback?: boolean;
  /** When true, hot save action is currently running. */
  hotSaveInProgress?: boolean;
  /** Controls visibility of the local Save button. */
  showLocalSave?: boolean;
  /** Controls visibility of Hot Save button. */
  showHotSave?: boolean;
  /** Controls visibility of Save2Repo / Cold Save button. */
  showColdSave?: boolean;
  /** Restore page from file (resets in-memory draft for current slug). Hidden by default; set showResetToFile to display. */
  onResetToFile?: () => void;
  /** When true, shows the "Ripristina da file" button (default false = hidden). */
  showResetToFile?: boolean;
  /** Available page slugs. When length > 0 and onPageChange set, shows page selector under Inspector header. */
  pageSlugs?: string[];
  /** Current page slug. */
  currentSlug?: string;
  /** Called when user selects another page; engine should navigate to /admin/:slug. */
  onPageChange?: (slug: string) => void;
}

const SETTINGS_KEYS = new Set(['anchorId', 'paddingTop', 'paddingBottom', 'theme', 'container']);
const INLINE_EDITOR_UI_HINTS = new Set(['ui:editorial-markdown']);

const unwrapSchema = (schema: z.ZodTypeAny): z.ZodTypeAny => {
  if (schema instanceof z.ZodOptional || schema instanceof z.ZodDefault || schema instanceof z.ZodNullable) {
    return unwrapSchema(schema._def.innerType);
  }
  return schema;
};

const getUiHint = (schema: z.ZodTypeAny | undefined): string => {
  if (!schema) return '';
  const raw = schema as z.ZodTypeAny & { _def?: { description?: unknown } };
  const direct = typeof schema.description === 'string' ? schema.description : null;
  if (direct) return direct;
  const defDescription = typeof raw._def?.description === 'string' ? raw._def.description : null;
  if (defDescription) return defDescription;
  const unwrapped = unwrapSchema(schema);
  if (unwrapped !== schema) {
    return getUiHint(unwrapped);
  }
  return '';
};

const humanizeLabel = (label: string): string =>
  label
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());

/** Activation: 8px movement to start drag (avoids accidental drag on click). Touch: 200ms delay so scroll works. */
const pointerSensor = { activationConstraint: { distance: 8 } };
const touchSensor = { activationConstraint: { delay: 200, tolerance: 5 } };

interface LayerRowOpts {
  isSelected: boolean;
  isActive: boolean;
  isDragging: boolean;
  canDelete: boolean;
  deleteConfirm: boolean;
  onSelect: () => void;
  onDelete: () => void;
  onOpenSettings: (e: React.MouseEvent) => void;
}

/** Shared row UI (used by both sortable and overlay). */
function LayerRowContent({
  layer,
  opts,
  dragHandleProps,
}: {
  layer: LayerItem;
  opts: LayerRowOpts;
  dragHandleProps?: { 'aria-pressed'?: boolean; 'aria-roledescription'?: string } & Record<string, unknown>;
}) {
  const { isSelected, isActive, isDragging, canDelete, onSelect, onOpenSettings, onDelete } = opts;
  const canReorder = !!dragHandleProps;
  return (
    <div
      className={cn(
        'group flex items-center gap-2 pl-1 pr-2 py-2.5 rounded-lg text-left transition-all duration-200 cursor-pointer border-l-2',
        isSelected ? 'bg-primary/[0.08] border-primary' : isActive ? 'bg-zinc-800/30 border-emerald-500/60' : 'border-transparent hover:bg-zinc-800/40',
        isDragging && 'opacity-50 shadow-lg',
        canReorder ? 'cursor-grab active:cursor-grabbing' : 'cursor-default'
      )}
    >
      {canReorder ? (
        <span
          className="shrink-0 w-5 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-150 cursor-grab touch-none"
          aria-label="Trascina per riordinare"
          {...dragHandleProps}
        >
          <GripVertical size={12} className="text-zinc-600" />
        </span>
      ) : (
        <span className="shrink-0 w-5 flex items-center justify-center opacity-0 group-hover:opacity-100 pointer-events-none">
          <GripVertical size={12} className="text-zinc-600/50" />
        </span>
      )}
      <button type="button" onClick={onSelect} className="flex-1 min-w-0 text-left">
        <div className="flex items-center gap-1.5">
          <span className={cn('text-xs font-bold uppercase tracking-[0.06em] truncate', isSelected ? 'text-primary' : 'text-zinc-500')}>
            {layer.type}
          </span>
          {isActive && <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 shrink-0" aria-hidden />}
        </div>
        <span className="text-[11px] text-zinc-600 block truncate leading-snug mt-0.5">
          {layer.title ?? `${layer.type} section`}
        </span>
      </button>
      <div className="flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity duration-150">
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="ghost" size="icon-xs" className="text-zinc-600 hover:text-zinc-300" onClick={(e) => { e.stopPropagation(); onOpenSettings(e); }}>
              <Settings size={12} />
            </Button>
          </TooltipTrigger>
          <TooltipContent>Settings</TooltipContent>
        </Tooltip>
        {canDelete && (
          <Tooltip>
            <TooltipTrigger asChild>
              <Button variant="ghost" size="icon-xs" className="text-zinc-600 hover:text-destructive" onClick={(e) => { e.stopPropagation(); onDelete(); }}>
                <Trash2 size={12} />
              </Button>
            </TooltipTrigger>
            <TooltipContent>Delete section</TooltipContent>
          </Tooltip>
        )}
      </div>
    </div>
  );
}

/** Sortable row: drag handle only, smooth transform/transition from @dnd-kit. */
function SortableLayerRow({
  layer,
  opts,
}: {
  layer: LayerItem;
  opts: LayerRowOpts & { canReorder: boolean };
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: layer.id,
    disabled: !opts.canReorder,
  });
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };
  return (
    <div ref={setNodeRef} style={style} className={cn(isDragging && 'z-10')}>
      <LayerRowContent
        layer={layer}
        opts={{ ...opts, isDragging }}
        dragHandleProps={opts.canReorder ? { ...attributes, ...listeners, 'aria-roledescription': 'elemento trascinabile' } : undefined}
      />
    </div>
  );
}

export const AdminSidebar: React.FC<AdminSidebarProps> = ({
  selectedSection,
  pageData,
  allSectionsData = [],
  schemas,
  collections,
  collectionSource,
  onUpdate,
  onUpdateSection,
  onClose,
  expandedItemPath = null,
  onReorderSection,
  allLayers = [],
  activeSectionId,
  onRequestScrollToSection,
  onDeleteSection,
  onAddSection,
  hasChanges = false,
  onSaveToFile,
  onHotSave,
  onColdSave,
  saveSuccessFeedback = false,
  hotSaveSuccessFeedback = false,
  hotSaveInProgress = false,
  showLocalSave = true,
  showHotSave = false,
  showColdSave = false,
  onResetToFile,
  showResetToFile = false,
  pageSlugs = [],
  currentSlug = 'home',
  onPageChange,
}) => {
  const [layersOpen, setLayersOpen] = useState(true);
  const [deleteConfirm, setDeleteConfirm] = useState<string | null>(null);
  const [activeDragId, setActiveDragId] = useState<string | null>(null);
  const [sidebarExpandedItem, setSidebarExpandedItem] = useState<{ fieldKey: string; itemId?: string } | null>(null);
  /** When set, the section-settings modal is open for this section id (avoids Inspector tab/selection state freeze). */
  const [settingsModalSectionId, setSettingsModalSectionId] = useState<string | null>(null);
  const contentScrollRef = useRef<HTMLDivElement>(null);
  const modalContentRef = useRef<HTMLDivElement>(null);

  const sensors = useSensors(
    useSensor(PointerSensor, pointerSensor),
    useSensor(TouchSensor, touchSensor),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
  );

  /** Defer heavy form render so first-time open + edit doesn't freeze the UI (enterprise-grade UX). */
  const deferredSection = useDeferredValue(selectedSection);
  const isFormPending = selectedSection != null && deferredSection?.id !== selectedSection.id;

  // Canvas path takes precedence; otherwise single-level sidebar expansion.
  const effectiveExpandedItemPath =
    expandedItemPath && expandedItemPath.length > 0
      ? expandedItemPath
      : sidebarExpandedItem
        ? [sidebarExpandedItem]
        : null;
  const effectiveExpandedItem =
    effectiveExpandedItemPath?.length
      ? {
          fieldKey: effectiveExpandedItemPath[effectiveExpandedItemPath.length - 1].fieldKey,
          itemId: effectiveExpandedItemPath[effectiveExpandedItemPath.length - 1].itemId,
        }
      : null;

  // When engine clears path (e.g. user clicked section on canvas), clear sidebar expansion too.
  const prevPathRef = useRef(expandedItemPath);
  useEffect(() => {
    if (prevPathRef.current != null && expandedItemPath == null) setSidebarExpandedItem(null);
    prevPathRef.current = expandedItemPath;
  }, [expandedItemPath]);

  /** When a section is selected (from Stage preview click or from Page Layers click), collapse the list so behaviour is the same. */
  useEffect(() => {
    if (selectedSection?.id != null) setLayersOpen(false);
  }, [selectedSection?.id]);

  /** Scroll sidebar content to top. Double rAF so it runs after layout (fixes scroll not moving). */
  const scrollSidebarToTop = () => {
    const id = requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        const el = contentScrollRef.current;
        if (el) {
          el.scrollTo({ top: 0, behavior: 'smooth' });
        }
      });
    });
    return () => cancelAnimationFrame(id);
  };

  /** Scroll sidebar to top when Page Layers list is opened via chevron (effect runs after commit). */
  const prevLayersOpenRef = useRef(layersOpen);
  useEffect(() => {
    if (layersOpen && !prevLayersOpenRef.current) {
      const cancel = scrollSidebarToTop();
      prevLayersOpenRef.current = layersOpen;
      return cancel;
    }
    prevLayersOpenRef.current = layersOpen;
  }, [layersOpen]);

  /** Defer scroll to next frame to avoid blocking main thread when form mounts (enterprise-grade UX). */
  useEffect(() => {
    if (!effectiveExpandedItem) return;
    const scrollEl = contentScrollRef.current;
    if (!scrollEl) return;
    const id = requestAnimationFrame(() => {
      const el = scrollEl.querySelector('[data-jp-expanded-item]') ?? scrollEl.querySelector('[data-jp-focused-field]');
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
    return () => cancelAnimationFrame(id);
  }, [effectiveExpandedItem]);

  const handleLayerClick = (sectionId: string) => {
    setLayersOpen(false);
    onRequestScrollToSection?.(sectionId);
  };

  /** Toggle Page Layers list (header or chevron); scroll to top when opening so list is in view. */
  const handlePageLayersToggle = () => {
    setLayersOpen((prev) => {
      const next = !prev;
      if (next) scrollSidebarToTop();
      return next;
    });
  };

  /** Open the section-settings modal for the given section (no Inspector tab/selection change to avoid UI freeze). */
  const handleOpenSectionSettings = (sectionId: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (allSectionsData.length > 0 && onUpdateSection) {
      setSettingsModalSectionId(sectionId);
    } else {
      setLayersOpen(false);
      onRequestScrollToSection?.(sectionId);
    }
  };

  // ESC closes the section-settings modal.
  useEffect(() => {
    if (settingsModalSectionId == null) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setSettingsModalSectionId(null);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [settingsModalSectionId]);

  const handleDelete = (sectionId: string) => {
    if (deleteConfirm === sectionId) {
      onDeleteSection?.(sectionId);
      setDeleteConfirm(null);
    } else {
      setDeleteConfirm(sectionId);
      setTimeout(() => setDeleteConfirm(null), 3000);
    }
  };

  const sortableIds = useMemo(
    () => allLayers.filter((l) => l.scope === 'local').map((l) => l.id),
    [allLayers]
  );
  const canReorder = !!onReorderSection && sortableIds.length > 0;

  const handleDragStart = (event: DragStartEvent) => {
    setActiveDragId(event.active.id as string);
  };

  const handleDragEnd = (event: DragEndEvent) => {
    setActiveDragId(null);
    const { active, over } = event;
    if (!over || active.id === over.id || !onReorderSection) return;
    const from = allLayers.findIndex((l) => l.id === active.id);
    const to = allLayers.findIndex((l) => l.id === over.id);
    if (from === -1 || to === -1) return;
    const newIndex = from < to ? to : to - 1;
    onReorderSection(active.id as string, newIndex);
  };

  const section = selectedSection
    ? pageData.sections.find((s: Section) => s.id === selectedSection.id)
    : undefined;
  /** Section/schema for the form only: deferred so heavy FormFactory doesn't block the main thread. */
  const formSection = deferredSection
    ? pageData.sections.find((s: Section) => s.id === deferredSection.id)
    : undefined;
  const formSchema = deferredSection
    ? (schemas[deferredSection.type] as z.ZodObject<z.ZodRawShape> | undefined)
    : undefined;
  const isInlineEditorialSection = useMemo(() => {
    if (!formSchema) return false;
    const shape = formSchema.shape;
    const contentKeys = Object.keys(shape).filter((k) => !SETTINGS_KEYS.has(k));
    if (contentKeys.length === 0) return false;
    return contentKeys.every((k) => INLINE_EDITOR_UI_HINTS.has(getUiHint(shape[k])));
  }, [formSchema]);
  useEffect(() => {
    if (selectedSection?.id != null && isInlineEditorialSection) {
      setLayersOpen(true);
    }
  }, [selectedSection?.id, isInlineEditorialSection]);

  /** When no section is selected, Page Layers list is always shown (open); otherwise use accordion state. */
  const showLayersList = allLayers.length > 0 && (layersOpen || !selectedSection);

  /** Page switcher: current page label (slug if no labels map). */
  const currentPageLabel = currentSlug ? currentSlug.charAt(0).toUpperCase() + currentSlug.slice(1) : 'Select page';

  /** Rows with separators (header→content, content→footer). Order is controlled by parent via allLayers. */
  const layerRowsWithSeparators = useMemo(() => {
    const rows: Array<{ layer: LayerItem; showSeparatorAbove: boolean }> = [];
    let prevType: string | null = null;
    for (const layer of allLayers) {
      const type = layer.type.toUpperCase();
      const showSeparatorAbove =
        prevType !== null &&
        ((prevType === 'HEADER' && type !== 'HEADER') ||
          (prevType !== 'HEADER' && prevType !== 'FOOTER' && type === 'FOOTER'));
      rows.push({ layer, showSeparatorAbove });
      prevType = type;
    }
    return rows;
  }, [allLayers]);

  return (
    <TooltipProvider>
      <aside data-jp-inspector className="relative w-full h-full bg-zinc-950 border-l border-zinc-800 flex flex-col shadow-2xl shrink-0 min-w-0 animate-in slide-in-from-right duration-300 text-zinc-100">
        {/* Header: Inspector + page context or type|scope */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800 shrink-0">
          <div className="min-w-0">
            <h2 className="text-sm font-bold text-white">Inspector</h2>
            <p className="text-[10px] tracking-[0.06em] text-zinc-600 mt-0.5">
              {selectedSection ? (
                <>
                  <span className="text-primary font-bold">{selectedSection.type}</span>
                  <span className="text-zinc-700 mx-1.5">|</span>
                  <span className="uppercase">{selectedSection.scope}</span>
                </>
              ) : (
                <span className="text-zinc-600">
                  {currentPageLabel} · {allLayers.length} sections
                </span>
              )}
            </p>
          </div>
          <Button variant="ghost" size="icon-sm" onClick={onClose} aria-label="Close Inspector">
            <X size={14} />
          </Button>
        </div>

        {/* Page Switcher: encapsulated in PageSelector (styling, a11y, single source of truth) */}
        {pageSlugs.length > 0 && onPageChange && (
          <PageSelector
            pageSlugs={pageSlugs}
            currentSlug={currentSlug}
            onPageChange={onPageChange}
            sectionCount={allLayers.length}
            currentPageLabel={currentPageLabel}
          />
        )}

        {/* Page Layers header */}
        {allLayers.length > 0 && (
          <div className="flex items-center gap-2 px-4 py-2 border-t border-zinc-800/50">
            <button
              type="button"
              onClick={handlePageLayersToggle}
              className="flex items-center gap-2 flex-1 cursor-pointer min-w-0 text-left"
              aria-expanded={showLayersList}
              aria-label={showLayersList ? 'Collapse Page Layers' : 'Expand Page Layers'}
            >
              <Layers size={14} className="text-zinc-500 shrink-0" />
              <span className="text-[11px] font-semibold tracking-[0.04em] text-zinc-400">Page Layers</span>
              <span className="text-[10px] text-zinc-600">({allLayers.length})</span>
              <ChevronUp
                size={13}
                className={cn('ml-auto text-zinc-600 transition-transform duration-200 shrink-0', !layersOpen && 'rotate-180')}
              />
            </button>
            {onAddSection != null && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="ghost" size="icon-sm" className="text-zinc-500 hover:text-primary" onClick={onAddSection}>
                    <Plus size={14} />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Add section</TooltipContent>
              </Tooltip>
            )}
          </div>
        )}

      {/* Radix ScrollArea uses an inner display:table wrapper that breaks position:sticky in descendants. */}
      <div className="relative flex-1 min-h-0 min-w-0 flex flex-col overflow-hidden">
        <div
          ref={contentScrollRef}
          className="min-h-0 min-w-0 flex-1 overflow-y-auto overflow-x-hidden flex flex-col"
          role="region"
          aria-label="Inspector content"
        >
        <div className="flex flex-col min-h-0">
        {showLayersList && (
          <div className="py-1">
            <DndContext
              sensors={sensors}
              collisionDetection={closestCenter}
              modifiers={[restrictToVerticalAxis]}
              onDragStart={handleDragStart}
              onDragEnd={handleDragEnd}
              accessibility={{
                announcements: {
                  onDragStart: () => `Sezione presa in carico. Usa i tasti freccia per spostare, Spazio per rilasciare.`,
                  onDragOver: ({ over }) => over ? `Posizione ${sortableIds.indexOf(String(over.id)) + 1} di ${sortableIds.length}.` : undefined,
                  onDragEnd: ({ over }) => over ? `Sezione rilasciata in nuova posizione.` : `Riposizionamento annullato.`,
                  onDragCancel: () => `Riposizionamento annullato.`,
                },
              }}
            >
              <SortableContext items={sortableIds} strategy={verticalListSortingStrategy}>
                <div className="px-2 space-y-0.5">
                  {layerRowsWithSeparators.map(({ layer, showSeparatorAbove }) => (
                    <React.Fragment key={layer.id}>
                      {showSeparatorAbove && <div className="mx-3 border-t border-zinc-800/60 my-1" />}
                      {layer.scope === 'local' && canReorder ? (
                        <SortableLayerRow
                          layer={layer}
                          opts={{
                            isSelected: selectedSection?.id === layer.id,
                            isActive: activeSectionId === layer.id,
                            isDragging: false,
                            canReorder: true,
                            canDelete: !!onDeleteSection,
                            deleteConfirm: deleteConfirm === layer.id,
                            onSelect: () => handleLayerClick(layer.id),
                            onDelete: () => handleDelete(layer.id),
                            onOpenSettings: (e) => handleOpenSectionSettings(layer.id, e),
                          }}
                        />
                      ) : (
                        <div>
                          <LayerRowContent
                            layer={layer}
                            opts={{
                              isSelected: selectedSection?.id === layer.id,
                              isActive: activeSectionId === layer.id,
                              isDragging: false,
                              canDelete: layer.scope === 'local' && !!onDeleteSection,
                              deleteConfirm: deleteConfirm === layer.id,
                              onSelect: () => handleLayerClick(layer.id),
                              onDelete: () => handleDelete(layer.id),
                              onOpenSettings: (e) => handleOpenSectionSettings(layer.id, e),
                            }}
                          />
                        </div>
                      )}
                    </React.Fragment>
                  ))}
                </div>
              </SortableContext>
              <DragOverlay dropAnimation={{ duration: 200, easing: 'cubic-bezier(0.18, 0.67, 0.6, 1.22)' }}>
                {activeDragId ? (() => {
                  const layer = allLayers.find((l) => l.id === activeDragId);
                  if (!layer) return null;
                  return (
                    <div className="px-2 w-full max-w-[var(--inspector-width,280px)]">
                      <LayerRowContent
                        layer={layer}
                        opts={{
                          isSelected: false,
                          isActive: false,
                          isDragging: true,
                          canDelete: false,
                          deleteConfirm: false,
                          onSelect: () => {},
                          onDelete: () => {},
                          onOpenSettings: () => {},
                        }}
                        dragHandleProps={{ 'aria-hidden': true }}
                      />
                    </div>
                  );
                })() : null}
              </DragOverlay>
            </DndContext>
            {deleteConfirm && (
              <div className="flex items-center gap-2 py-2 px-3 mt-1 mx-2 rounded-md bg-amber-500/10 border border-amber-500/30">
                <AlertCircle size={12} className="text-amber-500 shrink-0" />
                <p className="text-[10px] text-amber-500 font-medium">Click delete again to confirm</p>
              </div>
            )}
          </div>
        )}

        </div>
        {effectiveExpandedItem && section && (() => {
          const data = (section.data as Record<string, unknown>) || {};
          let label: string;
          if (effectiveExpandedItemPath && effectiveExpandedItemPath.length > 0) {
            let current: unknown = data;
            for (const seg of effectiveExpandedItemPath) {
              const next = (current as Record<string, unknown>)?.[seg.fieldKey];
              if (seg.itemId != null && Array.isArray(next)) {
                const item = (next as Record<string, unknown>[]).find(
                  (i) => String((i as Record<string, unknown>)?.id) === String(seg.itemId)
                );
                current = item ?? null;
              } else {
                current = next;
              }
            }
            const rec = (current as Record<string, unknown>) || {};
            const fieldKey = effectiveExpandedItem.fieldKey;
            label =
              (typeof rec.name === 'string' ? rec.name : null) ??
              (typeof rec.title === 'string' ? rec.title : null) ??
              (typeof rec.label === 'string' ? rec.label : null) ??
              humanizeLabel(fieldKey);
          } else {
            const fieldKey = effectiveExpandedItem.fieldKey;
            if (effectiveExpandedItem.itemId != null) {
              const arr = Array.isArray(data[fieldKey]) ? (data[fieldKey] as Record<string, unknown>[]) : [];
              const item = arr.find((i) => String(i?.id) === String(effectiveExpandedItem!.itemId));
              const rec = (item as Record<string, unknown>) || {};
              label =
                (typeof rec.name === 'string' ? rec.name : null) ??
                (typeof rec.title === 'string' ? rec.title : null) ??
                (typeof rec.label === 'string' ? rec.label : null) ??
                humanizeLabel(fieldKey);
            } else {
              label = humanizeLabel(fieldKey);
            }
          }
          return (
            <div className="px-4 py-2 border-b border-zinc-800 bg-zinc-900/50">
              <p className="text-[10px] font-bold uppercase tracking-widest text-zinc-500">Editing</p>
              <p className="text-xs font-medium text-white truncate mt-0.5">{label}</p>
            </div>
          );
        })()}

        <div
          className="flex-1 p-4"
          onFocusCapture={() => selectedSection != null && setLayersOpen(false)}
        >
          {!selectedSection ? (
            <p className="text-xs text-zinc-600 text-center py-10">
              Select a layer above or on the stage to edit.
            </p>
          ) : isFormPending ? (
            <div className="space-y-4 animate-pulse" role="status" aria-label="Loading form">
              <div className="h-4 w-3/4 rounded bg-zinc-800" />
              <div className="h-10 rounded bg-zinc-800/80" />
              <div className="h-10 rounded bg-zinc-800/80" />
              <div className="h-20 rounded bg-zinc-800/80" />
              <div className="h-10 rounded bg-zinc-800/60" />
            </div>
          ) : !formSchema ? (
            <div className="text-xs text-red-400 p-4 border border-dashed border-red-900/30 rounded bg-red-900/10">
              No schema found for {deferredSection?.type ?? selectedSection.type}
            </div>
          ) : (() => {
            const shapeKeys = Object.keys(formSchema.shape);
            const contentKeys = shapeKeys.filter(
              (k) =>
                !SETTINGS_KEYS.has(k) &&
                !INLINE_EDITOR_UI_HINTS.has(getUiHint(formSchema.shape[k]))
            );
            const data = (formSection?.data as Record<string, unknown>) || {};
            if (contentKeys.length === 0) {
              return (
                <p className="text-xs text-zinc-500">Inline editorial section: edit content directly on the canvas.</p>
              );
            }
            return (
              <FormFactory
                schema={formSchema}
                data={data}
                collections={collections}
                collectionSource={collectionSource}
                onChange={(newData) => onUpdate(newData)}
                keys={contentKeys}
                expandedItemPath={effectiveExpandedItemPath}
                onSidebarExpandedItemChange={setSidebarExpandedItem}
              />
            );
          })()}
        </div>
        </div>
      </div>

      <div className="px-4 py-2.5 border-t border-zinc-800 bg-zinc-900/50 flex items-center justify-between gap-3 opacity-100 shrink-0">
        {((showLocalSave && onSaveToFile != null) || (showHotSave && onHotSave != null) || (showColdSave && onColdSave != null) || onResetToFile != null) && (
          <>
            <div className="flex items-center gap-2 min-w-0">
              <div className={cn(
                'w-2 h-2 rounded-full transition-colors duration-300 shrink-0',
                hasChanges ? 'bg-amber-500 shadow-[0_0_8px_rgba(245,158,11,0.5)]' : 'bg-emerald-500'
              )} />
              <span className={cn(
                'text-sm font-medium transition-colors duration-300 truncate',
                (saveSuccessFeedback || hotSaveSuccessFeedback) ? 'text-emerald-400' : hasChanges ? 'text-amber-500' : 'text-zinc-500'
              )}>
                {(saveSuccessFeedback || hotSaveSuccessFeedback) ? 'Saved' : hasChanges ? 'Unsaved Changes' : 'All Changes Saved'}
              </span>
            </div>
            {showLocalSave && onSaveToFile != null && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    size="default"
                    disabled={!hasChanges}
                    className="h-9 min-w-[156px] px-5 text-sm gap-2 ml-auto"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      onSaveToFile();
                    }}
                  >
                    <Save size={14} />
                    <span>Save</span>
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Save to local file</TooltipContent>
              </Tooltip>
            )}
            {showHotSave && onHotSave != null && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    size="default"
                    disabled={!hasChanges || hotSaveInProgress}
                    className="h-9 min-w-[156px] px-5 text-sm gap-2 ml-auto"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      onHotSave();
                    }}
                  >
                    <Save size={14} />
                    <span>{hotSaveInProgress ? 'Saving...' : 'Hot Save'}</span>
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Hot save to edge</TooltipContent>
              </Tooltip>
            )}
            {showColdSave && onColdSave != null && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button
                    size="default"
                    disabled={!hasChanges}
                    className="h-9 min-w-[156px] px-5 text-sm gap-2 ml-auto"
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      onColdSave();
                    }}
                  >
                    <Save size={14} />
                    <span>Save2Repo</span>
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Save to repository</TooltipContent>
              </Tooltip>
            )}
            {onResetToFile != null && showResetToFile && (
              <button
                type="button"
                onClick={onResetToFile}
                className="shrink-0 flex items-center gap-1.5 px-2 py-1 rounded text-[11px] font-medium transition-all border border-zinc-700 bg-zinc-900 text-zinc-400 hover:bg-zinc-800 hover:border-zinc-600 hover:text-zinc-300"
                title="Ripristina la pagina dal file (elimina le modifiche in memoria)"
              >
                <span>Ripristina da file</span>
              </button>
            )}
          </>
        )}
      </div>

      {/* Section settings modal: centered, close via X or Escape to avoid Inspector state freeze. */}
      {settingsModalSectionId != null && allSectionsData.length > 0 && onUpdateSection != null && (() => {
        const modalSection = allSectionsData.find((s) => s.id === settingsModalSectionId);
        const layer = allLayers.find((l) => l.id === settingsModalSectionId);
        if (!modalSection) return null;
        const scope = (layer?.scope === 'global' ? 'global' : 'local') as 'global' | 'local';
        const sectionType = modalSection.type;
        const schema = schemas[sectionType] as z.ZodObject<z.ZodRawShape> | undefined;
        const shapeKeys = schema ? Object.keys(schema.shape) : [];
        const settingsKeys = shapeKeys.filter((k) => SETTINGS_KEYS.has(k));
        const data = (modalSection.data as Record<string, unknown>) ?? {};

        if (settingsKeys.length === 0) {
          return (
            <div
              className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 p-4"
              role="dialog"
              aria-modal="true"
              aria-labelledby="section-settings-modal-title"
              onClick={() => setSettingsModalSectionId(null)}
            >
              <div
                ref={modalContentRef}
                className="relative rounded-lg border border-zinc-700 bg-zinc-900 shadow-xl max-w-md w-full overflow-hidden"
                onClick={(e) => e.stopPropagation()}
              >
                <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800">
                  <h2 id="section-settings-modal-title" className="text-sm font-bold text-white">
                    Settings — {sectionType}
                  </h2>
                  <button
                    type="button"
                    onClick={() => setSettingsModalSectionId(null)}
                    className="p-1.5 rounded text-zinc-500 hover:text-white hover:bg-zinc-800 transition-colors"
                    aria-label="Close settings"
                  >
                    <X size={18} />
                  </button>
                </div>
                <div className="p-4">
                  <p className="text-xs text-zinc-500">No settings fields for this section.</p>
                </div>
              </div>
            </div>
          );
        }

        return (
          <div
            className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 p-4"
            role="dialog"
            aria-modal="true"
            aria-labelledby="section-settings-modal-title"
            onClick={(e) => e.target === e.currentTarget && setSettingsModalSectionId(null)}
          >
            <div
              ref={modalContentRef}
              className="relative rounded-lg border border-zinc-700 bg-zinc-900 shadow-xl max-w-md w-full max-h-[85vh] flex flex-col overflow-hidden"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800 shrink-0">
                <h2 id="section-settings-modal-title" className="text-sm font-bold text-white">
                  Settings — {sectionType}
                </h2>
                <button
                  type="button"
                  onClick={() => setSettingsModalSectionId(null)}
                  className="p-1.5 rounded text-zinc-500 hover:text-white hover:bg-zinc-800 transition-colors"
                  aria-label="Close settings (Escape)"
                >
                  <X size={18} />
                </button>
              </div>
              <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
                <FormFactory
                  schema={schema!}
                  data={data}
                  collections={collections}
                  collectionSource={collectionSource}
                  onChange={(newData) => {
                    const merged = { ...(modalSection.data as Record<string, unknown>), ...newData };
                    onUpdateSection(settingsModalSectionId, scope, sectionType, merged);
                  }}
                  keys={settingsKeys}
                />
              </div>
            </div>
          </div>
        );
      })()}
    </aside>
    </TooltipProvider>
  );
};
