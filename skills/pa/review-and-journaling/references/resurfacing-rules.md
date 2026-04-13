---
name: resurfacing-rules
description: This reference provides note resurfacing candidate selection rules for PA review loops. It should be consulted when an agent needs to "select resurfacing candidates from stale notes", "score forgotten context against active entities", "apply anti-nag suppression to resurfaced notes", "rank resurfacing suggestions for a review horizon", "vary resurfacing depth by weekly or yearly review", or "decide whether an old note deserves to re-enter attention".
---

# Resurfacing Rules - Selecting Forgotten Context That Still Matters

> Purpose: Detection and ranking reference for `review-and-journaling` - use it to decide which stale notes deserve to re-enter attention during a review loop.
> This reference is standalone and can be consulted without the parent skill.
> For the full review workflow, see `skills/pa/review-and-journaling/SKILL.md`.
> For checkpoint storage, see `skills/pa/review-and-journaling/references/review-state-schema.md`.

## Scope

This reference covers five concerns: candidate eligibility, relevance to present work, ranking, anti-nag suppression, and knowledge-refresh candidacy.
It does not decide whether the user should act on a resurfaced note.
It decides only whether the note deserves to be surfaced now.

## Candidate Selection Workflow

### Step 1: Eligibility Filter

Start from vault notes that have not been modified in 14 or more days.
Exclude assistant state, templates, and archive by default.
A note that fails eligibility is never sent to semantic ranking.

### Step 2: Build the Active Anchor Set

Build anchors from two sources.
Use active entities from `.pa/entities.json`.
Use current week's work items from `.pa/work.jsonl`.
If one source is missing, continue with the other.
If both are missing, skip resurfacing entirely rather than guessing.

### Step 3: Relevance and Scoring

Use QMD semantic search to compare each eligible note against the active anchor set.
Keep only candidates with `max_similarity >= 0.4`.
Score each candidate with `staleness_days * max_relevance_score`.
Sort by score descending.

### Step 4: Suppression and Output Cap

Apply suppression rules from `.pa/review-state.json` after ranking.
Remove candidates that were recently declined.
Surface at most 3 notes per review invocation.
A shorter list is better than a noisy list.

## Eligibility Rules

A note is eligible for resurfacing when all of the following are true.

1. It has not been modified in 14 or more days.
2. It is not inside `.pa/`.
3. It is not inside `templates/`.
4. It is not inside `archive/` during the primary operational pass.
5. It is still readable and indexable by QMD.

### Exclusion Set

| Excluded Path | Why Excluded |
|---------------|--------------|
| `.pa/` | Assistant state is not user-facing knowledge |
| `templates/` | Templates are scaffolding, not forgotten context |
| `archive/` | Operational resurfacing should not constantly pull back retired material |

`archive/` is excluded from the primary pool because operational reviews should favor live material.
Yearly and longer reviews may run a second archival pass after the primary ranking is complete.
That archival pass is additive and separately labeled.
It does not replace the default exclusion rule.

## Relevance Test

A candidate note is relevant when it has semantic similarity of `0.4` or higher to at least one active anchor.

### Active Anchors

| Anchor Type | Source | Use |
|-------------|--------|-----|
| **Active entities** | `.pa/entities.json` entries with active status, active canonical notes, or live project and person references | Capture what currently matters in the graph |
| **Current week's work items** | Open or recently touched work items from `.pa/work.jsonl` | Capture what currently matters in execution |

Use the maximum similarity score across all anchors.
Do not sum anchor scores.
Summing rewards notes that mention many things weakly.
Max score rewards the clearest present connection.

## Ranking

Use this formula for ranking.

```text
score = staleness_days * max_relevance_score
```

Apply these tie-breakers in order.

1. Higher `max_relevance_score`.
2. Older last-modified date.
3. Shorter distance to an active canonical note, if structural graph distance is available.
4. Stable path sort for deterministic output.

## Limits

- Surface at most 3 resurfacing suggestions per review invocation.
- If fewer than 3 notes clear the threshold and suppression rules, surface only the notes that passed.
- Do not lower the `0.4` threshold just to fill the list.

## Anti-Nag Rules

Use the latest matching record in `.pa/review-state.json -> resurfaced` for suppression.

| Latest `acted_on` value | Behavior |
|-------------------------|----------|
| `declined` | Suppress for 30 days from `resurfaced_at` |
| `accepted` | Do not resurface again until the note changes and later becomes stale again |
| `deferred` | Allow resurfacing only at a larger horizon or after 14 more days |
| `null` | Treat as recently shown and avoid repeating it in the next immediate review unless the horizon expands |

If the note has changed since it was last resurfaced, treat it as a new candidate and recompute from scratch.
Modification breaks suppression because the underlying situation changed.

## Horizon Variation

| Horizon | Candidate Depth | Anchor Preference | Special Rule |
|---------|-----------------|------------------|--------------|
| `week` | Recent dormant context, usually 14-45 days stale | Current week's work items first, active entities second | Favor actionable notes and recent handoffs |
| `month` | Deeper dormant context, usually 30-180 days stale | Active entities and recurring work themes | Favor neglected projects, recurring themes, and unfinished ideas |
| `quarter` | Portfolio memory, usually 60-365 days stale | Major projects, active entities, and monthly themes | Favor notes that explain why current priorities exist |
| `year` and longer | Deep memory, including a second archival pass if useful | Enduring entities, yearly themes, and strategic questions | Label archival resurfacing separately and still cap total output at 3 |

## Knowledge Decay Candidates

Knowledge notes that have not been referenced or modified for a long time may contain stale information.

### Decay Score

```text
decay_score = days_since_last_referenced / max(reference_count, 1)
```

- `days_since_last_referenced`: days since the note's last modification or last inbound wikilink from a recently modified note
- `reference_count`: count of inbound wikilinks plus `evidence_slices` referencing this note

### Candidacy Filter

A note is a knowledge-refresh candidate when:

1. `decay_score >= 60`
2. The note is tagged or classified as `technical`, `process`, `reference`, or `how-to` from frontmatter tags, folder in `references_dir` or `clippings_dir`, or title containing `guide`, `howto`, `reference`, or `process`
3. The note is not in archive, daily, or journal folders
4. The note has not been surfaced as a decay candidate in the last `90` days via `review-state.json -> knowledge_decay_suppressed[]`

### Surface

- Review month+ horizons: up to `5` candidates, sorted by `decay_score` descending
- Output section: `## Knowledge Refresh Candidates` in the follow-up report

## Design Rationale

Why the candidate must be both stale and relevant: staleness alone produces nostalgia spam.
Relevance alone produces recent-note duplication.
The intersection is where forgotten context becomes useful again.

Why the score multiplies staleness by relevance: a slightly relevant note that has been dormant for 200 days can deserve attention.
A highly relevant note from 15 days ago can also deserve attention.
Multiplication keeps both dimensions alive without inventing a more complex formula than the review loop needs.

Why the cap is 3: resurfacing exists to refresh memory, not to recreate an inbox.
More than 3 candidates turns review into triage overhead.

## Validation Checklist

- [ ] Every resurfacing candidate passes all eligibility checks before semantic ranking begins.
- [ ] Ranking uses `staleness_days * max_relevance_score` with max similarity, not summed anchor scores.
- [ ] Anti-nag suppression is checked against the latest matching `resurfaced` record, and changed notes are treated as new candidates.
- [ ] Knowledge decay candidates pass the candidacy filter for decay score, note type, path exclusions, and suppression state.
- [ ] Knowledge refresh candidates are surfaced only for `month+` horizons and never exceed 5 notes.
- [ ] The 90-day knowledge decay suppression window is respected before resurfacing the same knowledge note again.
- [ ] Any archival pass at `year+` remains separately labeled and does not bypass the primary output caps.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/review-and-journaling/SKILL.md` | Parent skill - full review-loop workflow |
| `skills/pa/review-and-journaling/references/review-state-schema.md` | Sibling reference - stores resurfacing outcomes and suppression state |
| `skills/pa/personal-ontology/SKILL.md` | Related skill - active entities provide one of the anchor sets |
| `agents/pa/sentinel.md` | Primary consumer - ranks resurfacing candidates during review |
| `commands/pa/review.md` | Caller - presents resurfaced notes as part of the review output |
