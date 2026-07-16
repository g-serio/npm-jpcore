import React, { useState } from 'react';
import { FileText, ChevronDown, Plus } from 'lucide-react';
import { cn } from '@olonjs/core';
import { Popover, PopoverTrigger, PopoverContent } from '../ui/popover';

export interface PageSelectorProps {
  /** Available page slugs. */
  pageSlugs: string[];
  /** Current page slug. */
  currentSlug: string;
  /** Called when user selects another page. */
  onPageChange: (slug: string) => void;
  /** Optional: show section count per page (e.g. "9s"). Omit to hide. */
  sectionCount?: number;
  /** Optional: when set, shows "New page" and calls this on click. Omit to hide (no dead UI). */
  onNewPage?: () => void;
  /** Optional class for the wrapper (e.g. spacing). */
  className?: string;
  /** Optional: override label for current page (default: capitalized slug). */
  currentPageLabel?: string;
}

const defaultLabel = (slug: string) =>
  slug ? slug.charAt(0).toUpperCase() + slug.slice(1) : 'Select page';

/**
 * Enterprise-grade page switcher: popover trigger + list, a11y, single source of styling.
 * Use in Inspector header when multiple pages exist and onPageChange is provided.
 */
export const PageSelector: React.FC<PageSelectorProps> = ({
  pageSlugs,
  currentSlug,
  onPageChange,
  sectionCount,
  onNewPage,
  className,
  currentPageLabel,
}) => {
  const [open, setOpen] = useState(false);
  const label = currentPageLabel ?? defaultLabel(currentSlug);

  const handlePageSelect = (slug: string) => {
    onPageChange(slug);
    setOpen(false);
  };

  return (
    <div className={cn('mx-3 mt-2 mb-2', className)}>
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <button
            type="button"
            aria-haspopup="listbox"
            aria-label={`Select page, current: ${label}`}
            className={cn(
              'flex items-center gap-2 w-full pl-3 pr-4 py-2 rounded-lg border text-left transition-all duration-150 cursor-pointer',
              'bg-transparent border-zinc-800 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50 hover:border-zinc-700',
              'data-[state=open]:bg-zinc-950 data-[state=open]:border-zinc-800 data-[state=open]:text-zinc-100',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-zinc-950'
            )}
          >
            <FileText size={14} className="shrink-0 text-zinc-500" aria-hidden />
            <span className="text-xs font-medium flex-1 truncate">{label}</span>
            <ChevronDown size={13} className="shrink-0 text-zinc-500" aria-hidden />
          </button>
        </PopoverTrigger>
        <PopoverContent
          align="start"
          sideOffset={4}
          className="min-w-[var(--radix-popover-trigger-width)] bg-zinc-950 border-zinc-800 p-1"
          role="listbox"
          aria-label="Page list"
        >
          {pageSlugs.map((slug) => {
            const isActive = slug === currentSlug;
            const optionLabel = defaultLabel(slug);
            return (
              <button
                key={slug}
                type="button"
                role="option"
                aria-selected={isActive}
                onClick={() => handlePageSelect(slug)}
                className={cn(
                  'flex items-center justify-between w-full px-2.5 py-2 rounded-md text-xs transition-colors cursor-pointer',
                  isActive
                    ? 'bg-primary/10 text-primary font-semibold'
                    : 'text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200'
                )}
              >
                <span>{optionLabel}</span>
                {sectionCount != null && (
                  <span className="text-[10px] text-zinc-600 tabular-nums" aria-hidden>
                    {sectionCount}s
                  </span>
                )}
              </button>
            );
          })}
          {onNewPage != null && (
            <div className="border-t border-zinc-800 mt-1 pt-1">
              <button
                type="button"
                onClick={() => {
                  onNewPage();
                  setOpen(false);
                }}
                className="flex items-center gap-1.5 w-full px-2.5 py-2 rounded-md text-[11px] text-zinc-600 hover:text-zinc-300 hover:bg-zinc-800 transition-colors cursor-pointer"
                aria-label="New page"
              >
                <Plus size={12} aria-hidden />
                <span>New page</span>
              </button>
            </div>
          )}
        </PopoverContent>
      </Popover>
    </div>
  );
};
