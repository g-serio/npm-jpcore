/**
 * Add Section Library — tenant-agnostic.
 * Displays a list of section types (from config) and invokes onSelect(type) when one is chosen.
 * Labels come from config.sectionTypeLabels or are derived by humanizing the type id.
 */
import React, { useEffect } from 'react';
import { Layers, X } from 'lucide-react';
import { cn } from '@olonjs/core';

function humanizeTypeId(typeId: string): string {
  return typeId
    .split('-')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

export interface AddSectionLibraryProps {
  open: boolean;
  onClose: () => void;
  /** Section type ids that can be added (e.g. from config.addSection.addableSectionTypes or derived). */
  sectionTypes: string[];
  /** Optional display label per type; falls back to humanized type id. */
  sectionTypeLabels?: Record<string, string>;
  onSelect: (sectionType: string) => void;
}

export const AddSectionLibrary: React.FC<AddSectionLibraryProps> = ({
  open,
  onClose,
  sectionTypes,
  sectionTypeLabels,
  onSelect,
}) => {
  useEffect(() => {
    if (!open) return;
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [open, onClose]);

  if (!open) return null;

  const getLabel = (typeId: string) =>
    sectionTypeLabels?.[typeId] ?? humanizeTypeId(typeId);

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="jp-add-section-title"
    >
      <div
        className="absolute inset-0 bg-zinc-950/80 backdrop-blur-sm"
        onClick={onClose}
        aria-hidden="true"
      />
      <div className="relative w-full max-w-md max-h-[85vh] flex flex-col rounded-xl border border-zinc-700 bg-zinc-900 shadow-2xl overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800 shrink-0">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-blue-500/20 text-blue-400">
              <Layers size={18} />
            </div>
            <h2 id="jp-add-section-title" className="text-sm font-bold text-white">
              Add section
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-md text-zinc-400 hover:text-white hover:bg-zinc-800 transition-colors"
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {sectionTypes.length === 0 ? (
            <p className="text-xs text-zinc-500 text-center py-8">
              No section types available. Configure addableSectionTypes or schemas.
            </p>
          ) : (
            <ul className="grid gap-2" role="listbox">
              {sectionTypes.map((typeId) => (
                <li key={typeId} role="option">
                  <button
                    type="button"
                    onClick={() => {
                      onSelect(typeId);
                      onClose();
                    }}
                    className={cn(
                      'w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left',
                      'border border-zinc-700/80 bg-zinc-800/50',
                      'hover:border-blue-500/40 hover:bg-zinc-800 transition-colors',
                      'focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:ring-offset-2 focus:ring-offset-zinc-900'
                    )}
                  >
                    <span className="flex items-center justify-center w-9 h-9 rounded-md bg-zinc-700/80 text-zinc-400 text-xs font-mono shrink-0">
                      {typeId}
                    </span>
                    <span className="text-sm font-medium text-zinc-200">
                      {getLabel(typeId)}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="px-5 py-3 border-t border-zinc-800 shrink-0">
          <p className="text-[10px] text-zinc-500 uppercase tracking-wider">
            Choose a section type to add to the bottom of this page
          </p>
        </div>
      </div>
    </div>
  );
};
