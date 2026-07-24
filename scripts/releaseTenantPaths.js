/**
 * Workspace npm name → apps/<dir> folder name for release stepTenant.
 * `tenant-next` lives at apps/next (not apps/tenant-next).
 */
export function resolveTenantAppDir(workspaceName) {
  if (workspaceName === 'tenant-next') return 'next';
  return workspaceName;
}
