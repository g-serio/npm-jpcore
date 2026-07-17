# @olonjs/react

## Unreleased — 1.0.0 (initial public release)

**ADR-0016: split out of the former monolithic `@olonjs/core`.**

`@olonjs/react` provides the React rendering bindings for the OlonJS engine: `JsonPagesEngine`, `OlonJSEngine`, `PageRenderer`, `ConfigProvider`, `StudioProvider`, `ThemeLoader`, `useConfig`, `useStudio`, `OlonFormsContext`/`useFormState`.

- Depends on `@olonjs/core` (hard dependency) and `react`/`react-dom`/`react-router-dom` (peer dependencies).
- Dynamically `import()`s the optional `@olonjs/studio` package only when the admin route (`/admin`) actually mounts — a visitor-only bundle never pays for Studio's editor UI. Verified: Studio admin code (`AdminSidebar`/`FormFactory`/`StudioStage`) is provably absent from the visitor's main chunk in a real application build.
- `@olonjs/studio` is an optional peer dependency (`peerDependenciesMeta.optional`); a visitor-only/SSG consumer that never renders `/admin` never needs to install it.

See [ADR-0016](../../docs/decisions/ADR-0016-core-react-studio-package-split.md) and [docs/plans/core-react-studio-package-split.md](../../docs/plans/core-react-studio-package-split.md) for the full migration record.
