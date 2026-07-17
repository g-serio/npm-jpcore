import { describe, expect, it, vi } from 'vitest';

import type { ProjectState } from '@olonjs/core';

import { createHotSaveHandler } from './createHotSaveHandler';

function sampleState(): ProjectState {
  return {
    page: { slug: 'home', title: 'Home', sections: [] },
    site: {},
    menu: {},
    theme: {},
    collections: {},
  } as unknown as ProjectState;
}

describe('createHotSaveHandler', () => {
  it('POSTs to /hotSave with Bearer and body', async () => {
    const fetchImpl = vi.fn(async () =>
      Response.json({ ok: true }, { status: 200 }),
    ) as unknown as typeof fetch;

    const hotSave = createHotSaveHandler({
      apiUrl: 'https://api.example.com/api/v1/',
      apiKey: 'secret-key',
      fetchImpl,
    });

    await hotSave(sampleState(), 'home');

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [url, init] = (fetchImpl as ReturnType<typeof vi.fn>).mock.calls[0] as [
      string,
      RequestInit,
    ];
    expect(url).toBe('https://api.example.com/api/v1/hotSave');
    expect(init.method).toBe('POST');
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer secret-key');
    const body = JSON.parse(String(init.body)) as { slug: string };
    expect(body.slug).toBe('home');
  });

  it('throws when credentials missing', async () => {
    const hotSave = createHotSaveHandler({ apiUrl: '', apiKey: '' });
    await expect(hotSave(sampleState(), 'home')).rejects.toThrow(/not configured/i);
  });

  it('throws on non-OK response', async () => {
    const fetchImpl = vi.fn(async () =>
      Response.json({ error: 'nope' }, { status: 403 }),
    ) as unknown as typeof fetch;

    const hotSave = createHotSaveHandler({
      apiUrl: 'https://api.example.com/api/v1',
      apiKey: 'k',
      fetchImpl,
    });

    await expect(hotSave(sampleState(), 'home')).rejects.toThrow('nope');
  });

  it('calls onSuccess after OK', async () => {
    const onSuccess = vi.fn();
    const fetchImpl = vi.fn(async () =>
      Response.json({}, { status: 200 }),
    ) as unknown as typeof fetch;

    const hotSave = createHotSaveHandler({
      apiUrl: 'https://api.example.com/api/v1',
      apiKey: 'k',
      fetchImpl,
      onSuccess,
    });

    const state = sampleState();
    await hotSave(state, 'about');
    expect(onSuccess).toHaveBeenCalledWith(
      expect.objectContaining({ slug: 'about', state, apiKey: 'k' }),
    );
  });
});
