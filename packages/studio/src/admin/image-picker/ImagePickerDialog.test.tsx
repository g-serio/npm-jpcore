import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import { StudioAssetsProvider } from '../../context/StudioAssetsContext';
import { ImagePickerDialog } from './ImagePickerDialog';

function renderDialog(onSelect = vi.fn(), onAssetUpload?: (file: File) => Promise<string>) {
  return render(
    <StudioAssetsProvider
      value={{
        icons: {},
        tenantId: 'tenant-a',
        assets: {
          onAssetUpload,
          assetsManifest: [],
        },
      }}
    >
      <ImagePickerDialog open onOpenChange={() => {}} onSelect={onSelect} />
    </StudioAssetsProvider>
  );
}

describe('ImagePickerDialog upload tab', () => {
  const originalFetch = globalThis.fetch;
  const originalFileReader = globalThis.FileReader;

  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn(() => Promise.resolve(new Response(null))));
  });

  afterEach(() => {
    vi.restoreAllMocks();

    if (originalFetch === undefined) {
      Reflect.deleteProperty(globalThis, 'fetch');
    } else {
      Reflect.set(globalThis, 'fetch', originalFetch);
    }

    if (originalFileReader === undefined) {
      Reflect.deleteProperty(globalThis, 'FileReader');
    } else {
      Reflect.set(globalThis, 'FileReader', originalFileReader);
    }
  });

  it('shows upload preview using the canonical URL returned by onAssetUpload', async () => {
    const user = userEvent.setup();

    renderDialog(vi.fn(), vi.fn(async () => '/assets/images/hero.png'));

    await user.click(screen.getByRole('button', { name: 'Upload' }));
    const input = document.querySelector('input[type="file"]');
    if (!(input instanceof HTMLInputElement)) {
      throw new Error('Expected upload input');
    }

    await user.upload(input, new File(['image'], 'hero.png', { type: 'image/png' }));

    await waitFor(() => {
      const preview = screen.getByAltText('Upload preview') as HTMLImageElement;
      expect(preview).toHaveAttribute('src', '/assets/images/hero.png');
    });

    expect(screen.getByRole('button', { name: 'Inserisci immagine' })).toBeEnabled();
  });

  it('blocks confirmation when only a transient data preview is available', async () => {
    const user = userEvent.setup();

    class FakeFileReader {
      onload: ((event: ProgressEvent<FileReader>) => void) | null = null;

      readAsDataURL(): void {
        this.onload?.({
          target: { result: 'data:image/png;base64,preview' },
        } as ProgressEvent<FileReader>);
      }
    }

    Reflect.set(globalThis, 'FileReader', FakeFileReader);

    renderDialog(vi.fn(), vi.fn(async () => {
      throw new Error('upload failed');
    }));

    await user.click(screen.getByRole('button', { name: 'Upload' }));
    const input = document.querySelector('input[type="file"]');
    if (!(input instanceof HTMLInputElement)) {
      throw new Error('Expected upload input');
    }

    await user.upload(input, new File(['image'], 'fallback.png', { type: 'image/png' }));

    await waitFor(() => {
      const preview = screen.getByAltText('Upload preview') as HTMLImageElement;
      expect(preview).toHaveAttribute('src', 'data:image/png;base64,preview');
    });

    expect(screen.getByRole('alert')).toHaveTextContent(
      "Upload non persistito: serve un URL asset canonico per inserire l'immagine."
    );
    expect(screen.getByRole('button', { name: 'Inserisci immagine' })).toBeDisabled();
  });

  it('confirms only the final canonical URL when persistence is valid', async () => {
    const user = userEvent.setup();
    const onSelect = vi.fn();

    renderDialog(onSelect, vi.fn(async () => '/assets/tenant-a/hero.png'));

    await user.click(screen.getByRole('button', { name: 'Upload' }));
    const input = document.querySelector('input[type="file"]');
    if (!(input instanceof HTMLInputElement)) {
      throw new Error('Expected upload input');
    }

    await user.upload(input, new File(['image'], 'hero.png', { type: 'image/png' }));

    const confirmButton = screen.getByRole('button', { name: 'Inserisci immagine' });
    await waitFor(() => expect(confirmButton).toBeEnabled());
    await user.click(confirmButton);

    expect(onSelect).toHaveBeenCalledWith({
      url: '/assets/tenant-a/hero.png',
      alt: 'hero.png',
    });
  });
});
