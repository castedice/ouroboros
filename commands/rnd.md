---
name: rnd
description: "Use when you need to run a bounded autonomous research study on an external question, map prior work, test hypotheses through literature probes, and produce a reviewed study package"
argument-hint: <question> [--resume <session-id>] [--status [session-id]] [--list] [--meta [extract <session-id>|analyze|suggest|status]] [--budget <minutes>] [--phase <stage>] [--branch auto|on|off] [--single] [--paper]
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Agent
  - AskUserQuestion
  - mcp__qmd__status
  - mcp__qmd__query
---

# RnD — Public Study Orchestrator

Run a bounded `literature-only` study with persisted state, explicit stage gates, an optional branch-search overlay, and clean resume behavior.
This command owns `docs/research/` and `.rnd/`.
It never writes `docs/specs/knowledge/`, `.pa/`, or production code.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|------------|------|
| 1-2 | Bash, Read | Parse intent, initialize or inspect session state, and load templates |
| 3 | investigator + critic | Draft and gate the study brief |
| 4 | AskUserQuestion | Human scope checkpoint in attended runs |
| 5 | collector + critic + optional `mcp__qmd__query` when `session-wiki` is registered | Collect and gate prior-work coverage |
| 6 | investigator + critic | Generate perspectives and prune weak tension |
| 7a | investigator + critic | Rank hypotheses and preserve pruned or parked rows |
| 7a.5 | investigator + critic + Bash (`scripts/rnd-branch.sh`, `scripts/rnd-budget.sh`) | Group ranked hypotheses into branches, initialize `queue.json`, allocate branch probe budgets, and schedule waves |
| 7b | investigator + critic | Draft linear or per-branch probe contracts and gate budget fit |
| 7, 11, 13 | Bash (`scripts/codex-relay.sh`, optional) | Optional routed second opinion when `--single` is absent and a boundary case remains |
| 8 | collector + critic + Bash (`scripts/parallel.sh`, `scripts/rnd-branch.sh`, `scripts/rnd-budget.sh`) | Run linear probes or branch waves, then validate traces, score branches, and update queue state |
| 9 | investigator + critic + Bash (`scripts/rnd-branch.sh`) | Synthesize evidence, merge or expand branches, and decide loopback vs report |
| 10 | investigator + critic | Draft and pre-review the final report |
| 11 | critic + Bash (`scripts/codex-relay.sh`) | Score `C1` to `C5`, run adversarial review when `--single` absent, consensus-merge per `peer-review-protocol.md`, and issue the release verdict |
| 12 | AskUserQuestion | Human release checkpoint in attended runs |
| 13 | investigator + Bash (`scripts/rnd-cite.sh`, `scripts/rnd-archive-index.sh`) | Distill meta-learning, generate citations and README, and finalize `state.json` as `completed` |
| 14 | investigator + critic | Cross-study meta-research analysis, suggestion generation, and advisory-only validation |

## References

| Reference | Path | Usage |
|-----------|------|-------|
| RnD methodology | `skills/rnd/methodology/SKILL.md` | Canonical 10-stage workflow and stage responsibilities |
| Investigator agent | `agents/rnd/investigator.md` | Drafting brief, perspectives, hypotheses, analysis, report, meta-learning, and meta-research |
| Collector agent | `agents/rnd/collector.md` | Query ladder collection, source normalization, and probe evidence packets |
| Critic agent | `agents/rnd/critic.md` | Stage gates, contract validation, and final `C1` to `C5` review |
| Artifact contracts | `skills/rnd/methodology/references/artifact-contracts.md` | Artifact fields, handoff packets, and reset-safe expectations |
| Hypothesis contract | `skills/rnd/methodology/references/hypothesis-contract.md` | Planned and executed ledger entry rules |
| Branch rubric | `skills/rnd/methodology/references/branch-rubric.md` | `B1` to `B4` branch scoring plus prune, merge, survive, and expand rules |
| Review rubric | `skills/rnd/methodology/references/review-rubric.md` | `C1` to `C5` scoring and verdict thresholds |
| Peer review protocol | `skills/rnd/methodology/references/peer-review-protocol.md` | Multi-model adversarial review, consensus rules, and fallback behavior |
| Budget policy | `skills/rnd/methodology/references/budget-policy.md` | Stage-bound budget rules, hard caps, and stop conditions |
| Adapter contracts | `skills/rnd/methodology/references/adapter-contracts.md` | Web search, web fetch, and routed-model contract shape |
| Source quality overlay | `skills/rnd/methodology/references/source-quality.md` | Source grading for claims, contradictions, and limitations |
| Archive index lifecycle | `scripts/rnd-archive-index.sh` | `build`, `update`, `search`, and `status` for cross-study memory |
| Archive index contract | `skills/rnd/methodology/references/archive-index-contract.md` | Schema, field rules, and consumer expectations |
| Session archive lifecycle | `scripts/session-archive.sh` | Read-only `status` and `search` for prior conversation context |
| Meta-research contract | `skills/rnd/methodology/references/meta-research-contract.md` | Metrics schema, suggestion taxonomy, recalibration rules, and advisory-only constraint |
| Meta-research report template | `templates/rnd/meta-report.md` | Cross-study analysis structure |
| Metrics lifecycle | `scripts/rnd-meta.sh` | `extract`, `aggregate`, and `status` for per-study and cross-study metrics |
| Brief template | `templates/rnd/brief.md` | Base structure for `brief.md` |
| Academic report template | `templates/rnd/report-academic.md` | Report structure when `--paper` is active |
| Report template | `templates/rnd/report.md` | Base structure for `report.md` |
| Archive README template | `templates/rnd/archive-readme.md` | Reproducibility bundle guide |
| Review template | `templates/rnd/review.md` | Base structure for `review.md` |
| Branch queue template | `templates/rnd/queue.json` | Runtime branch queue schema |
| Branch ledger template | `templates/rnd/branch-ledger-entry.json` | Append-only branch decision entry schema |
| Session lifecycle | `scripts/rnd-session.sh` | `init`, `advance`, `status`, `list`, `resume`, and `stop`, including `--branch-search` session seeding |
| Budget lifecycle | `scripts/rnd-budget.sh` | `init`, `charge`, `branch-allocate`, `branch-charge`, `check`, and `status` |
| Branch lifecycle | `scripts/rnd-branch.sh` | `init`, `allocate`, `schedule`, `score`, `prune`, `merge`, `expand`, `status`, `wave-status`, and `finalize` |
| Citation extractor | `scripts/rnd-cite.sh` | BibTeX generation from cited source records |
| Parallel execution helper | `scripts/parallel.sh` | Fan-out and fan-in coordination for branch probe waves |
| Optional routed second opinion | `scripts/codex-relay.sh` | Boundary-case hypothesis, review, or meta-learning disagreement note |
| External driver loop | `scripts/rnd-loop.sh` | Automation consumer for `needs_user`, `blocked_escalation`, and `completed` |

## System Boundaries

| Boundary | Rule |
|----------|------|
| `core:research` | Use `core:research` for knowledge-base learning, and use `/rnd` for bounded study packages under `docs/research/` |
| `pa` | Suggest `/pa ingest docs/research/{year}/{slug}/report.md` only after a `release` verdict and a human `release` decision |
| `swe` | Suggest SWE work only as a recommendation in `report.md` or `review.md`, and never as an automatic side effect |
| Study mode | Default and current implementation scope is `literature-only`, and requests that require code or data mode become `blocked_escalation` |
| Artifact ownership | The command writes all files, updates session state, and owns script calls, while agents return payloads only |
| Resume model | Persisted artifacts and `handoff/latest.json` outrank chat memory at every resume point |

## Phase-To-Stage Map

The command exposes 13 baseline orchestration phases plus the conditional Phase `7a.5` branch-grouping overlay and the conditional Phase 14 meta-research path while the runtime state machine uses 10 persisted stages.
Human checkpoints stay on the current runtime stage until the user approves a transition.

| Command Phase | Runtime Stage | Transition Rule |
|---------------|---------------|-----------------|
| 1. Parse & Route | terminal or existing stage | No stage change |
| 2. Session Init | `scope` | `rnd-session.sh init` seeds `scope` |
| 3. Scope | `scope` | No stage change until Phase 4 approval |
| 4. Human Scope Checkpoint | `scope` | On approval, `scope -> prior-work` |
| 5. Prior-work Collection | `prior-work` | On acceptance, `prior-work -> perspectives` |
| 6. Perspectives | `perspectives` | On acceptance, `perspectives -> hypotheses` |
| 7a. Hypotheses | `hypotheses` | No stage change until Phase `7a.5` accepts or skips branch grouping |
| 7a.5. Branch Grouping | `hypotheses` | On acceptance or linear skip, `hypotheses -> experiment-design` |
| 7b. Experiment Design | `experiment-design` | On acceptance, `experiment-design -> probes` |
| 8. Probes | `probes` | On completion, `probes -> analyze-prune` |
| 9. Analyze & Prune | `analyze-prune` | Loopback to `experiment-design` or advance to `report` |
| 10. Report | `report` | On acceptance, `report -> review` |
| 11. Review | `review` | No stage change until Phase 12 decision |
| 12. Human Release Checkpoint | `review` | On `release` or `archive-only`, `review -> meta-learn` |
| 13. Meta-learning | `meta-learn` | After artifact write, finalize `state.json` as `completed` |
| 14. Meta-Research | n/a (cross-study) | Only runs on `--meta analyze` or `--meta suggest`, outside the per-study state machine |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.rnd/sessions/{id}/state.json` | read/write | Session state machine |
| `.rnd/sessions/{id}/budget.json` | read/write | Budget tracking |
| `.rnd/sessions/{id}/queue.json` | read/write | Branch queue, wave schedule, and per-branch runtime state when branch mode is active |
| `.rnd/sessions/{id}/study-metrics.json` | read/write | Per-study structured metrics sidecar |
| `.rnd/archive-index.json` | read/write | Cross-study index for novelty and prior-work lookup |
| `.rnd/meta-aggregate.json` | read/write | Cross-study aggregate metrics |
| `.rnd/meta-report.md` | write | Latest meta-research analysis report |
| `docs/research/{year}/{slug}/brief.md` | write | Scope output |
| `docs/research/{year}/{slug}/prior-work-map.md` | write | Collection output |
| `docs/research/{year}/{slug}/hypothesis-backlog.md` | write | Hypothesis ranking |
| `docs/research/{year}/{slug}/experiment-ledger.jsonl` | append | Probe traces |
| `docs/research/{year}/{slug}/branch-ledger.jsonl` | append | Branch decision audit trail when branch mode is active |
| `docs/research/{year}/{slug}/report.md` | write | Final report |
| `docs/research/{year}/{slug}/review.md` | write | Review scores |
| `docs/research/{year}/{slug}/references.bib` | write | Citation export |
| `docs/research/{year}/{slug}/README.md` | write | Reproducibility bundle guide |
| `docs/research/{year}/{slug}/meta-learning.md` | write | Process lessons |
| `scripts/rnd-session.sh` | execute | Session lifecycle |
| `scripts/rnd-budget.sh` | execute | Budget tracking |
| `scripts/rnd-branch.sh` | execute | Branch lifecycle and wave management |
| `scripts/parallel.sh` | execute | Fan-out and fan-in coordination for wave probes |

`state.json` may also carry `pending_checkpoint`, `checkpoint_prompt`, `checkpoint_options`, `checkpoint_artifact`, `review_verdict`, `release_decision`, `blocked_reason`, `rework_stage`, and `final_summary`.
These fields are command-owned extensions on top of `templates/rnd/state.json`.
They exist so `scripts/rnd-loop.sh` and later resumes can recover human checkpoint state without hidden chat context.

## Artifact Output Contracts

| Artifact | Required Shape |
|----------|----------------|
| `brief.md` | Reuse `templates/rnd/brief.md`, append `## Approval Status`, and keep explicit values for question, scope boundary, mode, budget, done definition, stop rules, and user constraints |
| `prior-work-map.md` | Sections: `# Prior-Work Map`, `## Study Frame`, `## Source Map`, `## Contradictions`, `## Archive Overlaps`, optional `## Prior Session Wiki Context`, `## Prior Session Context`, `## Open Gaps`, `## Source Quality Notes` |
| `hypothesis-backlog.md` | Sections: `# Hypothesis Backlog`, `## Perspectives`, `## Tension Points`, `## Ranked Hypotheses`, `## Parked Questions`, and pruned rows remain visible with a reason |
| `experiment-ledger.jsonl` | Append-only `planned` and `executed` entries using `references/hypothesis-contract.md` exactly, and include `branch_id` whenever branch mode is active |
| `branch-ledger.jsonl` | Append-only `prune`, `survive`, `merge`, and `expand` entries using `templates/rnd/branch-ledger-entry.json` and the branch evidence refs captured at each wave decision |
| `report.md` | When `report_format=report`: reuse `templates/rnd/report.md` unchanged. When `report_format=paper`: reuse `templates/rnd/report-academic.md` with `## Executive Summary` preserved for archive compatibility. Both modes require stable claim ids inside `Claims & Evidence Table` and cite only source ids or contract ids |
| `review.md` | Reuse `templates/rnd/review.md` unchanged, keep the score table keyed by `C1` to `C5`, and choose only `release`, `archive-only-partial`, or `rework` |
| `meta-learning.md` | Sections: `# Meta-Learning`, `## Reusable Lessons`, `## Study-Local Noise`, and `## Deferred Changes` |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No question and no `--resume` or `--status` or `--list` | 1 | Abort: "No research question provided." |
| `--list` is present | 1 | Run `bash scripts/rnd-session.sh list`, then stop |
| `--status` is present | 1 | Run `bash scripts/rnd-session.sh status {session_id?}`, then stop |
| `--meta` without sub-action | 1 | Default to `--meta status`: run `bash scripts/rnd-meta.sh status` and stop |
| `--meta extract` without session-id | 1 | Abort: "Provide a session id after `extract`." |
| `--meta extract` with session-id but session not completed | 1 | Abort: "Session must be completed for metrics extraction." |
| `--meta analyze` or `--meta suggest` with zero completed studies | 1 | Abort: "No completed studies to analyze." |
| `--meta analyze` with only 1 completed study | 14 | Proceed but mark all suggestions as `observation` confidence |
| `--resume` is present without a session id | 1 | Abort: "Provide a session id after `--resume`." |
| `--phase` is present without `--resume` | 1 | Abort: "`--phase` is only valid with `--resume`." |
| `--resume` but session not found | 1 | Abort: "Session not found." |
| `--resume` but session is `completed` or `stopped` | 1 | Show final status, show archive path, and suggest starting a new study |
| `--phase` override is not the current stage, an allowed next stage, or a persisted `rework_stage` | 1, Resume | Abort: "Invalid resume phase override." |
| `--branch` value is not `auto`, `on`, or `off` | 1 | Abort: "`--branch` must be `auto`, `on`, or `off`." |
| `--single` is present | 1, 7, 11, 13 | Skip all optional routed-model tie-breakers |
| `--paper` is present | 1, 2 | Persist `report_format=paper` in `state.json` and use `templates/rnd/report-academic.md` in Phase 10 |
| `--branch off` is present | 1, 7a.5-10 | Preserve the v3.1.0 linear path and do not initialize or consult branch queue state |
| `--branch on` is present | 1, 2, 7a.5-10 | Force branch mode even when fewer than 3 ranked hypotheses survive |
| `--branch auto` and fewer than 3 ranked hypotheses survive | 7a.5 | Skip branch mode, leave `branch_search.enabled=false`, and continue linearly |
| `--branch auto` and 3 or more ranked hypotheses survive | 7a.5 | Enable branch mode, initialize `queue.json`, allocate branch budgets, and schedule waves |
| Budget check fails at any phase boundary | any | Write partial notes if needed, call `rnd-session.sh stop {id} --reason budget_exhausted`, and stop |
| Critic rejects scope brief | 3 | Revise once, then move to the human scope checkpoint with the critic findings attached |
| Critic rejects with blocking issue | any | Persist the issue in `state.json`, set `run_status=needs_user`, and stop at the current stage |
| No live checkpoint answer is available | 4, 12 | Persist checkpoint metadata, set `run_status=needs_user`, emit the checkpoint block, and stop |
| `analyze-prune -> experiment-design` loop count is already at `max_loops` | 9 | Skip the loopback and force advance to `report` |
| All active branches are pruned | 8, 9 | Write an all-pruned note into the backlog or report context and advance to `report` without new branch work |
| Wave budget is exceeded mid-wave | 8 | Stop launching new branch work in the current wave, preserve completed traces, and advance to `analyze-prune` |
| Literature-only evidence is insufficient because the study now needs code or data | any | Set `run_status=blocked_escalation`, persist the limitation, and stop gracefully |
| Review verdict is `archive-only-partial` | 12 | Allow `archive-only` or `rework`, and do not suggest PA export |
| Review verdict is `rework` | 12 | Persist `rework_stage`, keep the session open, and wait for a targeted resume |
| Adversarial review relay succeeds with parseable C1-C5 | 11 | Set review protocol to `adversarial`, apply consensus per `peer-review-protocol.md`, derive verdict from consensus scores |
| Adversarial review relay succeeds but output is unparseable | 11 | Charge `model_route 1`, degrade to `single-fallback`, record parse failure in `review.md` |
| Adversarial review relay fails (timeout, empty, unavailable) | 11 | Do not charge `model_route`, degrade to `single-fallback`, record failure reason in `review.md` |
| Phase 4 user chooses `narrow` but revised brief fails critic | 4 | Persist critic findings, set `run_status=needs_user`, stop at `scope` for a new narrowing attempt |
| `report_format=paper` on resume | 10 | Read `report_format` from persisted `state.json`, select `templates/rnd/report-academic.md` |
| Citation extraction fails | 13 | Log error as non-blocking, continue without `references.bib` |
| README generation fails | 13 | Log error as non-blocking, continue without archive README |

## Recovery And Convergence Policy

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Investigator or collector draft | 1 retry | The same blocking gap remains after revision | Stop retrying and move to a human checkpoint or stage stop |
| Critic gate | 1 revise loop | The second review still blocks on the same issue family | Persist the critic findings and stop at the stage |
| Web collection | 1 narrowed query pass | New search results are duplicates, echoes, or non-independent | Preserve the gap and continue with explicit coverage limits |
| Probe execution | 1 rerun within `retry_limit` | Executed trace is still incomplete or unreviewable | Append a failed executed entry and continue or stop per budget |
| Analyze-prune loop | `max_loops` from `budget.json`, bounded to 1-3 | Zero new `executed` entries with `result=supportive` or `result=contradictory` since the last cycle, or the loop cap is hit | Stop looping and force the report path |
| Release rework | 1 persisted `rework_stage` at a time | The user asks for rework but does not specify the fix target | Persist `needs_user` and wait for a focused resume |

## Automation Status Contract

When the command must pause for a human decision, persist checkpoint fields in `state.json` and emit this block.

```text
run_status: needs_user
session_id: {session_id}
current_stage: {stage}
checkpoint: {scope_approval|stage_gate|release_decision|release_rework}
artifact: {artifact_path}
resume: /rnd --resume {session_id}
```

When the study hits the literature-only boundary, emit this block instead.

```text
run_status: blocked_escalation
session_id: {session_id}
current_stage: {stage}
reason: literature-only-insufficient
resume: /rnd --status {session_id}
```

These markers are required because `scripts/rnd-loop.sh` reads them and decides whether to continue, ask the user, or stop.

## Agent Delegation Contract

Every agent call follows this form.

```text
Agent(subagent_type: "ouroboros:rnd:{agent-name}")
```

Before delegation, read the artifact files from disk and pass both the artifact paths and the file contents inline.
Never say "use the prior chat" or rely on conversation memory as hidden context.
Every call includes `session_id`, `current_stage`, `archive_dir`, `budget.json`, and the relevant reference file paths.
Every call names the expected return payload explicitly.
The command writes files, appends ledger entries, calls scripts, and mutates `state.json`.
The agent never writes files directly.

| Agent | Stages | Input | Expected Output |
|-------|--------|-------|-----------------|
| `investigator` | `scope`, `perspectives`, `hypotheses`, `experiment-design`, `analyze-prune`, `report`, `meta-learn`, and `meta-research` | Artifact paths, inline file contents, stage instructions, budget snapshot, and required references | `artifact_draft`, `unresolved_questions`, `budget_notes`, `recommended_next_state`, and branch-specific `branches[]` or `branch_packets[]` when branch mode is active |
| `collector` | `prior-work`, `probes` | Approved brief or contract, existing artifacts, optional `archive_prior_work[]`, optional `session_wiki_prior_work[]`, optional `session_prior_work[]`, search/fetch budget allowance, and source-quality rules | `collection_payload` with query log, accepted source records, rejected candidates, gaps, optional `session_wiki_hints[]`, optional `conversation_session_hints[]`, and call counts |
| `critic` | all gated stages and final review | Current artifact, upstream artifacts, budget snapshot, and rubric or contract rules | `verdict`, `blocking_issues`, `required_revisions`, `accepted_strengths`, and `next_allowed_states` |

When `--single` is absent, an optional routed-model second opinion is allowed only for `hypotheses`, `review`, or `meta-learn` boundary cases.
The routed model is advisory only and never replaces the investigator or critic.

## Critic Gate Protocol

1. Delegate to critic with the current artifact, upstream artifacts, budget snapshot, and applicable rules.
2. If verdict is `accept`: proceed to the next phase.
3. If verdict is `revise`: revise once with the investigator using critic findings verbatim, rewrite the artifact, rerun critic once.
4. If the second pass still blocks on the same issue family: persist findings in `state.json`, set `run_status=needs_user`, and stop at the current stage.

Exception: for `scope`, a second-pass failure moves to the Phase 4 human checkpoint with the critic findings attached rather than stopping, because the human scope checkpoint is mandatory regardless.

## Budget Integration

Before each stage start, checkpoint, or `advance` call, run `bash scripts/rnd-budget.sh check {session_id}`.
Treat the `--budget` argument as minutes when calling `rnd-session.sh init`, because the script converts that value into seconds internally.
Every phase charges wall-clock at the end via `rnd-budget.sh charge {session_id} wall_clock {elapsed_seconds}`.
After each collector pass, charge `web_search` and `web_fetch` from the collector payload rather than guessing call counts.
Do not charge `web_search`, `web_fetch`, or `probe` budget for session-archive or session-wiki reads because they are local file reads.
After each routed-model call that completes (success or parse failure), charge `model_route 1`. Do not charge when the relay itself fails with a transport error (timeout, empty response, codex unavailable).
After each executed linear probe contract, charge `probe 1`.
When branch mode is active, run `rnd-budget.sh check {session_id} --branch {branch_id}` before launching or expanding a branch-local contract.
When branch mode is active, charge branch-local wall-clock, search, fetch, and probe spend through `rnd-budget.sh branch-charge {session_id} {branch_id} {metric} {amount}` so session and branch counters stay in sync.
Do not call any optional routed-model path when `--single` is present.
When `rnd-session.sh advance {id} experiment-design` succeeds from `analyze-prune`, let the script own the loopback counter.

## Resume Logic

On `--resume`, run `bash scripts/rnd-session.sh resume {session_id}` first so `handoff/latest.json` is refreshed.
Then read `.rnd/sessions/{id}/state.json`, `.rnd/sessions/{id}/budget.json`, and `.rnd/sessions/{id}/handoff/latest.json`.
Then read every file named in `latest_handoff.artifact_paths`, ignoring paths that do not exist yet.
If `state.json.branch_search.enabled = true`, treat `.rnd/sessions/{id}/queue.json` as the authoritative runtime branch state and read `docs/research/{year}/{slug}/branch-ledger.jsonl` when it already exists.
If `run_status` is `needs_user`, treat any trailing free text after the flags as `checkpoint_response`.
If the text starts with `User checkpoint input:`, strip that label and keep the remainder.
If `--phase` is present, validate it against the current stage, `latest_handoff.next_allowed_states`, or the persisted `rework_stage`.
If the override is a persisted `rework_stage` behind the current stage, reopen that stage by editing `state.json`, resetting later stages to `pending`, appending a `rework-regression` transition, and setting `run_status=active`.
If the session is already on the desired stage, continue without a transition.
If the session is on a checkpoint and no response was provided, emit the checkpoint block again and stop.

## Phase 1: Parse & Route

Parse `$ARGUMENTS` with this precedence.

1. `--list`
2. `--status [session-id]`
3. `--meta [extract <session-id>|analyze|suggest|status]`
4. `--resume <session-id> [--phase <stage>]`
5. New study with question text

Accepted stage names for `--phase` are `scope`, `prior-work`, `perspectives`, `hypotheses`, `experiment-design`, `probes`, `analyze-prune`, `report`, `review`, and `meta-learn`.
Use `90` minutes as the default budget when `--budget` is omitted.
Parse optional `--branch {auto|on|off}` into a local `branch_mode` variable.
Default `branch_mode` to `auto`.
Parse optional `--paper` into a local `report_format` variable.
Set `report_format=paper` when `--paper` is present, otherwise set `report_format=report`.
`auto` activates branch search only after Phase `7a` produces at least three ranked hypotheses.
`on` forces branch search even when fewer than three ranked hypotheses survive.
`off` preserves the v3.1.0 linear path.
If a resumed session already has `state.json.branch_search.enabled = true`, keep branch mode active because persisted runtime state outranks a fresh preference flag.
Preserve any free-text tail after `--resume` as checkpoint response material.
If the route is `--list`, `--status`, `--meta status`, or `--meta extract`, do not load study artifacts beyond what the shell script already prints.
If the route is a new study and the remaining positional text is empty, resolve per the Decision Matrix.

### Phase 1 Terminal Invocations

```text
bash scripts/rnd-session.sh list
bash scripts/rnd-session.sh status {session_id?}
bash scripts/rnd-meta.sh status
bash scripts/rnd-meta.sh extract {session_id}
bash scripts/rnd-session.sh resume {session_id}
```

Route `--meta analyze` and `--meta suggest` to Phase 14 instead of Phase 2.

## Phase 2: Session Init

Run this phase only for a new study.
Initialize the session with the question and budget minutes.
When `branch_mode=on`, seed the session with `--branch-search` so the runtime exposes `queue.json` from the first handoff onward.

```text
bash scripts/rnd-session.sh init "{question}" --budget {budget_minutes} {--branch-search?}
```

Parse the returned `Session ID`, `Archive`, `State`, and `Budget` lines, plus the optional `Queue` line when branch mode is explicitly on.
Read `templates/rnd/brief.md`, `templates/rnd/report.md`, and `templates/rnd/review.md`.
Write `brief.md`, `report.md`, and `review.md` from their templates if those files do not exist yet.
Create `prior-work-map.md` with the fixed sections from `Artifact Output Contracts` if it does not exist yet.
Create `hypothesis-backlog.md` with the fixed sections from `Artifact Output Contracts` if it does not exist yet.
Create `experiment-ledger.jsonl` as an empty append-only file if it does not exist yet.
If `branch_mode=on`, create `branch-ledger.jsonl` as an empty append-only file if it does not exist yet.
Create `meta-learning.md` with its fixed sections if it does not exist yet.
Edit `state.json` to clear any leftover checkpoint fields, set `mode` to `literature-only`, set `report_format` to `"report"` by default, and keep `run_status=active`.
After session init, if `--paper` was parsed, edit `state.json` to set `report_format` to `"paper"`.

### Phase 2 Recovery

| Failure | Action |
|---------|--------|
| `rnd-session.sh init` fails | Abort and surface the script error unchanged |
| A stub artifact cannot be written | Stop the session with `rnd-session.sh stop {id} --reason artifact_init_failed` |

## Phase 3: Scope

> Agent: **investigator** followed by **critic**

Read `brief.md`, `state.json`, `budget.json`, `templates/rnd/brief.md`, the original question from `state.json`, and any fresh user constraints from the current invocation.
Delegate to `investigator` with the question, the fixed `literature-only` mode, the budget snapshot, and the template path.
Instruct the investigator to draft the full brief and append `## Approval Status` with `pending`.
Write the returned draft to `brief.md`.
Apply the Critic Gate Protocol with `brief.md` and the scope validation rules from the critic's stage instructions and `budget-policy.md`.
If the protocol accepts, read the final question from `brief.md` and run `bash scripts/rnd-archive-index.sh search "{question}"`.
If `.rnd/archive-index.json` does not exist or the search returns `[]`, skip the archive advisory silently.
If any hit returns `outcome=duplicate`, append `## Novelty Warning` to `brief.md` with the matched study `path`, `title`, and `score`, plus a recommendation to narrow scope or explicitly build on the prior study.
If any hit returns `outcome=related`, append `## Related Prior Studies` to `brief.md` with the matched study `path`, `title`, and `score`.
Treat both archive sections as advisory context only, because the Phase 4 human checkpoint still decides whether the study proceeds unchanged, narrows scope, or stops.
Then run `bash scripts/session-archive.sh search "{question}" --project current --agent main --top 5 --format json`.
If the session archive is unavailable or empty, skip it silently.
If hits exist, append `## Prior Session Coverage` to `brief.md` with `segment_id`, `source_ref`, `ts`, `component_hint`, and a short snippet.
Treat this section as advisory novelty context only, and do not change the novelty verdict from the study archive check.
Then move to Phase 4.

### Scope Return Contract

The investigator returns `artifact_draft`, `unresolved_questions`, and `budget_notes`.
The critic returns `verdict`, `blocking_issues`, `required_revisions`, and `next_allowed_states`.

## Phase 4: Human Scope Checkpoint

Present the brief summary, critic verdict, and any unresolved assumptions.
In attended runs, use `AskUserQuestion` with the choices `approve`, `narrow`, and `reject`.
In automation or unattended runs, persist the checkpoint and stop with `run_status: needs_user`.

If the user approves, update `brief.md` so `## Approval Status` becomes `approved`, clear checkpoint fields in `state.json`, and run `bash scripts/rnd-session.sh advance {session_id} prior-work`.
If the user narrows the scope, revise `brief.md` through the investigator once, rerun the critic once, and only advance if the revised brief passes.
If the user rejects the study, update `brief.md` so `## Approval Status` becomes `rejected`, call `bash scripts/rnd-session.sh stop {session_id} --reason scope_rejected`, and stop.
If the study is paused for input, persist `pending_checkpoint=scope_approval`, `checkpoint_artifact=docs/research/{year}/{slug}/brief.md`, and the prompt metadata in `state.json`.

## Phase 5: Prior-Work Collection

> Agent: **collector** followed by **critic**

Run `rnd-budget.sh check` before any new collection work.
Read the approved `brief.md`, `state.json`, `budget.json`, and any existing `prior-work-map.md`.
Read the approved question from `brief.md` and run `bash scripts/rnd-archive-index.sh search "{question}"` before delegating to `collector`.
If `.rnd/archive-index.json` does not exist or the search returns `[]`, skip archive reuse silently and proceed with external collection only.
If archive hits exist, keep only `related` and `duplicate` results and, for each hit, read the matched study's `report.md` `## Executive Summary`, `report.md` `## Claims & Evidence Table`, and `prior-work-map.md` `## Source Map`.
Package those local reads into `archive_prior_work[]` entries in the collector delegation payload, including the matched study path, overlap score, executive summary, inherited claim ids or claim text, and source-map summary.
Instruct the collector to use `archive_prior_work[]` to populate `## Archive Overlaps`, inherit reusable source families as query seeds, and flag contradictions between the new study framing and prior study conclusions.
Treat archive hits as context rather than evidence, and require the new study to earn its own evidence chain even when archive overlap is strong.
Do not charge adapter budget for archive reads because they are local file reads.
Run session archive search for the approved question with `bash scripts/session-archive.sh search "{question}" --project current --agent main --component rnd --top 5 --format json`.
If fewer than the desired advisory hits are found, optionally rerun the same search command shape with `--component research`.
Deduplicate both result sets by `segment_id`.
Package results as `session_prior_work[]` in the collector delegation payload with `segment_id`, `source_ref`, `ts`, `component_hint`, and snippet.
Treat session hits as advisory context only and do not charge adapter budget for these local reads.
If `mcp__qmd__status` reports the `session-wiki` collection as registered, call `mcp__qmd__query` with `collection: "session-wiki"`, intent `prior research context`, and sub-queries `[{type: "lex", query: "{question}"}, {type: "vec", query: "{question}"}]`.
Package wiki results as `session_wiki_prior_work[]` in the collector delegation payload, with each entry containing `wiki_key`, `title`, `summary_excerpt`, `source_segments[]`, and `confidence`.
Rank `session_wiki_prior_work[]` before `session_prior_work[]` when both are present.
Treat both wiki and raw session hints as `conversation-session` context-only, and never let either mint source records by itself.
Do not charge adapter budget for QMD `session-wiki` reads because they are local file reads.
If `session-wiki` is unregistered or QMD is unavailable, skip this step silently.
Delegate to `collector` with the brief, the remaining collection budget, and the query-ladder rules from `agents/rnd/collector.md`.
Require one direct query, one synonym expansion, and one related-field or mechanism query unless the budget no longer supports all three.
Write `prior-work-map.md` from the collector payload using the fixed sections in `Artifact Output Contracts`.
Charge `web_search` and `web_fetch` from the collector payload before the critic gate.
Apply the Critic Gate Protocol with `prior-work-map.md` and `source-quality.md`.
If no credible sources survive the shortlist, persist the gap and stop with `run_status=needs_user` rather than fabricating coverage.
On acceptance, run `bash scripts/rnd-session.sh advance {session_id} perspectives`.

### Prior-Work Return Contract

The collector returns `query_log`, `accepted_source_records`, `rejected_candidates`, `open_gaps`, `archive_overlaps`, `session_wiki_hints`, `conversation_session_hints`, and `budget_counters`.
The critic returns `verdict`, `coverage_notes`, `blocking_issues`, and `required_revisions`.

## Phase 6: Perspectives

> Agent: **investigator** followed by **critic**

Read `brief.md`, `prior-work-map.md`, `hypothesis-backlog.md`, `state.json`, and `budget.json`.
Delegate to `investigator` with instructions to generate skeptic, practitioner, theorist, and adversarial lenses only when they create real decision tension.
Write the returned perspective seed into `hypothesis-backlog.md` under `## Perspectives` and `## Tension Points`.
Apply the Critic Gate Protocol with `hypothesis-backlog.md` and the current `prior-work-map.md`.
On acceptance, run `bash scripts/rnd-session.sh advance {session_id} hypotheses`.

## Phase 7a: Hypotheses

> Agent: **investigator** followed by **critic**

Read `brief.md`, `prior-work-map.md`, `hypothesis-backlog.md`, `state.json`, and `budget.json`.
Delegate to `investigator` to rank falsifiable branches by expected value per cost and to keep pruned or parked rows visible.
Write the ranked rows into `## Ranked Hypotheses`.
Apply the Critic Gate Protocol with `hypothesis-backlog.md` and the falsifiability, redundancy, and budget-fit rules.
If `--single` is absent and the top-rank decision remains a boundary case after the second pass, optionally route a bounded tie-breaker prompt through `scripts/codex-relay.sh`, charge `model_route 1`, and record the disagreement note in the backlog rather than letting the routed model rewrite the ranking.
If every hypothesis is pruned, keep the rows visible with prune reasons and continue to Phase 7b with no viable contract set.
On acceptance, continue to Phase `7a.5` while staying on the `hypotheses` runtime stage.

## Phase 7a.5: Branch Grouping

> Agent: **investigator** followed by **critic**

Read `brief.md`, `prior-work-map.md`, `hypothesis-backlog.md`, `state.json`, `budget.json`, and `queue.json` when it already exists.
If `branch_mode=off`, skip this phase and run `bash scripts/rnd-session.sh advance {session_id} experiment-design`.
If `branch_mode=auto`, count the viable ranked hypotheses after Phase `7a`.
If fewer than three viable ranked hypotheses remain, skip branch mode entirely, leave `branch_search.enabled=false`, and run `bash scripts/rnd-session.sh advance {session_id} experiment-design`.
When branch mode is active:
1. Delegate to `investigator` to cluster the ranked hypotheses into tension-point branches with `branch_id`, `label`, `lead_hypothesis`, `hypothesis_ids`, and `tension_points`.
2. Require the grouping to assign every viable hypothesis to exactly one branch unless the hypothesis is explicitly parked outside the live set.
3. Apply the Critic Gate Protocol to the proposed grouping and require: no orphan hypotheses, no artificial splits, and one distinct research angle per branch.
4. If accepted, run `bash scripts/rnd-branch.sh init {session_id} '{branches_json}'` to write the authoritative `queue.json`.
5. Run `bash scripts/rnd-budget.sh branch-allocate {session_id}` to assign per-branch probe ceilings.
6. Run `bash scripts/rnd-branch.sh schedule {session_id}` to create the wave plan.
7. Create `branch-ledger.jsonl` as an empty append-only file if it does not already exist.
8. Keep `state.json.branch_search.enabled=true` explicit for later resumes and handoffs.
After the grouping is accepted or skipped linearly, run `bash scripts/rnd-session.sh advance {session_id} experiment-design`.

## Phase 7b: Experiment Design

> Agent: **investigator** followed by **critic**

Read `brief.md`, `prior-work-map.md`, `hypothesis-backlog.md`, `experiment-ledger.jsonl`, `state.json`, `budget.json`, and `queue.json` when branch mode is active.
When branch mode is inactive, preserve the current linear contract flow and draft literature-probe contracts for the top viable hypotheses.
When branch mode is active, draft contracts per active branch rather than for the full backlog at once.
Require every branch-mode contract to include `branch_id`.
Run `rnd-budget.sh check {session_id} --branch {branch_id}` before accepting or appending a branch-local contract set.
Gate branch-mode contracts per branch with the critic against `references/hypothesis-contract.md`, the remaining session budget, and the branch-local probe ceiling.
Mirror accepted branch contracts into `.rnd/sessions/{id}/queue.json` under `.branches[{branch_id}].contracts.planned` so Phase `8` can execute the scheduled wave without re-deriving branch membership.
Do not append any `planned` entry until the critic accepts the contract set.
If no viable hypothesis remains, record `No viable contract set` in the backlog and advance directly to `probes` with zero planned entries.
Apply the Critic Gate Protocol with the proposed contract set and `references/hypothesis-contract.md` plus the remaining budget.
On acceptance, append one `planned` JSON object per contract to `experiment-ledger.jsonl`.
Then run `bash scripts/rnd-session.sh advance {session_id} probes`.

### Experiment-Design Return Contract

The investigator returns `planned_contracts[]`, `rank_rationale`, and `unresolved_questions`.
When branch mode is active, every `planned_contracts[]` item includes `branch_id`.
The critic returns `verdict`, `blocking_issues`, `required_revisions`, and `approved_contract_ids`.

## Phase 8: Probes

> Agent: **collector** followed by **critic**, with **investigator** for branch-mode wave synthesis

Read `brief.md`, `prior-work-map.md`, `hypothesis-backlog.md`, `experiment-ledger.jsonl`, `state.json`, `budget.json`, and `queue.json` when branch mode is active.
Load only `planned` entries whose `contract_id` does not already have an accepted `executed` entry.
If there are no pending contracts, skip execution and advance to `analyze-prune`.

When branch mode is inactive, preserve the existing per-contract loop.

1. Check the session budget.
2. Delegate to `collector` with the `contract_id`, `hypothesis_id`, `target_claim`, and budget allowance.
3. Charge `web_search`, `web_fetch`, and `probe 1` from the returned payload.
4. Delegate to `critic` to validate the trace against the planned contract.
5. If the critic accepts, append the `executed` entry to `experiment-ledger.jsonl`.
6. If the critic rejects on trace completeness, rerun the same contract once within `retry_limit`.
7. If the rerun still fails, append a failed `executed` entry with the negative result and continue only if budget remains.

When branch mode is active:
1. Read the active wave and its `branch_ids` from `.rnd/sessions/{id}/queue.json`.
2. If no active wave or no active branch ids remain, advance to `analyze-prune`.
3. Use `bash scripts/parallel.sh init {session_id}-{wave_id} '{expected_entries_json}'` to declare one collector result slot per active branch in the current wave.
4. For each active branch in the wave, load only that branch's planned contracts without an accepted `executed` entry and run `rnd-budget.sh check {session_id} --branch {branch_id}` before dispatch.
5. Dispatch a parallel `collector` call per active branch and use `bash scripts/parallel.sh collect {session_id}-{wave_id}` for fan-in validation before branch scoring starts.
6. After each branch payload returns, delegate to `critic` to validate the branch's executed traces against its accepted contracts.
7. Append every accepted or failed `executed` entry to `experiment-ledger.jsonl` with `branch_id`, and mirror completed contract ids into `.rnd/sessions/{id}/queue.json`.
8. Charge branch-local and session-local spend with `rnd-budget.sh branch-charge {session_id} {branch_id} wall_clock|web_search|web_fetch|probe {amount}`.
9. If session budget or branch budget is exceeded mid-wave, stop launching new branch work, preserve completed traces, and advance to `analyze-prune`.
10. After the wave's traces are frozen, delegate to `investigator` for one branch evidence packet per active branch, then delegate to `critic` with `references/branch-rubric.md` so the critic alone scores `B1` to `B4` and chooses `prune`, `survive`, `merge`, or `expand`.
11. Run `bash scripts/rnd-branch.sh score {session_id} {branch_id} '{scores_json}'` for each scored branch.
12. If the critic chooses `prune`, run `bash scripts/rnd-branch.sh prune {session_id} {branch_id} "{reason}"` to reclaim unused probes.
13. If the critic chooses `merge`, run `bash scripts/rnd-branch.sh merge {session_id} {source_branch_id} {target_branch_id}` with the critic's explicit merge target.
14. If the critic chooses `expand`, gate the new contracts, append the new `planned` entries to `experiment-ledger.jsonl`, and run `bash scripts/rnd-branch.sh expand {session_id} {branch_id} '{contracts_json}'`.
15. Append one decision event per scored branch to `branch-ledger.jsonl` using `templates/rnd/branch-ledger-entry.json`, including score breakdown, decision, reason, and evidence refs.
16. Continue to the next planned wave only if a live branch remains and another scheduled wave still exists.

After all pending linear contracts or all scheduled branch waves are resolved, run `bash scripts/rnd-session.sh advance {session_id} analyze-prune`.

## Phase 9: Analyze & Prune

> Agent: **investigator** followed by **critic**

Read `brief.md`, `prior-work-map.md`, `hypothesis-backlog.md`, `experiment-ledger.jsonl`, `report.md`, `state.json`, `budget.json`, `queue.json`, and `branch-ledger.jsonl` when branch mode is active.
Delegate to `investigator` to update confidence, merge evidence, preserve negative results, and prune weak or redundant branches.
Rewrite `hypothesis-backlog.md` with updated statuses, confidence notes, and prune reasons.
Delegate to `critic` to check claim-to-evidence alignment, limitation honesty, and whether another evidence cycle is justified.
When branch mode is active:
1. Ask `investigator` for cross-branch analysis covering redundancy, complementary evidence, merge opportunities, and distinct high-upside survivors.
2. Use `critic` to validate merge targets, survivor distinctiveness, reserve-probe justifications, and whether the branch portfolio is report-ready.
3. Apply any approved dominated-branch merge through `bash scripts/rnd-branch.sh merge {session_id} {source_branch_id} {target_branch_id}`.
4. If a distinct high-scoring branch justifies reserve follow-up, approve the branch-local contracts, append them to `experiment-ledger.jsonl`, and run `bash scripts/rnd-branch.sh expand {session_id} {branch_id} '{contracts_json}'`.
5. If every branch is now pruned or merged away, write an explicit all-pruned note into `hypothesis-backlog.md` or `report.md` and force the report path.
6. Before any advance to `report`, run `bash scripts/rnd-branch.sh finalize {session_id}` so `state.json.branch_search.final_summary` records survived, pruned, and merged ids.
7. Keep the loopback decision global to the session: if any branch expanded, loop back once through `experiment-design`; otherwise move to `report`.

If the critic says more evidence is justified, first read `.usage.loopbacks` and `.limits.max_loops` from `budget.json`.
When branch mode is active, treat `more evidence` as an approved branch expansion rather than a blind full-backlog replay.
If the loopback cap is still available and the linear path remains active, run `bash scripts/rnd-session.sh advance {session_id} experiment-design` and jump back to Phase 7b with only the surviving hypotheses.
If the loopback cap is still available and branch mode is active and at least one branch expanded, run `bash scripts/rnd-session.sh advance {session_id} experiment-design` and jump back to Phase 7b with only the surviving or expanded branches.
If the loopback cap is already hit, write a limitation note into `report.md` or `hypothesis-backlog.md` and force the report path instead.
If the critic says the remaining uncertainty is acceptable, run `bash scripts/rnd-session.sh advance {session_id} report`.
If the critic blocks on an unsupported decision-critical claim, persist the issue in `state.json`, set `run_status=needs_user`, and stop without looping.

## Phase 10: Report

> Agent: **investigator** followed by **critic**

Read `brief.md`, `prior-work-map.md`, `hypothesis-backlog.md`, `experiment-ledger.jsonl`, `report.md`, `state.json`, `budget.json`, `queue.json`, and `branch-ledger.jsonl` when branch mode is active.
Read `report_format` from `state.json` to select the template.
When `report_format` is `paper`, read `templates/rnd/report-academic.md` as the base template.
When `report_format` is `report` or absent, read `templates/rnd/report.md` as the base template.
Delegate to `investigator` to draft `report.md` from the selected template and to freeze claim ids, evidence pointers, limitations, recommendations, and next questions.
When branch mode is active, pass the full branch structure, including survived, pruned, and merged branches.
Require surviving branches to return structured finding packets with claims, evidence refs, confidence notes, and residual uncertainty.
Require pruned or merged branches to return negative findings and limitation notes so the final report preserves dead ends and branch-level caveats.
The final report still integrates into one `Claims & Evidence Table` rather than one report section per branch.
Write the returned draft to `report.md`.
Apply the Critic Gate Protocol with `report.md` and the pre-review rules.
On acceptance, run `bash scripts/rnd-session.sh advance {session_id} review`.

## Phase 11: Review

> Agent: **critic** + optional **codex-relay.sh**

Read `brief.md`, `prior-work-map.md`, `hypothesis-backlog.md`, `experiment-ledger.jsonl`, `report.md`, `review.md`, `state.json`, `budget.json`, `templates/rnd/review.md`, and `skills/rnd/methodology/references/peer-review-protocol.md`.

### Step 1: Primary Review

Delegate to `critic` with `review-rubric.md` and require a full `C1` to `C5` score table, blocking issues list, verdict, and calibration notes.
Write the primary review into the `## Primary Review` section of `review.md`.
Set `## Review Protocol` to `single` initially.

### Step 2: Adversarial Review (conditional)

If `--single` is absent, attempt the adversarial review.
Write a prompt file containing the frozen study artifacts (`brief.md`, `prior-work-map.md`, `hypothesis-backlog.md`, `experiment-ledger.jsonl`, `report.md`) plus `review-rubric.md` and the adversarial stance instruction: "Score C1-C5 independently, try to falsify release, attack the weakest claim-evidence chain first, do not repair the artifact."
Do NOT include the primary review scores in the adversarial prompt.
Route via `bash scripts/codex-relay.sh <prompt-file> --effort xhigh --text-output <adversarial-output>`.

If the relay succeeds and the output contains parseable C1-C5 scores and blocking issues:
Charge `model_route 1` via `rnd-budget.sh`.
Write the adversarial review into the `## Adversarial Review` section of `review.md`.
Update `## Review Protocol` to `adversarial`.

If the relay succeeds but the output cannot be parsed into C1-C5 scores (malformed response):
Charge `model_route 1` via `rnd-budget.sh` because the call completed.
Degrade to `single-fallback` and record: "Adversarial review output unparseable. Falling back to single-reviewer mode."

If the relay fails (timeout, empty response, or codex unavailable):
Do not charge `model_route`.
Degrade to `single-fallback` and record: "Adversarial review unavailable: {reason}. Falling back to single-reviewer mode."

For all fallback cases, update `## Review Protocol` to `single-fallback` and record the reason in `review.md` under `## Adversarial Review`.

### Step 3: Consensus (conditional)

If review protocol is `adversarial`, apply the consensus rules from `peer-review-protocol.md`:
- Per criterion C1-C5: take the lower score on split (DR-107)
- Blocker merge: confirmed (both raise same root), blocking (one raises with concrete anchor), minority concern (one raises without anchor)
- Derive verdict from consensus scores + confirmed blockers using release threshold from `review-rubric.md`
- Compute agreement rate: percentage of C1-C5 where both reviewers gave the same score

Write the consensus into the `## Consensus` section of `review.md`.
Copy consensus scores to the archive-compatible `## Rubric Scores (C1-C5)` mirror section.
Copy consensus verdict to the archive-compatible `## Release Verdict` mirror section.

If review protocol is `single` or `single-fallback`:
Copy primary scores to the archive-compatible `## Rubric Scores (C1-C5)` mirror section.
Copy primary verdict to the archive-compatible `## Release Verdict` mirror section.

### Finalization

Persist `review_verdict` and `blocking_issues` in `state.json`.
If adversarial mode was used, also persist `review_protocol`, `agreement_rate`, and `adversarial_scores` in `state.json`.
Do not advance stages yet.

## Phase 12: Human Release Checkpoint

Present the review verdict, the blocking set, and the archive path.
If the review verdict is `rework`, do not offer `release`.
In attended runs, use `AskUserQuestion` with `release`, `archive-only`, and `rework` when the verdict is not `rework`.
In attended runs, use `AskUserQuestion` with `archive-only` and `rework` when the verdict is `rework`.
In unattended runs, persist the checkpoint and stop with `run_status: needs_user`.

If the user chooses `release`, persist `release_decision=release`, clear checkpoint fields, and run `bash scripts/rnd-session.sh advance {session_id} meta-learn`.
If the user chooses `archive-only`, persist `release_decision=archive-only`, clear checkpoint fields, and run `bash scripts/rnd-session.sh advance {session_id} meta-learn`.
If the user chooses `rework`, derive the earliest required repair stage from the review blockers.
Use `report` for wording, claim organization, or limitation fixes.
Use `analyze-prune` for evidence-alignment fixes that do not need new probes.
Use `experiment-design` for missing or weak evidence that needs a new contract.
Persist `rework_stage`, `pending_checkpoint=release_rework`, and `run_status=needs_user`, then stop without advancing.
If the user does not specify enough information to pick the repair stage, keep `run_status=needs_user` and emit the checkpoint block again.

## Phase 13: Meta-learning

> Agent: **investigator**

Run this phase only after `review -> meta-learn` has advanced successfully.
Read `brief.md`, `hypothesis-backlog.md`, `experiment-ledger.jsonl`, `report.md`, `review.md`, `meta-learning.md`, `state.json`, and `budget.json`.
Delegate to `investigator` to distill reusable lessons, wasted spend, evaluator misses, and deferred harness changes.
Write the returned draft to `meta-learning.md`.
If `--single` is absent and the meta-learning draft includes a high-impact harness claim, an optional routed second opinion may be used once and recorded as a disagreement note.

### Citation Export

Run `bash scripts/rnd-cite.sh extract {session_id}`.
If the extraction fails, log the error as non-blocking and continue.
The generated `references.bib` lives beside `report.md` in the archive directory.

### Archive README

Read `templates/rnd/archive-readme.md`.
Fill all `{{placeholder}}` values from `state.json`, `budget.json`, `review.md`, and the study artifacts.
Count evidence metrics: total sources (from `prior-work-map.md`), cited sources (from `references.bib` or cite status), claims (from `report.md` Claims & Evidence Table), planned/executed probes (from `experiment-ledger.jsonl`), branches (from `queue.json` if branch mode).
Write the filled README to `docs/research/{year}/{slug}/README.md`.
If README generation fails, log the error as non-blocking and continue.

### Metrics Extraction

Run `bash scripts/rnd-meta.sh extract {session_id}`.
If the extraction fails, log the error as non-blocking and continue.
The generated `study-metrics.json` lives in `.rnd/sessions/{session_id}/`.

### Finalization

Edit `state.json` directly to set `stages["meta-learn"]="completed"`, `run_status="completed"`, `completed_at={now}`, `updated_at={now}`, and `pending_checkpoint=null`.
Append a final transition object with `from: "meta-learn"`, `to: "completed"`, `type: "complete"`, and the timestamp.
Persist `final_summary` with the archive path, verdict, release decision, loop count, and review protocol.
Then run `bash scripts/rnd-archive-index.sh update {session_id}`.
If the archive index update fails, log the error as non-blocking and keep the session completion state unchanged because the index can be rebuilt later.

### Final Output

Present the archive path, final verdict, release decision, review protocol, agreement rate (if adversarial), loop count, and the report path.
If the review verdict is `release` and the human decision is `release`, suggest this next action exactly once.

```text
/pa ingest docs/research/{year}/{slug}/report.md
```

This is a proposal only.
Never write PA state directly.

## Phase 14: Meta-Research

> Agent: **investigator** + **critic**

This phase runs only when `--meta analyze` or `--meta suggest` is present.
It does not run during normal study execution.

### Pre-condition

Run `bash scripts/rnd-meta.sh aggregate` to rebuild `.rnd/meta-aggregate.json` from all available `study-metrics.json` files.
Read `.rnd/meta-aggregate.json` and all available `.rnd/sessions/*/study-metrics.json` files.

### Analysis (`--meta analyze`)

Delegate to `investigator` with:
- All `study-metrics.json` contents inline.
- `meta-aggregate.json` inline.
- `meta-research-contract.md` reference path.
- Task: synthesize cross-study trends, identify budget patterns, probe efficiency signals, quality trends, and stage time distribution.

Write the returned analysis to `.rnd/meta-report.md` using `templates/rnd/meta-report.md` as the structure.

Run the Critic Gate Protocol with `meta-research-contract.md` as the applicable rules.
The critic must verify: all observations cite study data, no suggestion is phrased as a directive, and no write path targets files outside `.rnd/`.

### Suggestions (`--meta suggest`)

Run `--meta analyze` first if `.rnd/meta-report.md` does not exist or is stale.

Apply deterministic trigger rules from `meta-research-contract.md`:
- Budget utilization below 0.15 or above 0.95 across 2+ studies → `SUG-BDG`.
- Probe type success rate differs by more than 0.30 across 2+ studies → `SUG-PRB`.
- Criterion shows identical score across 3+ studies → `SUG-CAL`.
- Loopback utilization is zero across 3+ studies → `SUG-PRC`.
- A deferred change ID appears in 2+ studies → `SUG-PRM`.

Delegate to `investigator` to contextualize each triggered suggestion with study-specific evidence and caveats.
Delegate to `critic` to validate that every suggestion is phrased as a hypothesis and respects the advisory-only constraint.
Append the validated suggestions to `.rnd/meta-report.md`.

### Final Output

Present the number of studies analyzed, the number of suggestions generated by category, and any evaluator recalibration signals.
All suggestions are hypothesis-grade and require human review before any harness modification.

## Rules

- Keep the study in `literature-only` mode unless the command explicitly stops with `blocked_escalation`.
- Call `rnd-budget.sh check` before every new stage, checkpoint decision, and loopback.
- Use `rnd-session.sh advance` for all normal forward stage transitions and the `analyze-prune -> experiment-design` loopback.
- Use direct `state.json` edits only for checkpoint persistence, bounded rework regression, and the final `completed` state because those states are not represented by `rnd-session.sh`.
- Pass artifact paths and inline file contents to every agent call.
- Keep negative results visible in `hypothesis-backlog.md`, `experiment-ledger.jsonl`, `branch-ledger.jsonl`, `report.md`, and `review.md`.
- When branch mode is active, treat `.rnd/sessions/{id}/queue.json` as authoritative runtime branch state and `branch-ledger.jsonl` as the append-only branch decision trail.
- Stop early with an honest partial archive instead of spending the last budget on speculative collection.
