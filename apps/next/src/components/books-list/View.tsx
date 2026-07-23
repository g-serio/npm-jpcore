import type { Libro } from '@/collections/libri';
import type { BooksListData, BooksListSettings } from './types';

type BooksListViewProps = {
  data: BooksListData;
  settings?: BooksListSettings;
  /** From Next route params (`/authors/[authorId]/libri`) or `?author=`. */
  authorId?: string | null;
  /** 1-based page from `?page=` searchParams (RSC-safe pagination). */
  page?: number;
  /** Current pathname for pagination hrefs. */
  pathname?: string;
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

function pageHref(pathname: string, page: number, authorQuery?: string | null): string {
  const params = new URLSearchParams();
  if (page > 1) params.set('page', String(page));
  if (authorQuery) params.set('author', authorQuery);
  const qs = params.toString();
  return qs ? `${pathname}?${qs}` : pathname;
}

/** RSC-safe books catalog — author filter via props, pagination via href + searchParams. */
export function BooksListView({
  data,
  authorId = null,
  page = 1,
  pathname = '/',
}: BooksListViewProps) {
  const books = toBooks(data.items);
  const filteredBooks = authorId
    ? books.filter((book) => getAuthorId(book.author) === authorId)
    : books;
  const pageSize = Math.max(1, Math.floor(data.pageSize || 10));
  const totalPages = Math.max(1, Math.ceil(filteredBooks.length / pageSize));
  const currentPage = Math.min(Math.max(1, Math.floor(page) || 1), totalPages);
  const startIndex = (currentPage - 1) * pageSize;
  const visibleBooks = filteredBooks.slice(startIndex, startIndex + pageSize);
  const authorInQuery = pathname.includes('/authors/') ? null : authorId;

  return (
    <main className="min-h-screen bg-background px-6 py-16 text-foreground">
      <section className="mx-auto flex w-full max-w-5xl flex-col gap-10">
        <div className="max-w-2xl">
          {data.eyebrow ? (
            <p
              data-jp-field="eyebrow"
              className="text-sm font-medium uppercase tracking-[0.18em] text-muted-foreground"
            >
              {data.eyebrow}
            </p>
          ) : null}
          <h1
            data-jp-field="title"
            className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl"
          >
            {data.title}
          </h1>
          {data.description ? (
            <p
              data-jp-field="description"
              className="mt-4 text-base leading-7 text-muted-foreground"
            >
              {data.description}
            </p>
          ) : null}
        </div>

        <div data-jp-field="items" className="grid gap-4">
          {authorId ? (
            <p className="text-sm text-muted-foreground">
              Filtro autore: {authorId} · {filteredBooks.length} libri
            </p>
          ) : null}
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
                  href={`/libri/${encodeURIComponent(book.id)}`}
                  className="inline-flex shrink-0 items-center justify-center rounded-md border border-border px-3 py-2 text-sm font-medium hover:bg-muted"
                >
                  Apri scheda
                </a>
              </div>
            </article>
          ))}
        </div>

        <nav className="flex items-center justify-between border-t border-border pt-6 text-sm">
          {currentPage > 1 ? (
            <a
              href={pageHref(pathname, currentPage - 1, authorInQuery)}
              className="rounded-md border border-border px-3 py-2 font-medium hover:bg-muted"
            >
              Precedente
            </a>
          ) : (
            <span className="rounded-md border border-border px-3 py-2 font-medium opacity-40">
              Precedente
            </span>
          )}
          <span className="text-muted-foreground">
            Pagina {currentPage} di {totalPages} · {filteredBooks.length} libri
          </span>
          {currentPage < totalPages ? (
            <a
              href={pageHref(pathname, currentPage + 1, authorInQuery)}
              className="rounded-md border border-border px-3 py-2 font-medium hover:bg-muted"
            >
              Successiva
            </a>
          ) : (
            <span className="rounded-md border border-border px-3 py-2 font-medium opacity-40">
              Successiva
            </span>
          )}
        </nav>
      </section>
    </main>
  );
}
