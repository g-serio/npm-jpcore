import { NextResponse } from 'next/server';
import path from 'node:path';
import {
  createPublicPageJsonHttpResult,
  resolvePublicPageJson,
} from '@olonjs/next/server';
import { readServerCloudPolicy } from '@/lib/env/serverCloudPolicy';
import { loadPublicPageBundleForRequest } from '@/lib/loaders/loadPublicPageBundleForRequest';

/**
 * Public page JSON API — Local / Static / Live via server cloud policy bootSource
 * (Vite `GET /{slug}.json` parity).
 */
export async function GET(
  request: Request,
  context: { params: Promise<{ slug?: string[] }> },
) {
  try {
    const { slug: parts } = await context.params;
    const slug = (parts ?? []).join('/');
    const policy = readServerCloudPolicy();
    const bundle = await loadPublicPageBundleForRequest({
      bootSource: policy.bootSource,
      slug,
      requestUrl: request.url,
      appRoot: path.resolve(process.cwd()),
      apiUrl: policy.apiUrl,
      apiKey: policy.apiKey,
    });
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
