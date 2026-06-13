import { useEffect, useMemo, useState } from 'react';
import { useLocation } from 'react-router-dom';
import type { Libro } from '@/collections/libri';
import type { BooksListData } from './types';

type BooksListViewProps = {
  data: BooksListData;
};

function toBooks(items: BooksListData['items']): Libro[] {
  return Object.values(items ?? {}).sort((a, b) => a.title.localeCompare(b.title));
}

function getAuthorName(author: Libro['author']): string {
  if (typeof author === 'object' && author !== null && 'name' in author) {
    return String(author.name);
  }
  return 'Autore';
}

function getAuthorId(author: Libro['author']): string | null {
  if (typeof author === 'object' && author !== null && 'id' in author && typeof author.id === 'string') {
    return author.id;
  }
  if (typeof author === 'object' && author !== null && '$ref' in author && typeof author.$ref === 'string') {
    const pointer = author.$ref.split('#')[1]?.replace(/^\//, '') ?? '';
    return pointer.split('/')[0] || null;
  }
  return null;
}

function getAuthorFilterFromPath(pathname: string): string | null {
  const match = pathname.match(/^\/authors\/([^/]+)\/libri\/?$/);
  return match?.[1] ? decodeURIComponent(match[1]) : null;
}

export function BooksListView({ data }: BooksListViewProps) {
  const location = useLocation();
  const authorFilter = useMemo(() => {
    const queryAuthor = new URLSearchParams(location.search).get('author');
    return queryAuthor || getAuthorFilterFromPath(location.pathname);
  }, [location.pathname, location.search]);
  const books = useMemo(() => toBooks(data.items), [data.items]);
  const filteredBooks = useMemo(
    () => authorFilter ? books.filter((book) => getAuthorId(book.author) === authorFilter) : books,
    [authorFilter, books]
  );
  const pageSize = Math.max(1, Math.floor(data.pageSize || 10));
  const totalPages = Math.max(1, Math.ceil(filteredBooks.length / pageSize));
  const [page, setPage] = useState(1);
  const currentPage = Math.min(page, totalPages);
  const startIndex = (currentPage - 1) * pageSize;
  const visibleBooks = filteredBooks.slice(startIndex, startIndex + pageSize);

  useEffect(() => {
    setPage(1);
  }, [authorFilter]);

  return (
    <main className="min-h-screen bg-background text-foreground px-6 py-16">
      <section className="mx-auto flex w-full max-w-5xl flex-col gap-10">
        <div className="max-w-2xl">
          {data.eyebrow && (
            <p
              data-jp-field="eyebrow"
              className="text-sm font-medium uppercase tracking-[0.18em] text-muted-foreground"
            >
              {data.eyebrow}
            </p>
          )}
          <h1
            data-jp-field="title"
            className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl"
          >
            {data.title}
          </h1>
          {data.description && (
            <p
              data-jp-field="description"
              className="mt-4 text-base leading-7 text-muted-foreground"
            >
              {data.description}
            </p>
          )}
        </div>

        <div data-jp-field="items" className="grid gap-4">
          {authorFilter && (
            <p className="text-sm text-muted-foreground">
              Filtro autore: {authorFilter} · {filteredBooks.length} libri
            </p>
          )}
          {visibleBooks.map((book) => (
            <article
              key={book.id}
              data-jp-item-id={book.id}
              data-jp-item-field="items"
              className="rounded-xl border border-border bg-card p-5 shadow-sm"
            >
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h2 className="text-xl font-semibold">{book.title}</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {getAuthorName(book.author)} · {book.year} · {book.genre}
                  </p>
                  <p className="mt-3 max-w-3xl text-sm leading-6 text-muted-foreground">
                    {book.summary}
                  </p>
                </div>
                <a
                  href={`/libri/${book.id}`}
                  className="inline-flex shrink-0 items-center justify-center rounded-md border border-border px-3 py-2 text-sm font-medium hover:bg-muted"
                >
                  Apri scheda
                </a>
              </div>
            </article>
          ))}
        </div>

        <nav className="flex items-center justify-between border-t border-border pt-6 text-sm">
          <button
            type="button"
            onClick={() => setPage((value) => Math.max(1, value - 1))}
            disabled={currentPage === 1}
            className="rounded-md border border-border px-3 py-2 font-medium disabled:cursor-not-allowed disabled:opacity-40 hover:bg-muted"
          >
            Precedente
          </button>
          <span className="text-muted-foreground">
            Pagina {currentPage} di {totalPages} · {filteredBooks.length} libri
          </span>
          <button
            type="button"
            onClick={() => setPage((value) => Math.min(totalPages, value + 1))}
            disabled={currentPage === totalPages}
            className="rounded-md border border-border px-3 py-2 font-medium disabled:cursor-not-allowed disabled:opacity-40 hover:bg-muted"
          >
            Successiva
          </button>
        </nav>
      </section>
    </main>
  );
}
