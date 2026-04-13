# Proposition Schema

This schema is the research-spike contract for a proposition knowledge base.
It is intentionally small and should stay easy to inspect by hand.

## Record Shape

Each proposition is one JSON object in `propositions.jsonl`.

```json
{
  "proposition_id": "prop_001",
  "claim_text": "session-archive uses SQLite FTS5",
  "asp_encoding": "fact(prop_001, \"session-archive uses SQLite FTS5\").",
  "source_hash": "sha256:abc123",
  "source_ref": "skills/core/session-archive/SKILL.md:12",
  "confidence": "high",
  "kind": "direct",
  "depends_on": [],
  "status": "active",
  "created_at": "2026-04-13T00:00:00Z",
  "invalidated_at": null,
  "invalidation_reason": null
}
```

## Fields

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `proposition_id` | string | yes | Unique identifier within the KB |
| `claim_text` | string | yes | Natural-language claim preserved for human review |
| `asp_encoding` | string | yes | ASP fact representation of the claim |
| `source_hash` | string | yes | `sha256:<hex>` hash of the source document or segment |
| `source_ref` | string | yes | Path, URL, or segment id for the evidence |
| `confidence` | enum | yes | `high`, `medium`, or `low` |
| `kind` | enum | yes | `direct` when extracted from source, `derived` when inferred from other propositions |
| `depends_on` | string array | yes | Proposition ids that this proposition depends on |
| `status` | enum | yes | `active`, `invalidated`, or `superseded` |
| `created_at` | ISO timestamp | yes | UTC creation timestamp |
| `invalidated_at` | ISO timestamp or null | yes | UTC invalidation timestamp when inactive |
| `invalidation_reason` | string or null | yes | Human-readable reason for invalidation |

## Field Rules

- `proposition_id` must be stable after creation.
- `claim_text` must remain close enough to the source that a reviewer can verify it.
- `asp_encoding` is a projection used for checks and can be regenerated from structured fields.
- `source_hash` should hash the exact source segment when segment-level evidence exists.
- `source_ref` should be precise enough to retrieve the evidence without search.
- `confidence` is about grounding strength, not solver satisfiability.
- `kind=direct` means the claim is stated in the source.
- `kind=derived` means the claim follows from other propositions or a named inference rule.
- `depends_on` drives cascade invalidation.
- `status=invalidated` means consumers should ignore the proposition for active reasoning.
- `status=superseded` means a newer proposition replaced this one without necessarily making it false.

## ASP Encoding

Minimal generated facts should include identity, claim, source, confidence, kind, status, and dependencies.

```prolog
proposition(prop_001).
fact(prop_001, 'session-archive uses SQLite FTS5').
source(prop_001, 'sha256:abc123').
source_ref(prop_001, 'skills/core/session-archive/SKILL.md:12').
confidence(prop_001, high).
kind(prop_001, direct).
status(prop_001, active).
depends(prop_002, prop_001).
```

Use `contradicts/2` for explicit contradiction edges.

```prolog
contradicts(prop_010, prop_011).
```

The minimal contradiction constraint is:

```prolog
:- fact(P1, C1), fact(P2, C2), contradicts(P1, P2).
```

In practice, prefer a named derived predicate so solver output can explain the failure.

```prolog
active(P) :- proposition(P), status(P, active).
contradiction(P1, P2) :- active(P1), active(P2), contradicts(P1, P2).
:- contradiction(P1, P2).
#show contradiction/2.
```

## Integrity Constraints

Missing dependency:

```prolog
missing_dependency(P, D) :- active(P), depends(P, D), not proposition(D).
:- missing_dependency(P, D).
#show missing_dependency/2.
```

Invalidated dependency:

```prolog
invalid_dependency(P, D) :- active(P), depends(P, D), status(D, invalidated).
:- invalid_dependency(P, D).
#show invalid_dependency/2.
```

Derived proposition with no dependencies:

```prolog
has_dependency(P) :- depends(P, _).
unsupported_claim(P) :- active(P), kind(P, derived), not has_dependency(P).
#show unsupported_claim/1.
```

Duplicate active claim warning:

```prolog
duplicate_claim(P1, P2, C) :- active(P1), active(P2), fact(P1, C), fact(P2, C), P1 < P2.
#show duplicate_claim/3.
```

## Cascade Invalidation

Cascade invalidation is graph-based.
When `prop_001` is invalidated, every active proposition that depends on `prop_001` is invalidated, then the same rule repeats for dependents of those propositions.

Do not invalidate by semantic similarity.
If a proposition should cascade but no edge exists, add the missing dependency with evidence before relying on the cascade.

## Research-Spike Boundaries

This schema is not a production ontology.
It is a small bridge between source-grounded claims and ASP integrity checks.
Use `/rnd` to validate whether ASP, LOGIC-LM, or a hybrid approach should become the production design.
