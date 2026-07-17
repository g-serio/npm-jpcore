/**
 * Sync @olonjs/react's react/react-dom/react-router-dom peerDependencies from
 * @olonjs/stack. Run before pack/publish so published @olonjs/react declares
 * the same framework versions as the rest of the stack.
 *
 * Only the shared framework peers (`reactBindingPeerDependencies`) are synced —
 * the `@olonjs/studio` optional peer (ADR-0016 D2's dynamic-import bridge) is
 * package-specific, not stack-driven, and is preserved untouched.
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
  '@olonjs/studio': pkg.peerDependencies?.['@olonjs/studio'] ?? '*',
};
writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
console.log('sync-peers-from-stack: @olonjs/react peerDependencies synced from @olonjs/stack (reactBindingPeerDependencies).');
