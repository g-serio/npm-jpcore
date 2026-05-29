# ADR-0015: The Model — swamp models as the projection source of truth

## Status

Accepted

## Date

2026-05-29

## Context

RFC #1 (Pillar 1) proposes promoting a section's non-view artifacts to a single
declarative Model that is the source of truth, from which schema, types, index
and the view frame are projected rather than scaffolded once. The open question
the RFC raised was "what exactly is the Model, and in what language?".

For OlonJS that question is already answered. Core uses Zod schemas as its
contract layer. swamp models are Zod. There is no third schema language to
introduce and no translation layer between the Model and the schemas core
already consumes: a swamp model *is* a Zod schema. Expressing the OlonJS
ontology (section, page, theme) as swamp models is therefore a relatively
straightforward port, not a re-encoding.

This makes the Model a swamp model, and the projection engine a swamp-based
one. That is a deliberate dependency on swamp (System Initiative, AGPLv3),
taken as an explicit bet for the benefit of core.

## Decision

The Model of Pillar 1 is a **swamp model**. swamp is the projection engine.

Because swamp models are Zod and core is already Zod, the Model is the single
source of truth and the projected artifacts (schema, inferred types, index
re-exports, the view frame, the discovery manifests, the agent manual) are
recomputed from it every build. No schema-language boundary is crossed in the
projection.

## Alternatives Considered

### Invent a new Model meta-schema above Zod

- Pros: no external dependency; full control of the format.
- Cons: adds a new protocol surface above Zod, the exact adoption barrier the
  RFC warns about; duplicates what Zod already expresses.
- Why rejected: a new SOT above Zod is more to learn, not less, and swamp
  already provides a Zod-native model.

### Use swamp models but keep a separate hand-authored Zod layer

- Pros: looser coupling to swamp.
- Cons: two schema sources that can drift; reintroduces P1 in a new place.
- Why rejected: swamp models are Zod, so a separate layer is redundant and
  drift-prone.

### Do not adopt swamp; build projection in-house

- Pros: no third-party, pre-1.0 dependency.
- Cons: rebuilds models, definitions, workflows and the typed projection that
  swamp already provides, Zod-native.
- Why rejected: the in-house cost is high and the swamp dependency is a bet we
  accept for the benefit of core (see Consequences).

## Consequences

What becomes easier:

- The Model is Zod-native end to end; the port of the OlonJS ontology into swamp
  is straightforward, with no translation or impedance mismatch.
- Templates stop being cloned apps and become sets of Models (resolves P1).
- Projection (schema, types, index, frame, manifests, manual) is recomputed
  from one source and cannot drift.

What becomes harder / the bet:

- core takes a dependency on swamp (System Initiative, AGPLv3, pre-1.0). The
  projection engine lives on swamp; swamp's evolution is now core's concern.
- This is a second, intentional lock-in (core → swamp), distinct from the
  framework's tenant-facing lock-in noted in the RFC. It is accepted as an
  explicit bet for the benefit of core, not hidden.
- Projected artifacts are build outputs, never committed.

## Follow-ups

- Model granularity for sections (one polymorphic section Model vs one per
  section type).
- The frame/slot projection and IDAC binding (ADR for Pillar 2).
- The authoring-permission model enforced in swamp (ADR for Pillar 4).

## Decision Log

- 2026-05-29 — Initial draft, spawned by RFC #1. Dependency on swamp accepted
  as an explicit bet; Zod↔Model is not an open question (swamp models are Zod).
