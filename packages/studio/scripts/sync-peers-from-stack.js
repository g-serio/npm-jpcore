/**
 * Sync @olonjs/studio's react/react-dom/react-router-dom + zod peerDependencies
 * from @olonjs/stack. Run before pack/publish so published @olonjs/studio
 * declares the same framework versions as the rest of the stack.
 *
 * Studio needs both the shared framework peers (`reactBindingPeerDependencies`)
 * AND `zod` (its FormFactory/AdminSidebar introspect tenant Zod schemas
 * directly, per ECIP) — `zod`'s version is sourced from `corePeerDependencies`
 * so it always matches the version @olonjs/core itself peers on.
 */
import { readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const pkgRoot = join(__dirname, '..');
const pkgPath = join(pkgRoot, 'package.json');

let stack;
try {
  const stackModule = await import('@olonjs/stack');
  stack = stackModule.default ?? stackModule;
} catch (e) {
  console.warn('sync-peers-from-stack: @olonjs/stack not found, skipping sync.', e.message);
  process.exit(0);
}

if (!stack?.reactBindingPeerDependencies) {
  console.warn('sync-peers-from-stack: no reactBindingPeerDependencies in stack, skipping.');
  process.exit(0);
}

const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
pkg.peerDependencies = {
  ...stack.reactBindingPeerDependencies,
  ...(stack.corePeerDependencies?.zod ? { zod: stack.corePeerDependencies.zod } : {}),
};
writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
console.log('sync-peers-from-stack: @olonjs/studio peerDependencies synced from @olonjs/stack (reactBindingPeerDependencies + zod).');
