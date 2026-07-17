/**
 * @olonjs/stack — Export stack manifest for Node ESM and CJS.
 */
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(
  readFileSync(join(__dirname, 'stack-versions.json'), 'utf8')
);

export default data;
export const peerDependencies = data.peerDependencies ?? {};
export const corePeerDependencies = data.corePeerDependencies ?? {};
export const reactBindingPeerDependencies = data.reactBindingPeerDependencies ?? {};
export const packages = data.packages ?? {};
export const dependencies = data.dependencies ?? {};
export const devDependencies = data.devDependencies ?? {};
