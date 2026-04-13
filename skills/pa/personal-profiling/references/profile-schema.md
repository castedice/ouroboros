---
name: personal-profile-schema
description: This reference provides the schema contract for `.pa/personal-profile.json`. It should be consulted when an agent needs to "create a personal profile", "map interview output to profile fields", "read profile layers", "update confidence metadata", or "render a human-readable personal profile".
---

# Personal Profile Schema - Phase 9 Contract And Field Guide

> Purpose: Machine-readable contract for `.pa/personal-profile.json` - keep the user's identity, direction, and current focus legible enough for PA to help without collapsing the user into a persona.
> This reference is standalone and can be read without the parent skill.
> For lifecycle and update rules, see `skills/pa/personal-profiling/SKILL.md`.
> For interview input mapping, see `skills/pa/interviewing/SKILL.md`.

## Phase 9 Scope

Phase 9 captures three layers.
Layer 1 stores stable identity and the PA interaction contract.
Layer 2 stores long-horizon direction.
Layer 3 stores near-term focus.
Metadata stores confidence and recency.

This schema is not a psychological diagnosis and not a complete life archive.
When deep interviews reveal nuance that does not fit safely, keep it in notes, evidence, or open questions instead of forcing new top-level fields.

## Lifecycle Interpretation

`bootstrap` may leave many fields broad or blank.
`catch-up` should touch only the fields that changed.
`direction` should emphasize Layer 2 and the relationship between Layer 2 and Layer 3.
`deep` may fill optional pattern fields when the user explicitly confirmed them.

## Full Schema

```yaml
version: 1

identity:
  current_roles: []
  life_stage: ""
  core_areas: []
  communication_style: "unknown"
  enrichment_posture: "standard"
  values_and_principles: []
  patterns:
    motivations: []
    decision_style: ""
    relationship_patterns: []
    energy_sources: []
    energy_drains: []
    ideal_day_signals: []
    active_transitions: []
    lessons_and_regrets: []

direction:
  long_term_direction: ""
  directions_by_area: {}
  paused_areas: []
  constraints_and_fears: []
  last_direction_review: null

focus:
  current_focus: []
  current_commitments: []
  review_cadence: "month"

confidence:
  overall: 0.0
  identity: 0.0
  direction: 0.0
  focus: 0.0

last_interview: null
interview_mode_used: null
created: null
updated: null
```

## Population Rules

| Rule | Why It Exists |
|------|---------------|
| Keep the object shape stable across profiles. | Commands and templates need a fixed contract. |
| Store only fields that help future support, review, or direction checks. | Prevent profile bloat. |
| Prefer blank or empty values over invented specificity. | Unknown is safer than false certainty. |
| Treat Layer 2 as stickier than Layer 3. | A stressful week should not rewrite a life direction. |
| Fill optional `patterns` fields only after confirmed deep-interview signal. | Deep nuance needs stronger evidence than bootstrap facts. |

## Layer Guide

### Layer 1: Stable Identity + PA Contract

| Field | Type | Description | Notes |
|-------|------|-------------|-------|
| `identity.current_roles` | string[] | The roles the user currently occupies or claims | Keep to durable roles, not every temporary task |
| `identity.life_stage` | string | Broad description of current season of life | Example: "early-career transition", "parenting with startup workload" |
| `identity.core_areas` | string[] | Life areas the user actively maintains | Use user language when possible |
| `identity.communication_style` | string | How the user prefers PA to speak or structure responses | Treat as user-owned preference |
| `identity.enrichment_posture` | string | How proactively PA may surface profile updates | Keep conservative unless the user asks for deeper profiling |
| `identity.values_and_principles` | string[] | Confirmed values or decision principles | Use short phrases, not essays |

### Optional Layer 1 Pattern Fields

These fields are optional.
Use them only when `deep` interview signal is strong enough to matter later.

| Field | Type | Description |
|-------|------|-------------|
| `identity.patterns.motivations` | string[] | Repeated sources of meaning, ambition, or drive |
| `identity.patterns.decision_style` | string | How the user tends to make hard decisions |
| `identity.patterns.relationship_patterns` | string[] | Confirmed social or conflict-handling patterns |
| `identity.patterns.energy_sources` | string[] | Activities or contexts that reliably restore energy |
| `identity.patterns.energy_drains` | string[] | Activities or contexts that reliably drain energy |
| `identity.patterns.ideal_day_signals` | string[] | Repeated descriptions of an energizing or desirable day |
| `identity.patterns.active_transitions` | string[] | Ongoing transitions or identity shifts |
| `identity.patterns.lessons_and_regrets` | string[] | Confirmed lessons, regrets, or cautionary patterns |

### Layer 2: Long-Horizon Directions

| Field | Type | Description | Notes |
|-------|------|-------------|-------|
| `direction.long_term_direction` | string | Broad free-text description of where the user wants to head | This is the backbone direction field |
| `direction.directions_by_area` | object | Per-area direction statements keyed by life area | Keep keys aligned with `identity.core_areas` where possible |
| `direction.paused_areas` | string[] | Areas explicitly deprioritized or paused | Use only with user confirmation |
| `direction.constraints_and_fears` | string[] | Confirmed fears, blockers, or constraints that shape direction | Keep short and concrete |
| `direction.last_direction_review` | date or null | Date of the last explicit direction check | Update during `direction` or `deep` review work |

### Layer 3: Near-Term Focus

| Field | Type | Description | Notes |
|-------|------|-------------|-------|
| `focus.current_focus` | string[] | Current active priorities | Keep it current and limited |
| `focus.current_commitments` | string[] | Commitments that actively consume time, energy, or accountability | Include recurring obligations, not only projects |
| `focus.review_cadence` | string | Preferred cadence for re-checking focus or direction | Example: `week`, `month`, `quarter`, `year`, `custom` |

## Metadata Guide

| Field | Type | Description |
|-------|------|-------------|
| `version` | integer | Schema version for forward compatibility |
| `confidence.overall` | float | Overall profile confidence from `0.0` to `1.0` |
| `confidence.identity` | float | Confidence in Layer 1 |
| `confidence.direction` | float | Confidence in Layer 2 |
| `confidence.focus` | float | Confidence in Layer 3 |
| `last_interview` | timestamp or null | Most recent interview completion timestamp |
| `interview_mode_used` | string or null | Most recent mode that materially updated the profile |
| `created` | timestamp or null | Profile creation timestamp |
| `updated` | timestamp or null | Last profile update timestamp |

Round stored confidence to the nearest `0.05`.
If layer-specific confidence is unavailable, keep the layer value equal to the closest justified baseline instead of fabricating precision.

## Minimal Valid Object

This is the smallest useful Phase 9 object.

```json
{
  "version": 1,
  "identity": {
    "current_roles": [],
    "life_stage": "",
    "core_areas": [],
    "communication_style": "unknown",
    "enrichment_posture": "standard",
    "values_and_principles": [],
    "patterns": {
      "motivations": [],
      "decision_style": "",
      "relationship_patterns": [],
      "energy_sources": [],
      "energy_drains": [],
      "ideal_day_signals": [],
      "active_transitions": [],
      "lessons_and_regrets": []
    }
  },
  "direction": {
    "long_term_direction": "",
    "directions_by_area": {},
    "paused_areas": [],
    "constraints_and_fears": [],
    "last_direction_review": null
  },
  "focus": {
    "current_focus": [],
    "current_commitments": [],
    "review_cadence": "month"
  },
  "confidence": {
    "overall": 0.0,
    "identity": 0.0,
    "direction": 0.0,
    "focus": 0.0
  },
  "last_interview": null,
  "interview_mode_used": null,
  "created": null,
  "updated": null
}
```

## Versioning

Increment `version` when the schema changes materially.
Additive fields should get safe defaults so older profiles remain readable.
When future phases add ontology or people-graph data, keep those outside this profile unless they are essential to identity, direction, or focus.

## Bias Mitigation

Personal profiling is especially vulnerable to confident-sounding distortions because the artifact tries to compress a person into a usable support model.
Use the table below before adding or revising any field that feels interpretive.

| Bias | Profiling Risk | Detection Signal | Countermeasure |
|------|----------------|------------------|----------------|
| Projection bias | The assistant writes what it expects a coherent user to value instead of what the user actually confirmed | The profile starts sounding like generic self-improvement language instead of the user's wording | Prefer user-owned phrases, and move uncertain interpretations into notes or open questions |
| Recency bias | A recent sprint, crisis, or mood swing rewrites stable identity or long-term direction | Layer 1 or Layer 2 changes after one short-term event | Require repeated evidence or explicit user confirmation before changing stable fields |
| Aspiration bias | Desired future identity gets stored as current reality | Current roles or principles describe who the user wants to become rather than who they are now | Keep aspirational material in `direction.*` until the user confirms it as present identity |
| Consistency bias | Old profile language survives even when the user's life actually changed | New answers get forced to fit prior wording or categories | Treat contradictions as review prompts, and rewrite stale fields when the user names a real transition |

## Common Pitfalls

| Mistake | Where It Appears | Why It Harms The Profile | Safer Practice |
|---------|------------------|--------------------------|----------------|
| Treating one vivid answer as a stable trait | Bootstrap or deep interviews | Temporary mood or context gets frozen into identity | Keep it as an open question or near-term focus item until the pattern repeats |
| Moving short-term plans into `direction.long_term_direction` | Catch-up updates | Layer 2 becomes a to-do list instead of a durable arc | Keep time-bounded priorities in `focus.*` unless the user explicitly reframes direction |
| Keeping stale roles after a life transition | Ongoing maintenance | Downstream commands reason from an outdated self-model | Remove or rewrite roles when the user confirms a season change |
| Filling optional `identity.patterns.*` fields without deep confirmation | Early intake | The profile starts to sound diagnostic and overconfident | Leave optional pattern fields blank until the signal is explicit and reusable |
| Rewriting values in assistant language | Any profile refresh | The profile loses the user's real decision vocabulary | Use short phrases close to the user's own wording |
| Inflating confidence because the profile reads cleanly | Any profile refresh | Downstream agents trust prose quality more than evidence quality | Tie confidence to interview depth, recency, and explicit confirmation instead of narrative coherence |

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-profiling/SKILL.md` | Parent skill - lifecycle, gap detection, and update rules |
| `skills/pa/personal-profiling/references/enrichment-rules.md` | Sibling reference - proposal-only patch policy |
| `skills/pa/interviewing/SKILL.md` | Upstream source of profile evidence |
| `templates/pa/personal-profile.md` | Human-readable rendering target |
