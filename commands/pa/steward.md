---
name: pa:steward
description: "Use when you need routine vault maintenance without choosing each maintenance command yourself"
effort: high
type: meta-composite
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - Skill
  - mcp__qmd__status
argument-hint: "(no arguments — steward auto-determines what's needed)"
---

# Steward — Meta-Composite (Bounded Vault Maintenance)

Bounded vault maintenance for an already-onboarded PA vault.
Compose survey refresh, review, link repair, and agenda reset into one skip-aware stewardship pass.

Arguments: $ARGUMENTS

## Commands & Tools Used

| Phase | Command/Tool | Role |
|-------|--------------|------|
| 2 | Read (tool) | Load settings, profile, derivation, and review state, then determine which maintenance phases are needed |
| 2 | mcp__qmd__status (tool) | Check QMD freshness for survey-refresh need detection |
| 3 | Skill: `/pa survey` | Refresh vault profile, overlays, and ontology incrementally when stewardship needs it |
| 4 | Skill: `/pa review` | Review month-level vault health and return orphan, drift, resurfacing, and checkpoint findings |
| 5 | Skill: `/pa link` | Repair or propose connections for orphan or dirty targets surfaced by stewardship |
| 6 | Skill: `/pa agenda` | Reset weekly priorities using stewardship findings as context |
| 6 | AskUserQuestion (tool, optional) | Resolve any agenda focus checkpoint before the final report |
| 8 | Write (tool) | Update `.pa/derivation-state.json` with the stewardship timestamp after presentation |

## Delegated Agents Via Subcommands

| Phase | Subcommand | Delegated Agent(s) | Role |
|-------|------------|--------------------|------|
| A | `/pa survey` | cartographer, weaver | Refresh the vault profile, overlays, and ontology incrementally |
| B | `/pa review` | sentinel | Detect stale drift, orphan notes, unresolved links, resurfacing, and follow-up pressure |
| C | `/pa link` | weaver | Discover or repair high-signal note connections within bounded scope |
| D | `/pa agenda` | chief-of-staff, librarian (optional) | Reset near-term priorities from the stewardship findings |

The phase-level delegation contracts below are authoritative for the corresponding Skill calls.

## References

| Reference | Path | Usage |
|-----------|------|-------|
| Trust and Boundaries | `skills/pa/trust-and-boundaries/SKILL.md` | Posture, provenance, reversibility, and state-vs-markdown rules |
| Posture Matrix | `skills/pa/trust-and-boundaries/references/posture-matrix.md` | Bounded maintenance thresholds and escalation rules |
| Survey Command | `commands/pa/survey.md` | Incremental refresh contract |
| Review Command | `commands/pa/review.md` | Month review contract and checkpoint behavior |
| Link Command | `commands/pa/link.md` | Link-repair proposal behavior and dirty-path refresh |
| Agenda Command | `commands/pa/agenda.md` | Weekly agenda reset and checkpoint behavior |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/settings.json` | read | Vault path, QMD config, capability tier, and active posture |
| `.pa/vault-profile.json` | read | Existing vault profile and linking defaults for refresh and repair phases |
| `.pa/derivation-state.json` | read+write | Dirty-path tracking, prior maintenance state, and the stewardship timestamp |
| `.pa/review-state.json` | read | Last completed review timestamps and prior review memory |
| `.pa/sessions/{id}.json` | read+write | Pending unresolved coreference candidates and any confirm or reject decisions recorded during this stewardship run |
| `.pa/specialists.json` | read | Specialist registry for activation signal evaluation and suggested specialist detection |

## Decision Matrix

This matrix covers input parsing and load-time guardrails only.
Authoritative run and skip decisions for Phases A-D live in `Phase 2: Need Detection Rules`.
Phase-specific delegation, bounded-scope behavior, and failure handling live in the corresponding phase sections.

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No argument | 1 | Continue with auto-detected stewardship |
| Any argument is provided | 1 | Abort: "Steward accepts no arguments. Use `/pa reset --horizon ...`, `/pa survey <vault-path>`, `/pa review --horizon month`, `/pa link <note-path>`, or `/pa agenda --horizon week` instead" |
| No `.pa/settings.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| `settings.json` has no vault path | 2 | Abort: "Vault path missing from `.pa/settings.json`. Re-run `/pa survey <vault-path>`" |
| `.pa/derivation-state.json` is missing or malformed | 2 | Continue with a first-run maintenance state and treat dirty paths as unknown rather than automatically active |

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| Any explicit argument is provided | 1 | Abort and redirect to the narrow command named in `Redirect Hints` |
| Need Detection marks a sub-phase as unnecessary | 2-6 | Skip that phase, preserve the exact skip reason, and do not invoke the child command |
| Attended run has pending unresolved coreference candidates | 4 | Ask once for `confirm merge`, `keep separate`, or `defer`, then persist the decision to session state |
| Unattended run has pending unresolved coreference candidates | 4 | Leave candidates pending and skip the checkpoint |
| Link-repair targets exceed bounded maintenance scope | 5 | Repair only the top 5 targets and mark the remainder as deferred |
| Agenda returns a focus checkpoint | 6 | Relay the checkpoint once, wait for one focus choice, then rerun Phase D once |
| Every sub-phase skips cleanly | 7 | Render exactly `Vault is well-maintained. No actions needed.` |
| Any earlier phase ran, failed, or surfaced new maintenance signal | 6, 7 | Include `Agenda Reset` in the report and preserve failure or skip notes instead of recomputing them |

### Recovery

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Need detection reread | 1 pass only | The same state remains unreadable after the initial load | Mark the affected phase as unknown or first-run, keep the limitation explicit, and continue |
| Child command execution | 1 invocation per phase, except `Agenda Reset` may rerun once after a focus checkpoint | The rerun still fails, or it returns the same unresolved checkpoint or partial result | Stop rerunning that phase, record the degraded outcome, and continue with the remaining phases |
| Consecutive steward runs | 0 extra work once the same phase keeps failing or the same targets remain deferred for 2 consecutive steward runs | The same maintenance target set or the same child-command failure persists across those runs | Escalate to the matching narrow command in the report and stop expanding steward scope automatically |


## Phase 1: Parse Input

Steward accepts no arguments.
`$ARGUMENTS` must be empty.

If the user provides explicit control arguments, do not reinterpret them inside steward.
Redirect them to the most relevant narrow command instead of guessing.

### Redirect Hints

| Input Shape | Suggested Command |
|-------------|-------------------|
| `--horizon ...` | `/pa reset --horizon ...` |
| vault path or folder path | `/pa survey <vault-path>` |
| note path or note title | `/pa link <note-path or topic>` |
| explicit short-horizon prioritization intent | `/pa agenda --horizon week` |

## Phase 2: Load State

Check vault maturity per `skills/pa/trust-and-boundaries/references/vault-maturity.md`.
If below `expert`, present guidance and suggest `/pa review` or `/pa survey`.
Continue regardless.
Guidance is advisory.

1. Read `.pa/settings.json` and extract the vault path, QMD collection name, capability tier, and active posture.
2. Read `.pa/vault-profile.json` when present and extract linking defaults plus any survey-refresh baseline fields.
3. Read `.pa/derivation-state.json` when present and extract `dirty_paths`, `last_compile`, and any prior `last_steward` timestamp.
4. Treat only dirty-path entries with `refreshed != true` as active dirty paths.
5. Read `.pa/review-state.json` when present and extract `last_review.month.timestamp`.
6. Call `mcp__qmd__status` for the configured collection and capture `last_updated` when available.
7. Read `.pa/sessions/{id}.json` files when present and extract pending `unresolved_entities` that still need coreference review.
8. Read `.pa/specialists.json` when present and check for `status: "suggested"` entries that need user interaction.
9. Determine whether each sub-phase is needed before invoking any child command.

Only `.pa/settings.json` is a hard prerequisite.
Missing profile or assistant-state overlays trigger refresh behavior instead of a full stop.

### Need Detection Rules

This table is the authoritative source for whether Phases A-D run or skip.
If a phase is skipped per this table, record the skip reason and do not call the corresponding subcommand.

| Sub-Phase | Run When | Skip When |
|-----------|----------|-----------|
| Survey Refresh | Profile is missing, QMD freshness is stale or unknown, active dirty paths exist, or `.pa/specialists.json` has `status: "suggested"` entries awaiting user interaction | QMD `last_updated` is within the last 24 hours, no active dirty paths, and no suggested specialists |
| Review | Month review is missing, stale, unreadable, or pending unresolved coreference candidates still need review | `last_review.month.timestamp` is within the last 24 hours and no pending coreference review remains |
| Link Repair | Review surfaced orphan notes, or review failed or returned partial coverage while active dirty paths still remain | Review is healthy, or no eligible repair targets remain |
| Agenda Reset | Any earlier phase ran, failed, or surfaced new maintenance signal | Phases A-C all skipped cleanly and nothing new needs attention |

Ontology health: `entities.json` exists and (`dirty_paths` has pending entries or the last ontology health check is older than 7 days).

When `mcp__qmd__status` is unavailable or returns no usable `last_updated`, treat survey freshness as unknown instead of claiming the 24-hour skip.
Treat a missing or malformed `.pa/review-state.json` as unreadable for the `Review` row above.

## Phase 3: Phase A — Survey Refresh

> Subcommand: **`/pa survey`**

If Phase A is not needed per `Phase 2: Need Detection Rules`, skip it and preserve the skip reason.
This phase is refresh-only.
Do not allow a full re-survey branch inside steward.

When Phase A is needed, invoke the survey command through the Skill tool using the vault path from `.pa/settings.json`.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | vault path from `.pa/settings.json`, existing `.pa/` presence, active posture and capability context from `.pa/settings.json`, current dirty-path state, and any known QMD freshness signal |
| Instructions | Invoke `pa:survey` in incremental refresh mode only. Treat the vault as already onboarded. Use the existing `.pa/` state as the baseline. Preserve user-owned settings fields. Do not offer or branch into full re-survey from steward |
| Expected Output | Refresh status, QMD registration or indexing status, changed profile fields, overlay regeneration result, ontology refresh result, warnings, and any open questions |

```text
Skill: pa:survey
Args: {vault_path}
Additional instruction: Existing `.pa/` detected. Run incremental refresh only. Preserve user-owned settings fields. Do not branch into full re-survey.
```

### Capture

Store the refresh status, QMD registration or indexing status, changed profile fields, overlay regeneration result, ontology refresh result, and any warnings or open questions.

### Recovery

| Failure | Action |
|---------|--------|
| `/pa survey` fails | Mark `Survey Refresh` as failed and continue |
| `/pa survey` returns partial refresh | Preserve the partial result and continue |
| `/pa survey` reports no meaningful changes | Mark `Survey Refresh` as completed with no material updates |

## Phase 4: Phase B — Review

> Subcommand: **`/pa review`**

If Phase B is not needed per `Phase 2: Need Detection Rules`, skip it and preserve the skip reason.
This phase always uses the bounded maintenance horizon.
Do not expose a user-controlled horizon here.

When Phase B is needed, invoke the review command through the Skill tool.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | fixed horizon `month`, the latest `.pa/` state after Phase A if it ran, and the bounded stewardship intent |
| Instructions | Invoke `pa:review` through Skill with `--horizon month`. Apply the month review contract from `commands/pa/review.md`. Keep the pass bounded and maintenance-first. Return findings, evidence, and checkpoint payloads only |
| Expected Output | Follow-up report fields, health summary, orphan notes, unresolved-link findings, resurfacing candidates, limitation notes, and `checkpoint_payload` for `.pa/review-state.json` |

```text
Skill: pa:review
Args: --horizon month
```

### Capture

Store the follow-up report, health summary, orphan notes, unresolved-link findings, resurfaced notes, and `checkpoint_payload` for `.pa/review-state.json`.
Also store any unresolved coreference candidates surfaced from session state or the review output so they can be presented as merge proposals.

### Coreference Review Checkpoint

If unresolved coreference candidates remain pending, surface them during the entity-health portion of the review section.
Show only same-kind merge proposals and preserve each candidate's raw mention, best existing entity match, attempted strategy, and confidence.
Use AskUserQuestion in attended runs to let the user choose `confirm merge`, `keep separate`, or `defer`.
Do not apply the merge inside steward.
Write the decision back to `.pa/sessions/{id}.json` as `review_status: confirmed`, `rejected`, or `deferred` so the next survey or weaver pass can respect it.
If the run is unattended, skip the checkpoint and leave the candidates pending.

### Recovery

| Failure | Action |
|---------|--------|
| `/pa review` fails | Mark `Review` as failed and continue |
| `/pa review` reports a healthy vault | Preserve the healthy result and let `Phase 2: Need Detection Rules` determine whether Phase C is skipped |
| `/pa review` returns partial coverage | Preserve the limitation note and continue |

## Phase 5: Phase C — Link Repair

> Subcommand: **`/pa link`**

If Phase C is not needed per `Phase 2: Need Detection Rules`, skip it and preserve the skip reason.
Use this phase only for concrete repair targets.
Do not run a broad graph sweep.

### Target Selection

Build the target list in this order.

1. Orphan note paths surfaced by Phase B.
2. Active dirty paths only when Phase B failed or returned partial coverage and the paths still need refresh.

Dedupe targets by path.
Keep stable path order within each source bucket.
If the set exceeds bounded maintenance scope, repair only the top 5 targets and mark the remainder as deferred.

Invoke one link call per target.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | single target path, target source (`review_orphan` or `dirty_path_fallback`), active posture from `.pa/settings.json`, and the bounded-scope reminder |
| Instructions | Invoke `pa:link` once per target. Keep the analysis scoped to that target. Do not broaden into a graph sweep. Keep user markdown proposal-first inside steward. Allow only bounded `.pa/` refresh already permitted by the child command |
| Expected Output | Per-target link status, material connection suggestions or repairs, unresolved-link fixes, and any deferred or failure note tied to the target |

```text
Skill: pa:link
Args: {target_path}
Additional instruction: Bounded stewardship repair for one target only. Do not broaden scope. Keep user markdown proposal-first.
```

### Posture Handling

`/pa link` remains proposal-first for user markdown within steward.
Do not escalate from steward into bulk apply behavior.
Assistant-state refresh inside `.pa/` may proceed automatically because it is regenerable state.
If the active posture is below `apply-low-risk`, every visible markdown outcome stays proposal-only.
If the posture is `apply-low-risk` or `operate`, only child-command behavior already allowed by `trust-and-boundaries` may apply, and anything beyond the bounded thresholds must still remain proposal-only.

### Capture

Store the target list, per-target repair status, material connection suggestions, unresolved-link fixes, and any deferred targets that exceeded the stewardship bound.

### Recovery

| Failure | Action |
|---------|--------|
| No eligible targets exist | Mark `Link Repair` as skipped |
| One `/pa link` call fails | Record that target as failed and continue with the remaining targets |
| All `/pa link` calls fail | Mark `Link Repair` as failed and continue |

## Phase 6: Phase D — Agenda Reset

> Subcommand: **`/pa agenda`**

If Phase D is not needed per `Phase 2: Need Detection Rules`, skip it and preserve the skip reason.
This phase resets near-term priorities after the maintenance pass.
Use the weekly agenda horizon regardless of how many earlier phases ran.

When Phase D is needed, invoke the agenda command through the Skill tool.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | fixed agenda horizon `week`, ordered stewardship context from earlier phases, and optional user focus choice on the retry path |
| Instructions | Invoke `pa:agenda` through Skill with `--horizon week`. Use earlier phase outputs only as weighting context. Prefer review findings first, then survey-refresh changes, then link-repair outcomes or deferred targets. If the phase is retried after a focus checkpoint, preserve the earlier context and add the user's focus choice |
| Expected Output | Agenda report or focus checkpoint with prioritized items, risks, waiting-fors, suggested focus, confidence, and any low-confidence or limitation note |

```text
Skill: pa:agenda
Args: --horizon week
```

Pass the highest-signal outputs from the earlier phases as additional `user_context`.
Prefer review findings first, then survey-refresh changes, then link-repair outcomes or deferred targets.

### Context Rules

1. Pass stale items, stale waiting-fors, orphan-note findings, unresolved-link pressure, and resurfacing signals from Phase B when available.
2. Pass only material profile or overlay changes from Phase A that could affect current priorities.
3. Pass only the material new connections or deferred repair targets from Phase C, not the full raw link output.
4. If Phase B failed or skipped, pass the exact skip or failure note rather than inventing review findings.

### User Checkpoint

If `/pa agenda` returns the focus checkpoint from `commands/pa/agenda.md`, relay it unchanged with AskUserQuestion.
Wait for the user's choice, then re-run Phase D once with that choice added to `user_context`.

### Recovery

| Failure | Action |
|---------|--------|
| `/pa agenda` fails | Mark `Agenda Reset` as failed and continue |
| User does not answer the agenda checkpoint | Preserve the unresolved checkpoint in `Agenda Reset` and continue |
| `/pa agenda` returns low confidence | Preserve the low-confidence note and continue |

## Phase 7: Present

Render one unified stewardship report in the conversation.
Omit skipped sections instead of padding them.
Do not recompute the child-command analysis inline.
Compress child outputs only enough to make the report scannable.

If every sub-phase skipped cleanly, present exactly:

```text
Vault is well-maintained. No actions needed.
```

### Report Shape

```markdown
## Stewardship Report

**Date**: {YYYY-MM-DD}
**Posture**: {observe|propose|apply-low-risk|operate}
**Outcome**: {maintained|partial|needs-attention}

### Survey Refresh
{only when Phase A ran or failed}

### Review
{only when Phase B ran or failed}

### Link Repair
{only when Phase C ran or failed}

### Agenda Reset
{only when Phase D ran or failed}

### Next Actions
1. {highest-signal follow-up}
2. {optional second follow-up}
3. {optional third follow-up}
```

### Section Rules

| Section | Include When | Content Rule |
|---------|--------------|--------------|
| `Survey Refresh` | Phase A ran or failed | Show only material profile, overlay, QMD, ontology, or specialist activation changes |
| `Review` | Phase B ran or failed | Summarize the highest-signal maintenance findings only, including unresolved coreference candidates and any confirm or reject decisions when they exist |
| `Link Repair` | Phase C ran or failed | Show only connection changes or repair proposals that alter retrieval or priority |
| `Agenda Reset` | Phase D ran or failed | Show the weekly reset or unresolved checkpoint |
| `Next Actions` | Any non-empty report | Prefer concrete follow-ups implied by the surviving phase outputs |

### Next Action Rules

| Condition | Preferred Next Action |
|-----------|-----------------------|
| Phase D surfaced a primary thread | `/pa draft "{primary_thread}"` |
| Phase C surfaced a high-signal repair target | `/pa link "{target_path}"` |
| Phase B surfaced neglected context | `/pa brief "{project_or_topic}"` |
| Phase A surfaced profile uncertainty | Edit `.pa/vault-profile.md` or re-run `/pa survey {vault_path}` directly |
| Most phases failed | `/pa review --horizon month` — re-run the narrowest reliable maintenance layer |

## Phase 8: State Update

Update only the stewardship timestamp after the report is shown.
Do not invent a second source of truth for review, survey, or link outputs.

1. Read the latest `.pa/derivation-state.json` again before writing.
2. Preserve any newer child-command writes already made during Phases A-C.
3. Merge a top-level `last_steward` object with `timestamp: {now_iso8601}`.
4. If `.pa/derivation-state.json` was missing, initialize the minimal object needed for `last_steward`.
5. Do not overwrite `dirty_paths`, `last_compile`, or child-owned fields with older composite memory.

Example merge target:

```json
{
  "last_steward": {
    "timestamp": "2026-03-17T18:30:00+09:00"
  }
}
```

## Composability

| Context | Usage |
|---------|-------|
| Manual entry point | `steward` is the maintenance-first top-level command when the user wants PA to decide what upkeep is needed |
| `/pa day --mode evening` | Day may suggest `steward` when evening closeout reveals stale maintenance pressure |
| Composes primitives | `survey` + `review` + `link` + `agenda` remain independently callable outside the meta-composite |
| Complement to `/pa reset` | `reset` owns periodic horizon review plus compile, while `steward` owns maintenance plus survey refresh and excludes compile |
| PA Autopilot (`scripts/pa-autopilot.sh`) | Nightly unattended execution via `claude -p`. Steward runs under `operate` posture with unattended constraints: no follow-up questions, confirmation-required actions become report items. See `skills/pa/trust-and-boundaries/references/posture-matrix.md` (Unattended Operate) |
| Recurring session use | `/loop 6h /pa steward` — background maintenance during long sessions. See `commands/pa/README.md` (Recurring Use) |

## Rules

- **Meta-composite only**: Steward orchestrates child commands and does not duplicate their analysis logic.
- **Refresh, not onboarding**: Phase A uses the existing-vault refresh path only and never upgrades into full onboarding inside steward.
- **Proposal-first for markdown**: User-visible markdown stays proposal-first unless the child command can safely apply a bounded low-risk edit within the current posture.
- **`.pa/` auto-refresh allowed**: Assistant-state refresh may proceed automatically because `.pa/` is regenerable overlay state.
- **Bounded maintenance**: Respect the thresholds in `trust-and-boundaries` and `posture-matrix`; defer excess scope instead of hiding bulk work.
- **Skip-aware**: Each phase may skip independently, and skipped phases are omitted from the final report.
- **Graceful degradation**: Failure in one phase never blocks the remaining phases.
- **No compile**: Steward does not compose `/pa compile`; that remains the responsibility of `/pa reset`.
`
