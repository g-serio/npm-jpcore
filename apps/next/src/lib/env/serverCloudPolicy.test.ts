import { describe, expect, it } from 'vitest';
import { buildServerApiCandidates, readServerCloudPolicy } from './serverCloudPolicy';

describe('readServerCloudPolicy', () => {
  it('defaults to local without credentials', () => {
    expect(readServerCloudPolicy({}).bootSource).toBe('local');
  });

  it('selects live with credentials and Save2Repo off', () => {
    expect(
      readServerCloudPolicy({
        NEXT_PUBLIC_OLONJS_CLOUD_URL: 'https://api.example',
        NEXT_PUBLIC_OLONJS_API_KEY: 'k',
      }).bootSource,
    ).toBe('live');
  });

  it('selects static with credentials and Save2Repo on', () => {
    expect(
      readServerCloudPolicy({
        NEXT_PUBLIC_OLONJS_CLOUD_URL: 'https://api.example',
        NEXT_PUBLIC_OLONJS_API_KEY: 'k',
        NEXT_PUBLIC_SAVE2REPO: 'true',
      }).bootSource,
    ).toBe('static');
  });
});

describe('buildServerApiCandidates', () => {
  it('prefers /api/v1 and keeps raw base', () => {
    expect(buildServerApiCandidates('https://api.example')).toEqual([
      'https://api.example/api/v1',
      'https://api.example',
    ]);
  });
});
