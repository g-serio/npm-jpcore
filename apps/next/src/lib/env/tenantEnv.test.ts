import assert from 'node:assert/strict';
import { describe, it } from 'vitest';
import { getCloudPolicy, readCloudEnvFromNext } from './tenantEnv';

describe('readCloudEnvFromNext', () => {
  it('maps OLONJS public env to cloud + Save2Repo policy inputs', () => {
    const input = readCloudEnvFromNext({
      NEXT_PUBLIC_OLONJS_CLOUD_URL: ' https://api.example.com ',
      NEXT_PUBLIC_OLONJS_API_KEY: ' key ',
      NEXT_PUBLIC_OLONJS_SAVE2REPO: 'true',
    });
    assert.equal(input.apiUrl, 'https://api.example.com');
    assert.equal(input.apiKey, 'key');
    assert.equal(input.save2RepoFlag, true);
  });

  it('treats SAVE2REPO other than exact "true" as off', () => {
    const input = readCloudEnvFromNext({
      NEXT_PUBLIC_OLONJS_CLOUD_URL: 'https://api.example.com',
      NEXT_PUBLIC_OLONJS_API_KEY: 'key',
      NEXT_PUBLIC_OLONJS_SAVE2REPO: '1',
    });
    assert.equal(input.save2RepoFlag, false);
  });
});

describe('getCloudPolicy', () => {
  it('enables cold save and disables local save when credentials + Save2Repo', () => {
    const policy = getCloudPolicy({
      NEXT_PUBLIC_OLONJS_CLOUD_URL: 'https://api.example.com',
      NEXT_PUBLIC_OLONJS_API_KEY: 'key',
      NEXT_PUBLIC_OLONJS_SAVE2REPO: 'true',
    });
    assert.equal(policy.isCloudMode, true);
    assert.equal(policy.bootSource, 'static');
    assert.equal(policy.showLocalSave, false);
    assert.equal(policy.showColdSave, true);
  });

  it('stays local when credentials are missing', () => {
    const policy = getCloudPolicy({
      NEXT_PUBLIC_OLONJS_SAVE2REPO: 'true',
    });
    assert.equal(policy.isCloudMode, false);
    assert.equal(policy.showLocalSave, true);
    assert.equal(policy.showColdSave, false);
  });
});
