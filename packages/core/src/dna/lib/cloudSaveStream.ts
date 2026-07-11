import type { StepId } from '../types/deploy';

interface SaveStreamStepEvent {
  id: StepId;
  status: 'running' | 'done';
  label?: string;
}

interface SaveStreamLogEvent {
  stepId: StepId;
  message: string;
}

interface SaveStreamDoneEvent {
  deployUrl?: string;
  commitSha?: string;
}

interface SaveStreamErrorEvent {
  message?: string;
}

interface SaveStreamBundleFile {
  path: string;
  content: unknown;
}

interface StartCloudSaveStreamInput {
  apiBaseUrl: string;
  apiKey: string;
  path: string;
  content: unknown;
  message?: string;
  /** Additional repo files committed atomically alongside the primary path/content (e.g. site.json, menu.json). */
  additionalFiles?: SaveStreamBundleFile[];
  /** Declares which global scopes changed, mirroring the server's ERR_*_CONFIG_REQUIRED validation. */
  changedScopes?: Array<'page' | 'site' | 'menu'>;
  signal?: AbortSignal;
  onStep: (event: SaveStreamStepEvent) => void;
  onLog?: (event: SaveStreamLogEvent) => void;
  onDone: (event: SaveStreamDoneEvent) => void;
}

/**
 * Builds the request body for `POST /save-stream`. Stays on the legacy
 * single-file shape (`{ path, content, message }`) when no additional files
 * are provided, so existing callers are unaffected. Switches to the `files[]`
 * bundle shape (primary path/content + additionalFiles) otherwise.
 */
export function buildSaveStreamRequestBody(
  input: StartCloudSaveStreamInput
): Record<string, unknown> {
  if (input.additionalFiles && input.additionalFiles.length > 0) {
    return {
      files: [{ path: input.path, content: input.content }, ...input.additionalFiles],
      ...(input.changedScopes ? { changedScopes: input.changedScopes } : {}),
      message: input.message,
    };
  }

  return {
    path: input.path,
    content: input.content,
    message: input.message,
  };
}

function parseSseEventBlock(rawBlock: string): { event: string; data: string } | null {
  const lines = rawBlock
    .split('\n')
    .map((line) => line.trimEnd())
    .filter((line) => line.length > 0);

  if (lines.length === 0) return null;

  let eventName = 'message';
  const dataLines: string[] = [];
  for (const line of lines) {
    if (line.startsWith('event:')) {
      eventName = line.slice(6).trim();
      continue;
    }
    if (line.startsWith('data:')) {
      dataLines.push(line.slice(5).trim());
    }
  }
  return { event: eventName, data: dataLines.join('\n') };
}

export async function startCloudSaveStream(input: StartCloudSaveStreamInput): Promise<void> {
  const response = await fetch(`${input.apiBaseUrl}/save-stream`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${input.apiKey}`,
    },
    body: JSON.stringify(buildSaveStreamRequestBody(input)),
    signal: input.signal,
  });

  if (!response.ok || !response.body) {
    const body = (await response.json().catch(() => ({}))) as SaveStreamErrorEvent;
    throw new Error(body.message ?? `Cloud save stream failed: ${response.status}`);
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  let receivedDone = false;

  while (true) {
    const { value, done } = await reader.read();
    if (!done) {
      buffer += decoder.decode(value, { stream: true });
    } else {
      buffer += decoder.decode();
    }

    const chunks = buffer.split('\n\n');
    buffer = done ? '' : (chunks.pop() ?? '');

    for (const chunk of chunks) {
      const parsed = parseSseEventBlock(chunk);
      if (!parsed) continue;
      if (!parsed.data) continue;

      if (parsed.event === 'step') {
        const payload = JSON.parse(parsed.data) as SaveStreamStepEvent;
        input.onStep(payload);
      } else if (parsed.event === 'log') {
        const payload = JSON.parse(parsed.data) as SaveStreamLogEvent;
        input.onLog?.(payload);
      } else if (parsed.event === 'error') {
        const payload = JSON.parse(parsed.data) as SaveStreamErrorEvent;
        throw new Error(payload.message ?? 'Cloud save failed.');
      } else if (parsed.event === 'done') {
        const payload = JSON.parse(parsed.data) as SaveStreamDoneEvent;
        input.onDone(payload);
        receivedDone = true;
      }
    }

    if (done) break;
  }

  if (!receivedDone) {
    throw new Error('Cloud save stream ended before completion.');
  }
}

