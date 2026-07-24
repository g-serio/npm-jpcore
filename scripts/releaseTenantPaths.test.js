import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { resolveTenantAppDir } from './releaseTenantPaths.js';

describe('resolveTenantAppDir', () => {
  it('maps tenant-next workspace to apps/next directory', () => {
    assert.equal(resolveTenantAppDir('tenant-next'), 'next');
  });

  it('keeps tenant-alpha as tenant-alpha', () => {
    assert.equal(resolveTenantAppDir('tenant-alpha'), 'tenant-alpha');
  });
});
