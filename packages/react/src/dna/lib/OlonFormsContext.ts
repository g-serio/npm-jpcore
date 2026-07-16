import { createContext, useContext } from 'react';

export type FormStatus = 'idle' | 'submitting' | 'success' | 'error';

export interface FormState {
  status: FormStatus;
  message: string;
}

const DEFAULT_FORM_STATE: FormState = { status: 'idle', message: '' };

/**
 * Context holding the submission state of every olon-managed form,
 * keyed by the form's id attribute (or anchorId).
 * Provided by App.tsx via useOlonForms().
 */
export const OlonFormsContext = createContext<Record<string, FormState>>({});

/**
 * Read the submission state for a specific form.
 * @param formId - must match the id attribute on the <form> element.
 */
export function useFormState(formId: string): FormState {
  const states = useContext(OlonFormsContext);
  return states[formId] ?? DEFAULT_FORM_STATE;
}
