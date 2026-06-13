import React from 'react';
import { z } from 'zod';
import { InputWidgets, WidgetType } from './InputRegistry';
import { Plus, Trash2, ChevronDown, ChevronUp, ArrowUp, ArrowDown } from 'lucide-react';
import { BaseWidgetProps } from '../../lib/shared-types';

/**
 * 🛠️ HELPER: Generates a default value based on the Zod schema.
 * 🛡️ FIX: Now injects a deterministic UUID for every object created.
 */
const generateDefaultValue = (schema: z.ZodTypeAny): unknown => {
  if (schema instanceof z.ZodOptional || schema instanceof z.ZodDefault) {
    return generateDefaultValue(schema._def.innerType);
  }
  
  if (schema instanceof z.ZodObject) {
    // Inizializziamo l'oggetto con un ID univoco per la stabilità di React
    const obj: Record<string, unknown> = {
      id: crypto.randomUUID() 
    };
    
    for (const key in schema.shape) {
      // Se lo schema ha già un campo ID, non lo sovrascriviamo qui, 
      // lasciamo che venga processato normalmente se ha un default.
      if (key === 'id') continue;
      obj[key] = generateDefaultValue(schema.shape[key]);
    }
    return obj;
  }
  
  if (schema instanceof z.ZodArray) return [];
  if (schema instanceof z.ZodString) return "";
  if (schema instanceof z.ZodNumber) return 0;
  if (schema instanceof z.ZodBoolean) return false;
  if (schema instanceof z.ZodEnum) return schema._def.values[0];
  return null;
};

/**
 * 🛠️ HELPER: Extracts the real schema ignoring Zod wrappers.
 */
const getEffectiveSchema = (schema: z.ZodTypeAny): z.ZodTypeAny => {
  if (schema instanceof z.ZodOptional || schema instanceof z.ZodDefault || schema instanceof z.ZodNullable) {
    return getEffectiveSchema(schema._def.innerType);
  }
  return schema;
};

const getUiHint = (schema: z.ZodTypeAny): string | null => {
  const raw = schema as z.ZodTypeAny & { _def?: { description?: unknown } };
  if (typeof schema.description === 'string' && schema.description.length > 0) {
    return schema.description;
  }
  if (typeof raw._def?.description === 'string' && raw._def.description.length > 0) {
    return raw._def.description;
  }
  const effective = getEffectiveSchema(schema);
  if (effective !== schema) {
    return getUiHint(effective);
  }
  return null;
};

interface FormFactoryProps {
  schema: z.ZodObject<z.ZodRawShape>;
  data: Record<string, unknown>;
  onChange: (newData: Record<string, unknown>) => void;
  /** When set, only render fields whose key is in this array (e.g. Content vs Settings tabs). */
  keys?: string[] | null;
  /** Root-to-leaf path for deep focus (e.g. silos -> blocks). First segment applies to this level. */
  expandedItemPath?: Array<{ fieldKey: string; itemId?: string }> | null;
  /** Called when user expands/collapses an array item in the sidebar (so parent can drive fade). */
  onSidebarExpandedItemChange?: (item: { fieldKey: string; itemId?: string } | null) => void;
}

/**
 * 🏭 POLYMORPHIC FORM FACTORY (V2.8.0)
 * Governance through deterministic IDs.
 */
const fadeWhenUnfocused = (inItemScope: boolean, isFocused: boolean) =>
  inItemScope && !isFocused ? 'opacity-10' : 'opacity-100';

/** Match canvas-sent field key to schema key (e.g. "badge" vs "BADGE", "titleHighlight" vs "TITLEHIGHLIGHT"). */
const fieldKeyMatches = (focusedKey: string | null | undefined, schemaKey: string) =>
  focusedKey != null && schemaKey.toLowerCase() === focusedKey.toLowerCase();

const humanizeLabel = (label: string): string =>
  label
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase());

const getCollectionRefItemCount = (value: unknown): number => {
  if (Array.isArray(value)) return value.length;
  if (value != null && typeof value === 'object') return Object.keys(value).length;
  return 0;
};

export const FormFactory: React.FC<FormFactoryProps> = ({ schema, data, onChange, keys, expandedItemPath, onSidebarExpandedItemChange }) => {
  const shape = schema.shape;
  const fieldKeys = keys != null
    ? Object.keys(shape).filter((k) => keys.includes(k))
    : Object.keys(shape);
  const firstSeg = expandedItemPath?.[0];
  const effectiveFocusedFieldKey = firstSeg?.fieldKey ?? null;
  const inItemScope = effectiveFocusedFieldKey != null;

  return (
    <div className="space-y-4">
      {fieldKeys.map((key) => {
        const fieldSchema = shape[key];
        if (!fieldSchema) return null;

        const effectiveSchema = getEffectiveSchema(fieldSchema);
        const uiHint = getUiHint(fieldSchema) || 'ui:text';
        const value = data[key];

        // Editorial fields are edited directly on Stage and not in Inspector form.
        if (uiHint === 'ui:editorial-markdown') return null;

        if (uiHint === 'ui:collection-ref') {
          const isFocusedField = fieldKeyMatches(effectiveFocusedFieldKey, key);
          const itemCount = getCollectionRefItemCount(value);
          return (
            <div
              key={key}
              className={`rounded-lg border border-zinc-800 bg-zinc-900/30 p-4 transition-opacity duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
              {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
            >
              <div className="flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-[11px] font-semibold tracking-[0.04em] text-zinc-300">
                    {humanizeLabel(key)}
                  </p>
                  <p className="mt-1 text-[11px] leading-relaxed text-zinc-500">
                    Externally bound collection. The page keeps its reference; entity data is owned by the collection document.
                  </p>
                </div>
                <span className="shrink-0 rounded-full border border-zinc-700 px-2 py-1 text-[10px] font-semibold text-zinc-400">
                  {itemCount} items
                </span>
              </div>
            </div>
          );
        }

        // 0. IMAGE PICKER: object value but single widget (no nested form)
        if (uiHint === 'ui:image-picker' && effectiveSchema instanceof z.ZodObject) {
          const isFocusedField = fieldKeyMatches(effectiveFocusedFieldKey, key);
          const Widget = (InputWidgets['ui:image-picker'] || InputWidgets['ui:text']) as React.ComponentType<BaseWidgetProps<unknown>>;
          return (
            <div
              key={key}
              className={`transition-opacity duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
              {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
            >
              <Widget
                label={key}
                value={value}
                onChange={(val) => onChange({ ...data, [key]: val })}
              />
            </div>
          );
        }

        // 1. OBJECT HANDLING
        if (effectiveSchema instanceof z.ZodObject) {
          const objectData = (value as Record<string, unknown>) || {};
          const isFocusedField = fieldKeyMatches(effectiveFocusedFieldKey, key);
          return (
            <div
              key={key}
              className={`group/obj mb-6 p-4 border border-zinc-800 rounded-lg bg-zinc-900/20 hover:border-zinc-700 transition-[border-color,opacity] duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
              {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
            >
              <div className="flex items-center gap-2 mb-4">
                <div className="w-1 h-3 bg-blue-500 rounded-full" />
                <h4 className="text-[11px] font-semibold text-zinc-300 tracking-[0.02em]">
                  {humanizeLabel(key)}
                </h4>
              </div>
              <FormFactory 
                schema={effectiveSchema} 
                data={objectData} 
                onChange={(val) => onChange({ ...data, [key]: val })}
                expandedItemPath={expandedItemPath && fieldKeyMatches(firstSeg?.fieldKey, key) ? expandedItemPath.slice(1) : undefined}
              />
            </div>
          );
        }

        // 2. ARRAY HANDLING
        if (effectiveSchema instanceof z.ZodArray) {
          const items = (Array.isArray(value) ? value : []) as unknown[];
          const itemSchema = getEffectiveSchema(effectiveSchema.element);

          const moveItem = (from: number, to: number) => {
            if (to < 0 || to >= items.length) return;
            const newItems = [...items];
            const [removed] = newItems.splice(from, 1);
            newItems.splice(to, 0, removed);
            onChange({ ...data, [key]: newItems });
          };

          const isFocusedField = fieldKeyMatches(effectiveFocusedFieldKey, key);
          const openItemIdFromPath = fieldKeyMatches(firstSeg?.fieldKey, key) ? firstSeg?.itemId : undefined;
          const effectiveOpenItemId = openItemIdFromPath;
          return (
            <div
              key={key}
              className={`mb-8 transition-opacity duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
              {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
            >
              <div className="flex items-center justify-between mb-3">
                <label className="text-[12px] font-semibold text-zinc-300 tracking-[0.01em]">
                  {humanizeLabel(key)} ({items.length})
                </label>
                <button 
                  type="button"
                  onClick={() => {
                    const newItem = generateDefaultValue(itemSchema);
                    onChange({ ...data, [key]: [...items, newItem] });
                  }}
                  className="flex items-center gap-1 px-2.5 py-1.5 bg-blue-600/10 hover:bg-blue-600/20 text-blue-400 rounded text-[11px] font-semibold transition-colors"
                >
                  <Plus size={12} /> Add Item
                </button>
              </div>

              <div className="space-y-2">
                {items.map((item, index) => {
                  const itemRecord = item as Record<string, unknown>;
                  
                  // 🛡️ STABLE KEY STRATEGY:
                  // Prioritizziamo l'ID dell'oggetto. Se manca (dati legacy), 
                  // usiamo l'indice ma con un prefisso per evitare collisioni.
                  const stableKey = (itemRecord.id as string) || `legacy-${index}`;

                  const itemTitle = 
                    (typeof itemRecord.title === 'string' ? itemRecord.title : null) || 
                    (typeof itemRecord.label === 'string' ? itemRecord.label : null) || 
                    (typeof itemRecord.name === 'string' ? itemRecord.name : null) || 
                    (typeof itemRecord.content === 'string' ? itemRecord.content : null) || 
                    (typeof itemRecord.text === 'string' ? itemRecord.text : null) || 
                    `${humanizeLabel(key)} #${index + 1}`;

                  const openItemId = effectiveOpenItemId;
                  const itemIdStr = String(itemRecord.id ?? stableKey);
                  const isExpandedItem = openItemId != null && String(openItemId) === itemIdStr;
                  const pathTail =
                    isExpandedItem && expandedItemPath && expandedItemPath.length > 1 ? expandedItemPath.slice(1) : undefined;
                  const isFadedItem = inItemScope && isFocusedField && openItemId != null && !isExpandedItem;
                  return (
                    <ArrayItemWrapper 
                      key={stableKey} 
                      itemId={itemIdStr}
                      openItemId={openItemId != null ? String(openItemId) : undefined}
                      isFaded={isFadedItem}
                      index={index}
                      isFirst={index === 0}
                      isLast={index === items.length - 1}
                      label={itemTitle}
                      onExpandedChange={onSidebarExpandedItemChange ? (open) => onSidebarExpandedItemChange(open ? { fieldKey: key, itemId: itemIdStr } : null) : undefined}
                      onRemove={() => {
                        const newItems = items.filter((_, i) => i !== index);
                        onChange({ ...data, [key]: newItems });
                      }}
                      onMoveUp={() => moveItem(index, index - 1)}
                      onMoveDown={() => moveItem(index, index + 1)}
                    >
                      {itemSchema instanceof z.ZodObject ? (
                        <FormFactory 
                          schema={itemSchema} 
                          data={itemRecord || {}}
                          expandedItemPath={pathTail}
                          onChange={(val) => {
                            const newItems = [...items];
                            newItems[index] = val;
                            onChange({ ...data, [key]: newItems });
                          }}
                        />
                      ) : (
                        <div className="text-[10px] text-red-400">Primitive arrays not supported.</div>
                      )}
                    </ArrayItemWrapper>
                  );
                })}
              </div>
            </div>
          );
        }

        // 3. ATOMIC WIDGET HANDLING
        const widgetKey: WidgetType =
          uiHint in InputWidgets ? (uiHint as WidgetType) : 'ui:text';
        const Widget = (InputWidgets[widgetKey] || InputWidgets['ui:text']) as React.ComponentType<BaseWidgetProps>;
        const options = effectiveSchema instanceof z.ZodEnum ? (effectiveSchema._def.values as string[]) : undefined;
        const isFocusedField = fieldKeyMatches(effectiveFocusedFieldKey, key);

        return (
          <div
            key={key}
            className={`transition-opacity duration-200 ${fadeWhenUnfocused(inItemScope, isFocusedField)}`}
            {...(isFocusedField ? { 'data-jp-focused-field': key } : {})}
          >
            <Widget 
              label={key}
              value={value}
              options={options}
              onChange={(val) => onChange({ ...data, [key]: val })}
            />
          </div>
        );
      })}
    </div>
  );
};

interface ArrayItemWrapperProps {
  itemId: string;
  /** When this matches itemId, the item is expanded (e.g. after clicking it on the Stage). */
  openItemId?: string | null;
  /** When true, fade this row (other items in the same array when one is focused). */
  isFaded?: boolean;
  index: number;
  isFirst: boolean;
  isLast: boolean;
  label: string;
  /** Called when user toggles open/close (so parent can drive fade). */
  onExpandedChange?: (open: boolean) => void;
  onRemove: () => void;
  onMoveUp: () => void;
  onMoveDown: () => void;
  children: React.ReactNode;
}

const ArrayItemWrapper: React.FC<ArrayItemWrapperProps> = ({ 
  itemId,
  openItemId,
  isFaded = false,
  label, 
  onExpandedChange,
  onRemove, 
  onMoveUp, 
  onMoveDown, 
  isFirst, 
  isLast, 
  children 
}) => {
  const shouldOpen = openItemId != null && String(openItemId) === String(itemId);
  const [isOpen, setIsOpen] = React.useState(shouldOpen);
  // Only sync from path/canvas when this array level has an openItemId. Otherwise nested lists
  // (e.g. header menu → children) get shouldOpen false for every row and the effect would
  // immediately undo a manual chevron toggle.
  React.useEffect(() => {
    if (openItemId == null) return;
    if (shouldOpen && !isOpen) setIsOpen(true);
    if (!shouldOpen && isOpen) setIsOpen(false);
  }, [openItemId, shouldOpen, isOpen]);

  const handleToggle = () => {
    const next = !isOpen;
    setIsOpen(next);
    onExpandedChange?.(next);
  };

  const isExpandedTarget = shouldOpen && isOpen;
  return (
    <div
      className={`border border-zinc-800 rounded-md bg-zinc-900/40 overflow-hidden transition-opacity duration-200 ${isFaded ? 'opacity-10' : 'opacity-100'}`}
      {...(isExpandedTarget ? { 'data-jp-expanded-item': itemId } : {})}
    >
      <div className="flex items-center justify-between px-3 py-2 bg-zinc-900/60">
        <div className="flex items-center gap-2 flex-1 min-w-0">
          <button 
            type="button"
            onClick={handleToggle}
            className="flex items-center gap-2 text-[12px] font-semibold text-zinc-200 tracking-[0.01em] truncate"
          >
            {isOpen ? <ChevronUp size={12} className="shrink-0" /> : <ChevronDown size={12} className="shrink-0" />}
            <span className="truncate">{label}</span>
          </button>
        </div>
        
        <div className="flex items-center gap-1 shrink-0 ml-2">
          <button 
            type="button"
            disabled={isFirst}
            onClick={onMoveUp}
            className="text-zinc-500 hover:text-blue-400 disabled:opacity-20 p-1 transition-colors"
          >
            <ArrowUp size={12} />
          </button>
          <button 
            type="button"
            disabled={isLast}
            onClick={onMoveDown}
            className="text-zinc-500 hover:text-blue-400 disabled:opacity-20 p-1 transition-colors"
          >
            <ArrowDown size={12} />
          </button>
          <div className="w-px h-3 bg-zinc-800 mx-1" />
          <button 
            type="button"
            onClick={onRemove}
            className="text-zinc-600 hover:text-red-500 transition-colors p-1"
          >
            <Trash2 size={12} />
          </button>
        </div>
      </div>
      {isOpen && (
        <div className="p-4 border-t border-zinc-800 bg-black/20">
          {children}
        </div>
      )}
    </div>
  );
};
