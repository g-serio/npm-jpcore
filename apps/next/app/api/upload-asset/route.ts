import { NextResponse } from 'next/server';
import path from 'node:path';
import { resolveLocalDataRoots, saveUploadedImage } from '@olonjs/next/server';

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as {
      filename?: string;
      mimeType?: string;
      data?: string;
    };
    if (!body.filename || typeof body.data !== 'string') {
      return NextResponse.json({ error: 'Missing filename or data' }, { status: 400 });
    }
    const roots = resolveLocalDataRoots(path.resolve(process.cwd()));
    const result = saveUploadedImage({
      assetsImagesDir: roots.assetsImagesDir,
      filename: body.filename,
      mimeType: body.mimeType,
      base64Data: body.data,
    });
    return NextResponse.json(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Upload failed';
    const status = message.includes('too large') ? 413 : message.includes('Invalid file') ? 400 : 500;
    return NextResponse.json({ error: message }, { status });
  }
}
