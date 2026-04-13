---
name: life-entity-review
description: This reference provides pitfalls, rationale, and validation checks for life-facing entities in the PA ontology. It should be consulted when an agent needs to "review common modeling mistakes", "understand why the life-entity split exists", or "run a final validation pass over life ontology records".
---

# Life Entity Review - Pitfalls, Rationale, and Validation

> Purpose: Review companion for `personal-ontology` - use it to catch common modeling mistakes, understand the schema trade-offs, and run a final validation pass.
> This reference is standalone and can be consulted without the parent skill.
> For the schema contract and quantified rules, see `life-entity-schema.md`.
> For complete example entities and relations, see `life-entity-examples.md`.
> For the main extraction workflow, see `skills/pa/personal-ontology/SKILL.md`.

## Common Pitfalls

| Pitfall | Why It Breaks The Model | Prevention |
|---------|-------------------------|------------|
| Treating every current focus as a timeless direction | Near-term commitments stop aging and never get reviewed properly | Keep `goal` and `direction` separate through the two-layer time model |
| Merging a life `area` with a vault `topic` that shares the same name | The user's life structure collapses into note taxonomy and loses meaning | Keep `ontology_family` explicit and never auto-merge across families |
| Copying full habit state into the ontology | The graph duplicates `work.jsonl` and drifts out of sync | Store only a pointer entity for `habit` |
| Copying timeline event payloads into milestone entities | The graph becomes a second timeline with stale dates | Store only a pointer entity for `milestone` |
| Creating goal entities without `horizon` or `status` | Reviews cannot tell whether the goal is active, paused, or done | Require both fields on every goal |
| Letting profile wording overwrite vault reinforcement without trace | The user loses continuity across renamed areas or reframed goals | Preserve aliases, provenance, and reinforcement history |

## Design Rationale

Why separate `vault` and `life` families: a personal vault contains both note structure and life structure, and those are not the same thing.
A topic note named "health" is not automatically the same thing as the user's life area "health".
`ontology_family` keeps those worlds adjacent but distinct.

Why directions and goals need separate layers: the user needs room for durable direction without pretending that every north star is a measurable commitment.
Directions stay open-ended.
Goals carry horizons and statuses.
That split makes year-plus reviews more honest and weekly or monthly resets more operational.

Why habits and milestones are pointer entities: the ontology should name what matters without duplicating the operational overlays that already store cadence, dates, and event state.
Pointers let the graph stay legible while `work.jsonl` and `timeline.jsonl` remain the source of operational truth.

## Validation Checklist

- [ ] Every life entity has `ontology_family: "life"`
- [ ] Every life entity has a `canonical_source` that points to a profile field or overlay id
- [ ] Every life entity stores numeric `confidence` from `0.0` to `1.0`, rounded to the nearest `0.05`
- [ ] Every `goal` has a valid `horizon` and `status`
- [ ] Every active `goal` has been checked against the inactivity threshold for its horizon before leaving `stale` unset
- [ ] Every `area` entity is synchronized against `identity.core_areas`
- [ ] `habit` entities point to `work.jsonl` instead of duplicating operational state
- [ ] `milestone` entities point to `timeline.jsonl` instead of duplicating event data
- [ ] Vault reinforcement is recorded as reinforcement, not as the original source of truth
- [ ] Homonyms across `vault` and `life` families remain separate unless the user explicitly requests a merge

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/SKILL.md` | Parent skill - overall ontology workflow |
| `skills/pa/personal-ontology/references/entity-canonicalization.md` | Identity rules for life and vault entities |
| `skills/pa/personal-ontology/references/relation-taxonomy.md` | Life-specific relation types such as `belongs-to-area` and `advances-direction` |
| `skills/pa/personal-profiling/references/profile-schema.md` | Source profile fields that seed life entities |
| `agents/pa/weaver.md` | Primary consumer during survey extraction |
