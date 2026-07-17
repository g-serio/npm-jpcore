/**
 * Icon registry context — consumed at render time (Section icons in the
 * visitor flow), not just by Studio. Owning it in `@olonjs/react` keeps
 * this package decoupled from `@olonjs/studio` (Studio receives its own
 * icon map via `StudioAssetsContext`, passed explicitly as a prop by the
 * admin bridge — see `engine/StudioRoute.tsx`).
 */
import { createContext, useContext } from 'react';
import type { LucideIcon } from 'lucide-react';

export type IconRegistry = Record<string, LucideIcon>;

export const IconRegistryContext = createContext<IconRegistry>({});

export const useIconRegistry = (): IconRegistry => useContext(IconRegistryContext);
