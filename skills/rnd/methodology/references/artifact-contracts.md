# Artifact Contracts

This reference defines the seven study artifacts that make RnD reset-safe.
Every artifact must stand alone, preserve negative results, and support a fresh-agent handoff without hidden chat-only assumptions.

## Study Artifacts

| Artifact | Producer stage | Consumer stages | Required fields | Format rules |
|---------|----------------|-----------------|-----------------|--------------|
| `brief.md` | `scope` | `prior-work`, `review`, release checkpoint | Study title, question, scope boundary, mode, budget contract, done definition, stop rules, user constraints, and approval status | Markdown with one H1 title and fixed sections for `Question`, `Boundary`, `Mode`, `Budget`, `Done Definition`, `Stop Rules`, and `Constraints`; use explicit ISO dates and stable study ids |
| `prior-work-map.md` | `prior-work` | `perspectives`, `hypotheses`, `report`, `review` | Source ids, source types, key claims, contradiction notes, perspective tags, archive overlaps, codebase or dataset mentions, and open gaps | Markdown organized by evidence cluster or source family; every claim cites source ids; keep the gap list separate from accepted findings |
| `hypothesis-backlog.md` | `perspectives`, `hypotheses`, `analyze-prune` | `hypotheses`, `experiment-design`, `report`, `review` | Hypothesis id, statement, falsifiability note, novelty guess, expected value, expected cost, current status, linked evidence ids, and prune reason when applicable | Markdown table or ordered list sorted by rank; allowed statuses are `proposed`, `planned`, `tested`, `supported`, `rejected`, and `parked`; pruned rows stay visible |
| `experiment-ledger.jsonl` | `experiment-design`, `probes` | `probes`, `analyze-prune`, `report`, `review`, `meta-learn` | Contract id, hypothesis id, entry kind, timestamps, planned probe, executed probe, inputs, outputs, source ids, failures, costs, negative results, and reproducibility notes | JSONL only; append one object per event; pair `planned` and `executed` entries by `contract_id`; corrections append new events instead of mutating old ones |
| `report.md` | `report` | `review`, release checkpoint, optional PA or SWE handoff | Executive summary, claim table, evidence table, uncertainty notes, limitations, recommendations, and next questions | Markdown with stable claim ids; every material claim cites source ids or ledger contract ids; limitations are required even when findings look strong |
| `review.md` | `review` | release checkpoint, archive readers | Criterion scores, blocking issues, disagreements, release verdict, and calibration notes | Markdown with a fixed score table keyed by `C1` through `C5`; review comments point back to claim ids or ledger ids; the review never rewrites the report inline |
| `meta-learning.md` | `meta-learn` | future harness work, optional archive readers | What helped, what wasted budget, evaluator misses, adapter issues, candidate harness changes, and deferred promotion notes | Markdown with sections for `Reusable Lessons`, `Study-Local Noise`, and `Deferred Changes`; never auto-edit prompts, commands, or skills from this artifact |

## Handoff Packet Contract

Every approved stage emits a handoff packet before reset or delegation.
The packet is the minimum contract for continuation.

| Field | Required | Description |
|-------|----------|-------------|
| `stage_name` | yes | The last approved state from the RnD workflow, such as `prior-work` or `review` |
| `artifact_paths` | yes | Relative paths to the artifacts and sidecars required to resume safely |
| `unresolved_questions` | yes | Array of open questions, blockers, or ambiguities that the next stage must resolve or preserve |
| `next_allowed_states` | yes | Array of valid next workflow states, including `stop` when a stop condition is active |
| `generated_at` | recommended | ISO 8601 timestamp for the handoff packet |
| `budget_snapshot_path` | recommended | Relative path to the budget state used to justify the transition |

### Handoff Packet Template

```json
{
  "stage_name": "analyze-prune",
  "artifact_paths": [
    "docs/research/2026/study-slug/prior-work-map.md",
    "docs/research/2026/study-slug/hypothesis-backlog.md",
    "docs/research/2026/study-slug/experiment-ledger.jsonl",
    "docs/research/2026/study-slug/report.md"
  ],
  "unresolved_questions": [
    "Does claim H2 need one more contradiction check or is the remaining uncertainty acceptable?",
    "Can the report make a recommendation without escalating beyond literature-only mode?"
  ],
  "next_allowed_states": [
    "experiment-design",
    "report",
    "stop"
  ],
  "generated_at": "2026-04-08T12:34:56Z",
  "budget_snapshot_path": ".rnd/sessions/session-123/budget.json"
}
```

## Sidecar Conventions

Use adjacent `.json` sidecars for machine-readable mirrors and indexes.
Keep runtime control files such as `.rnd/sessions/{id}/state.json` and `.rnd/sessions/{id}/budget.json` separate from archive-side sidecars, even when they mirror some of the same fields.

| Primary artifact | Preferred companion | Purpose |
|------------------|---------------------|---------|
| `brief.md` | `brief.json` plus runtime mirror in `state.json` | Stable machine copy of the approved contract and checkpoint state |
| `prior-work-map.md` | `prior-work-map.json` | Source index, source ids, hashes, and gap ids |
| `hypothesis-backlog.md` | `hypothesis-backlog.json` | Ranked hypothesis records and status history |
| `experiment-ledger.jsonl` | `experiment-ledger.summary.json` | Probe summary, counts, and latest per-contract state |
| `report.md` | `report.json` | Claim index, evidence pointers, and recommendation ids |
| `review.md` | `review.json` | Normalized criterion scores, blockers, and release verdict |
| `meta-learning.md` | `meta-learning.json` | Structured lesson ids, categories, and promotion candidates |
| `meta-learning.md` plus session runtime | `study-metrics.json` | Budget utilization, stage durations, probe efficiency, quality scores, derived ratios, and meta-learning counts for `meta-learn` or `--meta extract`, consumed by `--meta analyze` or `--meta suggest` |

Every `.json` sidecar should contain `schema_version`, `study_id`, `artifact`, `producer_stage`, and `updated_at`.
Sidecars store normalized ids, ranks, hashes, enums, and path pointers rather than duplicating long prose.
Use UTF-8, deterministic key order, and two-space indentation for rewriteable `.json` files.
Use append-only `.jsonl` only for event streams and logs where deletion would hide negative history.

## Archive Index Runtime State

`archive-index.json` lives at `.rnd/archive-index.json`.
It is owned by `scripts/rnd-archive-index.sh`, which provides the `build` and `update` lifecycle actions.
The index is append-only under targeted `update` writes and supports full rebuilds from `docs/research/` when repair or backfill is needed.
Phase `3` consumes it for novelty checks, and Phase `5` consumes it for prior-work reuse.
It is not an archive artifact.
It is runtime state under `.rnd/`.

## Branch Search Runtime Artifacts

These artifacts are optional extensions for branch search and remain empty or absent when `state.json.branch_search.enabled = false`.

### `queue.json`

`queue.json` lives at `.rnd/sessions/{id}/queue.json`.
It is owned by the orchestrator and critic during branch-search stages, and it is mutable runtime state rather than an archive artifact.
Initialize it when the session starts or when branch search is first enabled.
Update it after branch creation, wave scheduling, contract assignment, scoring, pruning, merging, and reserve reallocation.
Keep the file session-scoped even when the final snapshot is useful for debugging, because the authoritative audit trail belongs in the archive ledger.

| Required field | Description |
|----------------|-------------|
| `schema_version` | Must be `rnd-queue.v1` |
| `reserve_probes` | Integer count of held-back probes that remain available for later waves |
| `branches` | Object keyed by `branch_id` with one mutable record per live or closed branch |
| `waves` | Array of wave scheduling records in execution order |

Each branch record in `branches` must include `branch_id`, `label`, `lead_hypothesis`, `hypothesis_ids`, `tension_points`, `status`, `sub_stage`, `contracts`, `scores`, and `budget`.
Each wave record in `waves` must include `wave_id`, `branch_ids`, and `status`.
Use `templates/rnd/queue.json` as the schema reference for field names and nested record shape.

### `branch-ledger.jsonl`

`branch-ledger.jsonl` lives at `docs/research/{year}/{slug}/branch-ledger.jsonl`.
It is an append-only archive artifact that records every `prune`, `survive`, `merge`, and `expand` decision for pruning auditability.
Never rewrite or delete prior entries, because branch failures and merged angles are part of the reproducibility record.
Write a new entry after each analyzed wave and whenever a merge or expansion decision changes future branch allocation.

| Required field | Description |
|----------------|-------------|
| `entry_kind` | One of `prune`, `survive`, `merge`, or `expand` |
| `branch_id` | Branch identifier such as `br-001` |
| `wave_id` | Wave identifier that anchors the decision to a probe batch |
| `scores` | `B1` through `B4` score breakdown |
| `composite` | Sum of `B1` through `B4` |
| `decision` | Final branch outcome after score interpretation |
| `reason` | Short explanation tied to evidence and budget |
| `evidence_refs` | Source ids, claim ids, or ledger anchors that justify the decision |
| `budget_spent` | Probe and adapter cost attributed to the branch by the decision point |
| `merge_target` | Required for merge entries and null otherwise |
| `expand_contracts` | Required for expand entries and empty otherwise |
| `decided_at` | ISO 8601 timestamp for the decision |

Use `templates/rnd/branch-ledger-entry.json` as the entry format reference.
Mirror the append-only discipline from `experiment-ledger.jsonl` so branch pruning can be audited without replaying chat history.
