import { defineConfig } from 'vitest/config';

/**
 * Pure-logic test suite (ADR-0016, Task 2.2). No jsdom, no React plugin —
 * `@olonjs/core` has zero React import after the package split; every
 * remaining test file exercises plain TypeScript logic (contract
 * resolution, theme-token flattening, WebMCP contracts, asset/base-path
 * helpers, routing helpers).
 */
export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
    include: ['src/**/*.test.{ts,tsx}'],
  },
});
