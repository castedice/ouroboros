---
name: pa:heartbeat
description: "Use when PA seems out of sync and you need a quick health check of indexing, memory, review cadence, and privacy state"
effort: low
allowed-tools:
  - Read
  - Bash
  - Agent
  - AskUserQuestion
  - CronCreate
argument-hint: "[--watch]"
---

# Heartbeat - PA Self-Check

Run a lightweight health check on all PA subsystems.
It may refresh `.pa/heartbeat.json`, but it never repairs state or edits vault notes.

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2 | Read (tool) | Load `.pa/` state prerequisites plus soul or persona render state |
| 3 | Bash (tool) | Run `bash scripts/pa-heartbeat.sh check` for deterministic health checks |
| 4 | Read (tool) | Load `.pa/heartbeat.json` after the shell backend finishes |
| 4 | sentinel (agent) | Interpret health results and produce actionable summary |
| 4 | Bash (tool, optional) | Run `bash scripts/pa-notify.sh send ...` when warning or error results should trigger push notification |
| 5 | AskUserQuestion (tool, optional) | Offer hourly in-session heartbeat monitoring when `--watch` is present |
| 5 | Bash (tool, optional) | Check whether `pa-scheduler.sh` already has `heartbeat` active before in-session scheduling |
| 5 | CronCreate (tool, optional) | Create the hourly in-session recurring heartbeat watch after explicit confirmation |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/settings.json` | read | Vault root, QMD collection name, and `shadow_root` for shell checks |
| `.pa/derivation-state.json` | read | Ontology dirty-path count and survey freshness timestamp |
| `.pa/review-state.json` | read | Week and month review checkpoint freshness |
| `.pa/memory/state.json` | read | Memory flush request flag |
| `.pa/memory/.pending-flush.jsonl` | read | Pending memory flush count |
| `.pa/memories.jsonl` | read | Fact log used for memory-head backing and contested-fact review-surfacing checks |
| `.pa/memory-heads.json` | read | Materialized fact heads required when `memories.jsonl` exists |
| `.pa/entities.json` | read | Ontology presence hint for revision-health checks |
| `.pa/entity-revisions.jsonl` | read | Entity revision overlay used for revision-health checks |
| `.pa/sessions/{id}.json` | read | Pending unresolved coreference candidates from recent sessions |
| `.pa/mask-map.json` | read | Privacy registry entry count |
| `.pa/hash-index.json` | read | Privacy hash-index coverage count |
| `.pa/soul.md` | read | Soul layer for render settings and tone |
| `.pa/persona.json` | read | Render-only fallback when `.pa/soul.md` is missing |
| `.pa/heartbeat.json` | read+write | Persisted heartbeat result produced by the shell backend and reread for presentation |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No argument | 1 | Continue with the default heartbeat flow for the configured or auto-detected PA vault |
| Exact `--watch` flag | 1 | Continue with the default heartbeat flow and queue the post-report watch offer |
| Any other argument or extra text is provided | 1 | Abort: "Heartbeat accepts no arguments or only `--watch`. Run `/pa heartbeat` or `/pa heartbeat --watch`" |
| No `.pa/` directory | 2 | Abort: "PA state directory not found. Run `/pa init` or `/pa survey` first" |
| No `.pa/settings.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| `scripts/pa-heartbeat.sh` not found | 2 | Abort: "`scripts/pa-heartbeat.sh` is missing. Update the plugin checkout to a build that includes the heartbeat backend" |
| Script returns healthy (`exit 0`) | 3 | Read `.pa/heartbeat.json` and present a concise healthy summary |
| Script returns warnings (`exit 1`) | 3-4 | Read `.pa/heartbeat.json`, present warning markers, and continue to notification integration |
| Script returns errors (`exit 2`) | 3-4 | Read `.pa/heartbeat.json`, present error markers, and send a critical notification when `scripts/pa-notify.sh` exists |
| Script fails before producing readable output | 3 | Abort with the backend failure and advise the user to rerun `bash scripts/pa-heartbeat.sh check` manually |

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| No argument | 1-4 | Run the standard one-off heartbeat flow and stop after presentation plus any best-effort notification |
| `--watch` is provided | 1-5 | Run the standard one-off heartbeat flow first, then offer hourly in-session monitoring |
| `--watch` is provided and the user declines scheduling | 5 | Keep the one-off result only and stop without creating any recurring job |
| `--watch` is provided and `pa-scheduler.sh status` already reports `heartbeat` | 5 | Warn that persistent unattended monitoring already exists, then continue with in-session monitoring only |
| `--watch` is provided and the user accepts scheduling | 5 | Create the CronCreate job and confirm the session-only hourly watch |

## Phase 1: Parse Input

Heartbeat accepts no positional arguments and one optional flag.
`$ARGUMENTS` must be empty or exactly `--watch`.
Accepted forms are `no argument` and `--watch`.
No horizon flag, topic text, vault-path override, or additional flag is part of the command interface today.
If any extra input is present, abort per the Decision Matrix instead of guessing user intent.
Set `watch_requested = true` only when the sole accepted flag is `--watch`.

## Phase 2: Load State

1. Confirm that the resolved vault root contains a `.pa/` directory.
2. Read `.pa/settings.json` and extract `vault_root`, `qmd_collection_name`, and `shadow_root`.
3. Confirm that `scripts/pa-heartbeat.sh` exists before invoking the Bash tool.
4. Load the remaining files exactly as listed in the State Contract above, in the same order, and use each row's `Purpose` column as the source of truth for what that file contributes to the run.
5. Apply the persona fallback chain from the State Contract: `.pa/soul.md` → `.pa/persona.json` → defaults from `skills/pa/persona-response/references/persona-schema.md`.
6. Do not reinterpret missing or malformed overlays during load.
Surface them through the backend result as warnings, errors, or `not evaluated` coverage instead of silently repairing them here.

Only `.pa/` and `.pa/settings.json` are hard prerequisites before delegation.

## Phase 3: Execute Health Check

Heartbeat uses the shell backend as the authoritative checker.

```bash
PA_VAULT_PATH="$VAULT" bash scripts/pa-heartbeat.sh check
```

The backend checks nine operational surfaces.
Those surfaces are `qmd`, `shadow`, `ontology`, `memory`, `review`, `survey`, `privacy`, `relationships`, and `calendar`.
It writes `.pa/heartbeat.json`, prints the same JSON payload to stdout, and returns an exit code that maps to the overall status.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | Resolved vault path, `.pa/settings.json`, and the existing `.pa/` health state files listed in the State Contract |
| Instructions | Run `scripts/pa-heartbeat.sh check` against the resolved vault. Let the shell backend evaluate QMD freshness, shadow sync, ontology dirty paths, revision overlay health, memory flush state, missing `memory-heads.json` when `memories.jsonl` exists, contested facts that have not yet been surfaced by review, unresolved coreference candidates from session state, survey freshness, privacy integrity, relationship health, and calendar freshness. Write `.pa/heartbeat.json`. Return the JSON payload without embellishment. Never edit vault markdown or perform repairs |
| Expected Output | JSON with `checked_at`, `status`, `highest_severity`, `relationships`, `checks.{qmd,shadow,ontology,memory,review,survey,privacy,calendar}`, `summary[]`, `recommended_actions[]`, and an exit code of `0`, `1`, or `2` |

### Recovery

Use one bounded recovery loop per surface.

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Heartbeat backend | 1 full run + 1 retry when the first failure occurred before a readable `.pa/heartbeat.json` was produced | The retry fails before producing a readable file, or it returns the same backend error class | Stop retrying and abort with the backend failure note |
| Sentinel interpretation | 1 delegation attempt only | Delegation fails or returns no structured summary | Stop delegation and fall back to direct rendering of `.pa/heartbeat.json` |
| Notification delivery | 1 send attempt only | The backend returns the same `skipped`, `queued`, or `failed` status for the current event | Do not retry inside heartbeat. Keep notification best-effort and leave the heartbeat result unchanged |
| Partial current-run coverage | 0 retries once a readable current-run file exists | Missing check blocks persist in the current-run payload | Present `NOT EVALUATED` for those categories and stop rather than substituting older data |
| Watch scheduling offer | 1 question only | The user declines, or no reply is available | Leave the one-off heartbeat result unchanged and stop before CronCreate |
| Persistent schedule status check | 1 command only | `pa-scheduler.sh status` fails or returns no readable status | Continue without the redundancy warning and keep the in-session scheduling path available |
| CronCreate scheduling | 1 create attempt only | CronCreate fails or does not confirm the job | Report the scheduling failure briefly and keep the one-off heartbeat result unchanged |

Do not silently substitute an older heartbeat file as if it were current.
Current-run output is authoritative.

## Phase 4: Present

Read `.pa/heartbeat.json` after Phase 3 completes.
Do not write a user-facing note.

### Health Interpretation

Delegate health result interpretation to the **sentinel** agent:
- **Input**: `.pa/heartbeat.json` content (current run)
- **Instructions**: "Interpret the health check results. Identify the most critical issue, suggest one actionable next step per warning/error, and produce a prioritized summary. Do not rerun checks or repair state."
- **Expected output**: Prioritized health summary with actionable recommendations

If delegation fails (timeout or error), fall back to direct rendering of `.pa/heartbeat.json` below.

### Persona Application

Before presenting results, apply the persona render contract from `skills/pa/persona-response/references/render-contract.md`.
Use the sentence style from `render_hints.sentence_style`.
Apply warmth from `warmth`.
Apply directness from `directness`.
Respect the emoji setting from `render_hints.emoji`.
Do not alter substance.
Statuses, check ordering, severity, detail strings, summary items, and recommended actions must remain faithful to the backend output.

### Rendering Guidance

If the overall status is `healthy`, a brief summary is enough.
If the overall status is `warnings` or `errors`, render the full seven-check table plus recommended actions.
Preserve the backend check order as `QMD`, `Shadow`, `Ontology`, `Memory`, `Review`, `Survey`, `Privacy`, `Relationships`, and `Calendar`.
Use explicit status markers such as `OK`, `WARNING`, and `ERROR`.
Do not downplay an `error` as a warning or rephrase a warning into healthy language.
If partial coverage occurred, use `NOT EVALUATED` for missing categories and say coverage was partial.

Use this shape for non-healthy runs:

```markdown
## PA Heartbeat

**Status**: {healthy|warnings|errors}
**Checked**: {timestamp}

| Check | Status | Detail |
|-------|--------|--------|
| QMD | {OK|WARNING|ERROR} | {detail} |
| Shadow | {OK|WARNING|ERROR} | {detail} |
| Ontology | {OK|WARNING|ERROR} | {detail} |
| Memory | {OK|WARNING|ERROR} | {detail} |
| Review | {OK|WARNING|ERROR} | {detail} |
| Survey | {OK|WARNING|ERROR} | {detail} |
| Privacy | {OK|WARNING|ERROR} | {detail} |
| Relationships | {OK|WARNING|ERROR} | {detail} |
| Calendar | {OK|WARNING|ERROR} | {detail} |

### Summary
- {summary_item}

### Recommended Actions
- {action_item}
```

If all checks pass, render `## PA Heartbeat`, the checked timestamp, and a short line such as `All systems healthy.` instead of forcing the full table.

### User Checkpoint (errors only)

If the overall status is `errors`, pause before notification and ask the user to choose a follow-up action:

1. **Fix now**: run the top recommended action immediately (e.g., `/pa survey`, `/pa review --horizon week`)
2. **Notify and defer**: send push notification and take no further action
3. **Dismiss**: acknowledge the error without notification or action

If running in unattended mode (scheduler/autopilot), skip the checkpoint and default to "notify and defer".
If the status is `warnings` or `healthy`, skip the checkpoint entirely and proceed to notification.

### Notification Integration

If the overall status is `warnings` or `errors` and `scripts/pa-notify.sh` exists, send a masked push summary after rendering (or after the user chooses "notify and defer" in the checkpoint).
Use `warning` priority for `warnings`.
Use `critical` priority for `errors`.
Keep the title and message short and summary-only.
Do not include raw vault note content or unmasked private names.
Use tags such as `heartbeat` plus the matching severity.
If the notify backend reports `skipped`, `queued`, or `failed`, do not change the heartbeat result.
Notification delivery is best-effort.

## Phase 5: Optional Watch Scheduling

Run this phase only when `watch_requested = true`.
Always finish the normal heartbeat rendering and any notification handling first.
Offer recurring monitoring once after the report completes.
If the user declines, stop and preserve the one-off heartbeat result unchanged.

Before creating the CronCreate job, check whether the persistent scheduler already has heartbeat active:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/pa-scheduler.sh status 2>/dev/null | grep -q heartbeat
```

If that check succeeds, warn exactly:
"Persistent heartbeat schedule is already active via pa-scheduler. CronCreate monitoring would be redundant during unattended periods. Proceeding with in-session monitoring only."

Create the recurring monitor with CronCreate:

```text
CronCreate(cron: "7 */1 * * *", prompt: "Run /pa heartbeat and report any findings. This is an automated check — be concise.", recurring: true)
```

After a successful create, report exactly:
"Heartbeat monitoring scheduled every hour (session-only, 7-day auto-expiry). Use CronDelete to stop."

Do not create a CronCreate job unless the user explicitly requested `--watch` and accepted the scheduling offer.

## Next Actions

| Result | Suggested Action |
|--------|------------------|
| QMD stale | `qmd update && qmd embed` |
| Shadow mismatch | `bash scripts/pa-shadow.sh sync "$VAULT" --incremental` |
| Ontology pending | `/pa steward` |
| Memory pending | Run a PA command that processes memory, such as `/pa day` or `/pa agenda --horizon week` |
| Unresolved coreference candidates | `/pa steward` — review and confirm or reject pending merge proposals |
| Review stale | `/pa review --horizon week` |
| Survey stale | `/pa survey` or `/pa steward` |
| Privacy error | Check mask-map integrity, then rebuild the hash index |
| Ongoing in-session monitoring desired | `/pa heartbeat --watch` — run a one-off heartbeat first, then offer hourly in-session monitoring |
| All healthy | No action needed |

## Composability

| Context | Usage |
|---------|-------|
| `scripts/pa-scheduler.sh` | The default `heartbeat` schedule runs every 6 hours and is seeded with `notify: push` |
| `/pa steward` | Heartbeat detects drift. Steward is the repair-oriented follow-up when the user wants bounded maintenance |
| `scripts/pa-standing-orders.sh` | Orders with `approval_gate.require_healthy_heartbeat: true` block when heartbeat is missing, malformed, or unhealthy |
| `scripts/pa-notify.sh` | Heartbeat can escalate warning and error summaries to mobile push without exposing raw vault content |

## Rules

- **Read-only for vault notes**: Heartbeat never edits user markdown, daily notes, or project notes.
- **Assistant-state write only**: The only state file heartbeat may refresh is `.pa/heartbeat.json`.
- **Shell-backend-only**: Health evaluation, thresholds, summary items, and recommended actions come from `scripts/pa-heartbeat.sh`.
- **Persona is render-only**: Soul or persona state may change wording, but never status, severity, or action substance.
- **No silent repairs**: Heartbeat reports problems and follow-up actions, but it never runs `qmd update`, `pa-shadow.sh`, `pa-mask.sh`, or other repair commands inline.
- **Notification integration is optional**: If `scripts/pa-notify.sh` exists, warnings and errors may trigger best-effort push delivery. If it does not exist, heartbeat still completes normally.
