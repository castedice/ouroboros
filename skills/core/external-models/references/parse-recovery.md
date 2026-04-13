# Parse Recovery

This reference defines the recovery path from raw Codex JSONL output to caller-usable payloads.

## Recovery Layers

Layer 1 is `scripts/codex-relay.sh`, which runs the external command, preserves raw JSONL, and invokes mechanical parsing.
Layer 2 is `scripts/codex-parse.sh`, which extracts `thread_id`, plain text, or the largest JSON object from the last `agent_message`.
Layer 3 is caller-level salvage, where the host reads the raw artifact and reconstructs full or partial output.
Keep the layers separate so scripts stay mechanical and callers stay task-aware.

## Success Path

When `scripts/codex-relay.sh` exits `0`, treat the parsed `--output` or `--text-output` file as authoritative.
If `--save-thread` was requested, treat the saved thread file as authoritative for later resume calls.
If `--meta` was requested, treat the sidecar metadata file as auxiliary transport context rather than as the payload.
Preserve the `.raw` file even on success when later debugging or comparison may matter.

## Parse Failure Path

When `scripts/codex-relay.sh` exits `1`, execution succeeded but structured extraction failed.
Read the `.raw` file before deciding to skip the external branch.
Attempt re-parse first if the failure may have been transient or file-related.
If the raw response contains partial structured data, salvage the recoverable fields instead of forcing all-or-nothing parsing.
Record partial recovery explicitly so downstream integration knows what is missing.

## Execution Failure Path

When `scripts/codex-relay.sh` exits `2`, treat the branch as an execution failure rather than a malformed payload.
Common causes are timeout, missing CLI, empty output, invalid helper arguments, or resume failures.
The caller decides whether to continue in single-model mode, retry later, or trip a circuit breaker.

## What `codex-parse.sh` Actually Does

The parser walks JSONL events line by line and ignores malformed non-JSON lines.
It records the `thread_id` from the `thread.started` event when present.
It accumulates every `agent_message` text payload it can find.
For `--json` mode it inspects the last `agent_message` and extracts the largest valid JSON object inside it.
For text mode it prints the concatenated `agent_message` payloads.

## Parallel Recovery

When manifest-backed fan-out detects a missing parsed file, try `scripts/parallel.sh recover` before discarding the branch.
Recovery first reparses the sibling `.raw` file when it exists.
Transcript scraping is the last resort and should be treated as lower-confidence than raw-file recovery.

## Caller Responsibilities

Keep schema validation at the caller level because only the caller knows which fields are mandatory for the phase.
Allow partial recovery when the integration mode can tolerate it.
Skip the branch only after the raw artifact yields no usable payload.
