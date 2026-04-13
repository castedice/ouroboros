---
name: evolution-methodology
description: This skill provides evolution methodology knowledge. It should be activated when an agent needs to "improve a component", "evolve a module", "apply evaluation feedback", "prioritize improvements", or "validate an evolution result".
summary: Guides incremental component improvement from baseline measurement through diagnosis, planning, execution, verification, and recording.
version: 1
tags: [core, methodology, evolution, improvement, validation]
preamble_tier: 4
---

# Evolution Methodology

## Core Rule

If you are running as a subagent dispatched by a command, skip loading this skill.
Commands already embed the relevant methodology inline.

**"One at a time, with certainty."**

Evolution is incremental, evidence-driven, and only complete after validation.
Follow the full Measure -> Diagnose -> Plan -> Execute -> Verify -> Record cycle, and treat skipped verification as a failure of the method.
Use this file for operating rules, and pull the mapped references when you need stage detail, gate logic, or retry guidance.
The method is intentionally conservative because unverified improvement is just disguised regression risk.

## Gotchas

These are the ways evolution cycles drift from disciplined improvement into noise.

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Stale evaluation used as baseline | Baseline | Verify that the baseline used the current criteria set |
| Fixing the symptom instead of the root cause | Analysis | Classify the gap as Missing, Format error, or Insufficient depth |
| Vague plan like "make it better" | Planning | State exact changes, preserved scope, and success conditions |
| Plan drift during apply | Apply | Diff the edits against the approved plan before validating |
| Total-score-only validation | Validate | Compare criterion-by-criterion, not just total score |
| Discarding failed attempt data | Retry iteration | Keep degraded attempt traces because the failure context prevents repeating the same mistake |
| Skipping the record step for a "small" change | Record | Log every evolution cycle so the pattern history compounds |

Rationalization red flags:

| Red Flag | What It Means | Correct Response |
|----------|---------------|------------------|
| No quote, no score | Validation reasoning lacks concrete evidence from the component | Score 0 for that criterion |
| Overall score up but criterion regressed | Aggregate gain is hiding local damage | Flag the regression explicitly |
| Close enough | Borderline pass is being rationalized | Binary criteria mean "almost" still scores 0 |
| Prior score anchoring | Current judgment is being pulled by previous runs | Re-evaluate from scratch and ignore history |
| Severity inflation | LOW work is being framed as HIGH to justify action | Use evidence thresholds, not urgency language |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The fix is obvious, so skip the baseline" | Editing without a fresh or still-valid per-criterion baseline | Confirm the baseline and preserve the before snapshot before planning changes |
| "This HIGH item can absorb a few nearby cleanups" | Expanding scope beyond the diagnosed gap | Keep the plan tied to the selected criteria and defer unrelated improvements |
| "The score went up, so verification is done" | Accepting aggregate improvement without checking regressions | Compare criterion-by-criterion and call out any drop from 1 to 0 |
| "The second retry just needs more polish" | Repeating the same failed strategy | Change the strategy materially or stop after the retry limit |
| "The change is small, so it does not need a record" | Skipping the record step after a validated evolution cycle | Log the cycle outcome so future improvement work can compound |

## Workflow

Each stage exists to hand a better input to the next stage.

1. Baseline the current state with a fresh or still-relevant evaluation and keep the per-criterion breakdown.
2. Diagnose root causes for 0-score criteria and prioritized improvements before proposing edits.
3. Build a bounded plan, including preserved scope, and get user confirmation before applying changes.
4. Preserve the before snapshot and implement only changes that trace back to the approved plan.
5. Validate with before/after evaluation and the quality gate, including regression checks and position swap when the comparison is pairwise.
6. Record the cycle in the decision log once the verdict is accepted.

## Decision Rules

Use these rules to keep the cycle bounded and auditable.

| Decision Point | Rule |
|----------------|------|
| Priority order | Address 0-score criteria first, then HIGH, then MED, then LOW improvements |
| Scope selection | Single-component work can batch all 0-score and HIGH items, while module work should focus on the weakest component only |
| Planning checkpoint | Do not edit until the plan states both what changes and what stays unchanged |
| Quality gate | `improved` passes, `lateral` requires an explicit keep-or-discard decision, and `degraded` fails |
| Regression handling | Any criterion that drops from 1 to 0 must be called out even if the total score rises |
| Retry policy | Retry at most twice, and the second attempt must use a materially different strategy |
| Trace preservation | Save before-snapshot, after-snapshot, strategy, evaluation summary, and diff for every attempt including degraded ones |
| Archive selection | On convergence or cap, select the best non-degraded attempt rather than always using the last iteration |

## Reference Map

Pull the detailed reference only for the stage you are actively executing.

| Need | Reference |
|------|-----------|
| Detailed stage procedures, plan structure, and record contents | `${CLAUDE_SKILL_DIR}/references/evolution-stages-detail.md` |
| Priority order, mode selection, retry examples, and cycle checklist | `${CLAUDE_SKILL_DIR}/references/planning-and-retry-rules.md` |
| Quality gate verdict logic and edge cases | `${CLAUDE_SKILL_DIR}/references/quality-gate-guide.md` |
| Bias catalog and pre-flight checks | `${CLAUDE_SKILL_DIR}/references/bias-patterns.md` |
| Researcher handoff template for diagnosis | `${CLAUDE_SKILL_DIR}/references/researcher-relay-prompt.md` |

## See Also

These components typically supply inputs to, or consume outputs from, the evolution cycle.

- **evaluate command** (`commands/core/evaluate.md`) - Produces the baseline and validation inputs that evolution depends on
- **evolve command** (`commands/core/evolve.md`) - Orchestrates the full improvement cycle around this methodology
- **evaluation-methodology** (`skills/core/evaluation/SKILL.md`) - Supplies the scoring model and comparison rules used by Baseline and Validate
- **researcher agent** (`agents/core/researcher.md`) - Common diagnosis consumer during the Analysis stage
