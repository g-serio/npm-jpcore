import type { SelectionPath } from './types-engine';

function appendLeafFieldSegment(
  path: SelectionPath,
  leafFieldKey: string | null
): SelectionPath {
  if (!leafFieldKey) return path;
  const last = path[path.length - 1];
  if (last && last.itemId == null && last.fieldKey === leafFieldKey) return path;
  return [...path, { fieldKey: leafFieldKey }];
}

export function buildSelectionPath(
  root: HTMLElement,
  sectionEl: HTMLElement
): SelectionPath {
  const itemSegments: SelectionPath = [];
  let leafFieldKey: string | null = null;
  let cursor: HTMLElement | null = root;

  while (cursor && cursor !== sectionEl) {
    const itemId = cursor.getAttribute?.('data-jp-item-id');
    const itemFieldKey = cursor.getAttribute?.('data-jp-item-field');
    if (itemId && itemFieldKey) {
      itemSegments.push({ fieldKey: itemFieldKey, itemId });
    }

    if (leafFieldKey == null) {
      const fieldKey = cursor.getAttribute?.('data-jp-field');
      if (fieldKey) leafFieldKey = fieldKey;
    }

    cursor = cursor.parentElement;
  }

  itemSegments.reverse();
  return appendLeafFieldSegment(itemSegments, leafFieldKey);
}
