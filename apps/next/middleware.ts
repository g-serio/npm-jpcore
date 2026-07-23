import { NextResponse, type NextRequest } from 'next/server';
import {
  authorizeAdminRequest,
  buildAdminSessionCookie,
} from '@olonjs/next/admin-gate';

/**
 * Admin protection (tenant-alpha Vite middleware parity, no SSO).
 * Active only when VERCEL_ENV is set + ADMIN_PUBLIC_KEY present.
 * Protects Studio HTML and local mutate APIs — not public page JSON.
 */
export async function middleware(request: NextRequest) {
  const result = await authorizeAdminRequest(request, {
    VERCEL_ENV: process.env.VERCEL_ENV,
    ADMIN_PUBLIC_KEY: process.env.ADMIN_PUBLIC_KEY,
  });

  if (result.kind === 'bypass' || result.kind === 'allow') {
    return NextResponse.next();
  }

  if (result.kind === 'set-session') {
    const response = NextResponse.redirect(result.location, 302);
    response.headers.set('Set-Cookie', buildAdminSessionCookie(result.token));
    return response;
  }

  console.error(`[admin-middleware] 401 reason: ${result.hint}`);
  return new NextResponse('Unauthorized', { status: 401 });
}

export const config = {
  matcher: [
    '/admin',
    '/admin/:path*',
    '/api/save-to-file',
    '/api/upload-asset',
    '/api/list-assets',
  ],
};
