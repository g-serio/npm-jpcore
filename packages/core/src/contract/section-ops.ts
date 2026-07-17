import type { PageConfig, Section } from './kernel';

export function reorderPageSections(
  currentDraft: PageConfig,
  sectionId: string,
  newIndex: number
): PageConfig {
  const sections = [...currentDraft.sections];
  const currentIndex = sections.findIndex((section) => section.id === sectionId);
  if (currentIndex === -1 || newIndex < 0 || newIndex >= sections.length) {
    return currentDraft;
  }

  const [removed] = sections.splice(currentIndex, 1);
  const insertIndex = newIndex > currentIndex ? newIndex - 1 : newIndex;
  sections.splice(Math.min(insertIndex, sections.length), 0, removed);

  return { ...currentDraft, sections };
}

export function appendDraftSection(
  currentDraft: PageConfig,
  sectionType: string,
  defaultData: Record<string, unknown>
): { draft: PageConfig; section: Section } {
  const section: Section = {
    id: crypto.randomUUID(),
    type: sectionType,
    data: defaultData,
    settings: undefined,
  };

  return {
    draft: {
      ...currentDraft,
      sections: [...currentDraft.sections, section],
    },
    section,
  };
}
