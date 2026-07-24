import { Icon } from '@/lib/IconResolver';
import type { FormDemoData, FormDemoSettings } from './types';
import { FormDemoClient } from './FormDemoClient';

type FormDemoViewProps = {
  data: FormDemoData;
  settings?: FormDemoSettings;
};

/**
 * RSC shell for form-demo — chrome + IDAC attrs; interactivity lives in FormDemoClient.
 */
export function FormDemoView({ data }: FormDemoViewProps) {
  const formId = data.anchorId?.trim() || 'form-demo';

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-6 text-foreground">
      <section className="w-full max-w-xl space-y-6 rounded-xl border border-border bg-card p-8 shadow-sm">
        {data.icon ? (
          <div data-jp-field="icon" className="mb-2">
            <Icon name={data.icon} size={24} />
          </div>
        ) : null}
        {data.title ? (
          <div>
            <h1 data-jp-field="title" className="text-2xl font-semibold tracking-tight">
              {data.title}
            </h1>
            {data.description ? (
              <p data-jp-field="description" className="mt-3 text-sm text-muted-foreground">
                {data.description}
              </p>
            ) : null}
          </div>
        ) : null}

        <FormDemoClient formId={formId} data={data} />
      </section>
    </main>
  );
}
