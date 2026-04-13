# Branch Rubric

This reference defines the branch-search scoring rubric used during `analyze-prune`.
The critic evaluates branch evidence and trace quality after each probe wave, not the investigator's confidence.

## Scoring Scale

Use a three-point scale for each branch criterion.
`0` means the branch currently fails the criterion or lacks enough traceable support.
`1` means the branch shows partial value but still has a material weakness or unresolved risk.
`2` means the branch clearly earns continued attention with traceable evidence from the latest wave.

## Criteria

| ID | Question it answers | Evidence required | Failure mode it catches | Scoring guide |
|----|---------------------|-------------------|-------------------------|---------------|
| `B1` Signal Gain | Does this branch meaningfully reduce uncertainty, close a contradiction, or sharpen the decision space? | Clear before-and-after evidence from the latest wave, including negative results that close a live uncertainty | Probe work that generated notes but did not change any decision or uncertainty | `0`: no meaningful update, `1`: some narrowing but uncertainty remains broad, `2`: clear narrowing, contradiction resolution, or justified disconfirmation |
| `B2` Evidence Strength | Are the branch conclusions supported by credible, traceable, and sufficiently direct evidence? | Strong source ids, probe outputs, contradiction notes, and explicit limits | Attractive branch narratives that outrun the underlying evidence | `0`: evidence is weak, missing, or mostly derivative, `1`: mixed evidence or thin caveats, `2`: evidence is strong enough for the current claim and its limits are explicit |
| `B3` Cost Efficiency | Did this branch earn its signal relative to the budget it consumed or now requests? | Budget spent, probe yield, retry history, and comparison with alternative branches | Branches that burn probe budget without proportional learning | `0`: poor return for the cost, `1`: acceptable but not compelling return, `2`: strong learning per probe or justified low-cost coverage closure |
| `B4` Distinctiveness | Does this branch remain meaningfully different from the other live branches? | Distinct tension point, contradiction, mechanism, or gap that is not already covered elsewhere | Duplicate branches that should have been merged earlier | `0`: effectively duplicate, `1`: partially overlapping but still somewhat distinct, `2`: clearly distinct angle that would be lost if collapsed |

## Composite Score

Compute the branch composite as `B1 + B2 + B3 + B4`.
The maximum composite score is `8`.
Use the composite as the default pruning signal, but keep the decision tied to traceable branch reasons instead of raw score alone.
When two branches tie on composite, prefer the branch with the higher `B2`, then the higher `B1`, then the higher `B3`.

## Outcome Rules

Use the rubric to produce one of four branch outcomes after each wave.
The default prune threshold is `4`, and the runtime may override it through `.rnd/sessions/{id}/budget.json`.

| Outcome | Default rule | Meaning |
|---------|--------------|---------|
| `prune` | `composite < prune_threshold` | Stop allocating new probes to the branch, keep its history visible, and record the prune reason in the queue and branch ledger |
| `survive` | `composite >= prune_threshold` and no stronger merge or expand condition applies | Keep the branch active for the next decision point without increasing its scope |
| `merge` | `composite >= prune_threshold` and another active branch covers the same tension point more cleanly, usually with `B4 <= 1` | Close the branch as a separate line of search and move its evidence into the stronger branch with an explicit `merge_target` |
| `expand` | `composite >= 6` and the branch remains distinct enough to justify new contracts, usually with `B1 >= 2` or `B4 >= 2` | Authorize additional contracts or reserve probes because the branch is both promising and meaningfully different |

`merge` is not a failure outcome.
Use it when a branch learned something useful but should no longer compete for parallel budget as an independent line of search.
`expand` should be rare and should consume reserve probes before it increases the overall probe footprint.

## Negative Results Still Score

A branch may still score well when the latest wave disproves a tempting claim, closes a decision-critical uncertainty, or rules out an entire low-value angle.
Strong falsification can earn `B1 = 2` when it materially narrows the search space.
Negative results can also earn `B2 = 2` when the disconfirmation is backed by strong, traceable evidence.
Do not punish honest contradiction closure just because the branch did not confirm its original hypothesis.

## Critic Application Protocol

After each probe wave, gather the latest branch evidence from `experiment-ledger.jsonl`, `hypothesis-backlog.md`, and `.rnd/sessions/{id}/queue.json`.
Score every active branch on `B1` through `B4` using the latest wave plus the cumulative branch trace.
Choose `prune`, `survive`, `merge`, or `expand`, then write the updated branch state to `queue.json`.
Append one decision event per affected branch to `branch-ledger.jsonl`, including score breakdown, decision, reason, and evidence references.
Allocate reserve probes only after the scoring pass is complete and only to branches that survive or expand on evidence rather than optimism.
