import { NextResponse } from 'next/server';
import path from 'node:path';
import {
  createPublicPageJsonHttpResult,
  resolvePublicPageJson,
} from '@olonjs/next/server';
import { loadLocalPublicPageBundle } from '@/lib/loaders/loadLocalPublicPageBundle';

/**
 * Public page JSON API — Local source (Vite `GET /{slug}.json` parity).
 * Static/Live sources land in later tasks via bootSource selection.
 */
export async function GET(
  _request: Request,
  context: { params: Promise<{ slug?: string[] }> },
) {
  try {
    const { slug: parts } = await context.params;
    const slug = (parts ?? []).join('/');
    const bundle = loadLocalPublicPageBundle(path.resolve(process.cwd()));
    const resolved = resolvePublicPageJson({ slug, bundle });
    const http = createPublicPageJsonHttpResult(resolved);
    return NextResponse.json(http.body, { status: http.status });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Page JSON resolution failed' },
      { status: 500 },
    );
  }
}
