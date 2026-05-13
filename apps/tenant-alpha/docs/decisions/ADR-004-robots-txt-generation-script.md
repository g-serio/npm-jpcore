# ADR-004: robots.txt Generation via Prebuild Script

## Status
Accepted

## Date
2026-05-13

## Context
Il tenant espone un `public/robots.txt` statico che non conteneva il `Sitemap:` URL
corretto per ogni ambiente (production vs locale) e non dichiarava esplicitamente le
policy per i principali AI crawler (GPTBot, ClaudeBot, PerplexityBot, ecc.).

Con l'introduzione di `sitemap.mjs` (ADR-003), il `Sitemap:` URL è ora dipendente da
`baseUrl` — variabile d'ambiente risolta a build time. Il `robots.txt` statico non può
più essere mantenuto manualmente senza rischio di desync.

## Decision

Script ESM standalone `scripts/robots.mjs`, agganciato in fondo al `prebuild` (dopo
`sitemap.mjs`), che:

1. Ricava `baseUrl` da `VERCEL_PROJECT_PRODUCTION_URL` (production) o `localhost:5173` (locale)
2. Genera una stringa `robots.txt` con due blocchi distinti:
   - **Standard crawlers** (`User-agent: *`): `Allow: /`, `Disallow: /api/`
   - **AI crawlers** (GPTBot, ChatGPT-User, ClaudeBot, Claude-Web, PerplexityBot,
     OAI-SearchBot): accesso esplicito a `/`, `/*.json`, `/schemas/`, `/llms.txt`,
     `/mcp-manifest.json`; `Disallow: /api/`
3. Appende `Sitemap: ${baseUrl}/sitemap.xml`
4. Sovrascrive `public/robots.txt`

Il contenuto è identico per tutti i tenant — varia solo `baseUrl`.

## Alternatives Considered

### Mantenere `robots.txt` statico con URL hardcoded
- Pro: zero codice
- Contro: il `Sitemap:` URL sarebbe sbagliato in locale e nei deploy preview;
  richiede aggiornamento manuale a ogni cambio dominio
- Rifiutato: fonte di errori silenziosi e desync con `sitemap.mjs`

### Generare `robots.txt` come parte di `sitemap.mjs`
- Pro: un file solo
- Contro: viola il principio una-responsabilità-per-script; rende lo script meno
  leggibile e più difficile da testare isolatamente
- Rifiutato: i due artefatti hanno cicli di vita distinti

### Plugin Vite per robots.txt
- Pro: integrazione nativa nel build graph
- Contro: dipendenza aggiuntiva per ~20 righe di codice
- Rifiutato: inconsistente con i pattern del tenant

## Consequences
- `public/robots.txt` è ora un artefatto generato — non va modificato manualmente
- I permessi per gli AI crawler sono dichiarati esplicitamente, coerentemente con la
  natura AI-native di OlonJS
- Il link `Sitemap:` è sempre sincronizzato con l'URL effettivo del deploy
- Ogni modifica alla policy crawler richiede un edit a `scripts/robots.mjs` e un
  rebuild — non è un problema per un file che cambia raramente
