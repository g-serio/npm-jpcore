import React, { useState } from 'react';
import { Image as ImageIcon, Pencil, Trash2 } from 'lucide-react';
import { Button } from '../../ui/button';
import { Label } from '../../ui/label';
import { cn, resolveAssetUrl } from '@olonjs/core';
import { useStudioAssets } from '../../context/StudioAssetsContext';
import { ImagePickerDialog } from './ImagePickerDialog';
import type { ImageSelection, ImagePreviewFieldProps } from './types';

export const ImagePreviewField: React.FC<ImagePreviewFieldProps> = ({
  value,
  onChange,
  label = 'IMAGE',
  className,
}) => {
  const { tenantId = 'default' } = useStudioAssets();
  const [pickerOpen, setPickerOpen] = useState(false);
  const [hover, setHover] = useState(false);

  const hasImage = Boolean(value?.url);
  const displayUrl = value?.url ? resolveAssetUrl(value.url, tenantId) : '';

  const handleSelect = (img: ImageSelection) => {
    onChange(img);
    setPickerOpen(false);
  };

  const handleRemove = (e: React.MouseEvent) => {
    e.stopPropagation();
    onChange({ url: '', alt: '' });
  };

  return (
    <div className={cn('space-y-1.5', className)}>
      <Label className="text-[9px] uppercase font-black tracking-widest text-zinc-500">
        {label}
      </Label>

      {hasImage ? (
        <div
          role="button"
          tabIndex={0}
          onClick={() => setPickerOpen(true)}
          onKeyDown={(e) => e.key === 'Enter' && setPickerOpen(true)}
          onMouseEnter={() => setHover(true)}
          onMouseLeave={() => setHover(false)}
          className={cn(
            'relative rounded-lg overflow-hidden cursor-pointer',
            'ring-1 ring-zinc-800 transition-all',
            hover && 'ring-blue-500/40'
          )}
        >
          <img
            src={displayUrl}
            alt={value?.alt ?? ''}
            className="w-full h-40 object-cover block"
            onError={(e) => {
              (e.target as HTMLImageElement).style.display = 'none';
            }}
          />
          <div
            className={cn(
              'absolute inset-0 flex items-center justify-center gap-2 transition-all duration-150',
              hover ? 'bg-black/50' : 'bg-black/0'
            )}
          >
            {hover && (
              <>
                <div className="flex items-center gap-1.5 bg-white/15 backdrop-blur-md rounded-lg px-3.5 py-2 text-white text-xs font-medium">
                  <Pencil size={13} />
                  <span>Cambia</span>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  className="h-8 w-8 p-0 bg-red-500/15 backdrop-blur-md text-red-300 hover:text-red-200 hover:bg-red-500/25"
                  onClick={handleRemove}
                >
                  <Trash2 size={13} />
                </Button>
              </>
            )}
          </div>
          <div className="px-2.5 py-1.5 bg-black/50 text-[10px] text-zinc-500 truncate">
            {(value?.url ?? '').length > 50
              ? '…' + (value?.url ?? '').slice(-47)
              : value?.url ?? ''}
          </div>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className={cn(
            'w-full rounded-lg border-2 border-dashed border-zinc-800 py-7',
            'flex flex-col items-center gap-2',
            'bg-white/[0.01] transition-all',
            'hover:border-blue-500/30 hover:bg-blue-500/[0.03]',
            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500'
          )}
        >
          <div className="w-9 h-9 rounded-lg bg-blue-500/10 flex items-center justify-center text-blue-500">
            <ImageIcon size={18} />
          </div>
          <span className="text-xs text-zinc-400 font-medium">
            Clicca per aggiungere un'immagine
          </span>
          <span className="text-[10px] text-zinc-600">Libreria · Upload · URL</span>
        </button>
      )}

      <ImagePickerDialog
        open={pickerOpen}
        onOpenChange={setPickerOpen}
        onSelect={handleSelect}
      />
    </div>
  );
};
