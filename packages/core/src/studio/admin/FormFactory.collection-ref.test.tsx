import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { z } from 'zod';
import { FormFactory } from './FormFactory';

const bookSchema = z.object({
  id: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  author: z.string().describe('ui:text'),
  summary: z.string().describe('ui:textarea'),
});

const collectionRecordSchema = z.object({
  items: z.record(z.string(), bookSchema).describe('ui:collection-ref'),
});

const collectionItemSchema = z.object({
  item: bookSchema.describe('ui:collection-ref'),
});

const StatefulFormFactory = ({
  schema,
  initialData,
  onChange,
}: {
  schema: z.ZodObject<z.ZodRawShape>;
  initialData: Record<string, unknown>;
  onChange: (next: Record<string, unknown>) => void;
}) => {
  const [data, setData] = useState(initialData);

  return (
    <FormFactory
      schema={schema}
      data={data}
      onChange={(next) => {
        setData(next);
        onChange(next);
      }}
      expandedItemPath={null}
    />
  );
};

describe('FormFactory ui:collection-ref', () => {
  it('renders collection records as expandable editable items', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const data = {
      items: {
        dune: {
          id: 'dune',
          title: 'Dune',
          author: 'Frank Herbert',
          summary: 'Desert planet politics.',
        },
        neuromancer: {
          id: 'neuromancer',
          title: 'Neuromancer',
          author: 'William Gibson',
          summary: 'Cyberspace noir.',
        },
      },
    };

    render(<StatefulFormFactory schema={collectionRecordSchema} initialData={data} onChange={onChange} />);

    expect(screen.getByText('2 items')).toBeInTheDocument();
    expect(screen.getByText(/entity data is owned by the collection document/i)).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Dune' }));
    await user.clear(screen.getByDisplayValue('Dune'));
    await user.type(screen.getByDisplayValue(''), 'Dune Messiah');

    const lastChange = onChange.mock.calls[onChange.mock.calls.length - 1]?.[0];
    expect(lastChange.items.dune.title).toBe('Dune Messiah');
    expect(lastChange.items.neuromancer.title).toBe('Neuromancer');
  });

  it('renders a single collection object as an editable entity', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    const data = {
      item: {
        id: 'dune',
        title: 'Dune',
        author: 'Frank Herbert',
        summary: 'Desert planet politics.',
      },
    };

    render(<StatefulFormFactory schema={collectionItemSchema} initialData={data} onChange={onChange} />);

    await user.clear(screen.getByDisplayValue('Desert planet politics.'));
    await user.type(screen.getByDisplayValue(''), 'Politics, ecology, and prophecy.');

    const lastChange = onChange.mock.calls[onChange.mock.calls.length - 1]?.[0];
    expect(lastChange.item.summary).toBe('Politics, ecology, and prophecy.');
    expect(lastChange.item.title).toBe('Dune');
  });
});
