import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import dts from 'vite-plugin-dts';
import path from 'path';
import { fileURLToPath } from 'url';
import tailwindcss from '@tailwindcss/vite';

// 🛡️ ESM Shim per __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PEER_DEPS = ['react', 'react-dom', 'react-router-dom', 'zod'];

// Singleton-bearing modules that MUST resolve to the same instance across
// the full and runtime bundles at runtime. See ADR-0012.
//
// Each file declares module-level identity (a `React.createContext()` call,
// a stateful singleton, an event channel) which would silently double if it
// were bundled into both `olonjs-core.js` and `olonjs-core-runtime.js`. The
// /runtime build authors these files; the /full build externalizes them and
// imports the sibling artifact at load time.
//
// The runtime-entry surface (`src/runtime-entry.ts`) re-exports every symbol
// the full bundle's import graph needs from these files (verified
// 2026-05-10: useConfig, ConfigProvider, useStudio, StudioProvider,
// themeManager, IconRegistryContext, useIconRegistry).
const SINGLETON_RUNTIME_MODULES = [
  /[/\\]runtime[/\\]config[/\\]ConfigContext(\.tsx?)?$/,
  /[/\\]studio[/\\]StudioContext(\.tsx?)?$/,
  /[/\\]runtime[/\\]theme[/\\]theme-manager(\.tsx?)?$/,
  /[/\\]runtime[/\\]icons[/\\]IconRegistryContext(\.tsx?)?$/,
];

const isSingletonRuntimeModule = (id: string): boolean =>
  SINGLETON_RUNTIME_MODULES.some((re) => re.test(id));

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    dts({
      insertTypesEntry: true,
      include: ['src'],
      exclude: ['src/**/*.test.ts', 'src/**/*.test.tsx', 'src/**/vitest-setup.ts'],
      // Genera file .d.ts puliti senza import circolari
      rollupTypes: true
    })
  ],
  build: {
    // ADR-0012: the orchestrator (`scripts/build-dual.mjs`) wipes dist
    // once at step 0, then runs the runtime build first. The full build
    // must NOT wipe dist again or it would erase the freshly emitted
    // runtime artifacts (olonjs-core-runtime.js + runtime.d.ts) that the
    // full bundle now references via './olonjs-core-runtime.js'.
    emptyOutDir: false,
    lib: {
      // Punto di ingresso della libreria
      entry: path.resolve(__dirname, 'src/index.ts'),
      name: 'OlonJsCore',
      formats: ['es', 'umd'],
      fileName: (format) => `olonjs-core.${format === 'es' ? 'js' : 'umd.cjs'}`,
    },
    rollupOptions: {
      // 🛡️ Peer Dependencies: non includerle nel bundle finale.
      // Singleton runtime modules: externalize so the full bundle imports
      // them from the sibling olonjs-core-runtime.js artifact (ADR-0012).
      external: (id: string): boolean => {
        if (PEER_DEPS.includes(id)) return true;
        if (isSingletonRuntimeModule(id)) return true;
        return false;
      },
      output: {
        globals: {
          react: 'React',
          'react-dom': 'ReactDOM',
          'zod': 'z',
          'react-router-dom': 'ReactRouterDOM'
        },
        // Rewrite externalized singleton paths to the sibling runtime
        // artifact. ESM consumers see `import { ... } from
        // './olonjs-core-runtime.js'` in the emitted full bundle; CJS/UMD
        // consumers see the equivalent `require('./olonjs-core-runtime.js')`.
        paths: (id: string): string => {
          if (isSingletonRuntimeModule(id)) return './olonjs-core-runtime.js';
          return id;
        },
      },
    },
  },
});