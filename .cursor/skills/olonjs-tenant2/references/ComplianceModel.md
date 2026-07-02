## Compliance Model

v1.6.1 distinguishes between:

- architectural law
- current implementation limitations
- tenant drift

Agents and implementers must not treat narrow runtime shortcuts as final architectural law when the spec states otherwise.

| Dimension | Transitional / Narrow Implementation | Full v1.6.1 Architecture |
|---|---|---|
| ICE binding | Missing or partial `data-jp-*` coverage | IDAC on editable fields and array items |
| Overlay styling | Markup exists but visuals are ad hoc or absent | Core injects markup, tenant styles TOCC selectors |
| Theme handling | Core or tenant-specific semantic assumptions | Core publishes flattened tokens; tenant owns semantics |
| Design token chain | Raw utilities or literals bypass theme layers | `theme.json -> runtime vars -> tenant bridge -> local scope -> JSX` |
| Typography chain | Fonts are hardcoded or ambiguously bridged | Published semantic font chain with optional local remapping |
| Menu ownership | `header/footer` appear to own links locally | `menu.json` is SOT; shell instances bind menu/link fields by reference in authored config and receive resolved values at runtime |
| Referenced field editing | Resolved values are edited and saved back into the binding document | Binding document preserves `$ref`; edits persist into the referenced owner document draft, including named `menu.json` branches |
| Shell types | Treated as conceptually reserved | Same compositional model, different scope and placement |
| Add section | Ad hoc defaults or modal wiring | `AddSectionConfig` with labels and valid default payloads |
| Bootstrap | Implicit app wiring | `JsonPagesConfig` plus `JsonPagesEngine` |
| Nested editing | Shorthands and flat adapters may survive | Deterministic path-based nested targeting |
| Array identity | Index-based fallback as primary model | Stable item identity across schema, DOM, and editor |
| Agent contract | Narrative-only understanding | Narrative plus machine-readable contract artifacts |

---
