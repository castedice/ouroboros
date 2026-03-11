---
name: core:doctor
description: System health check — verify CLI tools, MCP, settings, hooks, LSP, plugin version
argument-hint: ""
allowed-tools: Read, Glob, Grep, Bash, Agent
---

# Doctor — System Health Check

Verify the ouroboros plugin environment: external CLI tools, MCP connections, settings validation, hook health, LSP configuration, and plugin version.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2-7 | — (command) | Health checks via Read, Glob, Grep, Bash |
| 8 | researcher (agent, conditional) | Deep analysis when FAIL found — diagnose root cause and suggest fix |

## Phase 1: Parse Input

No flags in MVP. If arguments are provided, log "Doctor does not accept arguments yet. Running full check." and proceed.

Initialize a results collector:

```
checks = []  // { name, status: OK|WARN|FAIL, detail }
```

## Phase 2: External CLI Check

Check availability and version of external CLI tools used by ouroboros multi-model features.

### Codex CLI

Use Bash to check if `codex` is available on PATH and retrieve its version.

| Result | Status | Detail |
|--------|--------|--------|
| Found with version | OK | "codex v{version} at {path}" |
| Not found | WARN | "codex not installed — multi-model features unavailable" |

Add result to `checks`.

## Phase 3: MCP Connection Status

Read Claude Code settings to discover configured MCP servers.

1. Read `~/.claude/settings.json` — extract `mcpServers` keys
2. Read `~/.claude/settings.local.json` — extract `mcpServers` keys (if exists)
3. Read `.claude/settings.json` (project-level) — extract `mcpServers` keys (if exists)
4. Read `.claude/settings.local.json` (project-level) — extract `mcpServers` keys (if exists)

For each discovered MCP server entry:

| Check | Status | Detail |
|-------|--------|--------|
| Entry exists with `command` field | OK | "{name}: configured ({command})" |
| Entry exists but missing `command` | WARN | "{name}: configured but no command specified" |
| No MCP servers found | OK | "No MCP servers configured" |

Add results to `checks`.

## Phase 4: Settings Validation

Read project-level `.claude/settings.json` and verify essential patterns for ouroboros operation.

### Required Patterns

Check the following exist in `allowedTools` or equivalent allow list:

| Pattern | Purpose | Missing = |
|---------|---------|-----------|
| `Bash(codex *)` | Multi-model CLI invocation | WARN: "Bash(codex *) not in allow list — multi-model will prompt each time" |
| `Bash(bash scripts/*)` | Script execution | WARN: "Bash(bash scripts/*) not in allow list — scripts will prompt each time" |

### Deny Patterns

Verify safety deny patterns are present:

| Pattern | Purpose | Missing = |
|---------|---------|-----------|
| `Bash(rm *)` deny | Safe deletion policy | WARN: "Bash(rm *) deny not found — safe-rm.sh bypass possible" |

If `.claude/settings.json` does not exist: WARN "No project settings.json found."

Add results to `checks`.

## Phase 5: Hook Health

Read `hooks/hooks.json` from the plugin root (`${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` or resolve from Glob).

1. Parse JSON structure — if invalid JSON: FAIL "hooks.json: invalid JSON"
2. For each hook type present in the JSON, iterate entries and verify the referenced script path (`entry.hooks[].command`) exists on disk via Glob.

| Result | Status | Detail |
|--------|--------|--------|
| Script exists | OK | "{hook_type}/{matcher}: {script} exists" |
| Script missing | FAIL | "{hook_type}/{matcher}: {script} NOT FOUND" |
| Hook type not present | OK | (skip silently — not all types required) |

Add results to `checks`.

## Phase 6: LSP Configuration

Check for `.lsp.json` in the project root.

| Result | Status | Detail |
|--------|--------|--------|
| File exists and is valid JSON | OK | ".lsp.json: valid ({n} server configs)" |
| File exists but invalid JSON | FAIL | ".lsp.json: invalid JSON — LSP features broken" |
| File does not exist | OK | "No .lsp.json (LSP not configured)" |

Add result to `checks`.

## Phase 7: Plugin Version

Read the plugin manifest at `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.

| Result | Status | Detail |
|--------|--------|--------|
| File exists and parseable | OK | "ouroboros v{version}" |
| File missing or invalid | WARN | "plugin.json not found or invalid" |

Add result to `checks`.

## Phase 8: Report

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
- **Reference**: `skills/core/validation.md` for hook/settings validation patterns; `hooks/hooks.json` for hook schema
- **Instructions**: "Analyze these health check failures. For each FAIL: identify the root cause, check if related files exist or are misconfigured, and suggest a concrete fix command or edit."
- **Expected output**: Per-FAIL analysis with fix suggestions

### Recommendations

Generate context-aware recommendations based on findings:

| Condition | Recommendation |
|-----------|----------------|
| Any FAIL | Present researcher's fix suggestions. Ask user: "Apply suggested fixes? (y/n)" |
| Codex WARN | "Install Codex CLI for multi-model evaluation: `npm i -g @openai/codex`" |
| Settings WARN | "Add missing patterns to `.claude/settings.json` for smoother workflow." |
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
