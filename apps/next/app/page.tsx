import { VISITOR_SURFACE } from '@/lib/visitorSurface';

/**
 * Public placeholder — Server Component only.
 * Must not import @olonjs/studio or JsonPagesEngine (ADR-0017 visitor path).
 */
export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center gap-4 px-6">
      <p className="text-sm uppercase tracking-[0.18em] text-muted-foreground">OlonJS · Next</p>
      <h1 className="text-4xl font-semibold tracking-tight">Visitor surface ready</h1>
      <p className="text-muted-foreground">
        Mode: <code>{VISITOR_SURFACE.mode}</code> · Studio loaded:{' '}
        <code>{String(VISITOR_SURFACE.loadsStudio)}</code>
      </p>
    </main>
  );
}
