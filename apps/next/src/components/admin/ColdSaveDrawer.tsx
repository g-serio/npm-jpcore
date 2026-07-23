'use client';

import { useMemo, type CSSProperties } from 'react';
import { createPortal } from 'react-dom';
import { DEPLOY_STEPS, type StepId } from '@olonjs/core';
import type { CloudSaveUiState } from '@/lib/admin/useCloudSave';

export type ColdSaveDrawerProps = Pick<
  CloudSaveUiState,
  'isOpen' | 'phase' | 'currentStepId' | 'doneSteps' | 'progress' | 'errorMessage' | 'deployUrl'
> & {
  onClose: () => void;
  onRetry: () => void;
};

/**
 * Slim Save2Repo progress drawer for the Next admin island.
 * Lazy-load from the admin client only — never import on visitor routes.
 */
export function ColdSaveDrawer({
  isOpen,
  phase,
  currentStepId,
  doneSteps,
  progress,
  errorMessage,
  deployUrl,
  onClose,
  onRetry,
}: ColdSaveDrawerProps) {
  const currentStep = useMemo(
    () => DEPLOY_STEPS.find((step) => step.id === currentStepId) ?? null,
    [currentStepId],
  );

  if (typeof document === 'undefined' || !isOpen || phase === 'idle') return null;

  const isRunning = phase === 'running';
  const isDone = phase === 'done';
  const isError = phase === 'error';

  return createPortal(
    <div
      role="status"
      aria-live="polite"
      aria-label={isDone ? 'Deploy completed' : isError ? 'Deploy failed' : 'Deploying'}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 2147483600,
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
        padding: '1rem',
        background: 'rgb(0 0 0 / 0.45)',
      }}
      onClick={isDone || isError ? onClose : undefined}
    >
      <div
        style={{
          width: '100%',
          maxWidth: '28rem',
          marginBottom: '1.5rem',
          borderRadius: '0.75rem',
          border: '1px solid rgb(255 255 255 / 0.08)',
          background: 'hsl(222 18% 8%)',
          color: 'hsl(210 20% 96%)',
          padding: '1.25rem',
          boxShadow: '0 20px 50px rgb(0 0 0 / 0.55)',
        }}
        onClick={(event) => event.stopPropagation()}
      >
        <p style={{ margin: 0, fontSize: '0.75rem', letterSpacing: '0.04em', textTransform: 'uppercase', opacity: 0.7 }}>
          {isDone ? 'Live' : isError ? 'Build failed' : currentStep?.verb ?? 'Saving'}
        </p>
        <p style={{ margin: '0.5rem 0 0', fontSize: '1.05rem', fontWeight: 600 }}>
          {isDone
            ? 'Your content is live.'
            : isError
              ? 'Deploy failed.'
              : currentStep
                ? currentStep.poem[0]
                : 'Starting Save2Repo…'}
        </p>
        <p style={{ margin: '0.35rem 0 0', fontSize: '0.85rem', opacity: 0.75 }}>
          {isDone
            ? 'Deployed to production successfully'
            : isError
              ? (errorMessage ?? 'Check your logs or retry below')
              : currentStep
                ? currentStep.poem[1]
                : null}
        </p>

        <ol style={{ listStyle: 'none', margin: '1rem 0 0', padding: 0, display: '0.35rem' }}>
          {DEPLOY_STEPS.map((step) => {
            const done = doneSteps.includes(step.id as StepId);
            const active = isRunning && currentStepId === step.id;
            return (
              <li
                key={step.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem',
                  fontSize: '0.8rem',
                  opacity: done || active ? 1 : 0.45,
                }}
              >
                <span
                  aria-hidden
                  style={{
                    width: '0.55rem',
                    height: '0.55rem',
                    borderRadius: '999px',
                    background: done ? step.color : active ? step.color : 'rgb(255 255 255 / 0.25)',
                    boxShadow: active ? `0 0 8px ${step.color}` : undefined,
                  }}
                />
                {step.verb}
              </li>
            );
          })}
        </ol>

        <div
          style={{
            marginTop: '1rem',
            height: '0.35rem',
            borderRadius: '999px',
            background: 'rgb(255 255 255 / 0.08)',
            overflow: 'hidden',
          }}
        >
          <div
            style={{
              height: '100%',
              width: `${Math.max(0, Math.min(100, progress))}%`,
              background: isError ? 'hsl(0 72% 51%)' : 'linear-gradient(90deg, #60a5fa, #34d399)',
              transition: 'width 0.35s ease',
            }}
          />
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.5rem', marginTop: '1rem' }}>
          {isDone ? (
            <>
              <button type="button" onClick={onClose} style={btnStyle('ghost')}>
                Close
              </button>
              <button
                type="button"
                disabled={!deployUrl}
                onClick={() => {
                  if (deployUrl) window.open(deployUrl, '_blank', 'noopener,noreferrer');
                }}
                style={btnStyle('primary')}
              >
                Open site
              </button>
            </>
          ) : null}
          {isError ? (
            <>
              <button type="button" onClick={onClose} style={btnStyle('ghost')}>
                Cancel
              </button>
              <button type="button" onClick={onRetry} style={btnStyle('danger')}>
                Retry
              </button>
            </>
          ) : null}
          {isRunning ? (
            <span style={{ fontSize: '0.75rem', opacity: 0.6 }}>
              {doneSteps.length + 1} / {DEPLOY_STEPS.length}
            </span>
          ) : null}
        </div>
      </div>
    </div>,
    document.body,
  );
}

function btnStyle(kind: 'ghost' | 'primary' | 'danger'): CSSProperties {
  const base: CSSProperties = {
    borderRadius: '0.5rem',
    border: '1px solid transparent',
    padding: '0.45rem 0.85rem',
    fontSize: '0.85rem',
    cursor: 'pointer',
  };
  if (kind === 'primary') {
    return { ...base, background: '#34d399', color: '#0a0f1a', fontWeight: 600 };
  }
  if (kind === 'danger') {
    return { ...base, background: 'hsl(0 72% 51%)', color: '#fff', fontWeight: 600 };
  }
  return { ...base, background: 'transparent', color: 'inherit', borderColor: 'rgb(255 255 255 / 0.15)' };
}
