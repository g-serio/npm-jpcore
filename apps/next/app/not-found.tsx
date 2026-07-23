export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-[50vh] max-w-xl flex-col justify-center px-6 py-16 text-[var(--foreground)]">
      <p className="text-sm opacity-60">404</p>
      <h1 className="mt-2 text-2xl font-semibold tracking-tight">Page not found</h1>
      <p className="mt-3 opacity-80">This route does not match any page in the tenant.</p>
      <a href="/" className="mt-8 text-sm underline underline-offset-4 opacity-80 hover:opacity-100">
        Back to home
      </a>
    </main>
  );
}
