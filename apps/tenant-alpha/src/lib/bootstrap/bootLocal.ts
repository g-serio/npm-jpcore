import { logBootstrapEvent } from '@/lib/cloud/bootstrapTelemetry';
import type { BootstrapContentSetters } from './types';

/** No-cloud boot: local draft/files already in React state. */
export function bootLocal(setters: Pick<
  BootstrapContentSetters,
  'setContentMode' | 'setContentFallback' | 'setShowTopProgress' | 'setHasInitialCloudResolved'
>): void {
  setters.setContentMode('cloud');
  setters.setContentFallback(null);
  setters.setShowTopProgress(false);
  setters.setHasInitialCloudResolved(true);
  logBootstrapEvent('boot.local.ready', { mode: 'local' });
}
