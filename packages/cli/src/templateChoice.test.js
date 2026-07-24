import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  resolveTemplateId,
  shouldPromptForTemplate,
  UI_TEMPLATE_CHOICES,
} from './templateChoice.js';

describe('UI_TEMPLATE_CHOICES', () => {
  it('exposes next and vite labels for the TUI', () => {
    assert.deepEqual(
      UI_TEMPLATE_CHOICES.map((c) => c.label),
      ['next', 'vite'],
    );
  });
});

describe('resolveTemplateId', () => {
  it('maps next → next and vite/alpha → alpha', () => {
    assert.equal(resolveTemplateId('next'), 'next');
    assert.equal(resolveTemplateId('vite'), 'alpha');
    assert.equal(resolveTemplateId('alpha'), 'alpha');
    assert.equal(resolveTemplateId('NEXT'), 'next');
  });

  it('returns null for unknown values', () => {
    assert.equal(resolveTemplateId('spa'), null);
    assert.equal(resolveTemplateId(''), null);
  });
});

describe('shouldPromptForTemplate', () => {
  it('prompts only when flag absent and stdin is a TTY', () => {
    assert.equal(shouldPromptForTemplate({ templateOption: undefined, isTTY: true }), true);
    assert.equal(shouldPromptForTemplate({ templateOption: 'next', isTTY: true }), false);
    assert.equal(shouldPromptForTemplate({ templateOption: undefined, isTTY: false }), false);
  });
});
