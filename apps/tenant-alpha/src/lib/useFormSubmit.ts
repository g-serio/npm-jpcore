import { useState, useCallback } from 'react';

import { cloudPolicy } from '@/lib/tenantEnv';

export type SubmitStatus = 'idle' | 'submitting' | 'success' | 'error';

interface UseFormSubmitOptions {
  source: string;
  tenantId: string;
}

export function useFormSubmit({ source, tenantId }: UseFormSubmitOptions) {
  const [status, setStatus] = useState<SubmitStatus>('idle');
  const [message, setMessage] = useState<string>('');

  const submit = useCallback(async (
    formData: FormData,
    recipientEmail: string,
    pageSlug: string,
    sectionId: string
  ) => {
    const { apiUrl, apiKey } = cloudPolicy;

    if (!apiUrl || !apiKey) {
      setStatus('error');
      setMessage('Configurazione API non disponibile. Riprova tra poco.');
      return false;
    }

    const data: Record<string, string> = {};
    formData.forEach((value, key) => {
      data[key] = String(value).trim();
    });

    const payload = {
      ...data,
      recipientEmail,
      page: pageSlug,
      section: sectionId,
      tenant: tenantId,
      source: source,
      submittedAt: new Date().toISOString(),
    };

    const idempotencyKey = `form-${sectionId}-${Date.now()}`;

    setStatus('submitting');
    setMessage('Invio in corso...');

    try {
      const apiBase = apiUrl.replace(/\/$/, '');
      const response = await fetch(`${apiBase}/forms/submit`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: JSON.stringify(payload),
      });

      const body = (await response.json().catch(() => ({}))) as { error?: string; code?: string };

      if (!response.ok) {
        throw new Error(body.error || body.code || `Submit failed (${response.status})`);
      }

      setStatus('success');
      setMessage('Richiesta inviata con successo. Ti risponderemo al più presto.');
      return true;
    } catch (error: unknown) {
      const errorMsg = error instanceof Error ? error.message : 'Invio non riuscito. Riprova tra poco.';
      setStatus('error');
      setMessage(errorMsg);
      return false;
    }
  }, [source, tenantId]);

  const reset = useCallback(() => {
    setStatus('idle');
    setMessage('');
  }, []);

  return { submit, status, message, reset };
}
