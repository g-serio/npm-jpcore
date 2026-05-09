/**
 * Build config for the @olonjs/core/runtime subpath entry (ADR-0009 D1, D2, D8).
 *
 * Produces `dist/olonjs-core-runtime.js` (ESM only, no UMD/CJS) plus
 * `dist/runtime.d.ts` for the types. Run alongside the default
 * `vite.config.ts` (full bundle) via the `build` npm script:
 *
 *     "build": "vite build && vite build --config vite.config.runtime.ts"
 *
 * The two configs share peer-deps externalization but differ in:
 *   - `lib.entry`: `src/runtime-entry.ts` instead of `src/index.ts`
 *   - `lib.formats`: `['es']` only — modern bundlers consume this entry,
 *     no Node `require()` use case justifies the extra UMD output (D8)
 *   - `lib.fileName`: `olonjs-core-runtime.js`
 *   - `dts`: declaration entry produced as `runtime.d.ts`
 *   - `emptyOutDir`: false — the full build runs first; we must not
 *     wipe its `olonjs-core.js` / `index.d.ts` artifacts
 */
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import dts from 'vite-plugin-dts';
import path from 'path';
import { fileURLToPath } from 'url';
import tailwindcss from '@tailwindcss/vite';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    dts({
      // Emit a separate types entry for the runtime subpath. The full
      // build still emits dist/index.d.ts; we add dist/runtime.d.ts here.
      // The runtime entry never references JsonPagesEngine /
      // StudioRoute / PreviewRoute, so excluding them from the include
      // pattern keeps the dts pass clean (those files reference
      // `?inline` CSS modules that have no .d.ts and are admin-only).
      insertTypesEntry: false,
      include: [
        'src/runtime-entry.ts',
        'src/runtime/engine/JsonPagesEngineCore.tsx',
        'src/runtime/engine/OlonJSEngine.tsx',
        'src/runtime/engine/EngineErrorBoundary.tsx',
        'src/runtime/engine/VisitorRoute.tsx',
        'src/runtime/engine/head-sync.ts',
        'src/runtime/engine/route-utils.ts',
        'src/runtime/config/**',
        'src/runtime/rendering/**',
        'src/runtime/theme/**',
        'src/runtime/url/**',
        'src/runtime/assets/**',
        'src/runtime/icons/**',
        'src/contract/**',
        'src/lib/**',
        'src/studio/StudioContext.tsx',
        'src/studio/events.ts',
      ],
      exclude: ['src/**/*.test.ts', 'src/**/*.test.tsx', 'src/**/vitest-setup.ts'],
      rollupTypes: true,
      entryRoot: 'src',
    }),
  ],
  build: {
    emptyOutDir: false,
    lib: {
      entry: path.resolve(__dirname, 'src/runtime-entry.ts'),
      name: 'OlonJsCoreRuntime',
      formats: ['es'],
      fileName: () => 'olonjs-core-runtime.js',
    },
    rollupOptions: {
      external: ['react', 'react-dom', 'react-router-dom', 'zod'],
      output: {
        globals: {
          react: 'React',
          'react-dom': 'ReactDOM',
          zod: 'z',
          'react-router-dom': 'ReactRouterDOM',
        },
      },
    },
  },
});
