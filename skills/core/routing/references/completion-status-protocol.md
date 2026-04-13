# Completion Status Protocol

> Terminal response contract for ouroboros agents.
> The block is appended to the end of every non-JSON-only agent response.

## Terminal Block Format

Place exactly one terminal block at the end of the response, after the human-readable content.
Use this exact shape and marker spelling.

```text
<<<OUROBOROS_COMPLETION_STATUS_START>>>
STATUS: DONE
SUMMARY: Completed the requested work.
NEXT_ACTION: NONE
<<<OUROBOROS_COMPLETION_STATUS_END>>>
```

`STATUS` must be one of `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`.
`SUMMARY` must be a single-line caller-facing summary of what happened.
`NEXT_ACTION` must be a single-line caller-facing next step, or `NONE` when no follow-up is required.
Do not add any content after the end marker.
Do not add extra keys unless the caller explicitly requests them.

## Status Selection

### `DONE`

Use `DONE` when the requested work is complete and the caller can continue without intervention.
Minor notes that do not change readiness stay in the main body, not in the status.

### `DONE_WITH_CONCERNS`

Use `DONE_WITH_CONCERNS` when the requested work is complete but the caller should surface non-blocking risks, uncertainty, or follow-up checks.
Describe the concern in the main body, and use `NEXT_ACTION` to tell the caller whether to continue, review, or verify.

### `NEEDS_CONTEXT`

Use `NEEDS_CONTEXT` when progress stopped because the agent needs missing input, files, decisions, or scope clarification from the caller or user.
State the missing context in the main body, and make `NEXT_ACTION` a specific request.

### `BLOCKED`

Use `BLOCKED` when progress stopped due to an external blocker that the agent cannot resolve with more context alone.
Examples include missing tools, permissions, unavailable dependencies, failed infrastructure, or contradictory constraints.
State the blocker in the main body, and use `NEXT_ACTION` to describe the unblock condition.

## Caller Behavior

- `DONE`: Consume the payload and continue the workflow.
- `DONE_WITH_CONCERNS`: Consume the payload, surface the concern, and continue only if the concern is acceptable for the current phase.
- `NEEDS_CONTEXT`: Stop automation, ask for the missing context, and resume only after the context arrives.
- `BLOCKED`: Stop automation, preserve any partial output, and wait for an unblock action or explicit fallback decision.

## Strip Instructions For Parse-Heavy Callers

Parse-heavy callers must treat the completion block as transport metadata, not payload content.
Before JSON parsing, section extraction, file-content capture, score extraction, or regex-based parsing, strip the final block delimited by `<<<OUROBOROS_COMPLETION_STATUS_START>>>` and `<<<OUROBOROS_COMPLETION_STATUS_END>>>`.
Strip only the last matching block so earlier literal examples remain untouched.
If no terminal block is present, continue with the legacy parser unchanged.
JSON-only relay prompts and other strict machine-only channels must not include this block.
