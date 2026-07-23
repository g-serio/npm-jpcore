/**
 * Admin access gate (Vite tenant-alpha middleware parity).
 * JWT ECDSA P-256, sub=admin-access. Active only when VERCEL_ENV is set.
 */

export const ADMIN_SESSION_COOKIE = '__olonjs_admin_session';
export const ADMIN_SESSION_MAX_AGE = 3600;
const JWT_MAX_AGE_SECONDS = 45;

export type AdminGateEnv = {
  VERCEL_ENV?: string;
  ADMIN_PUBLIC_KEY?: string;
};

export type AdminGateResult =
  | { kind: 'bypass' }
  | { kind: 'allow' }
  | { kind: 'deny'; hint: string }
  | { kind: 'set-session'; token: string; location: string };

function base64urlToBase64(str: string): string {
  return str.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (str.length % 4)) % 4);
}

function base64ToArrayBuffer(b64: string): ArrayBuffer {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PUBLIC KEY-----/g, '')
    .replace(/-----END PUBLIC KEY-----/g, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '');
  return base64ToArrayBuffer(b64);
}

async function importPublicKey(pem: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'spki',
    pemToArrayBuffer(pem),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['verify'],
  );
}

type JwtPayload = {
  sub?: string;
  iat?: number;
  exp?: number;
};

export async function verifyAdminJwt(
  token: string,
  publicKey: CryptoKey,
  options: { checkExp: boolean } = { checkExp: true },
): Promise<boolean> {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return false;
    const [headerB64, payloadB64, signatureB64] = parts;

    const payload = JSON.parse(atob(base64urlToBase64(payloadB64))) as JwtPayload;
    if (payload.sub !== 'admin-access') return false;

    if (options.checkExp) {
      const now = Math.floor(Date.now() / 1000);
      if (typeof payload.exp !== 'number' || payload.exp < now) return false;
      if (typeof payload.iat !== 'number' || now - payload.iat > JWT_MAX_AGE_SECONDS) return false;
    }

    const message = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
    const signature = base64ToArrayBuffer(base64urlToBase64(signatureB64));
    return crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, publicKey, signature, message);
  } catch {
    return false;
  }
}

export function parseCookieHeader(header: string | null): Record<string, string> {
  if (!header) return {};
  return Object.fromEntries(
    header.split(';').map((c) => {
      const [k, ...v] = c.trim().split('=');
      return [k.trim(), decodeURIComponent(v.join('='))];
    }),
  );
}

/**
 * Authorize an admin HTML or mutate-API request.
 * Cookie Path must be `/` so session covers `/admin` and `/api/*` mutate routes.
 */
export async function authorizeAdminRequest(
  request: Request,
  env: AdminGateEnv,
): Promise<AdminGateResult> {
  if (!env.VERCEL_ENV) return { kind: 'bypass' };

  const publicKeyPem = env.ADMIN_PUBLIC_KEY;
  if (!publicKeyPem) return { kind: 'deny', hint: 'missing_public_key' };

  let publicKey: CryptoKey;
  try {
    publicKey = await importPublicKey(publicKeyPem);
  } catch (e) {
    return {
      kind: 'deny',
      hint: `key_import_failed: ${e instanceof Error ? e.message : String(e)}`,
    };
  }

  const url = new URL(request.url);
  const cookies = parseCookieHeader(request.headers.get('Cookie'));

  const sessionToken = cookies[ADMIN_SESSION_COOKIE];
  if (sessionToken) {
    const cookieValid = await verifyAdminJwt(sessionToken, publicKey, { checkExp: false });
    if (cookieValid) return { kind: 'allow' };
  }

  const authHeader = request.headers.get('Authorization') ?? '';
  const bearerToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (bearerToken && (await verifyAdminJwt(bearerToken, publicKey))) {
    return { kind: 'allow' };
  }

  const queryToken = url.searchParams.get('token');
  if (queryToken && (await verifyAdminJwt(queryToken, publicKey))) {
    const cleanUrl = new URL(url.toString());
    cleanUrl.searchParams.delete('token');
    return { kind: 'set-session', token: queryToken, location: cleanUrl.toString() };
  }

  return { kind: 'deny', hint: 'token_invalid' };
}

export function buildAdminSessionCookie(token: string): string {
  // Path=/ so cookie is sent to /admin and protected /api/* mutate routes.
  // SameSite=Lax: navigation from cross-site platform (app.olon.it) with ?token=
  return `${ADMIN_SESSION_COOKIE}=${encodeURIComponent(token)}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${ADMIN_SESSION_MAX_AGE}`;
}
