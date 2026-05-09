/**
 * Re-export shim. The icon registry context now lives in
 * `runtime/icons/IconRegistryContext.tsx` (per ADR-0009 D5). This file is
 * kept so existing imports — both relative (sibling files in
 * `studio/admin/`) and any external consumers that referenced the old
 * path — keep working without modification.
 *
 * To remove this shim, replace all imports of
 * `studio/admin/IconRegistryContext` with `runtime/icons/IconRegistryContext`
 * (deferred: the shim is harmless and removal is a future major).
 */
export {
  IconRegistryContext,
  useIconRegistry,
  type IconRegistry,
} from '../../runtime/icons/IconRegistryContext';
