# RFC: Core Presentation Sovereignty

## Status

Draft

## Date

2026-05-09

## Submitter

Tenant team — LightAlpine.

## Summary

`@olonjs/core` currently makes a number of presentation-layer decisions (router type, layout shell composition, where the route content is rendered, scroll restoration strategy) that the tenant cannot override or extend. This RFC proposes a small set of additive API changes that move those decisions back to the tenant, in line with the principle already established for theme tokens in OlonJS Architecture Spec v1.6 §4.4.2 ("Core must not govern or restrict the tenant semantic vocabulary").

## Problem

The tenant is the authority over how content is rendered, animated, scrolled and composed within the shell. The core is the authority over which content corresponds to which route. The current implementation conflates the two: by choosing `BrowserRouter` (legacy) and rendering the route content inside an opaque internal `<main>`, the core forecloses an entire class of tenant-side capabilities.

Concrete symptoms observed on the LightAlpine tenant:

1. **`viewTransition` prop on `<Link>` is a silent no-op.** React Router's `viewTransition` requires a data router (`createBrowserRouter` + `<RouterProvider>`); under the legacy `<BrowserRouter>` the prop is forwarded as an HTML attribute and ignored. The tenant has annotated dozens of `<Link>` instances with `viewTransition` expecting browser-native crossfade — none of them fire.

2. **`AnimatePresence` cannot wrap the route content.** The `<Outlet>` (or its equivalent render slot) is internal to `<JsonPagesEngine>`. The tenant cannot wrap it in `<AnimatePresence mode="wait">` to drive Framer Motion page transitions. Keying `<JsonPagesEngine>` on `pathname` from outside is not viable — it would remount the engine on every navigation, destroying drafts, refetching pages and tearing down studio state.

3. **No public hook for route lifecycle.** The tenant cannot ask "what is the current page slug?", "is a navigation in flight?", "are we transitioning to slug X?". Without these, route-coordinated UI (progress bars, prefetch, analytics, page-aware overlays) requires re-deriving information from `useLocation` heuristics.

4. **No `onRouteChange` / `onBeforeNavigate` callbacks.** Tenant cannot await a `fade-out` before the DOM swap, cannot guard navigation against unsaved changes, cannot flush analytics at the correct lifecycle point.

5. **Layout shell is hardcoded.** `<div flex-col>{header}{main}{footer}</div>` is fixed by the engine. Tenant cannot inject a global announcement bar between header and main, cannot reorder for mobile-first patterns, cannot replace `<main>` with `<motion.main>`.

6. **Scroll restoration strategy is not configurable.** The tenant cannot choose between scroll-top, restore-previous, hash-aware, animated-scroll, or no-op. The single internal strategy is the only option.

The unifying observation: **the core has crossed from "what content for this route" into "how that content is presented".** Each of the symptoms above is a consequence of that boundary violation.

## Proposal

Six additive changes to `@olonjs/core`, ordered by leverage (not by implementation order). Each is backward compatible: tenants that don't opt in see no behavior change.

### 1. Migrate to a data router

Replace the internal `<BrowserRouter>` + `<Routes>` with `createBrowserRouter` + `<RouterProvider>`. This is a single-place change that unlocks, for every existing tenant, **with no tenant-side code change**:

- `viewTransition` prop on `<Link>` works (browser fires `document.startViewTransition` automatically on navigation)
- `useNavigation()` exposes loading/submitting state across routes
- `unstable_useViewTransitionState(href)` for per-Link shared element transitions
- `useBlocker` for guarded navigation
- Loaders / actions / `defer` for first-class data fetching at the route boundary

Highest leverage of the six. Resolves symptoms (1) and partially (3).

### 2. Children render prop on `<JsonPagesEngine>`

```tsx
// Default — preserved
<JsonPagesEngine config={config} />

// Tenant takes over the render of the route content
<JsonPagesEngine config={config}>
  {({ slug, content, isTransitioning }) => (
    <AnimatePresence mode="wait">
      <motion.main
        key={slug}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -8 }}
        transition={{ duration: 0.3 }}
      >
        {content}
      </motion.main>
    </AnimatePresence>
  )}
</JsonPagesEngine>
```

Implementation: where the engine currently renders `<main>{routeContent}</main>`, render `props.children?.({ slug, content: routeContent, isTransitioning }) ?? <main>{routeContent}</main>`.

Resolves symptom (2). Smallest possible API surface — no new config keys, no opinionated wrapper.

### 3. Public lifecycle hooks

Export from `@olonjs/core`:

```ts
export function useCurrentPageSlug(): string;
export function useRouteTransitionState(): 'idle' | 'loading' | 'submitting';
export function useIsNavigatingTo(slug: string): boolean;
```

Implementation: thin wrappers over `useLocation` + `useNavigation` (data router prerequisite — ties into #1).

Resolves symptom (3). Enables global progress bars, route-aware overlays, prefetch coordination.

### 4. Lifecycle callbacks on `<JsonPagesEngine>`

```tsx
<JsonPagesEngine
  config={config}
  onBeforeRouteChange={async (from, to) => {
    await waitForFadeOut(); // tenant-side animation
  }}
  onRouteChange={(from, to) => {
    analytics.pageView(to);
  }}
  onPageMount={(slug) => {
    /* SSR/CSR-safe mount hook */
  }}
/>
```

Resolves symptom (4). Defers semantic decisions about timing, analytics, and side effects to the tenant.

### 5. Configurable shell slots

```ts
config.shell = {
  Header?: ReactComponent<{ children?: ReactNode }>,   // default: existing
  Main?: ReactComponent<{ children: ReactNode }>,      // default: <main>{children}</main>
  Footer?: ReactComponent<{ children?: ReactNode }>,
  // OR
  render?: (slots: { header, main, footer }) => JSX,   // full takeover
};
```

Resolves symptom (5). Tenant can replace `<main>` with `<motion.main>`, inject globals, reorder for mobile.

Note: overlaps in scope with #2 (children render prop). #2 covers the common case (animate the content); #5 covers the rarer case (restructure the entire shell). Both should ship — they address different needs.

### 6. Configurable scroll restoration

```ts
config.scrollRestoration =
  | 'top'                                           // default
  | 'preserve'                                      // restore previous offset
  | 'hash-aware'                                    // honor #anchor
  | 'manual'                                        // tenant fully owns it
  | ((location: Location) => 'top' | 'preserve' | { x: number; y: number });
```

Resolves symptom (6). Removes the friction documented in tenant code (e.g. comments warning not to call `window.scrollTo` because it interferes with view transitions) — tenant declares strategy, core executes.

## Architectural Principle

This RFC proposes that the OlonJS Architecture Specification add a section formalising the boundary it implies. Suggested wording for v1.7 §4.6:

> **§4.6 — Presentation Sovereignty**
>
> `@olonjs/core` is a route resolver and content renderer, not the presentation authority. The core decides which page content corresponds to a route; the tenant decides how that content is rendered, animated, scrolled, and composed within the shell.
>
> Concretely, the core MUST:
>
> - Use a data router so View Transitions, loaders, and navigation hooks work without tenant workarounds.
> - Expose route-resolved content to the tenant via a children render prop or shell slot.
> - Expose lifecycle hooks (`useCurrentPageSlug`, `useRouteTransitionState`, `useIsNavigatingTo`) and callbacks (`onBeforeRouteChange`, `onRouteChange`, `onPageMount`) as part of its public API.
> - Allow the tenant to override the scroll restoration strategy.
>
> The core MUST NOT:
>
> - Hardcode the layout shell ordering or composition.
> - Render the route content inside an opaque internal element without a tenant escape hatch.
> - Make presentation choices (animation, transitions, scroll behavior) that override or conflict with tenant declarations.
>
> Rationale: this is the same separation already established for theme tokens in §4.4.2 ("Core must not govern or restrict the tenant semantic vocabulary"), applied to the presentation layer.

## Migration Plan

All six changes are additive and backward compatible.

| Change | Compat | Tenant-side action required |
|---|---|---|
| #1 Data router migration | Behavior change: `viewTransition` props start firing | None (already harmless when no-op; works automatically when active) |
| #2 Children render prop | Additive | None to keep default; opt in to take over render |
| #3 Public hooks | Additive | None |
| #4 Lifecycle callbacks | Additive | None |
| #5 Shell slots | Additive | None |
| #6 Scroll restoration config | Additive | None to keep default |

Suggested release strategy:

- **Minor v1.x.0 release:** ship #1, #2, #3 together. Highest leverage, smallest surface. Resolves the immediate page-transitions blocker that motivated this RFC.
- **Subsequent minor:** ship #4, #5, #6 once usage patterns from early adopters inform the API shape.

## Acceptance Criteria

For this RFC to be considered satisfied:

- [ ] `@olonjs/core` ships with #1, #2, #3 in a single minor release.
- [ ] OlonJS Architecture Specification v1.7 includes §4.6 (Presentation Sovereignty) or equivalent.
- [ ] At least one reference tenant migrates from `viewTransition`-as-no-op to a working page transition (either via #1 native VT, or via #2 + Framer Motion).
- [ ] Documentation in `docs/ARCHITECTURE.md` or equivalent explains the children render prop pattern with at least one example.

## Open Questions

- **Naming.** `useCurrentPageSlug` vs `usePageSlug` vs `useRouteSlug`. `onRouteChange` vs `onNavigate`. Bikeshedding deferred to implementation.
- **Hook return shape.** Should `useRouteTransitionState` mirror React Router's `useNavigation().state` exactly, or wrap it for stability against future React Router changes? Prefer wrapping.
- **Shell slot vs children render prop overlap.** Is shipping both worth the surface area, or should one supersede the other? Recommendation: ship both — they serve different needs (content-only animation vs full shell restructure).
- **Studio compatibility.** Do these changes affect `/admin` and `/admin/preview` rendering? The data router migration in particular needs verification that the studio shell renders correctly under `<RouterProvider>`. This is implementation work, not a design issue.
- **Bundle impact.** Data router has marginally different tree-shaking characteristics than `BrowserRouter`. Expected to be negligible (<1 KB) but should be measured during implementation.

## Why this RFC, why now

The LightAlpine tenant has reached a point where multiple independent capabilities (page transitions, route-coordinated animations, branded curtain overlays, shared element morphs) are blocked by the same architectural boundary. Solving them tenant-side requires increasingly invasive workarounds (overlay-based motion shells, click interception, location heuristics) that all converge on the same conclusion: the core needs to expose what the tenant needs to control.

The proposal is small — three changes for the immediate problem, three more for completeness — and additive. It does not break existing tenants. It does not require a major version bump. It moves the core closer to the principle it already articulated for tokens in §4.4.2.

## References

- OlonJS Architecture Specification v1.6 §4.4.2 (Core Theme Transport Rule) — the analogous boundary for theme tokens.
- React Router: [Picking a router](https://reactrouter.com/v6/routers/picking-a-router) — data router vs `BrowserRouter`.
- React Router: [`unstable_useViewTransitionState`](https://reactrouter.com/en/main/hooks/use-view-transition-state).
- MDN: [`Document.startViewTransition`](https://developer.mozilla.org/en-US/docs/Web/API/Document/startViewTransition).
- LightAlpine ADR-002 (Internal navigation uses React Router `Link`) — context for the `viewTransition` annotations that currently no-op.
