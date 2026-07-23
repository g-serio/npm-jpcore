import type { Autore } from '@/collections/autori';
import type { AuthorsListData, AuthorsListSettings } from './types';

type AuthorsListViewProps = {
  data: AuthorsListData;
  settings?: AuthorsListSettings;
};

function toAuthors(items: AuthorsListData['items']): Autore[] {
  return Object.values(items ?? {}).sort((a, b) => a.name.localeCompare(b.name));
}

/** RSC-safe authors directory — plain href links, no react-router. */
export function AuthorsListView({ data }: AuthorsListViewProps) {
  const authors = toAuthors(data.items);

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

        <div data-jp-field="items" className="grid gap-4 sm:grid-cols-2">
          {authors.map((author) => (
            <a
              key={author.id}
              href={`/authors/${encodeURIComponent(author.id)}/libri`}
              data-jp-item-id={author.id}
              data-jp-item-field="items"
              className="block rounded-xl border border-border bg-card p-5 shadow-sm transition-colors hover:bg-muted/40"
            >
              <h2 className="text-xl font-semibold">{author.name}</h2>
              <p className="mt-2 text-sm text-muted-foreground">Vedi libri di {author.name}</p>
            </a>
          ))}
        </div>
      </section>
    </main>
  );
}
