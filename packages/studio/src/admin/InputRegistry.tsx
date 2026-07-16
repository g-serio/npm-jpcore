import { useState } from 'react';
import { Input } from '../ui/input';
import { Textarea } from '../ui/textarea';
import { Checkbox } from '../ui/checkbox';
import { Label } from '../ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../ui/select';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '../ui/dialog';
import { Button } from '../ui/button';
import {
  ImageIcon,
  type LucideIcon,
} from 'lucide-react';
import { useStudioAssets } from '../context/StudioAssetsContext';
import { BaseWidgetProps } from '../lib/shared-types';
import { cn } from '@olonjs/core';
import { ImagePreviewField } from './image-picker';

const humanizeLabel = (label: string): string =>
  label
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());

export const InputWidgets = {
  'ui:text': ({ label, value, onChange }: BaseWidgetProps<string>) => (
    <div className="grid w-full items-center gap-2 mb-4">
      <Label className="text-[11px] font-semibold tracking-[0.02em] text-zinc-300">
        {humanizeLabel(label)}
      </Label>
      <Input 
        type="text" 
        className="h-9 text-[13px] text-zinc-100 bg-zinc-900/50 border-zinc-700 focus-visible:ring-blue-600"
        value={value || ''} 
        onChange={(e) => onChange(e.target.value)} 
      />
    </div>
  ),

  'ui:textarea': ({ label, value, onChange }: BaseWidgetProps<string>) => (
    <div className="grid w-full gap-2 mb-4">
      <Label className="text-[11px] font-semibold tracking-[0.02em] text-zinc-300">
        {humanizeLabel(label)}
      </Label>
      <Textarea 
        className="min-h-[96px] text-[13px] text-zinc-100 bg-zinc-900/50 border-zinc-700 focus-visible:ring-blue-600 resize-none"
        value={value || ''} 
        onChange={(e) => onChange(e.target.value)} 
      />
    </div>
  ),

  'ui:select': ({ label, value, onChange, options = [] }: BaseWidgetProps<string>) => (
    <div className="grid w-full gap-2 mb-4">
      <Label className="text-[11px] font-semibold tracking-[0.02em] text-zinc-300">
        {humanizeLabel(label)}
      </Label>
      <Select value={value || ""} onValueChange={onChange}>
        <SelectTrigger className="w-full h-9 text-[13px] text-zinc-100 bg-zinc-900/50 border-zinc-700 focus:ring-blue-600">
          <SelectValue placeholder={`Select...`} />
        </SelectTrigger>
        <SelectContent className="dark">
          {options.map((opt) => (
            <SelectItem key={opt} value={opt} className="text-[13px]">
              {opt}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  ),

  'ui:checkbox': ({ label, value, onChange }: BaseWidgetProps<boolean>) => (
    <div className="flex items-center space-x-2 mb-4 p-2.5 rounded border border-zinc-700/60 bg-zinc-900/20">
      <Checkbox 
        id={label} 
        checked={!!value} 
        onCheckedChange={(checked) => onChange(checked === true)} 
      />
      <Label 
        htmlFor={label} 
        className="text-[13px] font-medium cursor-pointer select-none text-zinc-200"
      >
        {humanizeLabel(label)}
      </Label>
    </div>
  ),

  'ui:image-picker': ({ label, value, onChange }: BaseWidgetProps<unknown>) => {
    const selection: { url: string; alt: string } =
      value != null && typeof value === 'object' && 'url' in value
        ? {
            url: String((value as { url?: unknown }).url ?? ''),
            alt: String((value as { alt?: unknown }).alt ?? ''),
          }
        : { url: typeof value === 'string' ? value : '', alt: '' };

    const handleChange = (next: { url: string; alt: string }) => {
      onChange(next);
    };

    return (
      <div className="mb-4">
        <ImagePreviewField
          label={label}
          value={selection}
          onChange={handleChange}
        />
      </div>
    );
  },

  'ui:icon-picker': ({ label, value, onChange }: BaseWidgetProps<string>) => {
    const [open, setOpen] = useState(false);
    const { icons: tenantIcons } = useStudioAssets();
    const options: { name: string; Icon: LucideIcon }[] =
      Object.entries(tenantIcons).map(([name, Icon]) => ({ name, Icon }));
    const selected = options.find((o) => o.name === (value || ''));

    return (
      <div className="grid w-full gap-1.5 mb-4">
        <Label className="text-[9px] uppercase font-black tracking-widest text-zinc-500">
          {label}
        </Label>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button
              variant="outline"
              className="w-full h-9 rounded-md border border-zinc-800 bg-zinc-900/50 hover:bg-zinc-800/50 flex items-center gap-2 text-left"
            >
              {selected ? (
                <>
                  <selected.Icon size={16} className="text-zinc-400 shrink-0" />
                  <span className="text-[11px] text-zinc-300 capitalize truncate">{selected.name}</span>
                </>
              ) : (
                <>
                  <ImageIcon size={16} className="text-zinc-500 shrink-0" />
                  <span className="text-[11px] text-zinc-500">Choose icon...</span>
                </>
              )}
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[280px] p-4">
            <DialogHeader>
              <DialogTitle className="text-sm">Choose icon</DialogTitle>
              <DialogDescription className="text-xs">
                Click an icon to select it.
              </DialogDescription>
            </DialogHeader>
            <div className="grid grid-cols-5 gap-2 py-2">
              {options.map(({ name, Icon }) => (
                <button
                  key={name}
                  type="button"
                  onClick={() => {
                    onChange(name);
                    setOpen(false);
                  }}
                  className={cn(
                    'flex items-center justify-center w-10 h-10 rounded-md border transition-colors',
                    value === name
                      ? 'border-blue-500 bg-blue-500/20 text-blue-400'
                      : 'border-zinc-800 bg-zinc-900/50 hover:bg-zinc-800/50 text-zinc-400 hover:text-zinc-200'
                  )}
                  title={name}
                >
                  <Icon size={20} />
                </button>
              ))}
            </div>
          </DialogContent>
        </Dialog>
      </div>
    );
  },
} as const;

export type WidgetType = keyof typeof InputWidgets;
