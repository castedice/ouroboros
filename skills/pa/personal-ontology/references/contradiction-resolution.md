---
name: contradiction-resolution
description: This reference defines AGM-style contradiction handling for PA memory facts. It should be consulted when an agent needs to "detect conflicting facts", "resolve fact contradictions", "apply evidence ordering", "mark facts contested", or "persist contradiction links".
---

# Contradiction Resolution

> Purpose: Reference for `personal-ontology` and `weaver` refresh flows.
> Use it when two facts about the same subject and predicate cannot both be the active memory head.

## Conflict Gate

A contradiction exists when two fact versions share the same `subject_id` and `predicate` but assert incompatible objects or mutually exclusive states.
Reinforcement of the same normalized object is not a contradiction.

## Triggers

- During weaver fact extraction when a new fact conflicts with an existing memory head.
- During entity refresh when an entity attribute change implies a conflicting fact version.

## AGM Resolution Order

When two facts conflict, apply this priority strictly:

1. Stronger evidence wins.
   Compare higher `confidence` first, then compare the number of distinct `source_note` paths.
2. If evidence is equal, newer `event_date` wins.
3. If `event_date` is still tied or absent on both sides, newer `document_date` wins.
4. If still tied, keep both facts and mark them `contested`.

## Resolution Actions

When one fact wins:

- Mark the weaker fact `state: "superseded"`.
- Keep the stronger fact `state: "active"`.
- Create a memory-link with `relation: "contradicts"` between the competing facts.
- Optionally create a `supersedes` memory-link from the winning fact to the weaker fact when replacement is explicit.

When neither fact wins:

- Mark both facts `state: "contested"`.
- Leave both fact versions available for review.
- Create a memory-link with `relation: "contradicts"` between the tied facts.
- Surface the contested pair to sentinel and review instead of silently collapsing them.

## Tie Handling

If the evidence strength, newest `event_date`, and newest `document_date` are all equal, the system must not guess.
Use `state: "contested"` and escalate to review.

## State Semantics

| State | Meaning |
|------|---------|
| `active` | Current winning fact version |
| `superseded` | Older or weaker fact replaced by a stronger contradiction outcome |
| `contested` | Unresolved tied contradiction that still needs review |

## Persistence Rules

- Contradiction handling updates fact state in `memories.jsonl`.
- Contradiction edges are appended to `memory-links.jsonl`.
- `memory-heads.json` is rebuilt from the latest non-superseded facts after resolution.
- Contested facts stay visible so sentinel can surface them.

## Review Rule

Contested facts are not auto-resolved by later evidence refresh alone.
They remain `contested` until a stronger fact version arrives or a user-guided refresh explicitly resolves the tie.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/references/memory-schema.md` | Fact storage and state fields |
| `agents/pa/weaver.md` | Applies contradiction detection during extraction and refresh |
| `agents/pa/sentinel.md` | Surfaces unresolved contested facts in review |
