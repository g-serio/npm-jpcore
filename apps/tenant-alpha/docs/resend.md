# Forms & Email (Resend)

OlonJS routes form submissions through the OlonJS Cloud API, which uses [Resend](https://resend.com) to deliver emails.

## Setup

Add these variables to your `.env`:

```env
VITE_OLONJS_CLOUD_URL=https://cloud.olonjs.io
VITE_OLONJS_API_KEY=sk-...
```

## How it works

1. A `<form data-olon-recipient="you@example.com">` is rendered by a section View
2. `useOlonForms()` in `App.tsx` attaches a submit handler to every form with `data-olon-recipient`
3. On submit, the payload is sent to `VITE_OLONJS_CLOUD_URL/forms/submit` with `Authorization: Bearer <key>`
4. The cloud endpoint delivers the email via Resend to `recipientEmail`

## Payload

```json
{
  "recipientEmail": "you@example.com",
  "page": "/contatti",
  "source": "olon-form",
  "submittedAt": "2025-01-01T00:00:00.000Z",
  "...formFields": "..."
}
```

## Per-form state

Views read submission state via `useFormState(formId)` from `OlonFormsContext`:

```tsx
const { status, message } = useFormState('my-form-id');
// status: 'idle' | 'submitting' | 'success' | 'error'
```

## Section schema

```ts
import { BaseSectionData, WithFormRecipient } from '@olonjs/core';

export const MySchema = BaseSectionData.merge(WithFormRecipient).extend({
  // ...
});
```
