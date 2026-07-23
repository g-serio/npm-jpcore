import { describe, expect, it } from 'vitest';
import {
  ADMIN_SESSION_COOKIE,
  authorizeAdminRequest,
  parseCookieHeader,
} from './adminGate';

describe('parseCookieHeader', () => {
  it('parses name/value pairs', () => {
    expect(parseCookieHeader(`${ADMIN_SESSION_COOKIE}=abc%20123; other=1`)).toEqual({
      [ADMIN_SESSION_COOKIE]: 'abc 123',
      other: '1',
    });
  });
});

describe('authorizeAdminRequest', () => {
  it('bypasses when not running on Vercel', async () => {
    const req = new Request('https://example.com/admin');
    const result = await authorizeAdminRequest(req, {});
    expect(result).toEqual({ kind: 'bypass' });
  });

  it('denies on Vercel when ADMIN_PUBLIC_KEY is missing', async () => {
    const req = new Request('https://example.com/admin');
    const result = await authorizeAdminRequest(req, { VERCEL_ENV: 'production' });
    expect(result).toEqual({ kind: 'deny', hint: 'missing_public_key' });
  });
});
