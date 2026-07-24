import { NextResponse } from 'next/server';
import path from 'node:path';
import { listLocalImages, resolveLocalDataRoots } from '@olonjs/next/server';

export async function GET() {
  try {
    const roots = resolveLocalDataRoots(path.resolve(process.cwd()));
    return NextResponse.json(listLocalImages(roots.assetsImagesDir));
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'List failed' },
      { status: 500 },
    );
  }
}
