import { describe, expect, it } from 'vitest';
import { OLONJS_NEXT_SERVER } from './packageInfo';

describe('@olonjs/next/server', () => {
  it('exports package identity for the server surface', () => {
    expect(OLONJS_NEXT_SERVER.name).toBe('@olonjs/next');
    expect(OLONJS_NEXT_SERVER.surface).toBe('server');
  });
});
