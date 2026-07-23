import type { FC } from 'react';
import type { Section, SectionType } from '@/types';
import type { BooksListData } from '@/components/books-list';
import { BooksListView } from '@/components/books-list';
import { ComponentRegistry } from '@/lib/ComponentRegistry';

export type VisitorSectionExtras = {
  authorId?: string | null;
  page?: number;
  pathname?: string;
};

/** Render a resolved page section via the tenant ComponentRegistry (RSC path). */
export function VisitorSection({
  section,
  extras,
}: {
  section: Section;
  extras?: VisitorSectionExtras;
}) {
  if (section.type === 'books-list') {
    return (
      <BooksListView
        data={section.data as BooksListData}
        authorId={extras?.authorId}
        page={extras?.page}
        pathname={extras?.pathname}
      />
    );
  }

  const type = section.type as SectionType;
  const Comp = ComponentRegistry[type];
  if (!Comp) {
    return (
      <section className="px-6 py-8 text-muted-foreground">
        Unknown section type: {String(section.type)}
      </section>
    );
  }

  // Registry Views accept { data, settings? }; cast keeps MTRP map flexible for RSC host.
  const View = Comp as FC<{ data: unknown; settings?: unknown }>;
  return <View data={section.data} settings={section.settings} />;
}
