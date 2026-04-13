---
name: review-state-schema
description: This reference defines the checkpoint schema and assistant-side state rules for PA review loops. It should be consulted when an agent needs to "validate review checkpoint", "initialize review state", "check last review timestamp", "compute open loops delta", "manage resurfacing history", "apply serendipity suppression state", or "track knowledge decay suppression".
---

# Review State Schema - Incremental Checkpoints for PA Review Loops

> Purpose: Reference for `review-and-journaling` skill - defines the JSON schema for `{vault}/.pa/review-state.json`.
> This reference is standalone.
> For review cadence behavior, see `skills/pa/review-and-journaling/SKILL.md`.
> For resurfacing suppression behavior, see `skills/pa/review-and-journaling/references/resurfacing-rules.md`.

## Scope

This reference defines the checkpoint fields that let PA run incremental review loops instead of full re-discovery every time.
The file stores assistant-side review memory, not user-authored truth.
It records when each review horizon last ran, what open loops were present at review time, which forgotten-context notes were resurfaced, which serendipity notes were recently shown, and which knowledge-decay candidates are temporarily suppressed.

## File Location

`{vault}/.pa/review-state.json` - one JSON object rewritten after completed review cycles or explicit resurfacing feedback.

## Top-Level Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `last_review` | object | yes | Most recent completed review record per horizon |
| `open_loops_snapshot` | array | yes | Snapshot of unresolved loops from the most recent operational review |
| `resurfaced` | array | yes | Chronological resurfacing history with user disposition |
| `serendipity_shown` | array | yes | Recently surfaced serendipity notes with anti-repeat suppression |
| `knowledge_decay_suppressed` | array | yes | Anti-nag suppression entries for recently surfaced knowledge decay candidates |

## `last_review`

`last_review` is an object keyed by horizon.
Omit a key until that horizon has been run at least once.

### Supported Horizon Keys

- `week`
- `month`
- `quarter`
- `year`
- `3y`
- `10y`
- `30y`
- `lifetime`

Each horizon entry has this shape.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `horizon` | string | yes | Must match the parent key |
| `timestamp` | string (ISO 8601) | yes | When the review completed |
| `findings_count` | integer | yes | Number of surfaced findings for that review |

## `open_loops_snapshot`

`open_loops_snapshot` captures the unresolved operational loops visible at review time.
Replace this array after a completed weekly, monthly, quarterly, or explicit reset review when the operational loop picture has changed.

Each entry has this shape.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `item_id` | string | yes | Stable identifier from the source overlay or note path anchor |
| `source` | string | yes | Where the loop came from, such as `work.jsonl`, `timeline.jsonl`, or a vault note path |
| `state` | string | yes | Loop state such as `open`, `waiting`, `blocked`, `unresolved`, or `stale` |
| `since` | string (ISO date or ISO 8601) | yes | When the loop first became open or was first observed |

## `resurfaced`

`resurfaced` stores chronological resurfacing history for forgotten-context notes.
A path may appear multiple times.
The latest record for a path governs suppression and anti-nag behavior.

Each entry has this shape.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | Vault-relative note path that was resurfaced |
| `reason` | string | yes | Short explanation such as `21d stale + sim 0.58 to Project Alpha` |
| `resurfaced_at` | string (ISO 8601) | yes | When the note was shown to the user |
| `acted_on` | string or null | yes | `accepted`, `declined`, `deferred`, or `null` when no response has been recorded yet |

## `knowledge_decay_suppressed`

`knowledge_decay_suppressed` stores anti-nag suppression entries for knowledge refresh candidates.
Use only entries whose `expires` date is still in the future.

Each entry has this shape.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | Vault-relative note path for the suppressed knowledge candidate |
| `suppressed_at` | string (ISO date) | yes | When the decay candidate was last surfaced or dismissed |
| `expires` | string (ISO date) | yes | When the suppression window ends |

## `serendipity_shown`

`serendipity_shown` stores anti-repeat suppression entries for randomly surfaced notes.
Use only entries whose `expires` date is still in the future.

Each entry has this shape.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | yes | Vault-relative note path for the serendipity note |
| `shown_at` | string (ISO date) | yes | When the note was last shown in a review |
| `expires` | string (ISO date) | yes | When the 90-day suppression window ends |

## Checkpoint Rules

| Event | Update Rule |
|-------|-------------|
| Completed review for a horizon | Write `last_review[horizon]` with the completion timestamp and surfaced finding count |
| Completed weekly, monthly, quarterly, or reset review | Replace `open_loops_snapshot` with the current unresolved-loop view |
| Purely strategic `year+` review with no operational carry-forward changes | Update `last_review` only |
| Resurfacing suggestions shown | Append `resurfaced` entries with `acted_on: null` |
| Serendipity notes shown | Append or refresh the matching `serendipity_shown` entry with a `90`-day expiry |
| User response to a resurfaced note | Update the latest matching `resurfaced` entry or rewrite it with `acted_on` set to `accepted`, `declined`, or `deferred` |
| Knowledge decay candidate surfaced or dismissed | Append or refresh the matching `knowledge_decay_suppressed` entry with a `90`-day expiry |

## How To Use For Incremental Review

1. Use `last_review[horizon].timestamp` as the lower bound for recency checks and delta summaries.
2. Diff current open loops against `open_loops_snapshot` to label loops as `new`, `persistent`, or `resolved`.
3. Use the latest `resurfaced` record per note path to suppress declined notes for 30 days.
4. Use non-expired `serendipity_shown` entries to suppress repeated random resurfacing for 90 days.
5. Use non-expired `knowledge_decay_suppressed` entries to suppress repeated knowledge-refresh surfacing for 90 days.
6. If `review-state.json` is missing or malformed, fall back to a full review and recreate the file on completion.
7. Do not treat `review-state.json` as source of truth for work, timeline, or ontology data.
8. Regenerate findings from the source overlays on every run.

## Example Object

```json
{
  "last_review": {
    "week": {
      "horizon": "week",
      "timestamp": "2026-03-17T18:30:00+09:00",
      "findings_count": 6
    },
    "month": {
      "horizon": "month",
      "timestamp": "2026-03-01T09:10:00+09:00",
      "findings_count": 9
    }
  },
  "open_loops_snapshot": [
    {
      "item_id": "w-014",
      "source": "work.jsonl",
      "state": "waiting",
      "since": "2026-03-10"
    },
    {
      "item_id": "daily/2026-03-02.md#Open-loops",
      "source": "daily/2026-03-02.md",
      "state": "unresolved",
      "since": "2026-03-02"
    }
  ],
  "serendipity_shown": [
    {
      "path": "notes/old-idea.md",
      "shown_at": "2026-03-24",
      "expires": "2026-06-24"
    }
  ],
  "knowledge_decay_suppressed": [
    {
      "path": "references/old-api-guide.md",
      "suppressed_at": "2026-03-24",
      "expires": "2026-06-24"
    }
  ],
  "resurfaced": [
    {
      "path": "projects/alpha/retrospective.md",
      "reason": "19d stale + sim 0.62 to Project Alpha",
      "resurfaced_at": "2026-03-17T18:30:00+09:00",
      "acted_on": "declined"
    },
    {
      "path": "notes/old-handoff-plan.md",
      "reason": "24d stale + sim 0.54 to this week's work",
      "resurfaced_at": "2026-03-17T18:30:00+09:00",
      "acted_on": null
    }
  ]
}
```

## Design Rationale

| Decision | Why |
|----------|-----|
| Checkpoint per horizon | Each horizon has independent cadence — week and month reviews should not block each other |
| Open loops as snapshot | Snapshot enables delta comparison — "what changed since last review" is more useful than "all current loops" |
| 90-day anti-nag for resurfacing | Shorter suppression causes note fatigue; longer suppression risks permanent burial |
| serendipity_shown separate from resurfaced | Serendipity is random, resurfacing is relevance-based — different suppression lifecycles |
| knowledge_decay_suppressed with expiry | Decay candidates should return after 90 days if still stale — suppression is temporary, not permanent |
| No automatic state cleanup | Review state grows slowly — manual cleanup via `/pa survey` is sufficient |

## Common Pitfalls

| Pitfall | Why It Fails | Prevention |
|---------|-------------|------------|
| Comparing checkpoints across different horizons | Week and month snapshots have different scopes — delta is meaningless cross-horizon | Always compare within the same horizon key |
| Treating missing checkpoint as "all clean" | Missing means "never reviewed", not "nothing to find" | Initialize with explicit first-run marker, lower confidence |
| Accumulating unbounded suppression arrays | Arrays grow forever without cleanup | Expiry dates on all suppression entries, cleanup during survey |
| Overwriting open_loops_snapshot at year+ | Strategic reviews should not replace operational loop tracking | Only update snapshot for week/month/quarter runs |

## Bias Mitigation

| Bias | Risk | Countermeasure |
|------|------|----------------|
| Recurrence bias | Same findings resurface every review | Anti-nag suppression via `resurfaced[]` and `knowledge_decay_suppressed[]` with 90-day cooldown |
| Stale-data anchoring | Old checkpoint data treated as current truth | Always compare against fresh overlay data, not cached checkpoint values |
| Completeness bias | Reporting "healthy" when overlays are missing | Explicitly note when overlays are absent — lower confidence, don't claim health |
| Review fatigue | User ignores findings after repeated reviews | Compress low-signal findings at shorter horizons, preserve only high-signal at longer horizons |

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/review-and-journaling/SKILL.md` | Parent skill — review methodology |
| `skills/pa/review-and-journaling/references/resurfacing-rules.md` | Sibling — resurfacing eligibility and suppression |
| `skills/pa/review-and-journaling/references/fractal-journaling.md` | Sibling — review hierarchy and horizon behavior |
| `commands/pa/review.md` | Primary consumer — reads and writes review-state.json |
| `agents/pa/sentinel.md` | Primary producer — generates checkpoint payloads |

## Validation Checklist

- [ ] `last_review` contains only completed horizons and each entry keeps the horizon key, ISO 8601 timestamp, and finding count together.
- [ ] `open_loops_snapshot` uses stable item identifiers, valid loop states, and source context for every unresolved entry.
- [ ] The current `open_loops_snapshot` reflects the latest operational review so `new`, `persistent`, and `resolved` loop deltas can be computed correctly.
- [ ] `resurfaced` preserves chronological history per path and the latest matching record is the one used for suppression decisions.
- [ ] `serendipity_shown` entries use note-path keys with active 90-day expiry windows before suppressing repeat random surfacing.
- [ ] `knowledge_decay_suppressed` entries use future `expires` dates and suppress only the matching knowledge candidate path.
- [ ] Missing or malformed review state falls back to a full review and state recreation instead of partial trust.
