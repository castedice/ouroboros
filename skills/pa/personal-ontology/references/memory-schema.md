---
name: memory-schema
description: This reference defines the PA memory-layer storage contract for atomic facts, fact-to-fact links, and the active fact materialization. It should be consulted when an agent needs to "write atomic facts from notes", "persist fact links", "rebuild memory-heads.json", "normalize claim keys", or "trace a fact back to its source note".
---

# Memory Schema

> Purpose: Reference for `personal-ontology` and the weaver's refresh flow.
> Use it to store note-grounded atomic facts without replacing QMD as the note retrieval engine.

## File Set

| File | Role | Write Pattern |
|------|------|---------------|
| `.pa/memories.jsonl` | Append-only atomic fact log | Append new claim versions |
| `.pa/memory-links.jsonl` | Append-only fact-to-fact edges | Append new evidence links |
| `.pa/memory-heads.json` | Active and contested fact materialized view | Rebuild from `memories.jsonl` |

## `.pa/memories.jsonl`

Each line is one fact version.
Facts are atomic claims about one resolved entity.
Only extract claims with clear source evidence.

| Field | Meaning |
|------|---------|
| `claim_key` | Canonical fact identifier such as `person:alice:job:google` |
| `subject_id` | Entity id from `entities.json` |
| `predicate` | Relationship or attribute such as `works_at`, `lives_in`, `born_on`, `prefers` |
| `object` | Literal value or entity reference |
| `source_note` | Vault note path where the fact was found |
| `document_date` | Artifact date for the source note |
| `event_dates` | Array of `{start, end, precision}` objects for real-world time grounding |
| `confidence` | Fact confidence on `0.0` to `1.0` |
| `state` | `active`, `superseded`, `contested`, or `retracted` |
| `derived_from` | Array of source `claim_key` values when this fact is inferred from others |

`event_dates[].precision` follows `skills/pa/content-pipeline/references/temporal-grounding.md`.
Leave `event_dates` empty when no grounded event time is available.
Leave `derived_from` empty for directly observed facts.

Example:

```jsonl
{"claim_key":"person:alice:job:google","subject_id":"e-person-alice","predicate":"works_at","object":"entity:e-org-google","source_note":"people/alice.md","document_date":"2026-03-20","event_dates":[{"start":"2026-03-01","end":"2026-03-01","precision":"day"}],"confidence":0.92,"state":"active","derived_from":[]}
```

## `.pa/memory-links.jsonl`

Each line connects one fact to another fact.
Use these links to record reinforcement, conflict, replacement, or explicit derivation.

| Field | Meaning |
|------|---------|
| `source_claim` | Upstream `claim_key` |
| `target_claim` | Downstream `claim_key` |
| `relation` | `supports`, `contradicts`, `supersedes`, or `derives` |
| `evidence` | Source note path or short reasoning note |
| `confidence` | Link confidence on `0.0` to `1.0` |
| `created_at` | ISO 8601 timestamp |

Store `derives` only when two or more grounded facts explicitly combine into the derived claim.

Example:

```jsonl
{"source_claim":"person:alice:job:google","target_claim":"person:alice:work_city:mountain-view","relation":"derives","evidence":"Combined with org:google:location:mountain-view","confidence":0.75,"created_at":"2026-03-29T12:00:00+09:00"}
```

## `.pa/memory-heads.json`

This file is a materialized view for fast lookup.
It maps each `claim_key` to the latest non-superseded claim version.
Rebuild it from `memories.jsonl` instead of editing it directly.

Each head keeps this compact shape:

| Field | Meaning |
|------|---------|
| `claim_key` | Canonical fact identifier |
| `subject_id` | Entity id |
| `predicate` | Fact predicate |
| `object` | Literal or entity reference |
| `confidence` | Active confidence |
| `source_note` | Latest active source note |

Example:

```json
{
  "person:alice:job:google": {
    "claim_key": "person:alice:job:google",
    "subject_id": "e-person-alice",
    "predicate": "works_at",
    "object": "entity:e-org-google",
    "confidence": 0.92,
    "source_note": "people/alice.md"
  }
}
```

## Write Rules

- `memories.jsonl` and `memory-links.jsonl` are assistant-owned append logs in `.pa/`.
- `memory-heads.json` is the fast lookup view and can always be regenerated from the fact log.
- Extract only direct attributes, relationships, states, and preferences from notes.
- Do not create memory facts from semantic similarity, tone, or weak implication alone.
- When a fact is inferred, keep the source claims in `derived_from` and add `derives` links from each source claim to the new claim.
- When two facts contradict, resolve them using `skills/pa/personal-ontology/references/contradiction-resolution.md`.
- Keep unresolved ties as `state: "contested"` so review consumers can surface them instead of hiding them.
