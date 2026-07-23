import { NextResponse } from 'next/server';
import path from 'node:path';
import {
  resolveLocalDataRoots,
  saveProjectStateToDisk,
  type ProjectStateLike,
} from '@olonjs/next/server';

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as { projectState?: ProjectStateLike; slug?: string };
    if (!body.projectState || typeof body.slug !== 'string') {
      return NextResponse.json({ error: 'Missing projectState or slug' }, { status: 400 });
    }
    const roots = resolveLocalDataRoots(path.resolve(process.cwd()));
    saveProjectStateToDisk(roots, body.projectState, body.slug);
    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Save to file failed' },
      { status: 500 },
    );
  }
}
