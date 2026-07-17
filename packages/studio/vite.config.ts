/**
 * Build config for @olonjs/studio (ADR-0016, Phase 2 Task 2.1).
 *
 * Single library build, framework-agnostic peer deps only (react/react-dom
 * as generic UI runtime — this package never imports the @olonjs/react
 * package itself, per ADR-0016 D1/D2). `@olonjs/core` is its only internal
 * @olonjs dependency; everything else (Radix primitives, @dnd-kit) is a
 * genuinely owned dependency of the editor UI, not shared with any
 * rendering-binding package.
 */
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import dts from 'vite-plugin-dts';
import path from 'path';
import { fileURLToPath } from 'url';
import tailwindcss from '@tailwindcss/vite';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const EXTERNAL_DEPS = ['react', 'react-dom', 'react-router-dom', '@olonjs/core', 'zod'];

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
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
      name: 'OlonJsStudio',
      formats: ['es', 'umd'],
      fileName: (format) => `olonjs-studio.${format === 'es' ? 'js' : 'umd.cjs'}`,
    },
    rollupOptions: {
      external: EXTERNAL_DEPS,
      output: {
        globals: {
          react: 'React',
          'react-dom': 'ReactDOM',
          'react-router-dom': 'ReactRouterDOM',
          '@olonjs/core': 'OlonJsCore',
        },
      },
    },
  },
});
