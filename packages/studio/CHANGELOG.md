# @olonjs/studio

## Unreleased — 1.0.0 (initial public release)

**ADR-0016: split out of the former monolithic `@olonjs/core`.**

`@olonjs/studio` provides the schema-driven Studio editor UI for OlonJS: `AdminSidebar`, `FormFactory`, `StudioStage`, `StudioRouteBody`, image/icon pickers.

- Depends **only** on `@olonjs/core` — never on `@olonjs/react`, by construction (verified by the `test:boundary` cross-package check). This means a future non-React rendering binding (e.g. a hypothetical `@olonjs/vue`) can reuse `@olonjs/studio` unmodified.
- `react`/`react-dom`/`react-router-dom` are peer dependencies (Studio's UI is still built with React + Radix; it just never imports the `@olonjs/react` package). `zod` is also a peer dependency (`FormFactory`/`AdminSidebar` introspect tenant Zod schemas directly, per ECIP).
- Tenant asset/icon/tenant-ID context is provided via this package's own `StudioAssetsContext`, not `@olonjs/react`'s `ConfigContext` — resolving the last residual coupling found during the split (see ADR-0016 D8, plan Task 2.3).

See [ADR-0016](../../docs/decisions/ADR-0016-core-react-studio-package-split.md) and [docs/plans/core-react-studio-package-split.md](../../docs/plans/core-react-studio-package-split.md) for the full migration record.
