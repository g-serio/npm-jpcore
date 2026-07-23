import { describe, expect, it } from 'vitest';
import { applyDevSliceFilters } from './applyDevSliceFilters';

describe('applyDevSliceFilters', () => {
  it('filters collection map entries by $sliceFilter route params (libri/[slug] parity)', () => {
    const authored = {
      sections: [
        {
          data: {
            books: {
              $sliceFilter: {
                'data.authorId': { $routeParam: 'slug' },
              },
            },
          },
        },
      ],
    };

    const resolved = {
      sections: [
        {
          data: {
            books: {
              'book-1': { data: { authorId: 'orwell', title: '1984' } },
              'book-2': { data: { authorId: 'kafka', title: 'Metamorphosis' } },
              'book-3': { data: { authorId: 'orwell', title: 'Animal Farm' } },
            },
          },
        },
      ],
    };

    const filtered = applyDevSliceFilters(resolved, authored, { slug: 'orwell' });
    const books = filtered.sections?.[0]?.data?.books as Record<string, unknown>;
    expect(Object.keys(books).sort()).toEqual(['book-1', 'book-3']);
  });

  it('leaves page unchanged when authored has no $sliceFilter', () => {
    const page = {
      sections: [{ data: { title: 'Hello' } }],
    };
    expect(applyDevSliceFilters(page, { sections: [{ data: { title: 'Hello' } }] }, {})).toEqual(page);
  });
});
