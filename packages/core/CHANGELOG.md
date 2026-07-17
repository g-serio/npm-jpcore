# @olonjs/core

## Unreleased — 2.0.0 (breaking)

**ADR-0016: split into three packages — `@olonjs/core`, `@olonjs/react`, `@olonjs/studio`.**

`@olonjs/core` is now a pure, framework-agnostic TypeScript engine: protocol types, config/collection resolution, theme-token logic, WebMCP contracts, and routing helpers. It has **zero React dependency** — verified at the built-artifact level (no `react` import in `dist/olonjs-core.js`, `peerDependencies` contains only `zod`).

### Breaking changes

- `JsonPagesEngine`, `OlonJSEngine`, `ConfigProvider`, `PageRenderer`, `StudioProvider`, `ThemeLoader`, `useConfig`, `useStudio`, `OlonFormsContext`, `useFormState` moved to the new `@olonjs/react` package.
- `AdminSidebar`, `FormFactory`, `StudioStage`, `StudioRouteBody`, image/icon pickers moved to the new `@olonjs/studio` package.
- The `@olonjs/core/runtime` subpath (ADR-0009) is retired. There is now a single `@olonjs/core` build with a single import surface.
- No back-compat shim is provided. Tenants pinned to `@olonjs/core@1.x` continue to work unchanged on that pinned version; upgrading to `2.x` requires installing `@olonjs/react` and/or `@olonjs/studio` alongside `@olonjs/core` and updating imports per the new package boundary (see JEB §10.5 in `specs/olonjsSpecs_V_1_6_1.md`).

### What stays in `@olonjs/core`

Contract types and kernel (`contract/*`), WebMCP contracts (`webmcp/*`), base schemas and deploy-step types (`dna/lib/*`, `dna/types/deploy.ts`), pure asset/url/routing helpers (`assets/*`, `url/*`, `routing/*`), and `cn()` (`lib/utils.ts`).

See [ADR-0016](../../docs/decisions/ADR-0016-core-react-studio-package-split.md) and [docs/plans/core-react-studio-package-split.md](../../docs/plans/core-react-studio-package-split.md) for the full migration record.

## 1.1.17 and earlier

See git history — pre-split, single-package releases under the ADR-0009 full/`./runtime` dual-bundle model.
