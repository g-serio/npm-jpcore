# ADR-006: Admin Route Protection via EC P-256 JWT Verification

## Status
Accepted — Supersedes ADR-005

## Date
2026-05-13

## Context
ADR-005 proteggeva `/admin` con un pre-shared key (PSK): un token statico confrontato
con `ADMIN_TOKEN` env var. Il modello PSK presenta un limite architetturale critico:
chiunque intercetti il token (query param, log Vercel, proxy) ottiene accesso illimitato
nel tempo — non c'è scadenza né legame crittografico all'identità del chiamante.

La piattaforma (`jsonpages-platform`) gestisce chiavi per conto di tenant diversi.
Il modello PSK richiede di condividere il segreto tra i due sistemi in forma leggibile;
se la colonna `admin_token` in Supabase viene letta, tutti i tenant sono compromessi
con la stessa operazione.

Si è scelto di passare a crittografia asimmetrica per isolare il rischio per-tenant
e introdurre token con scadenza breve.

## Decision

**Algoritmo:** ECDSA P-256 (ES256 nel vocabolario JWT).

**Keypair per-tenant:**
- La **private key** (PEM) è generata dalla platform e memorizzata in Supabase nella
  colonna `tenants.admin_private_key`. Non lascia mai il server platform.
- La **public key** (PEM, formato `-----BEGIN PUBLIC KEY-----`) è configurata come
  env var `ADMIN_PUBLIC_KEY` sul progetto Vercel del tenant.

**Token:** JWT standard (header.payload.signature, tutto base64url).
- `alg: ES256`, `typ: JWT`
- Payload: `{ sub: "admin-access", iat: <unix>, exp: <iat + 300> }` (scadenza 5 minuti)

**Flusso di accesso:**
1. L'utente clicca "Admin" nella platform
2. Il browser chiama `POST /api/v1/tenants/:id/admin-token` (server platform)
3. Il server legge `admin_private_key` da Supabase, firma il JWT ES256
4. Restituisce `{ token: "<jwt>" }` al browser
5. Il browser apre `<tenantPublicUrl>/admin?token=<jwt>`
6. Edge Middleware importa `ADMIN_PUBLIC_KEY` come CryptoKey via Web Crypto API
7. Verifica la firma ES256 e il campo `exp`
8. Se valido → session cookie httpOnly (1h) + redirect `/admin` senza token in URL
9. Altrimenti → 401

**Env var richiesta sul progetto Vercel del tenant:**
```
ADMIN_PUBLIC_KEY=-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYFK4EEACIDQgAE...
-----END PUBLIC KEY-----
```

**Cookie di sessione:** `__olonjs_admin_session`
- Valore: il JWT originale (rivalidato ad ogni richiesta a `/admin/*`)
- httpOnly, Secure, SameSite=Strict, Max-Age=3600

## Alternatives Considered

### Mantenere PSK (ADR-005)
- Pro: zero crittografia, implementazione triviale
- Contro: token statico senza scadenza; condivisione del segreto tra sistemi;
  compromissione del DB Supabase espone tutti i tenant simultaneamente
- Superato: il modello PSK non soddisfa i requisiti di isolamento per-tenant

### RSA-PSS (RS256) invece di EC P-256 (ES256)
- Pro: standard consolidato, ampia letteratura
- Contro: chiavi 2048-bit (>1KB PEM), token più grandi, operazioni più lente;
  nessun vantaggio pratico per questo use case
- Rifiutato: EC P-256 è equivalente per sicurezza con 10x meno bytes di chiave

### Global platform keypair (chiave condivisa tra tutti i tenant)
- Pro: zero gestione per-tenant, un solo segreto da ruotare
- Contro: se la chiave platform viene compromessa, TUTTI i tenant sono accessibili;
  non c'è isolamento tra tenant diversi
- Rifiutato: il requisito era per-tenant isolation

### Token con lunga scadenza (es. 24h)
- Pro: meno richieste di firma
- Contro: finestra di exploit più ampia se il JWT viene intercettato
- Rifiutato: 5 minuti è sufficiente per il caso d'uso (accesso interattivo da UI)

## Consequences
- `middleware.ts` usa Web Crypto API (`crypto.subtle.importKey` + `crypto.subtle.verify`)
  — disponibile nell'Edge Runtime senza dipendenze aggiuntive
- `ADMIN_TOKEN` env var (ADR-005) non viene più usata; sostituita da `ADMIN_PUBLIC_KEY`
- La rotazione della chiave richiede: rigenerare keypair in platform, aggiornare
  `ADMIN_PUBLIC_KEY` su Vercel, ridepployare il tenant
- Un JWT intercettato è valido al massimo 5 minuti (vs. infinito con PSK)
- Il cookie di sessione è ancora 1h — compromissione del cookie è un vettore separato,
  mitigato da httpOnly + Secure + SameSite=Strict

## See Also
- ADR-005 (superseded) — approccio PSK precedente
- ADR-002 in `jsonpages-platform` — generazione keypair, endpoint di firma, UI platform
