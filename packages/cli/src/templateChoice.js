/**
 * Template selection for `olonjs new tenant`.
 * UI labels: next | vite → DNA ids: next | alpha
 */

export const UI_TEMPLATE_CHOICES = [
  { label: 'next', dnaId: 'next' },
  { label: 'vite', dnaId: 'alpha' },
];

/** @param {string | undefined | null} raw */
export function resolveTemplateId(raw) {
  const v = String(raw ?? '')
    .trim()
    .toLowerCase();
  if (!v) return null;
  if (v === 'next') return 'next';
  if (v === 'vite' || v === 'alpha') return 'alpha';
  return null;
}

/**
 * Prompt when humans run without --template on a TTY.
 * Agents/CI must pass --template (non-TTY without flag → no prompt).
 */
export function shouldPromptForTemplate({ templateOption, isTTY }) {
  if (templateOption != null && String(templateOption).trim() !== '') return false;
  return Boolean(isTTY);
}
