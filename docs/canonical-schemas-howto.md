# Aggiungere o modificare uno schema canonico v1

Riferimento normativo: [ADR-0003](decisions/ADR-0003-jsonschema-as-public-contract-zod-as-internal-sot.md), [ADR-0013](decisions/ADR-0013-v1-schemas-implementation.md).

Questa guida copre i tre flussi pratici:
1. Aggiungere un campo a uno schema esistente
2. Aggiungere un nuovo schema canonico
3. Convenzioni Zod source (gotcha)

## Architettura in 30 secondi

```
packages/core/src/contract/zod-schemas.ts   (SOT Zod, interna)
  → npm run bump:all (scripts/bump-schemas.ts)
    → apps/olonjs.io/public/schemas/v1/<nome>.schema.json
```

Zod è la verità interna. Il file `.schema.json` è il contratto pubblico. Si modifica **solo** lo Zod — mai il `.json` direttamente (ADR-0003 §AD-3).

I 5 schemi canonici v1:
- `menu.schema.json` — `MenuConfig`
- `site.schema.json` — `SiteConfig`
- `page.schema.json` — `PageConfig`
- `tenant.schema.json` — `TenantManifest` (thin wrapper con cross-file `$ref`)
- `design.schema.json` — design system tokens (**hand-authored**, fuori dal pipeline)

## Flusso 1 — Aggiungere un campo a uno schema esistente

Esempio: aggiungere `priority?: number` a `MenuItem`.

1. In [`packages/core/src/contract/zod-schemas.ts`](../packages/core/src/contract/zod-schemas.ts), trovare `MenuItemSchema` e aggiungere il campo:
   ```ts
   priority: z.number().int().min(0).optional().describe(
     'Display priority. Lower values render first within the same parent. ' +
     'Used by themes that sort items algorithmically rather than by source order.',
   ),
   ```
2. `npm run bump:all`
3. Diff manuale di `apps/olonjs.io/public/schemas/v1/menu.schema.json`. Verificare che `definitions.MenuItem.properties.priority` sia presente.
4. Se l'output è verboso, sporco, o storto, **fixare lo Zod source**, non il JSON output.

## Flusso 2 — Aggiungere un nuovo schema canonico

> ⚠️ Ampliare il set di 5 canonici v1 è una decisione architetturale. Apri un nuovo ADR che superseda o estenda ADR-0003 §AD-5 prima di scrivere codice.

Sequenza tecnica:

1. Definire lo schema Zod in [`packages/core/src/contract/zod-schemas.ts`](../packages/core/src/contract/zod-schemas.ts). Convenzioni:
   - `.describe(...)` top-level ricco e Stripe-grade sullo schema esportato.
   - `.describe(...)` su ogni campo, con esempi inline (`e.g. \`/docs\``) dove utile.
   - Allineare i tipi a `kernel.ts` per i contratti già esistenti lì.

2. In [`scripts/bump-schemas.ts`](../scripts/bump-schemas.ts):
   - Import della nuova schema.
   - Aggiungere una entry in `resources[]`:
     ```ts
     {
       name: 'webhook',
       zod: WebhookConfigSchema,
       title: 'Olon Webhook Configuration',
       description: '...prosa enterprise-grade...',
       definitions: { /* schemi riusati 2+ volte o ricorsivi */ },
       crossRefs: { /* opzionale, solo per manifest thin */ },
       examples: [{ /* example completo */ }],
     }
     ```

3. `npm run bump:all`. Verificare il nuovo `apps/olonjs.io/public/schemas/v1/webhook.schema.json`.

4. Aggiornare l'ADR di riferimento, link in `CLAUDE.md`, eventuale entry su `olon.it/resources`.

## Flusso 3 — Convenzioni Zod source (gotcha)

Tre regole non ovvie. Violarle produce JSON Schema sporco. Tutti i dettagli in [ADR-0013](decisions/ADR-0013-v1-schemas-implementation.md) "Gotchas learned".

### Regola 1 — `.optional().describe()`, mai `.describe()` diretto su schema registrata in `definitions`

```ts
// ✅ corretto — emette $ref pulito
header: SectionSchema.optional().describe('Optional global header...'),

// ❌ rotto — emette decomposizione per-property:
//    { properties: { type: { $ref: '#/definitions/Section/properties/type' }, … } }
header: SectionSchema.describe('Optional global header...'),
```

`.optional()` preserva l'identità referenziale che `zod-to-json-schema` matcha. `.describe()` diretto crea un clone, la lib non lo riconosce, decompone per proprietà.

**Workaround** se il campo non è opzionale: lasciare la description top-level sulla schema definita, non aggiungerla al campo nell'usage.

### Regola 2 — `z.object({}).passthrough()`, mai `z.unknown()` per cross-ref placeholder

```ts
// ✅ corretto — il campo è required
design: z.object({}).passthrough(),

// ❌ rotto — il campo NON è required
design: z.unknown(),
```

`z.unknown()` accetta `undefined` → il campo non finisce in `required`. Per `tenant.schema.json` questo significa che `design`, `site`, `menu` sparirebbero da required, rompendo il contratto.

### Regola 3 — `definitions` solo per schemi riusati o ricorsivi (o per coerenza esplicita)

Quando registrare in `definitions: { … }`:
- **Sempre**: schemi ricorsivi (es. `MenuItem` via `children`) o usati 2+ volte nello stesso file di output (es. `Section` in site = header+footer, in page = items dell'array).
- **Per coerenza**: schemi single-use che però vogliamo siano renderizzati uguali in più file di output (es. `SiteIdentity` registrata sia in `site` che in `tenant`).
- **Mai**: single-use senza ragione di consistenza → lasciare inline.

## Test cycle minimo

```bash
npm run bump:all
git diff apps/olonjs.io/public/schemas/v1/
```

Se il diff è quello atteso, commit. Se è strano: **fix sullo Zod source**, non sull'output (ADR-0003 §AD-3).

## ADR di riferimento

- [ADR-0003](decisions/ADR-0003-jsonschema-as-public-contract-zod-as-internal-sot.md) — SOT Zod, contratto JSON Schema, review gate.
- [ADR-0013](decisions/ADR-0013-v1-schemas-implementation.md) — implementation v1, gotcha learned, conventions.
