# Tenant — guida agli agenti

Documento operativo per chi lavora sul source di un tenant OlonJS (questo è `tenant-alpha`, ma vale per qualsiasi tenant generato dal CLI).

Il `CLAUDE.md` alla radice del monorepo descrive l'architettura di `@olonjs/core` e i protocolli del framework. Questo file copre invece le scelte che vivono **dentro al tenant**.

---

## Tre pacchetti, confini netti (ADR-0016)

Da [ADR-0016](../../docs/decisions/ADR-0016-core-react-studio-package-split.md) il vecchio bundle unico `@olonjs/core` (con lo split opt-in via subpath `/runtime` di [ADR-0009](../../docs/decisions/ADR-0009-core-studio-split-via-runtime-subpath.md), ora superato) è stato sostituito da tre pacchetti npm distinti, ciascuno con un confine chiaro:

| Pacchetto | Cosa contiene | Framework |
|---|---|---|
| `@olonjs/core` | Contratto, tipi, kernel MTRP, utility pure (`cn`, `withBasePath`, WebMCP, routing, schemi Zod base) | Nessuno — zero React a runtime |
| `@olonjs/react` | Engine di rendering: `JsonPagesEngine`, `PageRenderer`, contexts (`ConfigProvider`, `StudioProvider`, `OlonFormsContext`), hooks (`useConfig`, `useStudio`, `useFormState`) | React |
| `@olonjs/studio` | UI dell'editor: `AdminSidebar`, `FormFactory`, `StudioStage`, image/icon picker | React |

Il tenant dichiara tutti e tre come dipendenze dirette in `package.json` (workspace protocol in questo monorepo). Import statici da `@olonjs/core` (tipi, schema, utility) e da `@olonjs/react` (componenti/hook) coesistono nello stesso file senza alcun vincolo — non c'è più un "subpath giusto" da ricordare.

### Codice dell'editor: split automatico, zero configurazione tenant

A differenza del vecchio meccanismo opt-in via `/runtime` subpath, il code-splitting di Studio **non richiede più nessuna azione nel tenant**. `@olonjs/react`'s `JsonPagesEngine` fa internamente un dynamic `import('@olonjs/studio')` (vedi `StudioRoute` in `@olonjs/react`) solo quando la route `/admin`/`/admin/preview` viene effettivamente montata. Il tenant importa staticamente `JsonPagesEngine` da `@olonjs/react` ovunque, senza `lazy()`/`Suspense` manuali e senza gating su `window.location.pathname` in `App.tsx` — il bundler produce comunque un chunk separato per Studio.

Verificato su `tenant-alpha` con build reale (`npm run build`):
```bash
ls dist/assets/*.js
# index-<hash>.js          580 KB — main chunk del visitor, zero codice Studio
# olonjs-studio-<hash>.js  344 KB — Studio admin, caricato lazy solo su /admin

grep -c "AdminSidebar\|FormFactory\|StudioStage" dist/assets/index-*.js         # → 0
grep -c "AdminSidebar\|FormFactory\|StudioStage" dist/assets/olonjs-studio-*.js # → 1
```

### `src/types.ts` — augmentation singola, non più duale

Con lo split a tre pacchetti, `SectionDataRegistry`/`SectionSettingsRegistry`/`CollectionItemRegistry` (MTRP) sono dichiarate **una sola volta**, in `@olonjs/core`. Il vecchio problema del dual-augmentation (`@olonjs/core` vs `@olonjs/core/runtime` come module identifier distinti, footgun documentato nella vecchia versione di questo file) non esiste più:

```ts
declare module '@olonjs/core' {
  export interface SectionDataRegistry { /* tipi data delle sezioni */ }
  export interface SectionSettingsRegistry { /* tipi settings delle sezioni */ }
  export interface CollectionItemRegistry { /* tipi item delle collection */ }
}

export * from '@olonjs/core';
```

`@olonjs/react` e `@olonjs/studio` importano i tipi `Section`/`SectionType` direttamente da `@olonjs/core`, quindi l'augmentation del tenant si propaga automaticamente ovunque senza duplicazione.

### Riferimenti

- [ADR-0016](../../docs/decisions/ADR-0016-core-react-studio-package-split.md) — decisione architetturale corrente (tre pacchetti)
- [ADR-0009](../../docs/decisions/ADR-0009-core-studio-split-via-runtime-subpath.md) — meccanismo predecessore, superato
- `docs/ARCHITECTURE.md` § Build and Distribution Topology — vista architettura dei package

---

## Cloud mode (HotSave + Save2Repo)

Unica lettura env: `src/lib/tenantEnv.ts` → `cloudPolicy` (`resolveCloudPolicy` in `@olonjs/react`). Non leggere `import.meta.env` cloud altrove.

| Env | Boot | Studio save |
|---|---|---|
| Nessuna credenziale | locale | Local only |
| `VITE_OLONJS_CLOUD_URL` + `VITE_OLONJS_API_KEY` | **live** (SPP `/render`) | HotSave |
| + `VITE_SAVE2REPO=true` | **static** (JSON pubblicati) | HotSave **e** Cold/Save2Repo |

Alias: `VITE_JSONPAGES_CLOUD_URL` / `VITE_JSONPAGES_API_KEY`.

Regola: Save2Repo cambia solo il **boot** (live → static). Non spegne HotSave.
