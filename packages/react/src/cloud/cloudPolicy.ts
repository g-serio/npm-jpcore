/**
 * Cloud policy — single explicit contract for boot vs save.
 *
 * Boot and save are different:
 * - bootSource: where content loads at startup (only Save2Repo yes/no among cloud modes)
 * - hotSave / coldSave: what Studio may persist (Hot stays on whenever credentials exist)
 */
export type CloudBootSource = 'local' | 'live' | 'static';

export type CloudEnvInput = {
  /** Cloud API base URL (trimmed). Empty ⇒ no cloud credentials. */
  apiUrl: string;
  /** Bearer API key (trimmed). Empty ⇒ no cloud credentials. */
  apiKey: string;
  /** True when VITE_SAVE2REPO === 'true'. */
  save2RepoFlag: boolean;
};

export type CloudPolicy = {
  /** Has both URL and API key. */
  isCloudMode: boolean;
  /**
   * Startup content source — decided only by credentials + Save2Repo:
   * local (no cloud) | live (cloud, no Save2Repo) | static (Save2Repo on).
   */
  bootSource: CloudBootSource;
  /** Hot save allowed whenever cloud credentials exist (also with Save2Repo). */
  hotSaveEnabled: boolean;
  /** Cold / Save2Repo save when cloud credentials exist AND save2RepoFlag. */
  save2RepoEnabled: boolean;
  showLocalSave: boolean;
  showHotSave: boolean;
  showColdSave: boolean;
  apiUrl: string;
  apiKey: string;
};

function hasCredentials(apiUrl: string, apiKey: string): boolean {
  return Boolean(apiUrl && apiKey);
}

/**
 * Pure policy. Pass env in — do not read import.meta.env here.
 */
export function resolveCloudPolicy(input: CloudEnvInput): CloudPolicy {
  const apiUrl = input.apiUrl.trim();
  const apiKey = input.apiKey.trim();
  const isCloudMode = hasCredentials(apiUrl, apiKey);
  const save2RepoEnabled = isCloudMode && input.save2RepoFlag;
  const hotSaveEnabled = isCloudMode;

  let bootSource: CloudBootSource = 'local';
  if (isCloudMode) {
    bootSource = save2RepoEnabled ? 'static' : 'live';
  }

  return {
    isCloudMode,
    bootSource,
    hotSaveEnabled,
    save2RepoEnabled,
    showLocalSave: !isCloudMode,
    showHotSave: hotSaveEnabled,
    showColdSave: save2RepoEnabled,
    apiUrl,
    apiKey,
  };
}
