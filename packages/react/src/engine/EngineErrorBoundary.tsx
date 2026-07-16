import React, { Component, type ErrorInfo, type ReactNode } from 'react';

/**
 * Engine-level error boundary: prevents black screen on any render error
 * and surfaces a visible error UI.
 */
export class EngineErrorBoundary extends Component<
  { children: ReactNode },
  { hasError: boolean; error: Error | null }
> {
  constructor(props: { children: ReactNode }) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('[JsonPages Engine]', error, errorInfo);
  }

  render() {
    if (this.state.hasError && this.state.error) {
      return (
        <div
          style={{
            minHeight: '100vh',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 24,
            backgroundColor: '#0f172a',
            color: '#e2e8f0',
            fontFamily: 'ui-sans-serif, system-ui, sans-serif',
          }}
        >
          <h1 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: 8 }}>
            JsonPages Engine Error
          </h1>
          <pre
            style={{
              maxWidth: '100%',
              overflow: 'auto',
              padding: 16,
              backgroundColor: 'rgba(0,0,0,0.3)',
              borderRadius: 8,
              fontSize: 12,
              marginTop: 8,
            }}
          >
            {this.state.error.message}
          </pre>
        </div>
      );
    }
    return this.props.children;
  }
}
