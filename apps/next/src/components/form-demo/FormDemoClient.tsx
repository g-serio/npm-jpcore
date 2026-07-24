'use client';

import { useCallback, useState, type FormEvent } from 'react';
import { OlonFormsContext, useFormState, type FormState } from '@olonjs/react';
import type { FormDemoData } from './types';

type FormDemoClientProps = {
  formId: string;
  data: FormDemoData;
};

function FormDemoFields({
  formId,
  data,
  onSubmit,
}: FormDemoClientProps & { onSubmit: (event: FormEvent<HTMLFormElement>) => void }) {
  const { status, message } = useFormState(formId);

  return (
    <form
      id={formId}
      data-olon-recipient={data.recipientEmail ?? ''}
      className="space-y-4"
      onSubmit={onSubmit}
    >
      <div>
        <label className="mb-1 block text-xs font-medium text-muted-foreground">Nome</label>
        <input
          name="name"
          type="text"
          required
          className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
        />
      </div>

      <div>
        <label className="mb-1 block text-xs font-medium text-muted-foreground">Email</label>
        <input
          name="email"
          type="email"
          required
          className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
        />
      </div>

      <div>
        <label className="mb-1 block text-xs font-medium text-muted-foreground">Messaggio</label>
        <textarea
          name="message"
          required
          rows={4}
          className="w-full resize-none rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
        />
      </div>

      {status === 'error' ? <p className="text-xs text-red-500">{message}</p> : null}
      {status === 'success' ? <p className="text-xs text-green-600">{message}</p> : null}

      <button
        type="submit"
        disabled={status === 'submitting'}
        className="w-full rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {status === 'submitting' ? 'Invio...' : data.submitLabel || 'Invia'}
      </button>
    </form>
  );
}

/**
 * Client leaf for form-demo — OlonFormsContext is scoped HERE only (not root layout).
 */
export function FormDemoClient({ formId, data }: FormDemoClientProps) {
  const [states, setStates] = useState<Record<string, FormState>>({});

  const onSubmit = useCallback(
    async (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();
      const form = event.currentTarget;
      setStates((prev) => ({
        ...prev,
        [formId]: { status: 'submitting', message: 'Invio in corso...' },
      }));

      // Stub submit UX for local Next visitor (cloud submit can replace later).
      await new Promise((resolve) => setTimeout(resolve, 400));
      const fd = new FormData(form);
      const name = String(fd.get('name') ?? '').trim();
      const email = String(fd.get('email') ?? '').trim();
      const body = String(fd.get('message') ?? '').trim();

      if (!name || !email || !body) {
        setStates((prev) => ({
          ...prev,
          [formId]: { status: 'error', message: 'Compila tutti i campi.' },
        }));
        return;
      }

      setStates((prev) => ({
        ...prev,
        [formId]: {
          status: 'success',
          message: data.successMessage || 'Richiesta inviata con successo.',
        },
      }));
      form.reset();
    },
    [data.successMessage, formId],
  );

  return (
    <OlonFormsContext.Provider value={states}>
      <FormDemoFields formId={formId} data={data} onSubmit={onSubmit} />
    </OlonFormsContext.Provider>
  );
}
