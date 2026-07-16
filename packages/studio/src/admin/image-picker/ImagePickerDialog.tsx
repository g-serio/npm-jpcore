import React, { useState, useRef, useCallback, useEffect } from 'react';
import {
  Image as ImageIcon,
  Upload,
  Link2,
  Search,
  Check,
  Trash2,
  X,
} from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '../../ui/dialog';
import { Button } from '../../ui/button';
import { Input } from '../../ui/input';
import { Label } from '../../ui/label';
import {
  cn,
  isCanonicalAssetUrl,
  resolveAssetUrl,
  type LibraryImageEntry,
} from '@olonjs/core';
import { useStudioAssets } from '../../context/StudioAssetsContext';
import type { ImageSelection } from './types';

const TABS = ['library', 'upload', 'url'] as const;
type TabId = (typeof TABS)[number];

interface UploadPreview {
  name: string;
  size: number;
  previewSrc: string;
  finalUrl?: string;
  isPersistent: boolean;
}

interface ImagePickerDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSelect: (image: ImageSelection) => void;
}

function LibraryTab({
  library,
  selectedId,
  onSelect,
}: {
  library: LibraryImageEntry[];
  selectedId: string | null;
  onSelect: (id: string | null) => void;
}) {
  const [search, setSearch] = useState('');
  const [activeTag, setActiveTag] = useState('all');
  const tags = ['all', ...new Set(library.flatMap((img) => img.tags ?? []))];

  const filtered = library.filter((img) => {
    const matchTag = activeTag === 'all' || (img.tags ?? []).includes(activeTag);
    const matchSearch =
      !search || (img.alt ?? '').toLowerCase().includes(search.toLowerCase());
    return matchTag && matchSearch;
  });

  return (
    <div className="space-y-4">
      <div className="relative">
        <Search
          size={14}
          className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-600 pointer-events-none"
        />
        <Input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Cerca immagini..."
          className="pl-9 h-8 text-xs bg-zinc-900/50 border-zinc-800"
        />
      </div>
      <div className="flex flex-wrap gap-1.5">
        {tags.map((tag) => (
          <button
            key={tag}
            type="button"
            onClick={() => setActiveTag(tag)}
            className={cn(
              'px-2.5 py-1 rounded text-[10px] font-medium border transition-colors',
              activeTag === tag
                ? 'border-blue-500 bg-blue-500/20 text-blue-400'
                : 'border-zinc-700 text-zinc-500 hover:border-zinc-600 hover:text-zinc-400'
            )}
          >
            {tag === 'all' ? 'Tutte' : tag}
          </button>
        ))}
      </div>
      {filtered.length > 0 ? (
        <div className="grid grid-cols-3 gap-2.5 max-h-[45vh] overflow-y-auto">
          {filtered.map((img) => {
            const isSelected = selectedId === img.id;
            return (
              <button
                key={img.id}
                type="button"
                onClick={() => onSelect(isSelected ? null : img.id)}
                className={cn(
                  'group relative aspect-[4/3] rounded-lg overflow-hidden',
                  'ring-1 transition-all duration-150',
                  isSelected
                    ? 'ring-blue-500 ring-2 ring-offset-1 ring-offset-zinc-900'
                    : 'ring-zinc-800 hover:ring-zinc-600 hover:scale-[1.02]'
                )}
              >
                <img
                  src={img.url}
                  alt={img.alt}
                  loading="lazy"
                  className={cn(
                    'w-full h-full object-cover transition-[filter] duration-150',
                    isSelected ? 'brightness-[0.6]' : 'brightness-[0.85] group-hover:brightness-100'
                  )}
                />
                <div
                  className={cn(
                    'absolute inset-x-0 bottom-0 px-2 py-1.5',
                    'bg-gradient-to-t from-black/70 to-transparent',
                    'opacity-0 group-hover:opacity-100 transition-opacity',
                    isSelected && 'opacity-100'
                  )}
                >
                  <span className="text-[10px] text-white font-medium leading-tight line-clamp-2">
                    {img.alt}
                  </span>
                </div>
                {isSelected && (
                  <div className="absolute top-2 right-2 w-6 h-6 rounded-full bg-blue-600 flex items-center justify-center">
                    <Check size={14} className="text-white" />
                  </div>
                )}
              </button>
            );
          })}
        </div>
      ) : (
        <div className="text-center py-12 text-zinc-600 text-xs">
          Nessuna immagine in libreria. Configura assets.assetsManifest nel tenant (es. da public/assets).
        </div>
      )}
    </div>
  );
}

function UploadTab({
  preview,
  onPreviewChange,
  onAssetUpload,
  tenantId,
}: {
  preview: UploadPreview | null;
  onPreviewChange: (p: UploadPreview | null) => void;
  onAssetUpload?: (file: File) => Promise<string>;
  tenantId: string;
}) {
  const [dragOver, setDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFile = useCallback(
    async (file: File) => {
      if (!file.type.startsWith('image/')) return;
      if (onAssetUpload) {
        try {
          const url = await onAssetUpload(file);
          const finalUrl = isCanonicalAssetUrl(url) ? url : undefined;
          onPreviewChange({
            name: file.name,
            size: file.size,
            previewSrc: resolveAssetUrl(url, tenantId),
            finalUrl,
            isPersistent: finalUrl != null,
          });
        } catch {
          const reader = new FileReader();
          reader.onload = (e) => {
            onPreviewChange({
              name: file.name,
              size: file.size,
              previewSrc: e.target?.result as string,
              isPersistent: false,
            });
          };
          reader.readAsDataURL(file);
        }
        return;
      }
      const reader = new FileReader();
      reader.onload = (e) => {
        onPreviewChange({
          name: file.name,
          size: file.size,
          previewSrc: e.target?.result as string,
          isPersistent: false,
        });
      };
      reader.readAsDataURL(file);
    },
    [onPreviewChange, onAssetUpload, tenantId]
  );

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      e.stopPropagation();
      setDragOver(false);
      const file = e.dataTransfer?.files?.[0];
      if (file) handleFile(file);
    },
    [handleFile]
  );

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragOver(true);
  }, []);

  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      if (file) handleFile(file);
    },
    [handleFile]
  );

  return (
    <div className="space-y-3">
      <div
        onDragOver={handleDragOver}
        onDragEnter={handleDragOver}
        onDragLeave={(e) => {
          e.preventDefault();
          e.stopPropagation();
          setDragOver(false);
        }}
        onDrop={handleDrop}
        onClick={() => !preview && fileInputRef.current?.click()}
        className={cn(
          'rounded-xl border-2 border-dashed transition-all min-h-[240px]',
          'flex flex-col items-center justify-center overflow-hidden cursor-pointer relative',
          dragOver
            ? 'border-blue-500/50 bg-blue-500/[0.04]'
            : preview
              ? 'border-zinc-800 bg-transparent cursor-default'
              : 'border-zinc-800 bg-white/[0.01] hover:border-zinc-600 hover:bg-white/[0.02]'
        )}
      >
      {preview ? (
        <>
          <img
            src={preview.previewSrc}
            alt="Upload preview"
            className="w-full max-h-[320px] object-contain"
          />
          <div className="absolute bottom-0 inset-x-0 bg-gradient-to-t from-black/80 to-transparent p-4 flex items-center justify-between">
            <div>
              <p className="text-xs font-medium text-white">{preview.name}</p>
              <p className="text-[10px] text-zinc-400">
                {(preview.size / 1024).toFixed(1)} KB
              </p>
            </div>
            <Button
              type="button"
              variant="ghost"
              className="text-zinc-400 hover:text-red-400 hover:bg-red-500/10 h-8 w-8 p-0"
              onClick={(e) => {
                e.stopPropagation();
                onPreviewChange(null);
              }}
            >
              <Trash2 size={14} />
            </Button>
          </div>
        </>
      ) : (
        <>
          <div className="w-12 h-12 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-500 mb-3">
            <Upload size={22} />
          </div>
          <p className="text-sm font-medium text-white mb-1">
            Trascina un&apos;immagine qui
          </p>
          <p className="text-[11px] text-zinc-500 mb-3">
            oppure clicca per selezionare un file
          </p>
          <span className="text-[10px] text-zinc-600 bg-white/[0.03] px-3 py-1 rounded">
            PNG, JPG, WebP — max 5MB
          </span>
        </>
      )}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handleInputChange}
        />
      </div>
      {preview != null && !preview.isPersistent && (
        <p
          role="alert"
          className="rounded-lg border border-amber-500/25 bg-amber-500/10 px-3 py-2 text-[11px] text-amber-200"
        >
          Upload non persistito: serve un URL asset canonico per inserire l&apos;immagine.
        </p>
      )}
    </div>
  );
}

function UrlTab({
  urlPreview,
  onUrlPreviewChange,
}: {
  urlPreview: string | null;
  onUrlPreviewChange: (url: string | null) => void;
}) {
  const [urlInput, setUrlInput] = useState('');
  const [error, setError] = useState(false);

  const handleCheck = () => {
    if (!urlInput.trim()) return;
    try {
      new URL(urlInput);
      onUrlPreviewChange(urlInput);
      setError(false);
    } catch {
      setError(true);
      onUrlPreviewChange(null);
    }
  };

  return (
    <div className="space-y-4">
      <div>
        <Label className="block text-[10px] font-bold uppercase tracking-[0.08em] text-zinc-500 mb-1.5">
          URL immagine
        </Label>
        <div className="flex gap-2">
          <Input
            value={urlInput}
            onChange={(e) => {
              setUrlInput(e.target.value);
              setError(false);
            }}
            onKeyDown={(e) => e.key === 'Enter' && handleCheck()}
            placeholder="https://images.unsplash.com/photo-..."
            className={cn('h-8 text-xs bg-zinc-900/50 border-zinc-800', error && 'border-red-500/50')}
          />
          <Button type="button" variant="outline" onClick={handleCheck} className="shrink-0 h-8">
            Anteprima
          </Button>
        </div>
        {error && (
          <p className="text-[11px] text-red-400 mt-1.5">
            URL non valido. Inserisci un URL completo (https://…)
          </p>
        )}
      </div>
      {urlPreview ? (
        <div className="rounded-lg overflow-hidden ring-1 ring-zinc-800">
          <img
            src={urlPreview}
            alt="URL preview"
            className="w-full max-h-[320px] object-contain bg-black/30"
            onError={() => {
              setError(true);
              onUrlPreviewChange(null);
            }}
          />
          <div className="px-3.5 py-2.5 bg-white/[0.02] border-t border-zinc-800 flex items-center gap-2">
            <Check size={14} className="text-emerald-400" />
            <span className="text-[11px] text-zinc-500">Immagine caricata correttamente</span>
          </div>
        </div>
      ) : !error ? (
        <div className="flex flex-col items-center py-12 text-zinc-600">
          <Link2 size={32} className="mb-3 opacity-40" />
          <p className="text-xs">Incolla un URL e premi Anteprima per verificare</p>
        </div>
      ) : null}
    </div>
  );
}

export const ImagePickerDialog: React.FC<ImagePickerDialogProps> = ({
  open,
  onOpenChange,
  onSelect,
}) => {
  const { assets, tenantId = 'default' } = useStudioAssets();
  const library = assets?.assetsManifest ?? [];
  const [tab, setTab] = useState<TabId>('library');
  const [selectedLibraryId, setSelectedLibraryId] = useState<string | null>(null);
  const [uploadPreview, setUploadPreview] = useState<UploadPreview | null>(null);
  const [urlPreview, setUrlPreview] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setTab('library');
      setSelectedLibraryId(null);
      setUploadPreview(null);
      setUrlPreview(null);
    }
  }, [open]);

  // Prevent browser default (navigate to file = full page reload) when Upload tab is open. Capture only, no stopPropagation, so drop still reaches the zone.
  useEffect(() => {
    if (!open || tab !== 'upload') return;
    const prevent = (e: DragEvent) => {
      e.preventDefault();
    };
    const opts = { capture: true } as AddEventListenerOptions;
    document.addEventListener('dragover', prevent, opts);
    document.addEventListener('drop', prevent, opts);
    window.addEventListener('dragover', prevent, opts);
    window.addEventListener('drop', prevent, opts);
    return () => {
      document.removeEventListener('dragover', prevent, opts);
      document.removeEventListener('drop', prevent, opts);
      window.removeEventListener('dragover', prevent, opts);
      window.removeEventListener('drop', prevent, opts);
    };
  }, [open, tab]);

  const canConfirm =
    (tab === 'library' && selectedLibraryId != null) ||
    (tab === 'upload' && uploadPreview?.isPersistent === true && uploadPreview.finalUrl != null) ||
    (tab === 'url' && urlPreview != null);

  const handleConfirm = () => {
    if (tab === 'library' && selectedLibraryId) {
      const img = library.find((i) => i.id === selectedLibraryId);
      if (img) onSelect({ url: img.url, alt: img.alt });
    } else if (tab === 'upload' && uploadPreview?.isPersistent && uploadPreview.finalUrl) {
      onSelect({
        url: uploadPreview.finalUrl,
        alt: uploadPreview.name,
      });
    } else if (tab === 'url' && urlPreview) {
      onSelect({ url: urlPreview, alt: '' });
    }
    // Defer close so parent state (section draft) is committed and Stage re-renders before modal unmounts
    setTimeout(() => onOpenChange(false), 0);
  };

  const statusLabel =
    tab === 'library' && selectedLibraryId
      ? '1 immagine selezionata'
      : tab === 'upload' && uploadPreview
        ? uploadPreview.isPersistent
          ? uploadPreview.name
          : 'Upload non persistito'
        : tab === 'url' && urlPreview
          ? 'URL pronto'
          : 'Nessuna selezione';

  // Drag-and-drop reload fix: prevent browser from navigating to dropped file (would cause full page reload).
  // Backdrop (dialog.tsx) and modal content both block drop; document-level listener (when Upload tab) prevents default only so drop still reaches the zone.
  const blockDropNavigation = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className="max-w-2xl p-0 gap-0 max-h-[90vh] flex flex-col"
        preventCloseOnBackdropClick={tab === 'upload'}
        onDragOver={blockDropNavigation}
        onDrop={blockDropNavigation}
      >
        <DialogHeader className="px-5 py-4 flex flex-row items-start justify-between gap-4 border-b border-zinc-800">
          <div className="flex items-center gap-3">
            <div className="p-1.5 rounded-lg bg-blue-500/15 text-blue-500">
              <ImageIcon size={18} />
            </div>
            <div>
              <DialogTitle>Image Picker</DialogTitle>
              <DialogDescription>
                Scegli dalla libreria, carica dal disco o inserisci un link
              </DialogDescription>
            </div>
          </div>
          <button
            type="button"
            onClick={() => onOpenChange(false)}
            className="p-1.5 rounded text-zinc-500 hover:text-white hover:bg-zinc-800 transition-colors"
            aria-label="Chiudi"
          >
            <X size={18} />
          </button>
        </DialogHeader>

        <div className="flex border-b border-zinc-800">
          {TABS.map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setTab(t)}
              className={cn(
                'flex items-center gap-2 px-4 py-3 text-xs font-medium border-b-2 transition-colors',
                tab === t
                  ? 'border-blue-500 text-blue-400'
                  : 'border-transparent text-zinc-500 hover:text-zinc-300'
              )}
            >
              {t === 'library' && <ImageIcon size={14} />}
              {t === 'upload' && <Upload size={14} />}
              {t === 'url' && <Link2 size={14} />}
              {t === 'library' ? 'Libreria' : t === 'upload' ? 'Upload' : 'URL'}
            </button>
          ))}
        </div>

        <div className="flex-1 overflow-y-auto p-5 min-h-0">
          {tab === 'library' && (
            <LibraryTab
              library={library}
              selectedId={selectedLibraryId}
              onSelect={setSelectedLibraryId}
            />
          )}
          {tab === 'upload' && (
            <UploadTab
              preview={uploadPreview}
              onPreviewChange={setUploadPreview}
              onAssetUpload={assets?.onAssetUpload}
              tenantId={tenantId}
            />
          )}
          {tab === 'url' && (
            <UrlTab
              urlPreview={urlPreview}
              onUrlPreviewChange={setUrlPreview}
            />
          )}
        </div>

        <DialogFooter className="px-5 py-4 border-t border-zinc-800 flex-row justify-between">
          <span className="text-[10px] uppercase tracking-[0.05em] text-zinc-600">
            {statusLabel}
          </span>
          <div className="flex gap-2">
            <Button type="button" variant="outline" size="sm" onClick={() => onOpenChange(false)}>
              Annulla
            </Button>
            <Button
              type="button"
              size="sm"
              disabled={!canConfirm}
              onClick={handleConfirm}
              className={cn(!canConfirm && 'opacity-40')}
            >
              Inserisci immagine
            </Button>
          </div>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};
