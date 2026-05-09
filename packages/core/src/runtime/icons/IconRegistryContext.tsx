/**
 * Icon registry context — moved here from `studio/admin/` per ADR-0009 D5.
 *
 * The registry maps section schema icon names to LucideIcon components and
 * is consumed at *render* time (Section icons in the visitor flow), not
 * just by Studio. Owning it here keeps `runtime/` decoupled from
 * `studio/admin/`.
 *
 * The original path (`packages/core/src/studio/admin/IconRegistryContext.tsx`)
 * remains as a thin re-export shim for backwards compatibility with any
 * external consumer that imported it directly.
 */
import { createContext, useContext } from 'react';
import type { LucideIcon } from 'lucide-react';

export type IconRegistry = Record<string, LucideIcon>;

export const IconRegistryContext = createContext<IconRegistry>({});

export const useIconRegistry = (): IconRegistry => useContext(IconRegistryContext);
