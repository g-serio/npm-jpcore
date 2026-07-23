import { NextResponse } from 'next/server';
import {
  createPublicPageJsonHttpResult,
  normalizePublicPageSlug,
} from '@olonjs/next/server';

/**
 * Public page JSON API (Vite `GET /{slug}.json` parity).
 * Content source wiring lands in Task D (Local) / E–F (Static/Live).
 */
export async function GET(
  _request: Request,
  context: { params: Promise<{ slug?: string[] }> },
) {
  const { slug: parts } = await context.params;
  const slug = normalizePublicPageSlug((parts ?? []).join('/'));
  if (!slug) {
    const http = createPublicPageJsonHttpResult(null);
    return NextResponse.json(http.body, { status: http.status });
  }
  // Bundle loader not wired yet — unknown until Local/Static/Live adapters.
  const http = createPublicPageJsonHttpResult(null);
  return NextResponse.json(http.body, { status: http.status });
}
