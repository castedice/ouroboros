---
name: core:doctor
description: Use when you need to verify ouroboros environment health
argument-hint: ""
allowed-tools: Read, Glob, Grep, Bash, Agent
---

# Doctor — System Health Check

Verify the ouroboros plugin environment: external CLI tools, MCP connections, settings validation, hook health, LSP configuration, and plugin version.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2-8 | — (command) | Health checks via Read, Glob, Grep, Bash |
| 9 | researcher (agent, conditional) | Deep analysis when FAIL found — diagnose root cause and suggest fix |

## Phase 1: Parse Input

No flags in MVP. If arguments are provided, log "Doctor does not accept arguments yet. Running full check." and proceed.

### Branch Summary

| Condition | State | Affected Phases | Behavior |
|-----------|-------|-----------------|----------|
| Extra arguments | present | 1 | Warn and continue with the full health check |
| `--fix` | present | 1, 9 | Warn that fix mode is not implemented and continue report-only |
| Codex CLI | missing | 2, 9 | Record WARN and continue |
| MCP servers | none discovered | 4 | Record OK: no MCP servers configured |
| Project settings | missing | 4 | Record WARN and continue with remaining checks |
| Hooks or `.lsp.json` | invalid JSON or missing scripts | 5, 9 | Record FAIL and trigger Phase 9 deep analysis |
| Learning data | missing overlays or empty directories | 6 | Record OK or WARN per finding and continue |
| Plugin manifest | missing or invalid | 7, 9 | Record WARN and continue |
| Any FAIL present | true | 9 | Delegate root-cause analysis before recommendations |
| Any FAIL present | false | 9 | Skip deep analysis and render the report directly |


Initialize a results collector:

```
checks = []  // { name, status: OK|WARN|FAIL, detail }
```

## Phase 2: Health Collector

Delegate the raw environment audit to the researcher agent as a read-only health collector so the command stays at the orchestration layer.

> Agent: **researcher** (subagent_type: `ouroboros:core:researcher`)

### Collector Contract

| Contract Part | Content |
|---------------|---------|
| Input | Current plugin root, project root, home-level Claude settings paths, project-level Claude settings paths, `hooks/hooks.json`, `.lsp.json`, `${CLAUDE_PLUGIN_DATA:-${CLAUDE_PLUGIN_ROOT}/.tmp}`, and `.claude-plugin/plugin.json` |
| Instructions | Perform a read-only environment audit. Use Bash, Read, Glob, and Grep only to collect evidence. Populate `.tmp/{SESSION_ID}_doctor_checks.json` with check rows for `external_cli`, `mcp`, `settings`, `hooks`, `lsp`, `learning_pipeline`, and `plugin_version`. For each row return `name`, `status`, `detail`, `family`, and `evidence_path`. Never repair files or suppress failures. |
| Expected Output | A machine-consumable JSON payload at `.tmp/{SESSION_ID}_doctor_checks.json` plus a compact summary message listing FAIL and WARN counts. |

The collector must treat `.tmp/{SESSION_ID}_doctor_checks.json` as the authoritative payload.
If the collector cannot inspect a family, it must still emit a row for that family with `status: FAIL` or `WARN` and the blocked path in `detail`.
If the agent returns prose, use it only as an execution log.
Strip any trailing status block per `skills/core/routing/references/completion-status-protocol.md` before reading the summary text.

## Phase 3: External CLI Findings

Read `.tmp/{SESSION_ID}_doctor_checks.json`.
Copy every `family="external_cli"` row into `checks`.

## Phase 4: MCP + Settings Findings

Read `.tmp/{SESSION_ID}_doctor_checks.json`.
Copy every `family="mcp"` and `family="settings"` row into `checks`.

## Phase 5: Hook + LSP Findings

Read `.tmp/{SESSION_ID}_doctor_checks.json`.
Copy every `family="hooks"` and `family="lsp"` row into `checks`.

## Phase 6: Learning Pipeline Findings

Read `.tmp/{SESSION_ID}_doctor_checks.json`.
Copy every `family="learning_pipeline"` row into `checks`.

## Phase 7: Plugin Version Findings

Read `.tmp/{SESSION_ID}_doctor_checks.json`.
Copy every `family="plugin_version"` row into `checks`.

## Phase 8: Health Summary Preparation

Sort `checks` by severity (`FAIL` → `WARN` → `OK`) and then by family.
Compute `ok_count`, `warn_count`, and `fail_count` for Phase 9 reporting.

## Phase 9: Report

### Health Report Table

```markdown
## Doctor Report

| # | Check | Status | Detail |
|---|-------|--------|--------|
| 1 | {name} | {OK/WARN/FAIL} | {detail} |
| 2 | ... | ... | ... |

**Summary**: {ok_count} OK, {warn_count} warnings, {fail_count} failures
```

### Deep Analysis (conditional)

When any FAIL is found, delegate root cause analysis to the researcher agent:

> Agent: **researcher** (subagent_type: `ouroboros:core:researcher`)

- **Input**: FAIL entries from checks collector (name, status, detail)
- **Reference**: `skills/core/validation/SKILL.md`, `hooks/hooks.json`, `.claude/settings.json`, `.lsp.json`, and `.tmp/{SESSION_ID}_doctor_checks.json`
- **Payload handling**: Read FAIL source rows from `.tmp/{SESSION_ID}_doctor_checks.json`. Write deep-analysis notes to `.tmp/{SESSION_ID}_doctor_fail_analysis.md`. Strip any trailing status block per `skills/core/routing/references/completion-status-protocol.md` before extracting fixes.
- **Consensus**: None. The recorded Phase 2-7 statuses remain authoritative even if the analyst proposes a softer interpretation.
- **Instructions**: "Analyze these health check failures. For each FAIL: identify the root cause, check if related files exist or are misconfigured, and suggest a concrete fix command or edit."
- **Expected output**: `.tmp/{SESSION_ID}_doctor_fail_analysis.md` with one repeated block per FAIL using the ordered sections `## Failure: {name}`, `### Evidence`, `### Root Cause`, `### Fix Command`, and `### Verification`

#### Deep-Analysis Output Contract

The analyst must render `.tmp/{SESSION_ID}_doctor_fail_analysis.md` so every FAIL can be reconstructed and actioned without rereading the whole workspace:

````markdown
## Failure: {name}

### Evidence
- Status: {status}
- Detail: {detail}
- Evidence path: {evidence_path}

### Root Cause
- {concise diagnosis tied to the evidence}

### Fix Command
```bash
{current-run command using the exact failing path or missing script from this run}
```

### Verification
```bash
{current-run verification command against the same path}
```
````

### Recovery

| Failure | Max Retries | Stagnation Detection | Stop Behavior |
|---------|-------------|----------------------|---------------|
| Phase 2 collector payload missing or malformed | 1 | The retry still omits one or more required families from `.tmp/{SESSION_ID}_doctor_checks.json` | Record a synthetic FAIL for the missing family and continue |
| JSON parse failure for settings, hooks, or `.lsp.json` | 1 per file | The second read produces the same parse failure or byte-identical invalid content | Record FAIL once, stop retrying that file, and continue with remaining families |
| Learning-root scan failure | 1 narrowed retry | The narrowed retry returns the same access or parse error | Record WARN with the blocked path and continue |
| Phase 9 deep-analysis timeout or malformed output | 1 | The retry returns the same missing sections or no new root-cause detail | Omit deep analysis, surface raw FAIL rows, and stop recovery |

No recovery path may retry more than once.

### Recommendations

Generate context-aware recommendations from the current run's `checks` rows and, when present, the matching block in `.tmp/{SESSION_ID}_doctor_fail_analysis.md`.
Populate `{evidence_path}`, `{detail}`, `{plugin_root}`, `{project_settings_path}`, `{hooks_path}`, `{lsp_path}`, and `{plugin_data_path}` from `.tmp/{SESSION_ID}_doctor_checks.json` before rendering the final report.

| Condition | Recommendation |
|-----------|----------------|
| Any FAIL with deep-analysis output | Reproduce the matching `### Fix Command` and `### Verification` blocks from `.tmp/{SESSION_ID}_doctor_fail_analysis.md`, then ask the user whether to apply that exact fix |
| Codex WARN on `{evidence_path}` | `npm i -g @openai/codex && codex --version` |
| Settings WARN or FAIL on `{evidence_path}` | `jq empty "{evidence_path}"` and then edit that exact file to add the missing allowlist or shared settings entries named in `{detail}` |
| Hooks FAIL on `{evidence_path}` | `jq empty "{evidence_path}"` and verify every referenced script exists under `"{plugin_root}/scripts/"` before rerunning `/doctor` |
| `.lsp.json` FAIL on `{evidence_path}` | `jq empty "{evidence_path}"` and compare it to the matching template under `templates/core/lsp-configs/` |
| Learning pipeline WARN on `{plugin_data_path}` | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/learning-distill.sh distill` and inspect the warned path under `"{plugin_data_path}"` |
| All OK | "Environment healthy. All ouroboros features available." |
| First run | "`/onboard` — discover available modules and recommended workflows" |

## System Context

Doctor is a standalone diagnostic command. It does not compose with other commands programmatically, but serves as a prerequisite check:

| Context | Usage |
|---------|-------|
| Before `/evaluate --multi` | Verify Codex CLI + settings allow patterns are in place |
| After plugin update | Confirm hooks, scripts, and plugin.json are consistent |
| During `/onboard` | Environment validation as part of new-user setup |
| Troubleshooting | First step when ouroboros commands behave unexpectedly |

**Artifacts**: Produces a report (displayed, not persisted). No files created or modified.

**User checkpoint**: When FAIL items exist and researcher provides fix suggestions, the user chooses whether to apply fixes before the command ends.

## Rules

- Read-only — doctor never modifies files
- Report all findings — do not short-circuit on first failure
- Keep output concise — one line per check in the table
- Do not check network connectivity or API keys — those are runtime concerns
- `--fix` is reserved for future versions — if user passes it, log "⚠ --fix not yet implemented. Showing report only." and proceed with report
