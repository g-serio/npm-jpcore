/**
 * Build config for @olonjs/core (ADR-0016, Phase 2 Task 2.2).
 *
 * Single library build. No dual full/runtime bundle (that ADR-0009
 * mechanism is retired — `@olonjs/react` and `@olonjs/studio` are now
 * physically separate npm packages, not two Vite targets over one source
 * tree). No React plugin, no Tailwind plugin: this package ships zero
 * React import and zero CSS.
 */
import { defineConfig } from 'vite';
import dts from 'vite-plugin-dts';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PEER_DEPS = ['zod'];

export default defineConfig({
  plugins: [
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
      name: 'OlonJsCore',
      formats: ['es', 'umd'],
      fileName: (format) => `olonjs-core.${format === 'es' ? 'js' : 'umd.cjs'}`,
    },
    rollupOptions: {
      external: PEER_DEPS,
      output: {
        globals: {
          zod: 'z',
        },
      },
    },
  },
});
