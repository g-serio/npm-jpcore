import type { ResolvePublicPageJsonResult } from './resolvePublicPageJson';

export type PublicPageJsonHttpResult = {
  status: 200 | 404;
  body: unknown;
};

/** Map resolve result → HTTP status + JSON body (Vite page JSON parity). */
export function createPublicPageJsonHttpResult(
  result: ResolvePublicPageJsonResult | null,
): PublicPageJsonHttpResult {
  if (!result) {
    return { status: 404, body: { error: 'Page JSON not found' } };
  }
  return { status: 200, body: result.page };
}
