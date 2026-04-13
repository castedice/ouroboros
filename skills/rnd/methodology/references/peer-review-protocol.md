# Peer Review Protocol

This reference defines the multi-model adversarial review protocol for Phase 11 of the RnD workflow.
The goal is to add an independent challenge function without adding a third-judge layer.

## Review Roles

| Role | Executor | Input packet | Required behavior | Output |
|------|----------|--------------|-------------------|--------|
| Primary Reviewer | `critic` agent on Claude | The frozen study artifacts plus `review-rubric.md` | Score `C1` through `C5`, identify blocking issues, and issue a raw verdict from the rubric threshold | Primary review section in `review.md` |
| Adversarial Reviewer | External model via `codex-relay.sh` | The same frozen study artifacts plus `review-rubric.md`, without the primary review scores, notes, blockers, or verdict | Score `C1` through `C5` independently, try to falsify release, attack the weakest claim-evidence chain first, and do not repair the artifact | Adversarial review section in `review.md` |

The adversarial reviewer must see the same artifacts as the primary reviewer.
The adversarial reviewer must not see the primary review output before its own review is complete.

## Score Consensus Rules

Apply score consensus per criterion for `C1` through `C5`.

| Case | Consensus score | Rule |
|------|-----------------|------|
| Both reviewers give the same score | Use that score | Direct agreement |
| The reviewers split | Use the lower score | `DR-107` lower-score rule |

Consensus scoring is mechanical.
No reviewer may overwrite the other reviewer's score with prose alone.

## Blocker Merge Rules

Use blocker merge after both raw reviews exist.
Treat a concrete anchor as a stable claim id, source id, contract id, or file anchor that makes the blocker auditable.

| Case | Final status | Action |
|------|--------------|--------|
| Both reviewers raise the same blocker root | Confirmed blocking | Trigger blocking rework handling |
| Only one reviewer raises a rubric-defined absolute blocker with a concrete anchor | Confirmed blocking | Trigger blocking rework handling |
| Only one reviewer raises a blocker without a concrete anchor | Minority concern | Record it in the review artifact, but do not trigger automatic rework |

The blocker root is the underlying failure, not the wording.
Two differently phrased notes about the same unsupported frozen claim or the same missing source identity count as the same blocker root.

## Verdict Derivation

In adversarial mode, derive the final verdict from the consensus scores plus the confirmed blockers.
Use the existing release threshold in `review-rubric.md`.
Do not copy the final verdict directly from either reviewer's raw verdict.
Keep the raw reviewer verdicts in the artifact for auditability.

In `single` and `single-fallback` modes, preserve the existing single-review behavior and use the primary review outcome directly.

## Fallback Behavior

Reviewer availability must not decide whether the study succeeds or fails as a workflow run.

| Condition | Review protocol | Behavior |
|-----------|-----------------|----------|
| `--single` flag is present | `single` | Skip adversarial review entirely and use the primary reviewer only |
| Codex is unavailable and `--single` is absent | `single-fallback` | Degrade to primary-only review and record the fallback explicitly in `review.md` |
| Both reviewers are available and `--single` is absent | `adversarial` | Run both reviews and apply consensus plus blocker merge |

Never fail the study because a reviewer is unavailable.
Reviewer unavailability changes review mode, not study status.

## No Third Judge

v3.4.0 does not use a third judge.
The adversarial reviewer already provides the challenge function, so disagreement resolves through the lower-score rule and the blocker merge rules.
