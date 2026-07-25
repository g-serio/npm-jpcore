/**
 * Next bake entry — agentic WebMCP artifacts only (no Vite / no HTML SSG).
 * Runs scripts/bake.ts via tsx so SECTION_SCHEMAS can be imported from the tenant.
 */
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const bakeTs = path.join(__dirname, 'bake.ts');

const result = spawnSync(
  process.platform === 'win32' ? 'npx.cmd' : 'npx',
  ['tsx', '--tsconfig', 'tsconfig.json', bakeTs],
  {
    cwd: rootDir,
    stdio: 'inherit',
    env: process.env,
    shell: process.platform === 'win32',
  },
);

process.exit(result.status ?? 1);
