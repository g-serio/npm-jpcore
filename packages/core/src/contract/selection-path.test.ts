import { expect, test } from 'vitest';
import { buildSelectionPath } from './selection-path';

class FakeElement {
  parentElement: FakeElement | null;
  private attrs: Record<string, string>;

  constructor(attrs: Record<string, string> = {}, parent: FakeElement | null = null) {
    this.attrs = attrs;
    this.parentElement = parent;
  }

  getAttribute(name: string): string | null {
    return this.attrs[name] ?? null;
  }
}

test('scalar field only returns single field segment', () => {
  const section = new FakeElement();
  const title = new FakeElement({ 'data-jp-field': 'title' }, section);

  const path = buildSelectionPath(title as unknown as HTMLElement, section as unknown as HTMLElement);
  expect(path).toEqual([{ fieldKey: 'title' }]);
});

test('array item only returns array segment with item id', () => {
  const section = new FakeElement();
  const item = new FakeElement(
    { 'data-jp-item-id': 'item-1', 'data-jp-item-field': 'menu' },
    section
  );

  const path = buildSelectionPath(item as unknown as HTMLElement, section as unknown as HTMLElement);
  expect(path).toEqual([{ fieldKey: 'menu', itemId: 'item-1' }]);
});

test('array item + nested field returns root-to-leaf path', () => {
  const section = new FakeElement();
  const item = new FakeElement(
    { 'data-jp-item-id': 'item-1', 'data-jp-item-field': 'menu' },
    section
  );
  const label = new FakeElement({ 'data-jp-field': 'label' }, item);

  const path = buildSelectionPath(label as unknown as HTMLElement, section as unknown as HTMLElement);
  expect(path).toEqual([
    { fieldKey: 'menu', itemId: 'item-1' },
    { fieldKey: 'label' },
  ]);
});

test('interactive href field in item path stays deterministic', () => {
  const section = new FakeElement();
  const item = new FakeElement(
    { 'data-jp-item-id': 'cta-1', 'data-jp-item-field': 'ctas', 'data-jp-field': 'href' },
    section
  );

  const path = buildSelectionPath(item as unknown as HTMLElement, section as unknown as HTMLElement);
  expect(path).toEqual([
    { fieldKey: 'ctas', itemId: 'cta-1' },
    { fieldKey: 'href' },
  ]);
});
