import React, { Component, type ErrorInfo, type ReactNode } from 'react';
import { AlertTriangle, ChevronDown, ChevronUp } from 'lucide-react';
import { useConfig } from '../config/ConfigContext';
import { useStudio } from '../studio-mode/StudioContext';
import { cn, type MenuItem, type Section } from '@olonjs/core';

class SectionErrorBoundary extends Component<{ children: ReactNode; type: string }, { hasError: boolean }> {
  constructor(props: { children: ReactNode; type: string }) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error(`[JsonPages] Component Crash [${this.props.type}]:`, error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="p-8 m-4 bg-amber-500/5 border-2 border-dashed border-amber-500/20 rounded-xl flex flex-col items-center text-center gap-3">
          <AlertTriangle className="text-amber-500" size={32} />
          <div className="space-y-1">
            <h4 className="text-sm font-bold text-amber-200 uppercase tracking-tight">Component Error</h4>
            <p className="text-xs text-amber-500/70 font-mono">Type: {this.props.type}</p>
          </div>
          <p className="text-xs text-zinc-400 max-w-[280px] leading-relaxed">
            This section failed to render. Check the console for details or verify the JSON data structure.
          </p>
        </div>
      );
    }
    return this.props.children;
  }
}

interface SectionRendererProps {
  section: Section;
  menu?: MenuItem[];
  selectedId?: string | null;
  reorderable?: boolean;
  sectionIndex?: number;
  totalSections?: number;
  onReorder?: (sectionId: string, newIndex: number) => void;
}

const SovereignOverlay: React.FC<{
  type: string;
  scope: string;
  isSelected: boolean;
  sectionId?: string;
  sectionIndex?: number;
  totalSections?: number;
  onReorder?: (sectionId: string, newIndex: number) => void;
}> = ({ type, scope, isSelected, sectionId, sectionIndex = 0, totalSections = 0, onReorder }) => {
  const canMoveUp = typeof sectionIndex === 'number' && sectionIndex > 0 && onReorder;
  const canMoveDown = typeof sectionIndex === 'number' && sectionIndex < totalSections - 1 && onReorder;

  return (
    <div
      data-jp-section-overlay
      aria-hidden
      className={cn(
        'absolute inset-0 pointer-events-none transition-all duration-200 z-[50]',
        'border-2 border-transparent group-hover:border-blue-400/50 group-hover:border-dashed',
        isSelected && 'border-2 border-blue-600 border-solid bg-blue-500/5'
      )}
    >
      <div
        className={cn(
          'absolute top-0 right-0 flex flex-nowrap items-center gap-1 pl-1 pr-2 py-1 text-[9px] font-black uppercase tracking-widest transition-opacity pointer-events-auto',
          'bg-blue-600 text-white',
          isSelected || 'group-hover:opacity-100 opacity-0'
        )}
      >
        {onReorder && sectionId != null && (
          <span className="shrink-0 flex items-center gap-0.5">
            <button
              type="button"
              onClick={(event) => {
                event.stopPropagation();
                if (canMoveUp) onReorder(sectionId, sectionIndex - 1);
              }}
              disabled={!canMoveUp}
              className="inline-flex items-center justify-center min-w-[18px] min-h-[18px] rounded bg-white/20 hover:bg-white/30 disabled:opacity-30 disabled:pointer-events-none"
              title="Move section up"
              aria-label="Move section up"
            >
              <ChevronUp size={12} strokeWidth={2.5} />
            </button>
            <button
              type="button"
              onClick={(event) => {
                event.stopPropagation();
                if (canMoveDown) onReorder(sectionId, sectionIndex + 2);
              }}
              disabled={!canMoveDown}
              className="inline-flex items-center justify-center min-w-[18px] min-h-[18px] rounded bg-white/20 hover:bg-white/30 disabled:opacity-30 disabled:pointer-events-none"
              title="Move section down"
              aria-label="Move section down"
            >
              <ChevronDown size={12} strokeWidth={2.5} />
            </button>
          </span>
        )}
        <span className="shrink-0">{type}</span>
        <span className="opacity-50 shrink-0">|</span>
        <span className="shrink-0">{scope}</span>
      </div>
    </div>
  );
};

export const SectionRenderer: React.FC<SectionRendererProps> = ({
  section,
  menu,
  selectedId,
  reorderable: reorderableProp,
  sectionIndex,
  totalSections,
  onReorder,
}) => {
  const { mode } = useStudio();
  const { registry, overlayDisabledSectionTypes } = useConfig();
  const isStudio = mode === 'studio';
  const isSelected = isStudio && selectedId === section.id;

  const Component = registry[section.type];
  const scope = section.type === 'header' || section.type === 'footer' ? 'global' : 'local';
  const disableOverlayForSection = Array.isArray(overlayDisabledSectionTypes)
    ? overlayDisabledSectionTypes.includes(section.type as string)
    : false;

  const isStickyHeader =
    section.type === 'header' &&
    typeof section.settings === 'object' &&
    section.settings !== null &&
    'sticky' in section.settings &&
    Boolean((section.settings as { sticky?: unknown }).sticky);

  if (!Component) {
    return (
      <div className="p-6 m-4 bg-red-500/10 text-red-400 border border-red-500/20 rounded-lg text-sm font-mono">
        <strong>Missing Component:</strong> {section.type}
      </div>
    );
  }

  const renderInnerComponent = () => {
    const DynamicComponent = Component as React.ComponentType<{
      data: unknown;
      settings?: unknown;
      menu?: MenuItem[];
    }>;
    if (menu) {
      return <DynamicComponent data={section.data} settings={section.settings} menu={menu} />;
    }
    return <DynamicComponent data={section.data} settings={section.settings} />;
  };

  const anchorId =
    typeof section.data === 'object' && section.data !== null && 'anchorId' in section.data
      ? String((section.data as { anchorId?: unknown }).anchorId ?? '')
      : undefined;

  return (
    <div
      id={anchorId || undefined}
      data-section-id={isStudio ? section.id : undefined}
      data-section-type={isStudio ? section.type : undefined}
      data-section-scope={isStudio ? scope : undefined}
      {...(isStudio && isSelected ? { 'data-jp-selected': true } : {})}
      className={cn(
        'relative w-full',
        isStudio && !disableOverlayForSection && 'group cursor-pointer',
        isStudio && isStickyHeader
          ? 'sticky top-0 z-[60]'
          : section.type === 'header'
            ? 'relative'
            : 'relative z-0',
        isSelected && 'z-[70]'
      )}
    >
      <div className={section.type === 'header' ? 'relative' : 'relative z-0'}>
        <SectionErrorBoundary type={section.type}>{renderInnerComponent()}</SectionErrorBoundary>
      </div>

      {isStudio && !disableOverlayForSection && (
        <SovereignOverlay
          type={section.type}
          scope={scope}
          isSelected={Boolean(isSelected)}
          sectionId={reorderableProp && scope === 'local' ? section.id : undefined}
          sectionIndex={reorderableProp && scope === 'local' ? sectionIndex : undefined}
          totalSections={reorderableProp && scope === 'local' ? totalSections : undefined}
          onReorder={reorderableProp && scope === 'local' ? onReorder : undefined}
        />
      )}
    </div>
  );
};
