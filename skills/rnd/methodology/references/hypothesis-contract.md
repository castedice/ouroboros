# Hypothesis Contract

This reference defines the literature-probe contract used during `experiment-design` and `probes`.
No expensive probe starts until a contract exists and an evaluator has accepted it.

## Required Contract Fields

| Field | Required | Description |
|-------|----------|-------------|
| `contract_id` | yes | Stable identifier for one planned probe family, such as `H03-P01` |
| `hypothesis_id` | yes | Identifier of the backlog entry this probe is testing |
| `branch_id` | optional | Branch identifier, such as `br-001`, when branch search is active and the contract belongs to a branch cluster |
| `target_claim` | yes | The precise claim or uncertainty the probe is meant to confirm, weaken, or resolve |
| `planned_probe_type` | yes | The planned literature probe category, such as `claim-triangulation`, `citation-chase`, `repo-read`, `contradiction-check`, `archive-compare`, or `quality-audit` |
| `success_signal` | yes | Observable condition that means the probe produced enough evidence to count as a meaningful success |
| `failure_signal` | yes | Observable condition that means the probe weakens the claim, reveals a contradiction, or proves the probe path unhelpful |
| `budget_allowance` | yes | Maximum wall-clock, adapter calls, source count, and retry allowance that may be spent on this contract |
| `completion_artifact` | yes | The stable artifact path or artifact anchor that proves the contract completed, such as a ledger entry id or report claim id |
| `input_refs` | recommended | Pointers to the prior-work gaps, sources, or archived studies that motivated the probe |
| `reviewer_note` | recommended | The evaluator's approval note or risk warning for the contract |

## Budget Allowance Shape

The contract budget should be explicit enough that a later evaluator can tell whether the probe stayed inside the plan.
For the literature-only MVP, use the following nested fields inside `budget_allowance`.

| Field | Description |
|-------|-------------|
| `max_minutes` | Maximum wall-clock minutes for the contract |
| `max_web_search_calls` | Maximum WebSearch calls allowed for this contract |
| `max_web_fetch_calls` | Maximum WebFetch calls allowed for this contract |
| `max_routed_model_calls` | Maximum routed-model calls allowed for this contract |
| `max_sources_examined` | Maximum distinct sources that may be read or cited for this contract |
| `retry_limit` | Maximum reruns allowed when trace capture or fetch stability fails |

## Branch Search Extension Field

When branch search is active, add `branch_id` to both planned and executed ledger entries.
The field is optional for the literature-only path and should be omitted rather than left blank when no branch exists.
Use the same `branch_id` value across all contracts and branch-ledger entries that belong to the same tension-point cluster.

## Planned Ledger Entry Template

Write one `planned` entry to `experiment-ledger.jsonl` before execution begins.

```json
{
  "entry_kind": "planned",
  "contract_id": "H03-P01",
  "hypothesis_id": "H03",
  "branch_id": "br-001",
  "stage": "experiment-design",
  "target_claim": "Technique X is more sample-efficient than Technique Y for low-data adaptation.",
  "planned_probe_type": "claim-triangulation",
  "success_signal": "At least three independent high-quality sources support the direction of the claim or explain the same mechanism.",
  "failure_signal": "High-quality sources contradict the claim or only provide derivative restatements without direct evidence.",
  "budget_allowance": {
    "max_minutes": 20,
    "max_web_search_calls": 2,
    "max_web_fetch_calls": 5,
    "max_routed_model_calls": 0,
    "max_sources_examined": 6,
    "retry_limit": 1
  },
  "completion_artifact": "docs/research/2026/study-slug/experiment-ledger.jsonl#H03-P01",
  "input_refs": [
    "docs/research/2026/study-slug/prior-work-map.md#gap-g2",
    "docs/research/2026/study-slug/hypothesis-backlog.md#H03"
  ],
  "reviewer_note": "Good falsifiability, but watch for benchmark claims that depend on hidden dataset choices.",
  "created_at": "2026-04-08T12:34:56Z"
}
```

## Executed Ledger Entry Template

Write one `executed` entry after the probe finishes, aborts, or is stopped.
The executed entry must reference the planned entry through the same `contract_id`.

```json
{
  "entry_kind": "executed",
  "contract_id": "H03-P01",
  "hypothesis_id": "H03",
  "branch_id": "br-001",
  "stage": "probes",
  "status": "success",
  "planned_probe_type": "claim-triangulation",
  "executed_probe_type": "claim-triangulation",
  "source_ids": [
    "src-001",
    "src-004",
    "src-019"
  ],
  "inputs": [
    "query: sample efficient low-data adaptation technique x technique y",
    "prior-work gap g2"
  ],
  "outputs": [
    "docs/research/2026/study-slug/prior-work-map.md#cluster-c4",
    "docs/research/2026/study-slug/report.md#claim-r2"
  ],
  "success_signal_observed": true,
  "failure_signal_observed": false,
  "completion_artifact": "docs/research/2026/study-slug/report.md#claim-r2",
  "budget_spent": {
    "minutes": 17,
    "web_search_calls": 2,
    "web_fetch_calls": 4,
    "routed_model_calls": 0,
    "sources_examined": 5
  },
  "negative_results": [
    "One widely linked blog post traced back to the same paper and was excluded as non-independent."
  ],
  "deviations": [],
  "reproducibility_note": "All cited sources were snapshotted and linked by source id.",
  "completed_at": "2026-04-08T12:52:31Z"
}
```

## Validation Rules

The `target_claim`, `success_signal`, and `failure_signal` must be testable from the resulting artifacts rather than from the operator's impression.
The executed entry may narrow the interpretation of the claim, but it may not silently change the claim, the probe family, or the budget ceiling without a new planned entry.
The `completion_artifact` must point to a durable file path or anchor, not to a chat turn or ephemeral tool output.
If the probe fails because the trace is incomplete, record the failure in the executed entry and consume retry budget rather than rewriting history.

## Reserve Probe Allocation

Reserve probes are the held-back portion of branch-search probe budget that stays unassigned during the initial wave.
Use the default reserve formula `max(2, ceil(probe_budget * 0.15))` unless `.rnd/sessions/{id}/budget.json` overrides it.
Initial contract allocation should spend only the non-reserve portion across the first scheduled wave.
During `analyze-prune`, the critic may assign reserve probes only to branches that survive or expand on evidence.
Use reserve probes to close a decision-critical gap, break a high-impact tie, or stress-test a distinct branch with unusually high upside.
Do not spend reserve probes to rescue a branch that already falls below the prune threshold without new contrary evidence.
When a reserve probe is assigned, record the branch linkage through `branch_id` and append the resulting `planned` and `executed` entries as normal.
