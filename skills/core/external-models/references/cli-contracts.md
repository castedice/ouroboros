# CLI Contracts

This reference defines the helper surfaces that execute routed external model work today.

## Availability Checks

Check `codex` availability with `which codex && codex --version` before the first routed external call in a command or direct-relay session.
Store availability and version separately from any per-model failure counters.
Degrade routine command flows to Claude-only when `codex` is unavailable.
Fail fast in direct-relay flows when the external executor is mandatory for the assigned path.
Current command-level CLI checks live in `commands/core/evaluate.md`, `commands/core/brainstorm.md`, `commands/swe/ship.md`, and `commands/swe/tune.md`.
`commands/swe/spiral.md` performs a route-level probe before any specialist direct relay starts.

## `scripts/codex-relay.sh`

Use `scripts/codex-relay.sh <prompt-file> [options]` as the default one-shot relay surface.
Supported options are `--sandbox`, `--effort`, `--timeout`, `--output`, `--text-output`, `--thread-id`, `--save-thread`, `--meta`, `--raw`, and `--model`.
The helper defaults to `--sandbox read-only`, `--effort high`, and `--model gpt-5.4`.
Default timeouts are effort-sensitive at `xhigh=1800`, `high=600`, and `medium` or `low=300`.
Use `--output` when the caller expects parsed JSON.
Use `--text-output` when the caller expects markdown or plain text artifacts.
Use `--save-thread` on the first turn when follow-up is plausible.
Use `--thread-id` for resume calls on an existing external session.
`--meta` is auto-enabled whenever `--output` or `--text-output` is used, so the sidecar with `thread_id`, model, effort, and sandbox is always available for resume.
Use `--raw` only when the caller needs a non-default raw artifact path.

## `codex-relay.sh` Exit Contract

Exit `0` means execution succeeded and any requested parse step succeeded.
Exit `1` means execution succeeded but the requested text or JSON extraction failed, so the raw artifact should be recovered or inspected.
Exit `2` means execution failed because of timeout, CLI failure, empty output, invalid arguments, or environment issues.
Treat parse failure and execution failure differently at the caller level.
The helper does not own circuit breaker policy across multiple runs.

## `scripts/codex-parse.sh`

Use `scripts/codex-parse.sh <raw-jsonl-file> [--json output.json] [--thread-file thread.txt]` for mechanical extraction from JSONL.
Without flags it prints concatenated `agent_message` text to stdout.
With `--json` it extracts the largest JSON object from the last `agent_message`.
With `--thread-file` it extracts the `thread_id` from the `thread.started` event.
This parser is intentionally mechanical and should stay ignorant of caller-specific schemas.

## `scripts/parallel.sh`

Use `scripts/parallel.sh init <session_id> <expected_entries_json>` before fan-out work that writes result files.
Use `scripts/parallel.sh collect <session_id>` after fan-in to detect missing or empty result files.
Use `scripts/parallel.sh recover <session_id> <transcript_path>` when file-based collection shows gaps and the caller still wants salvage.
The manifest schema is `session_id`, `expected`, and `started_at`.
Expected entries include `idx`, `model`, and `file`.

## Operational Notes

Treat the helper default model as a fallback only because routing or the caller still owns actual model selection.
Preserve helper-generated `.raw` files even after a successful parse when later debugging or comparison may matter.
Prefer helper scripts over ad hoc shell pipelines so execution behavior stays consistent across commands.
