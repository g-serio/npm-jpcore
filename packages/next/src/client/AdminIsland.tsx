'use client';

/**
 * Admin client island — mounts JsonPagesEngine for Studio on `/admin`.
 * Tenant supplies protocol config (registry, schemas, pages, persistence).
 * Visitor routes must not import this module (ADR-0017).
 */

import type { ReactNode } from 'react';
import type { JsonPagesConfig } from '@olonjs/core';
import { JsonPagesEngine } from '@olonjs/react';

export type AdminIslandProps = {
  config: JsonPagesConfig;
  /** Optional overlays (e.g. Save2Repo DopaDrawer) rendered beside the engine. */
  children?: ReactNode;
};

export function AdminIsland({ config, children }: AdminIslandProps) {
  return (
    <>
      <JsonPagesEngine config={config} />
      {children}
    </>
  );
}
