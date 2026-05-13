# ADR-003: Sitemap Generation via Prebuild Script

## Status
Accepted

## Date
2026-05-13

## Context
Il tenant OlonJS espone pagine pubbliche che devono essere indicizzate sia da crawler
SEO tradizionali (Google, Bing) sia da agenti AI (llms.txt, mcp-manifest.json).
Serve un `sitemap.xml` generato deterministicamente dalla fonte dati canonica
(`src/data/pages/*.json`) a ogni build.

OlonJS è AI-native per contratto: il sitemap deve riflettere questa natura esponendo
tre livelli per pagina (Human UI, Machine Payload, Machine Contract Schema) e due nodi
di discovery globale per agenti.

## Decision

Script ESM standalone `scripts/sitemap.mjs`, agganciato al `prebuild`, che:

1. Legge tutte le pagine da `src/data/pages/**/*.json` ricorsivamente
2. Ricava `baseUrl` da `VERCEL_PROJECT_PRODUCTION_URL` (production) o `localhost:5173` (locale)
3. Emette in testa i Global Agent Discovery Nodes (`/llms.txt`, `/mcp-manifest.json`)
   con `priority 1.0` e `lastmod` = timestamp di build
4. Per ogni slug emette tre `<url>`:
   - Human UI: `/<slug-or-root>` — `changefreq daily`, `priority 0.9`
   - Machine Payload: `/<slug>.json` — `changefreq daily`, `priority 0.9`
   - Machine Contract: `/schemas/<slug>.schema.json` — `changefreq weekly`, `priority 0.8`
5. `lastmod` pagine = `fs.statSync(filePath).mtime.toISOString()`
6. Scrive `public/sitemap.xml`

Il slug `home` viene mappato alla root `/` per l'URL Human UI.

## Alternatives Considered

### Generazione a runtime (server-side / edge function)
- Pro: `lastmod` sempre aggiornato
- Contro: introduce dipendenza server; il tenant è un SPA statico su Vercel
- Rifiutato: complessità sproporzionata

### Plugin Vite per sitemap
- Pro: integrazione nativa nel build graph
- Contro: dipendenza npm aggiuntiva per ~50 righe di codice; gli script esistenti
  usano già il pattern `node scripts/*.mjs` nel prebuild
- Rifiutato: inconsistente con i pattern del tenant

### Sitemap solo per Human UI (no Machine endpoints)
- Pro: più semplice
- Contro: tradisce il contratto AI-native di OlonJS — il sitemap è anche un artefatto
  di discovery per agenti, non solo per Googlebot
- Rifiutato: incompatibile con la filosofia del framework

## Consequences
- `public/sitemap.xml` viene rigenerato ad ogni `npm run build`
- I nodi Machine Payload e Machine Contract assumono che i file `.json` e `.schema.json`
  siano effettivamente serviti da Vercel (dipendenza da `sync-pages-to-public.mjs`)
- In ambienti CI/CD dove `git checkout` azzera i `mtime`, il `lastmod` delle pagine
  rifletterà la data del checkout, non della vera ultima modifica — comportamento
  accettato e documentato
- Ogni nuova pagina aggiunta in `src/data/pages/` appare automaticamente nel sitemap
  senza intervento manuale
