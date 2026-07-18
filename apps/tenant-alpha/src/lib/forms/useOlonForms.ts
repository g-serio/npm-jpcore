import { useCallback, useEffect, useState } from 'react';
import type { FormState } from '@olonjs/react';

import { cloudPolicy } from '@/lib/env/tenantEnv';

interface UseOlonFormsOptions {
  /** Override the submit endpoint. Defaults to cloudPolicy.apiUrl/forms/submit */
  endpoint?: string;
}

/**
 * Mount once in App.tsx. Scans the DOM for all <form data-olon-recipient="...">
 * elements and attaches submit handlers. Returns per-form states to be provided
 * via OlonFormsContext.Provider.
 *
 * Views consume state via useFormState(formId) — no direct coupling to this hook.
 */
export function useOlonForms(options?: UseOlonFormsOptions): { states: Record<string, FormState> } {
  const [states, setStates] = useState<Record<string, FormState>>({});

  const setFormState = useCallback((formId: string, state: FormState) => {
    setStates((prev) => ({ ...prev, [formId]: state }));
  }, []);

  useEffect(() => {
    const apiUrl = cloudPolicy.apiUrl;
    const apiKey = cloudPolicy.apiKey;

    const resolvedBase = options?.endpoint
      ? options.endpoint.replace(/\/$/, '')
      : apiUrl
        ? apiUrl.replace(/\/$/, '')
        : null;

    if (!resolvedBase || !apiKey) {
      console.warn('[useOlonForms] Missing API endpoint or key — forms will not submit.');
      return;
    }

    const endpoint = resolvedBase.endsWith('/forms/submit')
      ? resolvedBase
      : `${resolvedBase}/forms/submit`;

    const forms = Array.from(
      document.querySelectorAll<HTMLFormElement>('form[data-olon-recipient]')
    );

    const controllers: AbortController[] = [];

    async function handleSubmit(form: HTMLFormElement, event: SubmitEvent) {
      event.preventDefault();

      const formId = form.id || form.dataset.olonRecipient || 'olon-form';
      const recipientEmail = form.dataset.olonRecipient ?? '';

      setFormState(formId, { status: 'submitting', message: 'Invio in corso...' });

      const raw: Record<string, string> = {};
      new FormData(form).forEach((value, key) => {
        raw[key] = String(value).trim();
      });

      const payload = {
        ...raw,
        recipientEmail,
        page: window.location.pathname,
        source: 'olon-form',
        submittedAt: new Date().toISOString(),
      };

      const controller = new AbortController();
      controllers.push(controller);

      try {
        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
            'Idempotency-Key': `form-${formId}-${Date.now()}`,
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        const body = (await response.json().catch(() => ({}))) as {
          error?: string;
          code?: string;
        };

        if (!response.ok) {
          throw new Error(body.error ?? body.code ?? `Submit failed (${response.status})`);
        }

        setFormState(formId, {
          status: 'success',
          message: 'Richiesta inviata con successo.',
        });
        form.reset();
      } catch (error: unknown) {
        if (error instanceof Error && error.name === 'AbortError') return;
        const message =
          error instanceof Error ? error.message : 'Invio non riuscito. Riprova.';
        setFormState(formId, { status: 'error', message });
      }
    }

    type Listener = { form: HTMLFormElement; handler: (e: Event) => void };
    const listeners: Listener[] = [];

    forms.forEach((form) => {
      const handler = (e: Event) => void handleSubmit(form, e as SubmitEvent);
      form.addEventListener('submit', handler);
      listeners.push({ form, handler });
    });

    return () => {
      controllers.forEach((c) => c.abort());
      listeners.forEach(({ form, handler }) => form.removeEventListener('submit', handler));
    };
  }, [options?.endpoint, setFormState]);

  return { states };
}
