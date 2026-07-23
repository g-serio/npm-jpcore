import { describe, expect, it } from 'vitest';
import { OLONJS_NEXT_CLIENT } from './packageInfo';

describe('@olonjs/next/client', () => {
  it('exports package identity for the client surface', () => {
    expect(OLONJS_NEXT_CLIENT.name).toBe('@olonjs/next');
    expect(OLONJS_NEXT_CLIENT.surface).toBe('client');
  });
});
