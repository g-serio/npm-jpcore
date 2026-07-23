import { describe, expect, it } from 'vitest';
import { VISITOR_SURFACE } from './visitorSurface';

describe('visitorSurface', () => {
  it('marks the public path as RSC (not a Studio client island)', () => {
    expect(VISITOR_SURFACE.mode).toBe('rsc');
    expect(VISITOR_SURFACE.loadsStudio).toBe(false);
  });
});
