import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { z } from 'zod';
import { FormFactory } from './FormFactory';

/** Mirrors header-style menu → optional children lists (no `id` in JSON → legacy-* keys). */
const nestedMenuSchema = z.object({
  menu: z
    .array(
      z.object({
        label: z.string().describe('ui:text'),
        href: z.string().describe('ui:text'),
        children: z
          .array(
            z.object({
              label: z.string().describe('ui:text'),
              href: z.string().describe('ui:text'),
            })
          )
          .optional()
          .describe('ui:list'),
      })
    )
    .describe('ui:list'),
});

describe('FormFactory nested ui:list', () => {
  it('keeps inner array row expanded when expandedItemPath does not include inner openItemId', async () => {
    const user = userEvent.setup();
    const data = {
      menu: [
        {
          label: 'Platform',
          href: '/platform',
          children: [
            { label: 'Overview', href: '/platform/overview' },
            { label: 'Architecture', href: '/platform/architecture' },
          ],
        },
      ],
    };

    render(
      <FormFactory
        schema={nestedMenuSchema}
        data={data}
        onChange={() => {}}
        expandedItemPath={null}
      />
    );

    await user.click(screen.getByRole('button', { name: /platform/i }));

    await user.click(screen.getByRole('button', { name: /overview/i }));

    const overviewHref = screen.getByDisplayValue('/platform/overview');
    expect(overviewHref).toBeVisible();
  });
});
