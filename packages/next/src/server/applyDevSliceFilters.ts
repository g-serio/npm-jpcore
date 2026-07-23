/**
 * Vite `applyDevSliceFilters` parity — filter resolved collection maps by authored `$sliceFilter`.
 */
export function applyDevSliceFilters<T extends { sections?: Array<{ data?: Record<string, unknown> }> }>(
  page: T,
  authored: { sections?: Array<{ data?: Record<string, unknown> }> } | undefined,
  params: Record<string, string>,
): T {
  if (!authored?.sections || !page?.sections) return page;
  const at = (o: unknown, p: string) =>
    p.split('.').reduce<unknown>((a, k) => (a as Record<string, unknown> | undefined)?.[k], o);
  return {
    ...page,
    sections: page.sections.map((section, i) => {
      const src = authored.sections?.[i]?.data as
        | Record<string, { $sliceFilter?: Record<string, unknown> }>
        | undefined;
      if (!src || !section.data) return section;
      const data = { ...section.data };
      for (const [key, ref] of Object.entries(src)) {
        if (!ref?.$sliceFilter || typeof data[key] !== 'object' || data[key] === null) continue;
        const filter = Object.fromEntries(
          Object.entries(ref.$sliceFilter)
            .map(([k, v]) => [
              k,
              typeof v === 'string' ? v : params[(v as { $routeParam?: string })?.$routeParam ?? ''] ?? '',
            ])
            .filter(([, v]) => v),
        );
        data[key] = Object.fromEntries(
          Object.entries(data[key] as Record<string, unknown>).filter(([, item]) =>
            Object.entries(filter).every(([p, v]) => String(at(item, p) ?? '') === v),
          ),
        );
      }
      return { ...section, data };
    }),
  };
}
