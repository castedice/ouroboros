# Invocation Protocol — CLI Basics

This reference covers the CLI assumptions, invocation patterns, and environment checks for external model routing.

## CLI Version Baseline

Record the CLI versions this protocol was tested against.
When invocation fails unexpectedly, check version first because CLI flags change frequently.

| CLI | Tested Version | Install | Check Version | Last Verified |
|-----|---------------|---------|---------------|---------------|
| Codex CLI | v0.118.0 (rust) | `npm install -g @openai/codex` | `codex --version` | 2026-04-06 |

Available models include `gpt-5.4`, `gpt-5.3-codex-spark`, `gpt-5.1-codex-max`, `gpt-5.2-codex`, `gpt-5.2`, and `gpt-5.1-codex`.

## CLI Invocation Patterns

### Codex CLI

```bash
echo 'PROMPT_TEXT' | codex exec --json -
codex exec --json "PROMPT_TEXT"
echo 'PROMPT_TEXT' | codex exec --json -m gpt-5.4 -
echo 'PROMPT_TEXT' | codex exec --json -c model_reasoning_effort="high" -
echo 'PROMPT_TEXT' | codex exec --json --sandbox read-only -
echo 'PROMPT_TEXT' | codex exec --json -m gpt-5.4 -c model_reasoning_effort="high" --sandbox read-only -
echo 'PROMPT_TEXT' | codex exec --json -C /path/to/repo --sandbox workspace-write -
echo 'PROMPT_TEXT' | codex exec --json --skip-git-repo-check -
echo 'PROMPT_TEXT' | codex exec --json --add-dir /extra/writable/path -
echo 'FOLLOW_UP' | codex exec resume --json {thread_id} -
```

The initial `codex exec` call returns a `thread.started` event containing `thread_id`.
Resume inherits the sandbox mode from the original session.

### Additional Flags (v0.118.0+)

| Flag | Purpose |
|------|---------|
| `--skip-git-repo-check` | Run outside a git repository |
| `--add-dir <DIR>` | Additional writable directory alongside workspace |
| `-o, --output-last-message <FILE>` | Write the agent's last message to a file |
| `--full-auto` | Convenience alias for `--sandbox workspace-write` with auto-approve |
| `--ephemeral` | Do not persist session files to disk |
| `-p, --profile <PROFILE>` | Use a named config profile from `config.toml` |
| `--enable/--disable <FEATURE>` | Toggle feature flags |

### Reasoning Effort Levels

| Level | Use Case | Speed |
|-------|----------|-------|
| `low` | Quick checks or trivial tasks | Fastest |
| `medium` | Default interactive coding | Balanced |
| `high` | Complex analysis or evaluation | Slower |
| `xhigh` | Maximum deliberation for the hardest tasks | Slowest |

Use `high` by default for ouroboros evaluation tasks.
Use `xhigh` for high-stake decisions.

### Timeout And Exit Codes

The default timeout is 300 seconds and can be overridden by `codex-relay.sh`.
Generous timeouts do not slow fast tasks because the command returns as soon as the process exits.

| Code | Meaning | Action |
|------|---------|--------|
| `0` | Success | Parse output |
| Non-zero | Error | Log warning and skip the model |

## CLI Availability Detection

Before invoking external models, verify installation:

```bash
which codex 2>/dev/null && codex --version || echo "codex:unavailable"
```

Detection runs once per command execution.
Store the result as boolean availability plus a version string for debugging.

Messaging on unavailability:

- If `--multi` was requested but Codex is missing: `Codex CLI not found. Proceeding with single-model (Claude only).`
- If Codex is available: `Codex CLI v{version} detected. Multi-model evaluation will use Claude + Codex.`

## Graceful Degradation

| Available Models | Behavior | Report Label |
|-----------------|----------|-------------|
| Claude + Codex | Bilateral consensus | `Multi-model (2)` |
| Claude only | Standard single-model flow | `Single-model (Codex unavailable)` |

External models are additive.
Claude always completes its own evaluation path even if every external model fails.

## Settings Requirements

Multi-model use requires Bash permission for Codex invocations.
Typical allow-list entries include `Bash(which codex)`, `Bash(codex *)`, and `Bash(echo * | codex *)`.
