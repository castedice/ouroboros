# Review Rubric

This reference defines the five RnD review criteria and the release threshold for a study package.
The reviewer evaluates artifacts and traces, not the generator's confidence.

## Scoring Scale

Use a three-point scale for each criterion.
`0` means the criterion fails or is materially unsupported.
`1` means the criterion is partially met but still has meaningful weakness.
`2` means the criterion is clearly met with traceable evidence.

## Criteria

| ID | Question it answers | Evidence required | Failure mode it catches | Scoring guide |
|----|---------------------|-------------------|-------------------------|---------------|
| `C1` Usefulness | Does the study narrow a decision, reduce uncertainty, or justify a concrete next move? | Clear line from `brief.md` to report recommendations and decision consequences | Polished report that does not change any choice | `0`: no actionable narrowing, `1`: some narrowing but next move is still vague, `2`: clearly changes or justifies a concrete decision or next action |
| `C2` Novelty | Does the study add something beyond the prior-work map and archive baseline? | Explicit contrast against `prior-work-map.md`, archive overlaps, and existing assumptions | Repackaged summary that only restates known material | `0`: no new synthesis, `1`: useful recombination or sharper framing, `2`: non-obvious connection, contradiction resolution, or genuinely new branch |
| `C3` Reproducibility | Could a fresh agent rerun the important probes from the stored artifacts? | Complete contracts, source ids, ledger traces, and stable artifact pointers | Claims that depend on missing execution context or memory | `0`: critical path is not rerunnable, `1`: partial rerun path with gaps, `2`: critical path can be rerun from files alone |
| `C4` Evidence Quality | Are claims backed by strong sources or valid probes with limitations stated? | Claim-to-evidence table, source quality judgments, and limitation notes | Unsupported or weakly supported conclusions | `0`: claims outrun evidence, `1`: evidence is mixed or caveats are thin, `2`: claims are proportionate to evidence and limits are explicit |
| `C5` Calibration | Do confidence and uncertainty match the strength of the evidence? | Confidence notes, prune reasons, negative results, and reviewer commentary | Overconfident synthesis or hidden ambiguity | `0`: certainty ignores gaps, `1`: some uncertainty is acknowledged but still optimistic, `2`: confidence and uncertainty are matched honestly to the evidence |

## Release Threshold

Use the criteria to produce one of three release verdicts.

| Verdict | Threshold | Meaning |
|---------|-----------|---------|
| `release` | `C3 = 2`, `C4 = 2`, `C5 = 2`, no blocking issue, and at least one of `C1` or `C2` is `1` or higher | The study is strong enough to archive as a finished report and may be proposed for PA or SWE handoff |
| `archive-only-partial` | No safety issue, `C3`, `C4`, and `C5` are all at least `1`, but the `release` threshold is not met | The study is worth preserving as partial work, but it is not ready for confident downstream action |
| `rework` | Any of `C3`, `C4`, or `C5` is `0`, or any blocking unsupported claim remains unresolved | The study must return to an earlier state before release |

Novelty and usefulness vary by study type.
A replication-style or landscape-mapping study may still be releaseable with a modest `C2` score if reproducibility, evidence quality, and calibration all pass clearly.
No study is releaseable while a decision-critical claim lacks adequate evidence.

## Blocking Issue Rules

Treat the following as blocking issues regardless of total score.

| Blocking issue | Why it blocks |
|----------------|---------------|
| Unsupported decision-critical claim | The report would overstate what is known |
| Missing or irrecoverable source identity for a key claim | The evidence chain cannot survive reset or audit |
| Critical probe cannot be reproduced or traced | The strongest evidence may be illusory |
| Review and report disagree on the same frozen claim without explicit resolution | The release candidate is internally inconsistent |

Use routed consensus only on boundary cases or high-impact disagreements.
The review artifact must preserve the disagreement reasoning, the final score breakdown, and the release recommendation separately from the report itself.
