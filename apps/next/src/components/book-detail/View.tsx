import type { BookDetailData, BookDetailSettings } from './types';

type BookDetailViewProps = {
  data: BookDetailData;
  settings?: BookDetailSettings;
};

function getAuthorName(author: BookDetailData['item']['author']): string {
  if (typeof author === 'object' && author !== null && 'name' in author) {
    return String(author.name);
  }
  return 'Autore';
}

/** RSC-safe book detail — plain href back link, no react-router. */
export function BookDetailView({ data }: BookDetailViewProps) {
  const book = data.item;

  return (
    <main className="min-h-screen bg-background px-6 py-16 text-foreground">
      <article
        data-jp-field="item"
        data-jp-item-id={book.id}
        data-jp-item-field="item"
        className="mx-auto w-full max-w-3xl rounded-2xl border border-border bg-card p-8 shadow-sm"
      >
        <a href="/libri" className="text-sm font-medium text-muted-foreground hover:text-foreground">
          {data.backLabel}
        </a>
        <p className="mt-10 text-sm font-medium uppercase tracking-[0.18em] text-muted-foreground">
          {book.genre} · {book.year}
        </p>
        <h1 className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl">{book.title}</h1>
        <p className="mt-4 text-lg text-muted-foreground">{getAuthorName(book.author)}</p>
        <p className="mt-8 text-base leading-8 text-muted-foreground">{book.summary}</p>
      </article>
    </main>
  );
}
