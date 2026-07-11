import { describe, expect, it } from 'vitest';

import { buildSaveStreamRequestBody } from './cloudSaveStream';

const noopHandlers = {
  onStep: () => {},
  onDone: () => {},
};

describe('buildSaveStreamRequestBody', () => {
  it('builds the legacy single-file body when additionalFiles is omitted', () => {
    const body = buildSaveStreamRequestBody({
      apiBaseUrl: 'https://api.example.com',
      apiKey: 'key',
      path: 'src/data/pages/home.json',
      content: { title: 'Home' },
      message: 'Update home',
      ...noopHandlers,
    });

    expect(body).toEqual({
      path: 'src/data/pages/home.json',
      content: { title: 'Home' },
      message: 'Update home',
    });
    expect(body).not.toHaveProperty('files');
    expect(body).not.toHaveProperty('changedScopes');
  });

  it('builds the legacy body when additionalFiles is an empty array', () => {
    const body = buildSaveStreamRequestBody({
      apiBaseUrl: 'https://api.example.com',
      apiKey: 'key',
      path: 'src/data/pages/home.json',
      content: { title: 'Home' },
      additionalFiles: [],
      ...noopHandlers,
    });

    expect(body).toEqual({
      path: 'src/data/pages/home.json',
      content: { title: 'Home' },
      message: undefined,
    });
  });

  it('builds a files[] bundle including the primary path/content plus additionalFiles', () => {
    const body = buildSaveStreamRequestBody({
      apiBaseUrl: 'https://api.example.com',
      apiKey: 'key',
      path: 'src/data/pages/home.json',
      content: { title: 'Home' },
      additionalFiles: [
        { path: 'src/data/config/site.json', content: { identity: { title: 'Site' } } },
        { path: 'src/data/config/menu.json', content: { main: [] } },
      ],
      changedScopes: ['page', 'site', 'menu'],
      message: 'Cold save',
      ...noopHandlers,
    });

    expect(body).toEqual({
      files: [
        { path: 'src/data/pages/home.json', content: { title: 'Home' } },
        { path: 'src/data/config/site.json', content: { identity: { title: 'Site' } } },
        { path: 'src/data/config/menu.json', content: { main: [] } },
      ],
      changedScopes: ['page', 'site', 'menu'],
      message: 'Cold save',
    });
  });

  it('omits changedScopes from the bundle body when not provided', () => {
    const body = buildSaveStreamRequestBody({
      apiBaseUrl: 'https://api.example.com',
      apiKey: 'key',
      path: 'src/data/pages/home.json',
      content: { title: 'Home' },
      additionalFiles: [{ path: 'src/data/config/site.json', content: {} }],
      ...noopHandlers,
    });

    expect(body).not.toHaveProperty('changedScopes');
    expect((body as { files: unknown[] }).files).toHaveLength(2);
  });
});
