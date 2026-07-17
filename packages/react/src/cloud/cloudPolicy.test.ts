import { expect, test } from 'vitest';
import { resolveCloudPolicy } from './cloudPolicy';

test('no credentials → local boot, only local save', () => {
  const p = resolveCloudPolicy({ apiUrl: '', apiKey: '', save2RepoFlag: false });
  expect(p.isCloudMode).toBe(false);
  expect(p.bootSource).toBe('local');
  expect(p.hotSaveEnabled).toBe(false);
  expect(p.save2RepoEnabled).toBe(false);
  expect(p.showLocalSave).toBe(true);
  expect(p.showHotSave).toBe(false);
  expect(p.showColdSave).toBe(false);
});

test('credentials without Save2Repo → live boot + hot save only', () => {
  const p = resolveCloudPolicy({
    apiUrl: 'https://cloud.example/api/v1',
    apiKey: 'sk-test',
    save2RepoFlag: false,
  });
  expect(p.isCloudMode).toBe(true);
  expect(p.bootSource).toBe('live');
  expect(p.hotSaveEnabled).toBe(true);
  expect(p.save2RepoEnabled).toBe(false);
  expect(p.showLocalSave).toBe(false);
  expect(p.showHotSave).toBe(true);
  expect(p.showColdSave).toBe(false);
});

test('credentials + Save2Repo → static boot; hot AND cold save (dual)', () => {
  const p = resolveCloudPolicy({
    apiUrl: 'https://cloud.example/api/v1',
    apiKey: 'sk-test',
    save2RepoFlag: true,
  });
  expect(p.isCloudMode).toBe(true);
  expect(p.bootSource).toBe('static');
  expect(p.hotSaveEnabled).toBe(true);
  expect(p.save2RepoEnabled).toBe(true);
  expect(p.showLocalSave).toBe(false);
  expect(p.showHotSave).toBe(true);
  expect(p.showColdSave).toBe(true);
});

test('Save2Repo flag alone without credentials does not enable cloud', () => {
  const p = resolveCloudPolicy({ apiUrl: '', apiKey: '', save2RepoFlag: true });
  expect(p.bootSource).toBe('local');
  expect(p.hotSaveEnabled).toBe(false);
  expect(p.save2RepoEnabled).toBe(false);
  expect(p.showColdSave).toBe(false);
});

test('trims url and key', () => {
  const p = resolveCloudPolicy({
    apiUrl: '  https://cloud.example  ',
    apiKey: '  sk  ',
    save2RepoFlag: false,
  });
  expect(p.apiUrl).toBe('https://cloud.example');
  expect(p.apiKey).toBe('sk');
  expect(p.isCloudMode).toBe(true);
});
