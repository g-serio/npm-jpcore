import { useCallback, useState } from 'react';

export interface StudioSelection {
  id: string;
  type: string;
  scope: string;
}

export interface ExpandedSelectionSegment {
  fieldKey: string;
  itemId?: string;
}

export function useStudioSelectionState() {
  const [selected, setSelected] = useState<StudioSelection | null>(null);
  const [expandedItemPath, setExpandedItemPath] = useState<ExpandedSelectionSegment[] | null>(null);
  const [activeSectionId, setActiveSectionId] = useState<string | null>(null);
  const [scrollToSectionId, setScrollToSectionId] = useState<string | null>(null);

  const clearSelection = useCallback(() => {
    setSelected(null);
    setExpandedItemPath(null);
  }, []);

  return {
    activeSectionId,
    clearSelection,
    expandedItemPath,
    scrollToSectionId,
    selected,
    setActiveSectionId,
    setExpandedItemPath,
    setScrollToSectionId,
    setSelected,
  };
}
