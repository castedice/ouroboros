# Sandbox And Threads

This reference defines execution-scope choices for routed external model runs.

## Sandbox Policy

Default to `read-only` for evaluation, research, brainstorming, review, comparison, and any flow where the host writes files locally.
Use `workspace-write` only when the external model itself is intentionally permitted to edit files.
Treat write permission as a scope decision, not as a convenience flag.
If the correct write root is an isolated worktree, enter that worktree before granting write access.
When repository policy or artifact naming must stay under host control, keep the external model read-only and let the host perform writes.

## Thread Modes

Use a fresh session for one-shot relay calls with no expected follow-up.
Use a saved thread when the caller may ask the external model to refine, repair, or extend the same output.
Use one thread per SWE stage in direct relay flows.
Do not reuse one thread across unrelated commands, components, or stages.

## Starting A Thread

On the first turn, call `scripts/codex-relay.sh` without `--thread-id`.
Add `--save-thread <file>` when a future resume is plausible.
Persist the saved thread artifact alongside the raw and parsed output files when later recovery may need it.
Treat the first-turn prompt as the contract for that thread's scope.

## Resuming A Thread

Resume only when the new prompt is a focused delta on the same task.
Resume prompts should name the exact missing section, failed test, or unmet acceptance point instead of restating the full problem from scratch.
Do not rely on resume to change sandbox or write scope.
If execution scope must change, start a fresh thread with a new prompt contract.
If context drift is suspected, abandon the old thread and start a fresh one rather than repairing the history manually.

## Direct Relay Pattern

The Director or host command uses multi-turn threads when it inspects each external response between turns.
The host owns file reads, writes, validation, and test runs in the current pattern.
The external model provides reasoning and proposed artifact content, but the host validates and materializes the result.
Thread continuity matters inside a stage because follow-up prompts reference prior gaps or failures directly.

## Practical Defaults

Use one-shot `read-only` relays for most current `--multi` command flows.
Use saved threads only when the caller has a real second-turn path.
Use direct-write sessions sparingly and only inside an already-safe root.
