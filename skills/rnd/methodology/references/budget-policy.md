# Budget Policy

This reference defines the default budget policy for the `literature-only` RnD MVP.
The policy is intentionally strict, because bounded autonomy is part of the methodology rather than an implementation detail.

## Default MVP Caps

| Budget dimension | Session cap | Phase cap or local limit | Notes |
|------------------|-------------|---------------------------|-------|
| Wall-clock | `120` minutes hard cap | `25` minutes hard cap for any non-`probes` stage and `40` minutes for `probes` | Stop immediately when the hard cap is hit |
| Token budget | `120000` tracked tokens | Warn at `70%` of expected phase spend and `85%` of session spend | Use for pruning and compaction decisions, not as a reason to skip artifact persistence |
| WebSearch adapter calls | `12` calls per session | `4` calls in `prior-work`, `2` in `perspectives`, and at most `2` per active hypothesis cycle | Retries count against the cap |
| WebFetch adapter calls | `24` calls per session | `8` calls in `prior-work`, `4` in `perspectives`, and at most `6` per active hypothesis cycle | Fetch only shortlisted sources |
| Model routing calls | `4` calls per session | `2` in `hypotheses`, `1` in `review`, and `1` in `meta-learn` | Spend only on ambiguity, adversarial review, or boundary cases |
| Probe contracts per hypothesis | `3` total | One active contract at a time per hypothesis | More than three probe families usually indicates a weak branch |
| Probe retries | `1` per contract | No second retry without human approval | Repeated trace failure is evidence in itself |
| Compute budget | `0` | `0` | Code and data execution are out of scope for the literature-only MVP |

## Phase-Level Versus Session-Level Tracking

Session-level budgets live in `.rnd/sessions/{id}/budget.json`.
They track monotonic totals across the entire study and never reset until the study ends.
Phase-level counters also live in `budget.json`, but they reset when the workflow enters a new approved state.
Per-contract planned and spent budget is duplicated into `experiment-ledger.jsonl` so the probe history stays auditable after reset.
Cross-adapter and cross-model cost events should also append to `.rnd/costs.jsonl`.

### Tracking Shape

```json
{
  "session": {
    "wall_clock_minutes_cap": 120,
    "wall_clock_minutes_used": 47,
    "web_search_calls_cap": 12,
    "web_search_calls_used": 5,
    "web_fetch_calls_cap": 24,
    "web_fetch_calls_used": 9,
    "model_routing_calls_cap": 4,
    "model_routing_calls_used": 1
  },
  "phases": {
    "prior-work": {
      "wall_clock_minutes_used": 18,
      "web_search_calls_used": 3,
      "web_fetch_calls_used": 6
    }
  }
}
```

Unused phase budget does not automatically authorize extra probe count.
Any budget increase or mode escalation requires a fresh contract and human approval.

## Stop Conditions

| Stop condition | Trigger | Required action |
|---------------|---------|-----------------|
| Success reached | The report meets the brief's done definition and passes review thresholds | Freeze the report, persist the review, and move to release handling |
| Diminishing returns | Two consecutive cycles add no new evidence or only restate prior claims | Stop probing, finalize limitations, and move to report or review |
| Budget exhausted | Any hard cap is reached | Stop immediately and emit a partial report with the budget note |
| Unsupported claim | Evaluator finds a key claim without adequate evidence chain | Return to the last valid state or prune the claim |
| Reproducibility failure | A critical probe cannot be rerun or traced within retry allowance | Mark the claim provisional or drop it |
| Human kill switch | The user stops the study, rejects escalation, or closes the run | Persist state and stop cleanly |
| Safety issue | A source, tool, or requested escalation crosses the allowed boundary | Stop, log the refusal, and require human review |

## Enforcement Rules

Budget checks happen before a stage starts, before a contract is approved, and after every probe batch.
The kill-switch set is hard budget exhaustion, explicit user stop, repeated unreproducible critical probes, and adapter-level safety refusal.
Compaction is allowed only when it is cheaper than handing off and never replaces artifact persistence at a stage boundary.
When in doubt, stop early with an honest partial report rather than spending the last budget on speculative collection.
