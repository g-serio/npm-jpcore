import React, { useState, useRef, useEffect } from 'react';
import { shouldRenderSiteGlobalHeader, type PageRendererProps } from '../../contract/kernel';
import { resolveSectionMenuItems } from '../../contract/config-resolver';
import { SectionRenderer } from './SectionRenderer';
import { useDocumentMeta } from './useDocumentMeta';

const REORDER_DATA_KEY = 'application/json';

type Props = PageRendererProps & {
  onReorder?: (sectionId: string, newIndex: number) => void;
  scrollToSectionId?: string | null;
  onActiveSectionChange?: (sectionId: string | null) => void;
};

export const PageRenderer: React.FC<Props> = ({
  pageConfig,
  siteConfig,
  menuConfig,
  selectedId,
  onReorder,
  scrollToSectionId,
  onActiveSectionChange,
}) => {
  useDocumentMeta(pageConfig.meta);
  const [dropIndex, setDropIndex] = useState<number | null>(null);
  const sectionRefs = useRef<Record<string, HTMLElement | null>>({});
  const onActiveSectionChangeRef = useRef(onActiveSectionChange);
  onActiveSectionChangeRef.current = onActiveSectionChange;

  const showGlobalHeader = shouldRenderSiteGlobalHeader(pageConfig, siteConfig);
  const headerSection = showGlobalHeader ? siteConfig.header ?? null : null;
  const footerSection = siteConfig.footer ?? null;

  const handleSectionHover = (sectionId: string) => {
    onActiveSectionChangeRef.current?.(sectionId);
  };

  useEffect(() => {
    if (!scrollToSectionId) return;
    const el = sectionRefs.current[scrollToSectionId];
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }, [scrollToSectionId]);

  useEffect(() => {
    const callback = onActiveSectionChangeRef.current;
    if (!callback) return;
    const ids: string[] = [
      ...(headerSection ? [headerSection.id] : []),
      ...pageConfig.sections.map((section) => section.id),
      ...(footerSection ? [footerSection.id] : []),
    ];
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && entry.intersectionRatio > 0.5) {
            const id = (entry.target as HTMLElement).getAttribute('data-section-id');
            if (id) onActiveSectionChangeRef.current?.(id);
          }
        });
      },
      { threshold: [0, 0.5, 1], rootMargin: '-20% 0px -20% 0px' }
    );
    let cancelled = false;
    const rafId = requestAnimationFrame(() => {
      if (cancelled) return;
      ids.forEach((id) => {
        const el = sectionRefs.current[id];
        if (el) observer.observe(el);
      });
    });
    return () => {
      cancelled = true;
      cancelAnimationFrame(rafId);
      observer.disconnect();
    };
  }, [footerSection, headerSection, pageConfig.sections, pageConfig['global-header'], showGlobalHeader]);

  const handleDragOver = (event: React.DragEvent, index: number) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
    setDropIndex(index);
  };

  const handleDragLeave = () => {
    setDropIndex(null);
  };

  const handleDrop = (event: React.DragEvent, insertIndex: number) => {
    event.preventDefault();
    setDropIndex(null);
    if (!onReorder) return;
    try {
      const raw = event.dataTransfer.getData(REORDER_DATA_KEY);
      const { sectionId } = JSON.parse(raw) as { sectionId?: string };
      if (typeof sectionId === 'string') onReorder(sectionId, insertIndex);
    } catch {
      // ignore malformed drag payloads
    }
  };

  const renderPageSections = () => {
    const reorderable = typeof onReorder === 'function';
    const sections = pageConfig.sections.map((section, index) => {
      const showDropIndicator = dropIndex === index;

      if (!reorderable) {
        return (
          <div
            key={section.id}
            ref={(element) => {
              sectionRefs.current[section.id] = element;
            }}
            data-section-id={section.id}
            onMouseEnter={() => handleSectionHover(section.id)}
          >
            <SectionRenderer
              section={section}
              menu={resolveSectionMenuItems(section, menuConfig.main ?? [])}
              selectedId={selectedId}
            />
          </div>
        );
      }

      return (
        <div
          key={section.id}
          ref={(element) => {
            sectionRefs.current[section.id] = element;
          }}
          data-section-id={section.id}
          style={{ position: 'relative' }}
          onMouseEnter={() => handleSectionHover(section.id)}
        >
          <div
            data-jp-drop-zone
            style={{
              position: 'absolute',
              left: 0,
              right: 0,
              top: -1,
              height: 12,
              zIndex: 55,
              pointerEvents: 'auto',
              backgroundColor: showDropIndicator ? 'rgba(59, 130, 246, 0.4)' : 'transparent',
              borderTop: showDropIndicator ? '2px solid rgb(96, 165, 250)' : '2px solid transparent',
            }}
            onDragOver={(event) => handleDragOver(event, index)}
            onDragLeave={handleDragLeave}
            onDrop={(event) => handleDrop(event, index)}
          />
          <SectionRenderer
            section={section}
            menu={resolveSectionMenuItems(section, menuConfig.main ?? [])}
            selectedId={selectedId}
            reorderable
            sectionIndex={index}
            totalSections={pageConfig.sections.length}
            onReorder={onReorder}
          />
        </div>
      );
    });

    if (reorderable && sections.length > 0) {
      const lastIndex = pageConfig.sections.length;
      const showDropIndicator = dropIndex === lastIndex;
      sections.push(
        <div
          key="jp-drop-after-last"
          data-jp-drop-zone
          style={{
            position: 'relative',
            left: 0,
            right: 0,
            height: 24,
            minHeight: 24,
            zIndex: 55,
            pointerEvents: 'auto',
            backgroundColor: showDropIndicator ? 'rgba(59, 130, 246, 0.4)' : 'transparent',
            borderTop: showDropIndicator ? '2px solid rgb(96, 165, 250)' : '2px solid transparent',
          }}
          onDragOver={(event) => handleDragOver(event, lastIndex)}
          onDragLeave={handleDragLeave}
          onDrop={(event) => handleDrop(event, lastIndex)}
        />
      );
    }

    return sections;
  };

  return (
    <div className="min-h-screen flex flex-col bg-[var(--color-background)]">
      {headerSection != null && (
        <div
          ref={(element) => {
            sectionRefs.current[headerSection.id] = element;
          }}
          data-section-id={headerSection.id}
          onMouseEnter={() => handleSectionHover(headerSection.id)}
        >
          <SectionRenderer
            section={headerSection}
            menu={resolveSectionMenuItems(headerSection, menuConfig.main ?? [])}
            selectedId={selectedId}
          />
        </div>
      )}

      <main className="flex-1">{renderPageSections()}</main>

      {footerSection != null && (
        <div
          ref={(element) => {
            sectionRefs.current[footerSection.id] = element;
          }}
          data-section-id={footerSection.id}
          onMouseEnter={() => handleSectionHover(footerSection.id)}
        >
          <SectionRenderer
            section={footerSection}
            menu={resolveSectionMenuItems(footerSection, menuConfig.main ?? [])}
            selectedId={selectedId}
          />
        </div>
      )}
    </div>
  );
};
