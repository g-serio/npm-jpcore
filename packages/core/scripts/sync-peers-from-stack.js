/**
 * Sync Core's peerDependencies from @olonjs/stack.
 * Run before pack/publish so published Core declares the same versions as the stack.
 *
 * Post-ADR-0016 (core/react/studio split): @olonjs/core is framework-agnostic
 * (zero React). It must sync from `corePeerDependencies` (currently just `zod`),
 * NOT from the full `peerDependencies` block — that block is the union used by
 * @olonjs/react and @olonjs/studio's own sync scripts, which do need the
 * react/react-dom/react-router-dom peers. Syncing the full union into Core here
 * was the exact regression Task 4.2 of the package-split plan caught and fixed:
 * it had silently reintroduced react/react-dom/react-router-dom into Core's
 * peerDependencies, contradicting the "zero-React" guarantee verified in Task 2.2.
 */
import { readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const coreRoot = join(__dirname, '..');
const pkgPath = join(coreRoot, 'package.json');

let stack;
try {
  const stackModule = await import('@olonjs/stack');
  stack = stackModule.default ?? stackModule;
} catch (e) {
  console.warn('sync-peers-from-stack: @olonjs/stack not found, skipping sync.', e.message);
  process.exit(0);
}

if (!stack?.corePeerDependencies) {
  console.warn('sync-peers-from-stack: no corePeerDependencies in stack, skipping.');
  process.exit(0);
}

const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
pkg.peerDependencies = { ...stack.corePeerDependencies };
writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
console.log('sync-peers-from-stack: Core peerDependencies synced from @olonjs/stack (corePeerDependencies: zero-React).');
