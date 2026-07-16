import { describe, expect, it } from 'vitest';

import {
  isCanonicalAssetUrl,
  isTransientAssetUrl,
  resolveAssetUrl,
} from './asset-resolver';

describe('resolveAssetUrl', () => {
  it('keeps absolute URLs unchanged', () => {
    expect(resolveAssetUrl('https://cdn.example.com/foo.png', 'tenant-a')).toBe(
      'https://cdn.example.com/foo.png'
    );
  });

  it('keeps /assets URLs unchanged', () => {
    expect(resolveAssetUrl('/assets/images/foo.png', 'tenant-a')).toBe(
      '/assets/images/foo.png'
    );
  });

  it('normalizes assets/ URLs to browser-facing /assets/ URLs', () => {
    expect(resolveAssetUrl('assets/images/foo.png', 'tenant-a')).toBe(
      '/assets/images/foo.png'
    );
  });

  it('resolves relative filenames into tenant-scoped asset URLs', () => {
    expect(resolveAssetUrl('hero.png', 'tenant-a')).toBe('/assets/tenant-a/hero.png');
  });

  it('resolves paths under sub-route base path', () => {
    expect(resolveAssetUrl('assets/images/foo.png', 'tenant-a', '/core/')).toBe(
      '/core/assets/images/foo.png'
    );
    expect(resolveAssetUrl('/assets/images/foo.png', 'tenant-a', '/core/')).toBe(
      '/core/assets/images/foo.png'
    );
  });

  it('keeps /uploaded-assets URLs unchanged', () => {
    expect(resolveAssetUrl('/uploaded-assets/hero.png', 'tenant-a')).toBe(
      '/uploaded-assets/hero.png'
    );
  });
});

describe('asset URL guards', () => {
  it('accepts canonical asset URLs and rejects transient or filesystem paths', () => {
    expect(isCanonicalAssetUrl('/assets/images/foo.png')).toBe(true);
    expect(isCanonicalAssetUrl('/uploaded-assets/foo.png')).toBe(true);
    expect(isCanonicalAssetUrl('https://cdn.example.com/foo.png')).toBe(true);
    expect(isCanonicalAssetUrl('assets/images/foo.png')).toBe(false);
    expect(isCanonicalAssetUrl('public/assets/foo.png')).toBe(false);
    expect(isCanonicalAssetUrl('C:\\assets\\foo.png')).toBe(false);
    expect(isCanonicalAssetUrl('data:image/png;base64,aaaa')).toBe(false);
  });

  it('detects transient preview-only URLs', () => {
    expect(isTransientAssetUrl('data:image/png;base64,aaaa')).toBe(true);
    expect(isTransientAssetUrl('blob:http://localhost/123')).toBe(true);
    expect(isTransientAssetUrl('/assets/images/foo.png')).toBe(false);
  });
});
