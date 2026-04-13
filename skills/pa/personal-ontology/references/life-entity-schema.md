---
name: life-entity-schema
description: This reference provides the schema contract for life-facing entities in the PA ontology. It should be consulted when an agent needs to "create area or goal entities from a personal profile", "distinguish life entities from vault entities", "assign goal horizon and status", "treat habits or milestones as pointers into overlays", or "validate life ontology records".
---

# Life Entity Schema - Areas, Goals, Directions, Values, Habits, Milestones, and Decisions

> Purpose: Detection and execution reference for `personal-ontology` - use it to define, create, and validate life-facing entities that come from the user's stated profile, interview-confirmed direction, or operational overlays.
> This reference is standalone and can be consulted without the parent skill.
> For worked examples and relation examples, see `life-entity-examples.md`.
> For the main extraction workflow, see `skills/pa/personal-ontology/SKILL.md`.

## Scope

This reference defines the life-facing side of the PA ontology.
It adds seven entity kinds: `area`, `goal`, `direction`, `value`, `habit`, `milestone`, and `decision`.
These entities represent the user's life structure, not just the vault's note structure.
They live alongside the original vault entities, but they follow different ingress and identity rules.

## Ontology Family Split

`ontology_family` is required on every entity.
Use it to keep life entities and vault entities from collapsing into one mixed namespace.

| `ontology_family` | Origin | Primary Creation Path | Typical Kinds |
|-------------------|--------|-----------------------|---------------|
| `vault` | Structural vault scan | Wikilinks, note titles, frontmatter, headings | `person`, `project`, `topic`, `place`, `event`, `artifact`, `concept` |
| `life` | Personal profile, approved interview output, or operational overlays | `personal-profile.json`, `work.jsonl`, `timeline.jsonl` | `area`, `goal`, `direction`, `value`, `habit`, `milestone`, `decision` |

Life entities come from user-owned life structure.
Vault entities come from structural note evidence.
A shared display name does not override `ontology_family`.

## Common Life Entity Fields

These fields apply to every `ontology_family: "life"` entity.

| Field | Required | Description |
|-------|----------|-------------|
| `canonical_name` | yes | Primary display name for the life entity |
| `kind` | yes | `area`, `goal`, `direction`, `value`, `habit`, `milestone`, or `decision` |
| `ontology_family` | yes | Always `life` for the entities in this reference |
| `canonical_source` | yes | Profile field path or overlay pointer that is the source of truth for identity |
| `confidence` | yes | Numeric confidence from `0.0` to `1.0`, seeded from the relevant profile or overlay confidence and rounded to the nearest `0.05` |
| `provenance` | yes | Which survey, review, interview, or overlay pass created or refreshed the entity |
| `first_seen` | yes | Earliest timestamp when PA created or observed this life entity |
| `source_notes` | no | Vault notes that reinforce or operationalize the life entity |
| `canonical_note` | no | Dedicated vault note path for the entity when one exists |
| `aliases` | no | Alternate phrasings or prior profile wording that resolve to the same life entity |
| `last_reinforced` | no | Most recent vault-backed reinforcement timestamp |

For life entities, `canonical_source` matters more than note frequency.

## Two-Layer Time Model

Life entities should follow a two-layer time model.

| Layer | Purpose | Entity Kinds | Temporal Shape |
|-------|---------|--------------|----------------|
| **Direction Layer** | Hold open-ended north stars and enduring guidance | `direction`, `value`, `area` | Open-ended, slowly changing, identity-shaping |
| **Goals-Initiatives Layer** | Hold bounded commitments, recurring practices, concrete checkpoints, and recorded choices | `goal`, `habit`, `milestone`, `decision` | Time-bounded, reviewable, operational |

`direction` answers where the user is trying to head.
`goal` answers what bounded commitment currently expresses that direction.
`area` names the domain where the direction and goals live.
`value` names the principle that should constrain the path.
`habit`, `milestone`, and `decision` keep the operational layer anchored without duplicating work, timeline, or explicit post-mortem data.

## Goal Field Enums

`goal.horizon` is required on every goal.

| Field | Allowed Values |
|-------|----------------|
| `goal.horizon` | `week`, `month`, `quarter`, `year`, `3y`, `10y`, `30y`, `lifetime` |
| `goal.status` | `active`, `paused`, `completed`, `abandoned` |

When a goal comes from `focus.current_focus[*]` and no tighter horizon is explicit, default the provisional horizon to `quarter`.
Record the defaulting choice in `provenance`.

## Entity Kind Guide

### `area`

| Aspect | Guidance |
|--------|----------|
| Definition | Durable life domain that the user actively maintains or wants to keep in view |
| Source | `personal-profile.json -> identity.core_areas[*]`, reinforced by `direction.directions_by_area` and related vault notes |
| Temporal nature | Long-lived and relatively stable, but may be renamed or paused |
| Required fields | `canonical_name`, `kind`, `ontology_family`, `canonical_source`, `confidence`, `provenance`, `first_seen` |
| Optional fields | `aliases`, `source_notes`, `canonical_note`, `last_reinforced` |

### `goal`

| Aspect | Guidance |
|--------|----------|
| Definition | Bounded commitment or active priority that should move over a named horizon |
| Source | `personal-profile.json -> focus.current_focus[*]`, approved interview updates, and vault reinforcement from project or plan notes |
| Temporal nature | Explicitly bounded by `goal.horizon` and stateful through `goal.status` |
| Required fields | `canonical_name`, `kind`, `ontology_family`, `canonical_source`, `horizon`, `status`, `confidence`, `provenance`, `first_seen` |
| Optional fields | `area_refs`, `direction_refs`, `value_refs`, `source_notes`, `canonical_note`, `last_reinforced`, `stale`, `stale_since`, `completed_at` |

### `direction`

| Aspect | Guidance |
|--------|----------|
| Definition | Open-ended north star or durable heading that orients goals without turning into a checklist |
| Source | `personal-profile.json -> direction.long_term_direction`, `direction.directions_by_area`, and direction interviews |
| Temporal nature | Open-ended and deliberately resistant to short-term swings |
| Required fields | `canonical_name`, `kind`, `ontology_family`, `canonical_source`, `confidence`, `provenance`, `first_seen` |
| Optional fields | `area_refs`, `source_notes`, `canonical_note`, `last_reinforced`, `last_reviewed` |

### `value`

| Aspect | Guidance |
|--------|----------|
| Definition | Principle or decision filter that should guide goals and habits |
| Source | `personal-profile.json -> identity.values_and_principles[*]`, deep or direction interviews, and vault reinforcement |
| Temporal nature | Durable, but revisable when the user explicitly reframes their values |
| Required fields | `canonical_name`, `kind`, `ontology_family`, `canonical_source`, `confidence`, `provenance`, `first_seen` |
| Optional fields | `aliases`, `source_notes`, `canonical_note`, `last_reinforced` |

### `habit`

| Aspect | Guidance |
|--------|----------|
| Definition | Recurring practice that matters to the life system but should remain operationally managed in `work.jsonl` |
| Source | Recurring or repeating `work.jsonl` items, optionally reinforced by interview-confirmed routines and habit notes |
| Temporal nature | Ongoing and cyclical rather than open-ended or terminal |
| Required fields | `canonical_name`, `kind`, `ontology_family`, `canonical_source`, `work_item_ids`, `confidence`, `provenance`, `first_seen` |
| Optional fields | `area_refs`, `value_refs`, `source_notes`, `last_reinforced`, `cadence` |

The operational state, streaks, and reminders stay in `work.jsonl`.
Do not duplicate day-to-day habit metadata into the ontology.

### `milestone`

| Aspect | Guidance |
|--------|----------|
| Definition | Concrete checkpoint or named marker that should remain operationally managed in `timeline.jsonl` |
| Source | `timeline.jsonl` milestone events, dated strategic checkpoints, and interview-confirmed future markers |
| Temporal nature | Dated or event-bound checkpoint with a clear before and after |
| Required fields | `canonical_name`, `kind`, `ontology_family`, `canonical_source`, `timeline_event_ids`, `confidence`, `provenance`, `first_seen` |
| Optional fields | `goal_refs`, `area_refs`, `source_notes`, `last_reinforced`, `target_date` |

The event payload, dates, and chronology stay in `timeline.jsonl`.
Do not create a second timeline inside the ontology.

### `decision`

A recorded choice with context, alternatives, rationale, and expected outcome.

| Field | Required | Description |
|-------|----------|-------------|
| `context` | yes | What situation led to this decision |
| `alternatives` | yes | Options considered (array of strings) |
| `chosen` | yes | Selected option with brief qualification |
| `rationale` | yes | Why this option was chosen |
| `outcome_expected` | no | What was expected to happen |
| `outcome_actual` | no | What actually happened (filled during post-mortem) |
| `lessons` | no | What was learned (filled during post-mortem) |
| `decision_date` | yes | When the decision was made (ISO date) |
| `review_date` | no | When to revisit (default: decision_date + 180 days) |
| `area_refs` | no | Life areas this decision affects |
| `goal_refs` | no | Goals this decision advances |

A decision entity becomes `review-due` when `current_date >= review_date` and `outcome_actual` is null.

Decision staleness threshold: `review_date` is the boundary.
Decisions are explicitly scheduled.

## Area Sync Rules

`area` entities and `personal-profile.json -> identity.core_areas` must stay synchronized.

1. Each `identity.core_areas[i]` should create or refresh exactly one `area` entity.
2. The profile is the source of truth for whether an area exists as a life entity.
3. Reordering `identity.core_areas` does not create a new area when the normalized name matches an existing `area` entity.
4. When the user renames an area, preserve the prior wording as an alias if vault reinforcement still points to it.
5. When an area disappears from the profile but active goals or habits still point to it, keep the entity temporarily, lower confidence, and flag the mismatch for review instead of silently deleting it.

## Vault Reinforcement Rules

Life entities may be reinforced by vault structure after they are created.
Vault reinforcement can increase confidence, enrich aliases, or attach source notes.
Vault reinforcement does not change `ontology_family`.

Use vault reinforcement for:

- matching wikilinks to the life entity's `canonical_name` or alias,
- attaching a dedicated note as `canonical_note`,
- collecting `source_notes` that show the life entity is being actively operationalized,
- strengthening relations such as `belongs-to-area` or `advances-direction`.

Do not require two structural signals to create a life entity.
A confirmed profile field or approved overlay pointer is enough to create one.
Structural evidence only reinforces it.

## Quantified Rules

Use numeric rules whenever life-entity confidence or goal freshness would otherwise be described qualitatively.
Round every stored confidence to the nearest `0.05`.
Cap reinforcement-adjusted confidence at `1.0`.

### Confidence Seeding

Profile-backed entities inherit the numeric confidence of the profile layer that created them.
A profile confidence of `0.40` creates an entity confidence of `0.40` before any reinforcement.
Use `confidence.identity` for `area` and `value`.
Use `confidence.direction` for `direction`.
Use `confidence.focus` for `goal`.
Use overlay extraction confidence for `habit`, `milestone`, and `decision`, or the closest justified profile baseline when the overlay score is unavailable.

| Entity Kind | Seed Source | Example |
|-------------|-------------|---------|
| `area` | `confidence.identity` | `0.80` identity confidence creates `0.80` area confidence |
| `value` | `confidence.identity` | `0.40` identity confidence creates `0.40` value confidence |
| `direction` | `confidence.direction` | `0.65` direction confidence creates `0.65` direction confidence |
| `goal` | `confidence.focus` | `0.55` focus confidence creates `0.55` goal confidence |
| `habit`, `milestone`, `decision` | Overlay extraction confidence | `0.70` overlay confidence creates `0.70` pointer-entity confidence |

### Vault Reinforcement Boosts

Apply vault reinforcement after seeding the base confidence.
Add `+0.15` for each reinforcing wikilink occurrence in a distinct note that resolves to the entity's `canonical_name` or alias.
Add `+0.10` when a dedicated note is promoted to `canonical_note`.
Add `+0.05` for each additional distinct `source_note` beyond the first when that note operationalizes the entity.
Do not let reinforcement alone create an entity.
Do not raise confidence above `1.0`.

| Signal | Confidence Change | Example |
|--------|-------------------|---------|
| Reinforcing wikilink in one distinct note | `+0.15` | `0.55` goal confidence becomes `0.70` |
| Dedicated `canonical_note` | `+0.10` | `0.70` becomes `0.80` after promoting a clear note |
| Additional distinct `source_note` beyond the first | `+0.05` | `0.80` becomes `0.85` when a second operationalizing note appears |

### Goal Staleness Thresholds

Flag only `goal` entities with `status: "active"` for inactivity-based staleness.
Treat a goal as stale when there is `0` related vault activity across `canonical_note`, `source_notes`, or reinforcing wikilinks during the threshold window for its horizon.
Set `stale_since` to the threshold-crossing date when the rule triggers.
Paused, completed, and abandoned goals do not become stale from inactivity alone.
A stale flag should trigger review, not silent deletion.

| `goal.horizon` | `stale` threshold with `0` related vault activity |
|----------------|---------------------------------------------------|
| `week`, `month` | `14` days |
| `quarter` | `30` days |
| `year` | `60` days |
| `3y`, `10y`, `30y`, `lifetime` | `90` days |
