## 7. Tenant Overlay CSS Contract (TOCC) v1.1

**Objective:** The Stage iframe loads tenant HTML/CSS. Core injects overlay markup but does not own tenant overlay visuals.

### 7.1 Required Selectors

Tenant global CSS must style at least:

1. `[data-jp-section-overlay]` as absolute overlay shell with transparent base state
2. `[data-section-id]:hover [data-jp-section-overlay]` for hover state
3. `[data-section-id][data-jp-selected] [data-jp-section-overlay]` for selected state
4. `[data-jp-section-overlay] > div` for the type label

### 7.2 Z-Index

Overlay z-index must remain above section content and consistent with CIP overlay governance.

### 7.3 Responsibility Split

- Core injects wrapper, overlay DOM, and selection state
- Tenant owns overlay appearance through CSS

**Why it matters:** Without TOCC, selection rings and type labels are structurally present but visually absent.

---