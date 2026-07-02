## 6. ICE Data Attribute Contract (IDAC) v1.2

**Objective:** Mandatory data attributes so Stage and Inspector can bind selection and field/item editing without coupling to tenant DOM structure.

### 6.1 Section-Level Markup

`SectionRenderer` or equivalent Core shell wrapper provides:

- `data-section-id` for the section instance identity
- a sibling overlay element using `data-jp-section-overlay`

Tenant Views render the content root inside the Core wrapper.

### 6.2 Field-Level Binding

For every editable scalar field, the View must attach:

- `data-jp-field="<fieldKey>"`

The field key must match the schema/data path such as `title`, `description`, `label`, or `sectionTitle`.

### 6.3 Array-Item Binding

For every editable array item, the View must attach:

- `data-jp-item-id="<stableId>"`
- `data-jp-item-field="<arrayKey>"`

The preferred source of identity is `item.id`.
Index fallback is non-canonical in strict editable object arrays.

### 6.4 Compliance

All editable Stage content that participates in Studio editing must implement field and array-item bindings.
Shell-scoped instances may omit these bindings only when they are out of editing scope for the current Studio surface.

### 6.5 Strict Path Extraction For Nested Arrays

For nested array targets, the runtime selection target is expressed as `SelectionPath` from root to leaf.

Rules:

- flat identity is not sufficient for nested structures
- nested editable object arrays require stable item identity
- path derivation must remain deterministic from DOM bindings and item identity

**Why it matters:** IDAC is the bridge between tenant DOM and Studio orchestration. Without it, Stage clicks and Inspector focus become guesswork.

---