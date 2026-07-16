/**
 * Build config for @olonjs/react (ADR-0016, Phase 2 Task 2.1).
 *
 * Deliberately a SINGLE library build — no dual full/runtime split like the
 * old @olonjs/core (ADR-0009). This is load-bearing, not a simplification:
 * per Task 0.2's spike, a module-scope singleton (React Context identity,
 * theme-manager's applied-properties Set, etc.) stays a single instance
 * only as long as every consumer of it is reachable from one Vite library
 * entry. `ConfigContext`, `runtime/studio-mode/StudioContext`,
 * `IconRegistryContext`, and `theme-manager`'s publish half all rely on
 * this. Do not add a second entry/config for this package without
 * re-opening that risk analysis (see docs/decisions/ADR-0012).
 */
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import dts from 'vite-plugin-dts';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Everything the consumer's own bundler should resolve, not us: React itself,
// our @olonjs/core dependency, and the optional @olonjs/studio peer (loaded
// only via dynamic import at the one bridge point, per ADR-0016 D2).
const EXTERNAL_DEPS = ['react', 'react-dom', 'react-router-dom', '@olonjs/core', '@olonjs/studio'];

export default defineConfig({
  plugins: [
    react(),
    dts({
      insertTypesEntry: true,
      include: ['src'],
      exclude: ['src/**/*.test.ts', 'src/**/*.test.tsx', 'src/**/vitest-setup.ts'],
      rollupTypes: true,
    }),
  ],
  build: {
    lib: {
      entry: path.resolve(__dirname, 'src/index.ts'),
      name: 'OlonJsReact',
      formats: ['es', 'umd'],
      fileName: (format) => `olonjs-react.${format === 'es' ? 'js' : 'umd.cjs'}`,
    },
    rollupOptions: {
      external: EXTERNAL_DEPS,
      output: {
        globals: {
          react: 'React',
          'react-dom': 'ReactDOM',
          'react-router-dom': 'ReactRouterDOM',
          '@olonjs/core': 'OlonJsCore',
          '@olonjs/studio': 'OlonJsStudio',
        },
      },
    },
  },
});
