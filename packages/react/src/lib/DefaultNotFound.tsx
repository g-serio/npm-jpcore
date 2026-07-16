/**
 * Default 404 used by the Engine when no NotFoundComponent is provided in config.
 * No dependency on src/components (e.g. IconResolver); safe for NPM package.
 */
import React from 'react';
import { Link } from 'react-router-dom';

export const DefaultNotFound: React.FC = () => (
  <div
    style={
      {
        '--local-bg': 'var(--color-background)',
        '--local-text': 'var(--color-text)',
        '--local-text-muted': 'var(--color-text-muted)',
        '--local-primary': 'var(--color-primary)',
        '--local-radius-md': 'var(--radius-md)',
      } as React.CSSProperties
    }
    className="min-h-screen flex flex-col items-center justify-center bg-[var(--local-bg)] px-6"
  >
    <h1 className="text-6xl font-bold text-[var(--local-text)] mb-4">404</h1>
    <p className="text-xl text-[var(--local-text-muted)] mb-8">Page not found</p>
    <Link
      to="/"
      className="inline-flex items-center gap-2 px-6 py-3 rounded-[var(--local-radius-md)] bg-[var(--local-primary)] text-[var(--local-bg)] font-semibold text-sm hover:opacity-90 transition-opacity"
    >
      Back to Home
    </Link>
  </div>
);
