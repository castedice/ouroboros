# Study Archive README

This README is the reproducibility entrypoint for the archived study bundle.
Replace every `{{placeholder}}` before treating the archive as complete.

## Study Metadata

| Field | Value |
|-------|-------|
| Study ID | `{{study_id}}` |
| Question | {{question}} |
| Mode | `{{mode}}` |
| Branch Mode | `{{branch_mode}}` |
| Report Format | `{{report_format}}` |
| Created At | `{{created_at}}` |
| Completed At | `{{completed_at}}` |

## Final Status

| Field | Value |
|-------|-------|
| Review Protocol | `{{review_protocol}}` |
| Verdict | `{{verdict}}` |
| Release Decision | `{{release_decision}}` |
| Agreement Rate | `{{agreement_rate}}` |

Use `n/a` for `{{agreement_rate}}` when the review protocol is `single` or `single-fallback`.

## Bundle Inventory

| Artifact | Purpose | Notes |
|----------|---------|-------|
| `brief.md` | Approved study contract | Question, boundary, mode, budget, stop rules, and constraints |
| `prior-work-map.md` | Prior-work landscape and gaps | Source clusters, contradictions, archive overlap, and open gaps |
| `hypothesis-backlog.md` | Ranked hypothesis backlog | Proposed, tested, pruned, supported, rejected, and parked hypotheses |
| `experiment-ledger.jsonl` | Probe execution audit log | Planned and executed contracts with negative results and deviations |
| `report.md` | Final narrative report | Synthesis, claims, limitations, recommendations, and next questions |
| `review.md` | Review record | Review protocol, reviewer outputs, consensus when present, and final verdict |
| `meta-learning.md` | Process retrospective | Reusable lessons, local noise, and deferred changes |
| `references.bib` | Citation export | Bibliographic reconstruction for cited sources |
| `branch-ledger.jsonl` | Branch pruning and merge audit trail | Present when `{{branch_mode}}` enables branch search |

## Evidence Counts

| Metric | Value |
|--------|-------|
| Total Sources | `{{total_sources}}` |
| Cited Sources | `{{cited_sources}}` |
| Claims | `{{claims}}` |
| Planned Probes | `{{planned_probes}}` |
| Executed Probes | `{{executed_probes}}` |
| Branches | `{{branches}}` |

Use `0` or `n/a` for `{{branches}}` when branch search is inactive.

## Reproduction Path

1. Read `README.md` to confirm the study boundary, bundle contents, and final status.
2. Read `brief.md` to recover the approved question, boundary, budget, and done definition.
3. Read `prior-work-map.md` to recover the source landscape, contradictions, and unresolved gaps.
4. Read `hypothesis-backlog.md` to see which hypotheses were proposed, pruned, tested, or parked.
5. Read `experiment-ledger.jsonl` to reconstruct the exact probe contracts and executed evidence path.
6. Read `report.md` to inspect the synthesized claims, limitations, recommendations, and next questions.
7. Read `review.md` to inspect the review protocol, blockers, disagreements, and final release decision.
8. Read `meta-learning.md` to recover reusable lessons and study-local noise.
9. Read `references.bib` to rebuild the cited reference set.
10. Read `branch-ledger.jsonl` after Step 5 when `{{branch_mode}}` indicates branch search.

## Known Limits

- The archive stays inside the literature-only boundary and does not prove claims that would require live experiments, product telemetry, or unpublished internal data.
- Web drift can change source availability, metadata quality, or page wording after the study completed.
- Some sources may expose sparse or uneven metadata even when the claim-evidence chain is still recoverable.
