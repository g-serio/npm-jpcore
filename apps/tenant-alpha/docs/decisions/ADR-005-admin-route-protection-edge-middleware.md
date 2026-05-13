# ADR-005: Admin Route Protection via Vercel Edge Middleware

## Status
Superseded by ADR-006

## Date
2026-05-13

## Context
La route `/admin` del tenant è attualmente pubblica — chiunque conosca l'URL può
accedere allo Studio OlonJS. Il tenant è una SPA statica deployata su Vercel.

Requisiti:
- In locale (Vite dev server) `/admin` deve restare accessibile senza autenticazione
- In deploy (Vercel) `/admin` deve essere protetta con un bearer token
- Il token segreto non deve mai finire nel bundle JS del client
- L'accesso autenticato viene avviato da `jsonpages-platform` (dashboard esterna)
  che inietta il bearer nell'header della richiesta

## Decision

**Vercel Edge Middleware** (`middleware.ts` alla radice del tenant) che:

1. Intercetta tutte le richieste a `/admin` e `/admin/*` a livello di Edge Network
2. È attivo solo quando `process.env.VERCEL_ENV` è presente (deploy Vercel)
3. In assenza di `VERCEL_ENV` (locale Vite) — non esiste → `/admin` libera
4. Legge l'header `Authorization: Bearer <token>`
5. Confronta il token con `ADMIN_TOKEN` env var (secret Vercel, mai nel bundle)
6. Match → lascia passare la richiesta
7. No match o header assente → risponde `401 Unauthorized`

Il confronto è time-safe (`timingSafeEqual` via `crypto` Web API) per prevenire
timing attacks.

### Env var richiesta sul progetto Vercel
```
ADMIN_TOKEN=<stringa-casuale-lunga>
```

### Configurazione `vercel.json` (opzionale, per chiarezza)
Il middleware copre già `/admin` per matching path — nessuna configurazione
aggiuntiva necessaria se il file è alla radice.

## Alternatives Considered

### Client-side React guard
- Pro: zero infrastruttura, puro codice tenant
- Contro: il token deve essere nel bundle o in `localStorage` — visibile al browser,
  bypassabile con DevTools. Protezione cosmetica, non reale.
- Rifiutato: sicurezza non accettabile

### Vercel native Password Protection
- Pro: zero codice
- Contro: protegge l'intero deploy (non solo `/admin`), UX non personalizzabile,
  non supporta bearer token programmatici
- Rifiutato: incompatibile con il requisito di proteggere solo `/admin` e con il
  flusso di accesso da jsonpages-platform

### Vercel serverless function come proxy
- Pro: protezione reale
- Contro: aggiunge latenza, complessità di routing, modifica l'architettura del tenant
  da statico a ibrido
- Rifiutato: Edge Middleware è più leggero e non cambia il modello di deploy

## Consequences
- `middleware.ts` è un file tenant — va incluso nel DNA template e nel `dist` script
- In locale il middleware non esiste → il test della protezione si fa solo su deploy
- `ADMIN_TOKEN` deve essere configurato come env var secret su ogni progetto Vercel
  tenant; se assente il middleware nega tutto l'accesso admin in produzione
- Il token è una stringa condivisa (pre-shared key) — non supporta utenti multipli
  con token distinti (fuori scope per v1)
- L'accesso da `jsonpages-platform` richiede che la platform conosca il token del
  tenant (configurato nella card Settings del progetto in platform)

## See Also
- ADR corrispondente in `jsonpages-platform` — UI accesso admin e gestione chiave
