# npm-jpcore — OlonJS

## What OlonJS Is

OlonJS è un framework open source che fornisce un **contratto deterministico tra siti web e agenti AI**. Il principio guida: **la struttura dati JSON è il contratto** — da una singola fonte tipizzata derivano rendering, validazione, accesso machine e SEO.

Il nome viene da "holon": ogni sito è autonomo e completo, ma parte di una rete più ampia. *Struttura coerente per costruzione, non per convenzione.*

Ogni scelta tecnica — Zod schemas, `ui:*` descriptors, `data-jp-*` DOM attributes, IDs stabili — è parte del contratto che rende ogni sezione ispezionabile e operabile da un agente AI.

Specs di riferimento: `specs/olonjsSpecs_V_1_6.md`

---

## I Protocolli Architetturali (v1.6)

| Acronimo | Nome | Versione | Cosa governa |
|---|---|---|---|
| **MTRP** | Modular Type Registry Pattern | v1.3 | Estensibilità TypeScript via module augmentation in `types.ts` — zero modifiche al Core |
| **JSP** | JsonPages Site Protocol | v1.9 | Ontologia deterministica del filesystem: `config/` per governance globale, `pages/` per contenuto |
| **TBP** | Tenant Block Protocol | v1.1 | Section Capsules — ogni sezione contiene `View.tsx`, `schema.ts`, `types.ts`, `index.ts` |
| **CIP** | Component Implementation Protocol | v1.7 | Regole per View: agnostica da schema, theme chain, z-index, asset resolution |
| **ECIP** | Editor Component Implementation Protocol | v1.6 | Contratto schema-driven per Studio: Form Factory, `ui:*` descriptors, path-based selection |
| **IDAC** | ICE Data Attribute Contract | v1.2 | Attributi DOM `data-jp-*` per Stage/Inspector — leggibili da agenti e umani |
| **TOCC** | Tenant Overlay CSS Contract | v1.1 | Selettori CSS tenant per overlay Studio (`[data-jp-section-overlay]`) |
| **BSDS** | Base Schema Fragments | v1.1 | ID anchor e React keys stabili — `BaseSectionData`, `BaseArrayItem`, `BaseSectionSettings` |
| **ASC** | AddSectionConfig | v1.1 | Contratto add-section per Studio: tipi, label, default data |
| **JEB** | JsonPagesConfig & Engine Bootstrap | v1.2 | Contratto bootstrap tra tenant app e `JsonPagesEngine` |
| **JAP** | JsonPages Admin Protocol | v1.3 | Orchestrazione deterministica di Studio: Stage, Inspector, Working Draft, persistenza |

---

## Project Structure

Monorepo con due workspaces:

- `packages/core` — `@olonjs/core` (CMS engine, pubblicato su npm)
- `apps/tenant-alpha` — App tenant di riferimento che consuma `@olonjs/core`

### File Paths (JSP v1.9 — canonical)

| Purpose | Path | Descrizione |
|---------|------|-------------|
| Site config | `src/data/config/site.json` | `SiteConfig` — shell structure, shell instances |
| Menu config | `src/data/config/menu.json` | `MenuConfig` — source of truth per menu |
| Theme config | `src/data/config/theme.json` | `ThemeConfig` — source of truth per token visivi |
| Page data | `src/data/pages/<slug>.json` | `PageConfig` per pagina |
| Base schemas | `src/lib/base-schemas.ts` | `BaseSectionData`, `BaseArrayItem`, `CtaSchema`, ecc. |
| Schema aggregate | `src/lib/schemas.ts` | `SECTION_SCHEMAS` keyed by `SectionType` |
| Registry | `src/lib/ComponentRegistry.tsx` | `ComponentRegistry` |
| Add-section config | `src/lib/addSectionConfig.ts` | `AddSectionConfig` |
| Tenant types | `src/types.ts` | Module augmentation + contract types |
| Bootstrap | `src/App.tsx` | Builds `JsonPagesConfig`, renders `JsonPagesEngine` |

---

## Tech Stack

- **React 19**, TypeScript 5, Vite 6, Tailwind CSS 4
- **Zod** per schema definition e Form Factory UI descriptors
- **react-router-dom** v6 per routing
- `@dnd-kit` per drag-and-drop nell'editor
- `@radix-ui` primitives per UI components
- `@tiptap` per rich text (in tenant-alpha)
- `yalc` per local package linking durante lo sviluppo del core

---

## Commands

### Root
```bash
npm install          # install all workspaces
npm run bump:all     # regenerate canonical JSON Schemas at apps/olonjs.io/public/schemas/v1/
```

### apps/tenant-alpha
```bash
npm run dev          # start dev server
npm run dev:clean    # start dev server clearing Vite cache
npm run build        # tsc + vite build (runs prebuild scripts first)
npm run preview      # preview production build
npm run bakemail     # render email templates to HTML
npm run dist         # package source as distributable shell archive
```

### packages/core
```bash
npm run build        # vite library build
npm test             # vitest run
```

---

## Core Concepts

### Section Capsules (TBP v1.1)

Ogni sezione vive in `apps/tenant-alpha/src/components/<name>/`:
- `View.tsx` — componente React puro (riceve `data` e `settings`, restituisce JSX)
- `schema.ts` — Zod schema per `Data` e `Settings`
- `types.ts` — TypeScript types inferiti dallo schema Zod
- `index.ts` — re-export di `View`, `Schema`, e types

### Registrare una Nuova Sezione
1. Creare la capsule in `apps/tenant-alpha/src/components/<name>/`
2. Aggiungere il tipo in `apps/tenant-alpha/src/types.ts` (module augmentation)
3. Registrare il componente in `apps/tenant-alpha/src/lib/ComponentRegistry.tsx`
4. Registrare lo schema in `apps/tenant-alpha/src/lib/schemas.ts`

### Base Schemas (`src/lib/base-schemas.ts`) — BSDS v1.1

Ogni schema capsule deve estendere questi:
- `BaseSectionData` — aggiunge `id?` e `anchorId?`
- `BaseSectionSettingsSchema` — aggiunge `paddingTop`, `paddingBottom`, `theme`, `container`
- `BaseArrayItem` — aggiunge `id?` per array items (obbligatorio per stabilità React keys)
- `CtaSchema` — CTA riutilizzabile (label, href, variant)
- `ImageSelectionSchema` — image picker field `{ url, alt? }` con `ui:image-picker`
- `WithFormRecipient` — mixin per sezioni con form di contatto

### Persistence Modes (App.tsx)
- **Local** (`!CLOUD_API_URL`) — salva via `/api/save-to-file`
- **Hot Save** (`CLOUD_API_URL` + `CLOUD_API_KEY`, no `VITE_SAVE2REPO`) — KV cloud save diretto
- **Save2Repo** (`VITE_SAVE2REPO=true`) — Git commit via cloud bridge, carica da JSON statici pubblicati

---

## Theme Chain (CIP v1.7 — Legge Architetturale)

La catena è normativa e non deve essere bypassata:

```
theme.json → published runtime vars → tenant semantic bridge → section --local-* → JSX classes
```

**Layers:**
1. `theme.json` — source of truth tenant per token visivi
2. Core pubblica variabili CSS flattened: `tokens.colors.primary` → `--theme-colors-primary`
3. Tenant semantic bridge in `index.css` (`:root` + `@theme`): `--background: var(--theme-colors-background)`
4. Section-local scope: `--local-bg`, `--local-text` sul root element della sezione
5. JSX classes consumano il layer locale: `className="bg-[var(--local-bg)]"`

**Flattening rule:** `object.path.in.json` → `--theme-object-path-in-json` (kebab-case)

**Pattern minimo compliant per una sezione themed:**
```tsx
<section
  style={{
    '--local-bg': 'var(--background)',
    '--local-text': 'var(--foreground)',
    '--local-primary': 'var(--primary)',
  } as React.CSSProperties}
  className="bg-[var(--local-bg)] text-[var(--local-text)]"
>
```

---

## IDAC Data Attributes (IDAC v1.2)

Ogni View deve esporre questi attributi sugli elementi editabili:

| Attributo | Dove | Valore |
|---|---|---|
| `data-jp-field="<fieldKey>"` | Su ogni campo scalare editabile | key del campo schema (es. `"title"`) |
| `data-jp-item-id="<id>"` | Su ogni item di array editabile | `item.id` (mai index) |
| `data-jp-item-field="<arrayKey>"` | Sullo stesso elemento array item | key dell'array nel data |

Il `data-section-id` e `data-jp-section-overlay` sono iniettati da Core — non dal tenant.

---

## ECIP — Form Factory UI Vocabulary (ECIP v1.6)

I `ui:*` descriptor in `.describe()` guidano il Form Factory:

| Key | Widget |
|---|---|
| `ui:text` | Single-line text input |
| `ui:textarea` | Multi-line text |
| `ui:select` | Enum / single choice |
| `ui:number` | Numeric input |
| `ui:list` | Array editor con add/remove/reorder |
| `ui:image-picker` | Image selection `{ url, alt? }` |
| `ui:icon-picker` | Icon selection |

Descriptor sconosciuti vengono trattati come `ui:text`.

---

## Menu — Source of Truth (JSP v1.9)

- `menu.json` è il **source of truth** per tutte le strutture menu
- `header`/`footer` in `site.json` bindano il menu via `data.menu.$ref` — non lo possiedono
- Esempio: `site.json → header.data.menu.$ref → ../config/menu.json#/main`
- Studio deve persistere le modifiche al menu in `menu.json`, mai in `site.json`
- `header` e `footer` sono sezioni ordinarie con scope shell — non tipi riservati

---

## Code Conventions

- **Named exports** ovunque — no default exports eccetto `App` in `App.tsx`
- Functional components con hooks — no class components
- `cn()` (da `@/lib/utils`) per class merging condizionale
- Zod `ui:*` descriptor in `.describe()` — mai in commenti
- Section data types inferiti da Zod: `z.infer<typeof MySchema.shape.data>`
- Immagini usano `ImageSelectionSchema`; risolvi URL in View con `resolveAssetUrl(url, tenantId)` da `@olonjs/core`
- Errori cloud usano shape `CloudLoadFailure` `{ reasonCode, message, correlationId? }` — mai throw di stringhe raw

---

## Leggi Architetturali — Non Fare Mai

- **View non importa Zod schema** — la View è metadata-blind
- **View non legge `theme.json` direttamente** — usa la theme chain
- **No `z-index > 1`** in sezioni ordinarie — solo eccezioni documentate per shell
- **No valori hardcoded themed** in JSX: `rounded-[7px]`, `bg-blue-500`, `text-zinc-100` sono non-compliant come contratto primario
- **No index fallback** per array items editabili — `item.id` è obbligatorio
- **No menu ownership in `site.json`** — usa sempre `$ref` verso `menu.json`
- **No edit al `$ref` binding** — le modifiche devono essere persistite nel documento referenziato

---

## Boundaries

- **Never commit** file `.env` o API keys
- **Never add** dipendenze npm senza verificare l'impatto sul bundle
- **Ask before** modificare l'API pubblica di `packages/core`
- **Ask before** modificare il module augmentation `SectionDataRegistry` / `SectionSettingsRegistry` in `types.ts`
- Il file `.claude/settings.local.json` è gitignored — non committare

---

## Local Core Development (yalc)

Quando si itera su `packages/core` localmente prima di pubblicare:
```bash
npm run build:all
```

---

## Canonical Schemas v1 (ADR-0003, ADR-0013)

Il contratto pubblico di OlonJS è pubblicato come JSON Schema a `https://olon.js.org/schemas/v1/`. **Zod è la SOT interna**, il JSON Schema è il contratto pubblico — mai modificare l'output `.schema.json` direttamente.

**Set canonico v1** (5 file):
- `menu.schema.json` — navigation menus (`MenuConfig`)
- `site.schema.json` — site shell: identity, header, footer (`SiteConfig`)
- `page.schema.json` — single page contract (`PageConfig`)
- `tenant.schema.json` — top-level tenant manifest (thin wrapper, cross-file `$ref` agli altri 4)
- `design.schema.json` — design system tokens (**hand-authored**, fuori dal pipeline)

**File paths:**
| Purpose | Path |
|---|---|
| Zod SOT interna | `packages/core/src/contract/zod-schemas.ts` |
| Generator script | `scripts/bump-schemas.ts` |
| Output pubblicati | `apps/olonjs.io/public/schemas/v1/` |

**Aggiungere o modificare** uno schema canonico: vedi [docs/canonical-schemas-howto.md](docs/canonical-schemas-howto.md). Riassunto: edit Zod → `npm run bump:all` → diff review → commit. **Mai patch sul `.schema.json` direttamente**.

**Gotcha non ovvi** (full detail in [ADR-0013](docs/decisions/ADR-0013-v1-schemas-implementation.md)):
- `.optional().describe()` su schema registrate in `definitions`, mai `.describe()` diretto (preserva il `$ref` invece di decomporlo).
- `z.object({}).passthrough()` per i placeholder cross-ref, mai `z.unknown()` (required-ness corretta).

