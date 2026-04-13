---
name: life-entity-examples
description: This reference provides worked examples and relation examples for life-facing entities in the PA ontology. It should be consulted when an agent needs to "inspect complete life entity records" or "see example relations between life entities".
---

# Life Entity Examples - Worked Entities and Relations

> Purpose: Example companion for `personal-ontology` - use it to inspect complete life-entity records and relation examples.
> This reference is standalone and can be consulted without the parent skill.
> For the schema contract and quantified rules, see `life-entity-schema.md`.
> For pitfalls, rationale, and final checks, see `life-entity-review.md`.
> For the main extraction workflow, see `skills/pa/personal-ontology/SKILL.md`.

## Worked Examples

Assume the sample user has `confidence.identity = 0.80`, `confidence.direction = 0.65`, and `confidence.focus = 0.55`.
Assume the quarter goal has one reinforcing wikilink in one distinct note.
Assume the `3y` goal has two reinforcing wikilinks in distinct notes and one dedicated `canonical_note`.
The example below shows one complete life-entity set for a user trying to build an independent but sustainable life.

### Area Entities

#### `area` - `career`

```json
{
  "canonical_name": "career",
  "kind": "area",
  "ontology_family": "life",
  "canonical_source": "identity.core_areas[0]",
  "confidence": 0.8,
  "provenance": "survey-2026-03-18",
  "first_seen": "2026-03-18T09:00:00+09:00"
}
```

#### `area` - `health`

```json
{
  "canonical_name": "health",
  "kind": "area",
  "ontology_family": "life",
  "canonical_source": "identity.core_areas[1]",
  "confidence": 0.8,
  "provenance": "survey-2026-03-18",
  "first_seen": "2026-03-18T09:00:00+09:00"
}
```

#### `area` - `finance`

```json
{
  "canonical_name": "finance",
  "kind": "area",
  "ontology_family": "life",
  "canonical_source": "identity.core_areas[2]",
  "confidence": 0.8,
  "provenance": "survey-2026-03-18",
  "first_seen": "2026-03-18T09:00:00+09:00"
}
```

### Goal Entities

#### `goal` - Quarter goal

```json
{
  "canonical_name": "Publish one flagship case study and reach out to 10 aligned leads",
  "kind": "goal",
  "ontology_family": "life",
  "canonical_source": "focus.current_focus[0]",
  "horizon": "quarter",
  "status": "active",
  "confidence": 0.7,
  "provenance": "survey-2026-03-18",
  "first_seen": "2026-03-18T09:00:00+09:00",
  "area_refs": [
    "career"
  ],
  "direction_refs": [
    "Build an independent life with strong health and enough financial margin to choose well"
  ],
  "value_refs": [
    "craft over hype",
    "sustainable pace"
  ],
  "source_notes": [
    "projects/case-study-sprint.md"
  ],
  "last_reinforced": "2026-03-18T09:00:00+09:00",
  "stale": false
}
```

#### `goal` - `3y` goal

```json
{
  "canonical_name": "Build 24 months of runway for independent work",
  "kind": "goal",
  "ontology_family": "life",
  "canonical_source": "focus.current_commitments[0]",
  "horizon": "3y",
  "status": "active",
  "confidence": 0.95,
  "provenance": "survey-2026-03-18",
  "first_seen": "2026-03-18T09:00:00+09:00",
  "area_refs": [
    "finance"
  ],
  "direction_refs": [
    "Build an independent life with strong health and enough financial margin to choose well"
  ],
  "value_refs": [
    "sustainable pace"
  ],
  "source_notes": [
    "plans/runway-plan.md",
    "weekly/2026-W11.md"
  ],
  "canonical_note": "plans/runway-plan.md",
  "last_reinforced": "2026-03-18T09:00:00+09:00",
  "stale": false
}
```

### Direction Entity

#### `direction` - Long-horizon direction

```json
{
  "canonical_name": "Build an independent life with strong health and enough financial margin to choose well",
  "kind": "direction",
  "ontology_family": "life",
  "canonical_source": "direction.long_term_direction",
  "confidence": 0.65,
  "provenance": "survey-2026-03-18",
  "first_seen": "2026-03-18T09:00:00+09:00",
  "area_refs": [
    "career",
    "health",
    "finance"
  ],
  "last_reviewed": "2026-03-18"
}
```

### Value Entities

#### `value` - `craft over hype`

```json
{
  "canonical_name": "craft over hype",
  "kind": "value",
  "ontology_family": "life",
  "canonical_source": "identity.values_and_principles[0]",
  "confidence": 0.8,
  "provenance": "survey-2026-03-18",
  "first_seen": "2026-03-18T09:00:00+09:00"
}
```

#### `value` - `sustainable pace`

```json
{
  "canonical_name": "sustainable pace",
  "kind": "value",
  "ontology_family": "life",
  "canonical_source": "identity.values_and_principles[1]",
  "confidence": 0.8,
  "provenance": "survey-2026-03-18",
  "first_seen": "2026-03-18T09:00:00+09:00"
}
```

### Relations Between The Example Entities

```json
[
  {
    "from": "Publish one flagship case study and reach out to 10 aligned leads",
    "type": "belongs-to-area",
    "to": "career",
    "evidence": "profile-backed",
    "confidence": "high",
    "provenance": "survey-2026-03-18"
  },
  {
    "from": "Build 24 months of runway for independent work",
    "type": "belongs-to-area",
    "to": "finance",
    "evidence": "profile-backed",
    "confidence": "high",
    "provenance": "survey-2026-03-18"
  },
  {
    "from": "Publish one flagship case study and reach out to 10 aligned leads",
    "type": "advances-direction",
    "to": "Build an independent life with strong health and enough financial margin to choose well",
    "evidence": "profile-backed",
    "confidence": "high",
    "provenance": "survey-2026-03-18"
  },
  {
    "from": "Build 24 months of runway for independent work",
    "type": "advances-direction",
    "to": "Build an independent life with strong health and enough financial margin to choose well",
    "evidence": "profile-backed",
    "confidence": "high",
    "provenance": "survey-2026-03-18"
  },
  {
    "from": "Publish one flagship case study and reach out to 10 aligned leads",
    "type": "guided-by-value",
    "to": "craft over hype",
    "evidence": "profile-backed",
    "confidence": "high",
    "provenance": "survey-2026-03-18"
  },
  {
    "from": "Publish one flagship case study and reach out to 10 aligned leads",
    "type": "guided-by-value",
    "to": "sustainable pace",
    "evidence": "profile-backed",
    "confidence": "high",
    "provenance": "survey-2026-03-18"
  },
  {
    "from": "Build 24 months of runway for independent work",
    "type": "guided-by-value",
    "to": "sustainable pace",
    "evidence": "profile-backed",
    "confidence": "high",
    "provenance": "survey-2026-03-18"
  }
]
```

The `health` area is still a valid entity even though neither sample goal currently belongs to it.
Areas come from durable user-owned structure, not only from the subset of goals that happen to be active today.
