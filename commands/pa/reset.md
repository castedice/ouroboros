---
name: pa:reset
description: "Use when you want a weekly, monthly, or longer-horizon reset that turns review findings into refreshed priorities and connections"
effort: high
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - Skill
argument-hint: "[--horizon week|month|quarter|year|3y|10y|30y|lifetime]"
---

# Reset — Horizon Refresh

Compose review, compile, agenda, and link into one bounded reset pass for the selected horizon.
Use the chosen horizon to decide how much evidence to pull forward, how operational the agenda should remain, and whether the output should lean toward tasks or direction.

Horizon: $ARGUMENTS

## Commands & Tools Used

| Phase | Command/Tool | Role |
|-------|--------------|------|
| 2 | Read (tool) | Load state, resolve horizon mappings, and read the final weekly-review template |
| 3 | Skill: `/pa review` | Produce the follow-up report and review checkpoint payload |
| 3-6 | mcp__qmd__status / mcp__qmd__query / mcp__qmd__get (via subcommands) | Support QMD-backed recency, synthesis, and link analysis when child commands need it |
| 4 | Skill: `/pa compile` | Generate or skip the lower-layer synthesis for the horizon window |
| 5 | Skill: `/pa agenda` | Reset priorities with review findings and compilation carry-forward in context |
| 5 | AskUserQuestion (tool, optional) | Resolve agenda focus checkpoints before final render |
| 6 | Skill: `/pa link` | Discover material connections for newly compiled or resurfaced notes |
| 8 | Write (tool) | Persist any checkpoint or derivation payload that subcommands returned but did not write |

## Delegated Agents Via Subcommands

| Phase | Subcommand | Delegated Agent(s) | Role |
|-------|------------|--------------------|------|
| A | `/pa review` | sentinel | Detect stale work, orphan notes, unresolved links, resurfacing, and open-loop delta |
| B | `/pa compile` | librarian, scribe | Collect eligible sources and synthesize the lower-layer period packet |
| C | `/pa agenda` | chief-of-staff, librarian (optional) | Turn review findings into a bounded priority reset |
| D | `/pa link` | weaver | Discover material new connections for compiled or resurfaced notes |

## References

| Reference | Path | Usage |
|-----------|------|-------|
| Fractal Journaling | `skills/pa/review-and-journaling/references/fractal-journaling.md` | Map the selected reset horizon to the nearest lower-layer synthesis |
| Compilation Policy | `skills/pa/executive-assistance/references/compilation-policy.md` | Compile preflight eligibility, no-op rules, and cursor behavior |
| Follow-Up Report Template | `templates/pa/follow-up-report.md` | Phase A artifact contract |
| Weekly Review Template | `templates/pa/weekly-review.md` | Final composite rendering contract |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/settings.json` | read | Vault path, QMD config, capability tier, and posture |
| `.pa/vault-profile.json` | read | Journaling cadence, linking style, placement rules, and review profile |
| `.pa/entities.json` | read | Active life goals used to keep the agenda aligned with longer-horizon commitments |
| `.pa/derivation-state.json` | read+write | Compile cursor, dirty paths, and additive derivation updates from compile or link |
| `.pa/review-state.json` | read+write | Review checkpoint merged from Phase A |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No argument | 1 | Default to `--horizon week` |
| `--horizon` missing a value | 1 | Abort: "Provide a horizon: `week`, `month`, `quarter`, `year`, `3y`, `10y`, `30y`, or `lifetime`" |
| `--horizon` value is invalid | 1 | Abort: "Invalid horizon. Use `week`, `month`, `quarter`, `year`, `3y`, `10y`, `30y`, or `lifetime`" |
| Extra arguments beyond `--horizon` | 1 | Abort: "Reset only accepts `--horizon week|month|quarter|year|3y|10y|30y|lifetime`" |
| No `.pa/settings.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/vault-profile.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/entities.json` | 2 | Continue without goal-aware agenda context |
| Phase A review fails | 3 | Record a failed review section and continue to Phase B |
| Compile preflight says no-op | 4 | Skip `/pa compile`, preserve the no-op reason, and continue to Phase C |
| Selected horizon is `3y`, `10y`, `30y`, or `lifetime` | 4 | Use the `year` compile window as the nearest lower-layer evidence packet, or skip cleanly if it is ineligible |
| Phase B compile fails | 4 | Record a failed compilation section and continue to Phase C |
| `/pa agenda` returns a focus checkpoint | 5 | Relay the checkpoint with AskUserQuestion, then re-run Phase C with the user's focus choice |
| Phase C agenda fails | 5 | Record a failed priority-reset section and continue to Phase D |
| No newly compiled note and no resurfaced notes | 6 | Skip `/pa link` and carry the skip reason into the final report |
| One link target fails | 6 | Continue linking the remaining targets and mark the failed target in `New Connections` |
| Any phase is skipped or fails | 7 | Render the final review anyway, and show the skip or failure reason inside that section |
| Phase A returned a checkpoint payload or Phases B/D returned derivation payloads | 8 | Merge and persist them without overwriting newer subcommand state |

## Horizon Mappings

### Compile Window Mapping

| Reset Horizon | Phase B Compile Window | Role in the Reset |
|---------------|------------------------|-------------------|
| `week` | Last 7 days | Weekly evidence packet |
| `month` | Last 30 days | Monthly evidence packet |
| `quarter` | Last 90 days | Quarterly lower-layer packet |
| `year` | Last 365 days | Yearly evidence packet |
| `3y` | Last 365 days | Nearest lower-layer evidence packet for a long-horizon reset |
| `10y` | Last 365 days | Nearest lower-layer evidence packet for a long-horizon reset |
| `30y` | Last 365 days | Nearest lower-layer evidence packet for a long-horizon reset |
| `lifetime` | Last 365 days | Nearest lower-layer evidence packet for a long-horizon reset |

### Agenda Mapping

| Reset Horizon | Phase C Agenda Horizon | Reason |
|---------------|------------------------|--------|
| `week` | `week` | Exact operational match |
| `month` | `month` | Exact operational match |
| `quarter` | `month` | `month` is the broadest agenda horizon and best carry-forward view for quarterly reset |
| `year` | `month` | Strategic reset still needs a bounded operational carry-forward layer |
| `3y` | `month` | Strategic reset still needs a bounded operational carry-forward layer |
| `10y` | `month` | Strategic reset still needs a bounded operational carry-forward layer |
| `30y` | `month` | Strategic reset still needs a bounded operational carry-forward layer |
| `lifetime` | `month` | Strategic reset still needs a bounded operational carry-forward layer |

## Phase 1: Parse Input

Parse `$ARGUMENTS` as a single optional horizon flag.

Accepted forms:

- no argument
- `--horizon week`
- `--horizon month`
- `--horizon quarter`
- `--horizon year`
- `--horizon 3y`
- `--horizon 10y`
- `--horizon 30y`
- `--horizon lifetime`

Default to `week` when no argument is provided.

Do not accept custom ranges or extra flags.
Resolve malformed input per the Decision Matrix.

## Phase 2: Load State

Check vault maturity per `skills/pa/trust-and-boundaries/references/vault-maturity.md`.
If below `advanced`, present guidance and suggest `/pa review --horizon week`.
Continue regardless.
Guidance is advisory.

1. Read `.pa/settings.json` and extract the vault path, posture, capability tier, and QMD configuration.
2. Read `.pa/vault-profile.json` and extract journaling cadence, linking style, placement rules, and any review-specific profile hints.
3. Read `.pa/entities.json` when present and extract active life goals for goal-aware agenda context.
4. Read `.pa/derivation-state.json` when present so Phase B can evaluate compile eligibility and Phase D can merge dirty-path outcomes cleanly.
5. Read `templates/pa/weekly-review.md` so the final render stays aligned with the template contract.
6. Resolve the Phase B compile window from `Horizon Mappings`.
7. Resolve the Phase C agenda horizon from `Horizon Mappings`.

Only `.pa/settings.json` and `.pa/vault-profile.json` are hard prerequisites.
Missing `.pa/derivation-state.json` means compile preflight starts without a prior cursor.
Missing `.pa/entities.json` means Phase C stays operationally useful but not goal-aware.

## Phase 3: Phase A — Review

> Subcommand: **`/pa review`**

Invoke the review command through the Skill tool.

```text
Skill: pa:review
Args: --horizon {selected_horizon}
```

Capture the full follow-up report, the health summary, any resurfaced note paths, any `goal_progress`, any long-horizon direction questions, and the `checkpoint_payload` for `.pa/review-state.json`.

### Recovery

| Failure | Action |
|---------|--------|
| `/pa review` fails | Preserve the error as the Review Summary section and continue |
| `/pa review` reports a healthy vault | Carry the healthy outcome forward without inventing extra drift |
| `/pa review` returns partial coverage | Preserve the limitation note and continue |

## Phase 4: Phase B — Compile Preflight

> Subcommand: **`/pa compile`**

Use `skills/pa/executive-assistance/references/compilation-policy.md` for eligibility and no-op rules.

1. Resolve the concrete `--from` and `--to` window from `Compile Window Mapping`.
2. Check `derivation-state.json -> last_compile` and the compilation-policy no-op rules before invoking `/pa compile`.
3. If the window is eligible, invoke `/pa compile`.
4. If the window is ineligible, store a clean skip result with the exact reason.

```text
Skill: pa:compile
Args: --from {window_start} --to {window_end}
```

For `3y` and longer resets, this phase compiles only the nearest lower-layer yearly packet.
It does not attempt to compile the full strategic horizon as one raw window.

### Capture

Store the compile status, any no-op reason, any written or proposed output path, key themes, carry-forward items, and evergreen candidates.

### Recovery

| Failure | Action |
|---------|--------|
| `/pa compile` returns a no-op | Mark `Period Compilation` as skipped with the policy reason and continue |
| `/pa compile` fails | Mark `Period Compilation` as failed and continue |
| `/pa compile` writes only a proposal because posture blocked the write | Preserve the rendered synthesis and mark the output path as proposal-only |

## Phase 5: Phase C — Agenda

> Subcommand: **`/pa agenda`**

Map the reset horizon to the supported agenda horizon before invocation.

Pass Phase A and Phase B outputs as additional context so chief-of-staff can weight stale loops, carry-forward items, compile themes, and active goals during prioritization.

```text
Skill: pa:agenda
Args: --horizon {agenda_horizon}
```

Pass review and compile summaries as additional `user_context` in the call.

### Agenda Context Rules

1. Pass stale items, stale waiting-fors, and open-loop drift from Phase A as `user_context`.
2. Pass carry-forward items, key themes, and any evergreen candidates from Phase B as `user_context`.
3. Pass active goal entities from `.pa/entities.json` as `user_context`, including `canonical_name`, `horizon`, `status`, and any `area_refs` or `direction_refs` that survived extraction.
4. Pass Phase A `goal_progress` when it is available so chief-of-staff can prioritize around real evidence of movement or staleness instead of goal names alone.
5. For `year+`, pass long-horizon direction questions from Phase A and the matching-or-longer goal set as framing context, but keep the actual agenda bounded to the mapped operational horizon.

### User Checkpoint

If `/pa agenda` returns the focus checkpoint from `commands/pa/agenda.md`, relay it unchanged with AskUserQuestion.
Wait for the user's choice, then re-run Phase C once with that focus choice injected into `user_context`.

### Recovery

| Failure | Action |
|---------|--------|
| `/pa agenda` fails | Mark `Priority Reset` as failed and continue |
| User does not answer the agenda checkpoint | Preserve the unresolved checkpoint in `Priority Reset` and continue |
| `/pa agenda` returns low confidence | Preserve the low-confidence note rather than rewriting it away |

## Phase 6: Phase D — Link

> Subcommand: **`/pa link`**

Select link targets from the fresh outputs only.

### Target Selection

| Candidate Source | Eligible When | Priority |
|------------------|---------------|----------|
| Newly compiled note | Phase B produced a real output path that exists now | 1 |
| Resurfaced note | Phase A surfaced the note path and it still exists | 2 |

Dedupe targets by path.
Run the newly compiled note first, then the resurfaced notes in stable path order.

```text
Skill: pa:link
Args: {target_path}
```

Skip Phase D when no eligible target exists.

### Capture

Store each target path, link result status, and only the material connections that change retrieval, priority, or framing.

### Recovery

| Failure | Action |
|---------|--------|
| One `/pa link` call fails | Record that target as failed and continue with the remaining targets |
| All targets fail | Mark `New Connections` as failed, but still render the final reset |
| No eligible targets exist | Mark `New Connections` as skipped, not failed |

## Phase 7: Present

Render the final output per `templates/pa/weekly-review.md`.

Do not recompute or reinterpret the subcommand outputs inline.
Compress them only enough to fit the template.

### Section Mapping

| Weekly Review Section | Source |
|-----------------------|--------|
| `Review Summary` | Compressed Phase A follow-up report or its healthy/failed/partial status |
| `Period Compilation` | Phase B synthesis, no-op note, or failure note |
| `Priority Reset` | Phase C agenda output or unresolved checkpoint |
| `New Connections` | Material Phase D link outputs only |
| `Next Actions` | Concrete follow-ups derived from the highest-signal available phase outputs |

### Next Action Rules

| Condition | Preferred Next Action |
|-----------|-----------------------|
| Phase C surfaced a concrete primary thread | `/pa draft "{primary_thread}"` |
| Phase B surfaced an evergreen candidate | `/pa draft "{evergreen_topic}"` |
| Phase D surfaced a high-signal connection target | `/pa focus "{entity_or_project}"` |
| `year+` reset ended in strategic questions | Reply to the direction questions before changing the system further |
| Most phases skipped or failed | `/pa review --horizon {selected_horizon}` — re-run the narrowest reliable layer first |

For `week` and `month`, keep the output operational.
For `quarter`, keep it hybrid.
For `year+`, compress low-level noise and end with commitments, experiments, or questions instead of a flat task dump.

## Phase 8: State Update

Persist only the state that existing subcommands already own.

1. If Phase A returned a `checkpoint_payload` and `.pa/review-state.json` was not already updated, merge it per `skills/pa/review-and-journaling/references/review-state-schema.md`.
2. If Phase B returned a new `last_compile` cursor or Phase D returned additive `dirty_paths` and those writes were not already persisted, merge them into `.pa/derivation-state.json`.
3. Never overwrite a newer subcommand write with older composite memory.
4. Do not invent reset-only state fields.
5. The reset's state update is reconciliation, not a second source of truth.

## Composability

| Context | Usage |
|---------|-------|
| Top-level user entry point | `reset` is the primary bounded review-loop entry point across horizons |
| Replaces `/pa weekly` | `week` horizon is the weekly reset path, and longer horizons extend the same composite |
| Composes primitives | `review` + `compile` + `agenda` + `link` stay independent and reusable outside the composite |
| Produces final artifact | Renders `templates/pa/weekly-review.md` from the four phase outputs |

## Rules

- **Composite orchestration only**: Reset sequences subcommands. It does not duplicate their analysis logic.
- **Independent phases**: Failure in one phase never blocks the remaining phases.
- **Skip-aware**: Every phase reports its result, including clean no-ops and skipped branches.
- **Posture is delegated**: Review, compile, agenda, and link each enforce their own trust and write rules.
- **Lower-layer first**: Long horizons use the nearest lower-layer evidence packet before shifting into conversation-driven reset.
- **Reconciliation only**: Phase 8 merges state payloads and does not invent a parallel reset-state schema.
