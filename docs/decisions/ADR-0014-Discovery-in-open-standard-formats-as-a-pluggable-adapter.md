# ADR-0014: Discovery emitted in open-standard formats, as a pluggable adapter

## Status

Proposed

## Date

2026-05-29

## Context

An OlonJS tenant already emits an agent-facing discovery surface, but mostly in
custom shapes: a custom JSON-LD `additionalType: "mcp-manifest"`, an
`mcp-manifest.json` of `kind: "olonjs-mcp-manifest-index"`, alongside standard
`robots.txt`, `sitemap.xml` and `llms.txt`.

This forces an agent that already speaks the open standards to learn an OlonJS
dialect to discover what is, structurally, generic information.

A tenant is a site, not a running server: it cannot itself be an MCP server. It
can expose WebMCP tools from the browser. The discovery surface in scope here is
the static description an agent reads to find and orient on the site. The
authenticated operation surface (the OAuth-scoped MCP Gateway) lives in
`platform` and is out of scope.

A second force: today the full agent-readiness of a site depends on `platform`.
A plain core/OSS tenant has no standard discovery surface of its own. Discovery
is static, build-time information; there is no technical reason for it to be
coupled to `platform` or to the framework runtime.

This ADR is spawned by RFC #1 (Pillar 3 and Pillar 5).

## Decision

Express the tenant's static discovery surface in open standards rather than
custom `olonjs-*` formats, and emit it through a pluggable adapter rather than
logic hard-wired into the framework.

In scope for the tenant-site discovery surface:

- RFC 9309 robots (keep)
- Sitemaps protocol (keep)
- llms.txt convention (keep)
- schema.org JSON-LD, dropping the custom `additionalType`
- RFC 8288 HTTP `Link` headers
- RFC 9264 linkset
- MCP Server Card / SEP-2127, replacing the custom `olonjs-mcp-manifest-index`
- A2A `.well-known` card, retained alongside the MCP Server Card

The emitter is a pluggable adapter, able to run as a standalone tool, including
over a non-OlonJS site. Conformance target: the public agent-ready checklist
(isitagentready.com), passed on first deploy.

## Alternatives Considered

### Keep the custom `olonjs-*` formats

- Pros: no migration, already shipped.
- Cons: every agent must learn an OlonJS dialect for generic information; no
  interoperability with agents that already speak the standards.
- Why rejected: the custom shapes carry no value the standards don't, and they
  block interop.

### Replace A2A with the MCP Server Card

- Pros: one discovery protocol, less surface.
- Cons: bets on MCP winning the agentic-discovery race, which is undecided.
- Why rejected: both are projected from one source of truth, so carrying both
  costs little and avoids a premature bet. (Recorded as the hedge below.)

### Emit discovery inside the framework, not as an adapter

- Pros: simpler wiring, one less seam.
- Cons: couples a generic, portable capability to the framework; excludes the
  existing-site market that a standalone tool could serve.
- Why rejected: the discovery surface is the least lock-in part of the system
  by design; keeping it as an adapter is what lets it run without the framework.

### Include `api-catalog` (RFC 9727) and SVCB/HTTPS (RFC 9460)

- Pros: completes the standards list from the RFC's P2 table.
- Cons: both are platform/infra concerns. A tenant is a site, not an API host,
  and SVCB/HTTPS is DNS-level binding.
- Why rejected: out of scope for a tenant-site discovery surface; revisit as a
  `platform` decision if needed.

## Consequences

What becomes easier:

- An agent that speaks the standards needs no OlonJS-specific knowledge.
- Discovery stops depending on `platform`: a plain OSS tenant is agent-ready by
  construction.
- The adapter is the least lock-in part of the system, making it portable and
  the most open to outside contribution.

What becomes harder / new burden:

- The custom `additionalType` and `olonjs-mcp-manifest-index` are retired; any
  consumer relying on them must migrate.
- Carrying both A2A and the MCP Server Card is a deliberate hedge; the criterion
  for collapsing to one (a de facto winner emerging) is left to a future ADR.
- The emitter is generated per site at build time and is a build output, never
  committed.

## Follow-ups

- Extract the discovery emitter as the standalone adapter (RFC Phase 1).
- Define the projection of each standard artifact from the Model (depends on
  ADR-0015).
- Decide a criterion for collapsing A2A / MCP Server Card to one protocol.

## Decision Log

- 2026-05-29 — Initial draft, spawned by RFC #1.
