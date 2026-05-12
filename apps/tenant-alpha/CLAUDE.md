# Tenant — guida agli agenti

Documento operativo per chi lavora sul source di un tenant OlonJS (questo è `tenant-alpha`, ma vale per qualsiasi tenant generato dal CLI).

Il `CLAUDE.md` alla radice del monorepo descrive l'architettura di `@olonjs/core` e i protocolli del framework. Questo file copre invece le scelte che vivono **dentro al tenant**.

---

## Split runtime/Studio — meccanismo di ottimizzazione opt-in

### Cosa è

Il pacchetto `@olonjs/core` espone due subpath con semantica distinta a runtime:

| Subpath | Cosa contiene | Peso |
|---|---|---|
| `@olonjs/core/runtime` | Engine visitor, hooks, schemi DNA, primitive di rendering | ~28 KB gz |
| `@olonjs/core` | Tutto il runtime + Studio admin (AdminSidebar, FormFactory, StudioStage, image picker, ecc.) | ~128 KB gz |

I due subpath sono **sempre disponibili**. Il tenant sceglie come consumarli.

### Perché esiste

Prima di [ADR-0009](../../docs/decisions/ADR-0009-core-studio-split-via-runtime-subpath.md), `@olonjs/core` era un bundle unico. Un tenant che importava `JsonPagesEngine` per montare Studio si trascinava nel main chunk del visitor anche tutto il codice dell'editor — ~100 KB gz di `AdminSidebar`, `FormFactory`, `StudioStage`, image picker — che il visitor non eseguirà mai (non andrà mai su `/admin`).

Misurato su `radice.olon.it` durante la migrazione del 2026-05-10:
- **Senza split** (full bundle inlined): visitor scarica **274 KB gz** di JS totali, di cui ~100 KB sono Studio admin morto sul critical path
- **Con split attivato**: visitor scarica **174 KB gz**; i 100 KB di Studio si caricano lazy SOLO quando uno naviga effettivamente su `/admin`

Lo split è quindi un **meccanismo di ottimizzazione**: il pacchetto te lo offre, il tenant decide se attivarlo.

### Quando ti conviene attivarlo

Sì se:
- È un sito pubblico (marketing, landing, ecommerce, blog, qualsiasi traffico SEO-sensitive)
- La maggioranza dei visitor non è admin (cioè quasi sempre — 99%+ degli utenti reali sull'1% di sessioni admin)
- Lighthouse / TTI / costo di rendering mobile contano per il business

No se:
- Tool interno admin-heavy dove ogni utente è admin
- Prototipo o spike dove la performance non importa
- Caso edge dove vuoi il binario unico per altri motivi

Se non attivi lo split, **non rompi nulla**: continua a funzionare con `import { JsonPagesEngine } from '@olonjs/core'` statico ovunque, paghi solo i ~100 KB gz extra sul visitor.

### Come si attiva

Tre pezzi devono allinearsi. Se uno solo manca, lo split esiste in source ma collassa a runtime.

**1. `src/App.tsx` — gating lazy su `/admin`**

```tsx
import { lazy, Suspense } from 'react';
import { OlonJSEngine } from '@olonjs/core/runtime';   // statico, runtime-only

const isAdminPath =
  typeof window !== 'undefined' && window.location.pathname.startsWith('/admin');

const LazyJsonPagesEngine = lazy(() =>
  import('@olonjs/core').then((m) => ({ default: m.JsonPagesEngine })),
);

return isAdminPath
  ? <Suspense fallback={null}><LazyJsonPagesEngine config={config} /></Suspense>
  : <OlonJSEngine config={config} />;
```

**2. `src/types.ts` — dual augmentation MTRP**

TypeScript tratta `'@olonjs/core'` e `'@olonjs/core/runtime'` come module identifier distinti. Augmentando solo uno dei due, l'altro vede `PageConfig.sections` come `FallbackSection[]` generico e il typecheck fallisce al confine `<LazyJsonPagesEngine config={config} />`.

```ts
declare module '@olonjs/core' {
  export interface SectionDataRegistry { /* tipi data delle sezioni */ }
  export interface SectionSettingsRegistry { /* tipi settings delle sezioni */ }
}

declare module '@olonjs/core/runtime' {
  export interface SectionDataRegistry { /* stesso elenco identico */ }
  export interface SectionSettingsRegistry { /* stesso elenco identico */ }
}

export * from '@olonjs/core/runtime';
```

I due blocchi sono volutamente identici. TypeScript fa interface-merging per module identifier, non c'è scorciatoia DRY: aggiungere una sezione è una modifica in due posti.

Il `export * from '@olonjs/core/runtime'` (non da `@olonjs/core`) è un re-export di valori. Vite tratta `export *` come edge runtime nel grafo dipendenze, e puntarlo al full bundle riporterebbe Studio admin nel chunk del visitor.

**3. Tutti gli altri file tenant — import statici da `/runtime`**

Ogni `src/components/*/schema.ts`, `src/components/*/types.ts`, `src/lib/*.ts`, `src/entry-ssg.tsx`, eccetera — quando importano staticamente da `@olonjs/core`, lo fanno da `@olonjs/core/runtime`.

Il vincolo deriva dal modo in cui Vite/Rollup costruisce il grafo: se un file qualsiasi del tenant fa `from '@olonjs/core'` staticamente (anche un `import type`), Vite vede una rotta statica al full bundle, lo inlinera nel main chunk, e il `lazy()` di App.tsx perde il suo effetto. Vite emette un warning giallo:

```
@olonjs/core/dist/olonjs-core.js is dynamically imported by App.tsx
but also statically imported by … schema.ts, … types.ts.
dynamic import will not move module into another chunk.
```

Il warning è facile da non vedere ed è la firma più comune di uno split rotto.

### Smoke test post-build

Tre check rapidi per confermare che lo split è davvero attivo:

```bash
# 1. Nessun import statico al full bundle
grep -rln "from '@olonjs/core'" src/
# Dovrebbe restituire solo:
#   - src/types.ts  (per la declare module verso @olonjs/core)
#   - src/App.tsx   (per il dynamic import('@olonjs/core') nel lazy())
# Niente altro.

# 2. Almeno due chunk JS distinti emessi dalla build
ls dist/assets/*.js
# Almeno due nomi diversi: il main del visitor + un chunk lazy
# (tipicamente nominato olonjs-core-<hash>.js o simile).
# Un chunk solo = lo split non è effettivo.

# 3. Browser Network tab dopo deploy/preview
# Visitando /  → si carica solo il main chunk
# Visitando /admin → compare un chunk JS aggiuntivo (~70-130 KB gz tipici)
# Stesso file su entrambe le route = lo split non sta splittando.
```

### Riferimenti

- [ADR-0009](../../docs/decisions/ADR-0009-core-studio-split-via-runtime-subpath.md) — decisione architetturale e razionale
- [ADR-0012](../../docs/decisions/ADR-0012-externalize-runtime-from-full-bundle.md) — meccanismo di dedup dei singleton React fra i due bundle (questa è invariante package-level, non tenant-level)
- `docs/ARCHITECTURE.md` § Build and Distribution Topology — vista architettura del package
