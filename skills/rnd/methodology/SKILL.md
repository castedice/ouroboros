---
name: rnd-methodology
description: This skill provides autonomous research methodology for the RnD module. It should be activated when an agent needs to "run a bounded research study", "map prior work", "generate competing perspectives", "rank falsifiable hypotheses", "design literature probes", "review research quality", or "resume a study from persisted artifacts".
summary: Runs budgeted research studies through artifact-first stages for prior work, hypotheses, literature probes, reports, review, and meta-learning.
version: 1
tags: [rnd, research, methodology, artifacts, hypotheses, review]
preamble_tier: 4
---

# RnD Methodology

## Core Rule

If you are running as a subagent dispatched by a command, skip loading this skill.
Commands already embed the relevant methodology inline.

**"Budget first, artifacts first, and evidence before narrative."**

RnD is a ten-stage workflow: **Scope → Prior-work → Perspectives → Hypotheses → Experiment-design → Probes → Analyze-prune → Report → Review → Meta-learn**.
The MVP posture is `literature-only`, so use read-only papers, docs, repos, archived studies, and normalized external content by default.
Escalation to code or data is a contract change that needs a revised budget and human approval.
Every stage has a generator and an evaluator, and the evaluator either accepts the artifact, prunes it, or returns it with explicit failure reasons.
Stage boundaries are reset boundaries, and persisted artifacts outrank chat memory.

## Gotchas

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Treating `literature-only` as a shallow summary mode | All | Keep falsifiable hypotheses, explicit probe contracts, and review gates even when probes are read-only |
| Letting the generator self-approve | All | Keep evaluator passes independent and require explicit acceptance or rejection |
| Deleting failed branches to make the report cleaner | Analyze-prune | Preserve negative results and prune reasons in the backlog and ledger |
| Blending review into report writing | Report, Review | Freeze the report first and keep review separate |
| Treating meta-research suggestions as confirmed improvements | Meta-learn, Meta-research | All suggestions from `--meta suggest` are hypothesis-grade. The critic must reject any suggestion phrased as a directive. Changes require human approval. |
| Missing SUBAGENT-STOP guard behavior | All | Treat SubagentStop as a hard stop for delegated agents, and persist handoff artifacts instead of loading this skill from inside the subagent. |

### Rationalization Red Flags

Treat these as research-integrity anti-drift checks before changing scope, stage gates, or evidence handling.

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "It is literature-only, so a narrative summary is enough" | Skipping hypotheses, probe contracts, or review gates | Keep falsifiable hypotheses, planned ledger entries, and evaluator acceptance even for read-only probes |
| "The evaluator can just clean up the artifact while reviewing it" | Letting the evaluator rewrite and accept the generator output | Return explicit failure reasons and make the generator revise the artifact |
| "The archive already studied this, so reuse the conclusion as evidence" | Treating archive novelty hits as accepted evidence for the new study | Use archive findings as context, then validate claims through current source records or ledger contracts |
| "Negative branches make the recommendation look weaker" | Deleting failed probes, weak branches, or prune reasons | Preserve negative results in the backlog and ledger, then explain how they changed confidence |
| "One quick script would settle the uncertainty" | Escalating from `literature-only` to executable code or observed data without a contract change | Revise the budget, probe contract, and approval state before running code or collecting data |

## Workflow

| Stage | Generator responsibility | Evaluator responsibility | Primary artifact |
|-------|--------------------------|--------------------------|------------------|
| `scope` | Write a bounded brief with question, mode, budget, and done definition. | Reject vague scope, weak success criteria, or budget mismatch. | `brief.md` |
| `prior-work` | Collect papers, docs, repos, archived studies, and normalized external sources into a map. | Score source quality, coverage, contradictions, and obvious gaps. | `prior-work-map.md` |
| `perspectives` | Generate skeptic, practitioner, theorist, and adversarial lenses. | Remove duplicate or decorative tension. | `hypothesis-backlog.md` seed |
| `hypotheses` | Rank falsifiable branches by expected value per cost. | Prune redundant, unfalsifiable, or low-value branches. | `hypothesis-backlog.md` |
| `branch-grouping` | Cluster ranked hypotheses into tension-point branches and initialize branch queue state when branch search is active. | Reject orphan hypotheses, artificial splits, or duplicate research angles. | `.rnd/sessions/{id}/queue.json` |
| `experiment-design` | Write literature-probe contracts with claim, probe type, signals, budget, and proof artifact. | Check falsifiability, reproducibility, and budget fit. | `experiment-ledger.jsonl` planned entries |
| `probes` | Run one contracted literature probe family at a time. | Verify trace completeness, contract satisfaction, and result integrity. | `experiment-ledger.jsonl` executed entries |
| `analyze-prune` | Update confidence, merge evidence, and prune weak branches. | Check claim-to-evidence alignment and whether more probes are justified. | Updated backlog and report draft sections |
| `report` | Freeze claims, evidence tables, limits, recommendations, and next questions. | Reject claims that cannot be traced to source or ledger ids. | `report.md` |
| `review` | Package the release candidate and unresolved issues. | Score `C1` to `C5` and issue the verdict. | `review.md` |
| `meta-learn` | Distill process lessons, wasted spend, evaluator misses, and harness ideas. | Separate reusable lessons from study-local noise. | `meta-learning.md` |

Reset after each accepted stage or probe batch unless continuing is clearly cheaper than handoff.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Default mode | Stay in `literature-only` unless the strongest remaining uncertainty depends on executable behavior or observed data |
| Budget discipline | Allocate wall-clock, adapter-call, and probe budgets before the first search or fetch of a new contract |
| Generator-evaluator separation | The evaluator must never silently rewrite the generator artifact, and the generator must never self-certify completion |
| Reset principle | A stage is complete only when a fresh agent could continue from persisted artifacts and a handoff packet without prior chat history |
| Evidence discipline | Cite source ids or ledger contract ids, and keep failed probes visible |
| Branch activation | When 3+ hypotheses exist and `--branch` is `auto`, activate branch search automatically |
| Branch execution | When `branch_search.enabled` is true, probes execute in waves with inter-wave scoring and pruning |
| Archive novelty check | When `.rnd/archive-index.json` exists, check novelty against prior studies before scope approval |
| Archive reuse discipline | Archive findings are context for the new study, not automatically accepted evidence |
| Review protocol | When `--single` is absent and the external reviewer is available, use adversarial multi-model review; otherwise degrade to `single-fallback` and record explicitly |
| Citation export | Run `rnd-cite.sh extract` after meta-learning to generate `references.bib` from cited source records |
| Meta-research advisory-only | Never auto-edit prompts, commands, skills, or scripts from meta-research output. All suggestions write to `.rnd/meta-report.md` only. |
| Reuse of existing infrastructure | Reuse core source evaluation, core routing, `scripts/codex-relay.sh`, and `content-pipeline` instead of inventing parallel machinery |

## Reference Map

| Need | Reference |
|------|-----------|
| Study artifact, handoff, and sidecar contracts | `${CLAUDE_SKILL_DIR}/references/artifact-contracts.md` |
| Literature-probe contract and ledger entry shape | `${CLAUDE_SKILL_DIR}/references/hypothesis-contract.md` |
| Branch scoring and prune or expand rules | `${CLAUDE_SKILL_DIR}/references/branch-rubric.md` |
| Research-specific source quality overlay | `${CLAUDE_SKILL_DIR}/references/source-quality.md` |
| Final review criteria and release thresholds | `${CLAUDE_SKILL_DIR}/references/review-rubric.md` |
| Multi-model peer review protocol and consensus rules | `${CLAUDE_SKILL_DIR}/references/peer-review-protocol.md` |
| Session budgets, stop conditions, and tracking rules | `${CLAUDE_SKILL_DIR}/references/budget-policy.md` |
| Adapter operations, source records, and future stubs | `${CLAUDE_SKILL_DIR}/references/adapter-contracts.md` |
| Citation extraction and BibTeX generation | `scripts/rnd-cite.sh` |
| Archive index contract and lifecycle | `${CLAUDE_SKILL_DIR}/references/archive-index-contract.md` |
| Meta-research metrics, suggestions, and recalibration rules | `${CLAUDE_SKILL_DIR}/references/meta-research-contract.md` |
| Branch decision audit trail | `docs/research/{year}/{slug}/branch-ledger.jsonl` |

## See Also

These components are the most common callers or downstream consumers of this methodology.

| Component | Relationship |
|-----------|--------------|
| `commands/rnd.md` | Public RnD study orchestrator |
| `agents/rnd/investigator.md` | Hypothesis generation and branch grouping |
| `agents/rnd/collector.md` | Literature collection and source normalization |
| `agents/rnd/critic.md` | Stage-gate evaluation and peer review |
| `skills/core/collaboration/SKILL.md` | Coordination patterns for fan-out probes |
| `skills/core/evaluation/SKILL.md` | Quality gate methodology |
