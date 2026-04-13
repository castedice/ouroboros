---
name: external-models
description: This skill governs external model execution after routing has already selected the model and integration mode, and it should be activated when a command or agent needs to assemble a relay prompt, verify Codex CLI availability, choose a sandbox, start or resume a thread, recover malformed JSONL output, strip completion status metadata before parsing, or coordinate fan-out and fan-in collection.
summary: Handles external model execution mechanics, relay assembly, sandbox selection, thread continuity, parse recovery, and fan-out collection.
version: 1
tags: [core, external-models, relay, sandboxing, parse-recovery]
preamble_tier: 3
---

# External Models

## Core Rule

Use this skill only after routing has already decided that an external model should run.
Routing owns task classification, stake, model choice, and integration mode.
This skill owns execution mechanics, prompt transport, session continuity, parse recovery, and collection discipline.
Default to `scripts/codex-relay.sh` for one-shot relay work.
Use direct relay plus `codex exec resume` when the caller needs iterative follow-up inside the same external thread.
Keep relay prompts neutral by templating role and response shape only.
Insert task content, criteria, and methodology verbatim unless a consumer-specific template explicitly says otherwise.
Default to `read-only` execution.
Let the host command or Director own file writes unless a prepared write scope explicitly authorizes external mutation.

## Gotchas

Re-deciding model choice inside the executor duplicates routing and creates drift.
Summarizing Section 2 or Section 3 content biases the external model and weakens independence.
Starting background jobs before the relay file is finalized can send inconsistent inputs to different branches.
Using `workspace-write` because it is available instead of because it is required expands risk without benefit.
Resuming the wrong thread carries stale context into a new task and is harder to notice than a parse failure.
Assuming resume can change sandbox or write scope is wrong because thread continuity should preserve execution scope.
Reading assistant stdout instead of the parsed `--output` file can discard the authoritative payload on success.
Deleting or ignoring the `.raw` file removes the recovery path when JSON extraction fails.
Letting the terminal completion block reach JSON or section parsers causes false extraction failures.
Treating circuit breaking as a helper-script concern is wrong because the caller owns failure counts across runs.

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "Routing probably picked the right model, but I should double-check" | Reopening task classification or model selection inside the executor | Treat the caller's routing decision as fixed and execute the transport contract |
| "Workspace-write is available, so it is harmless" | Granting external mutation without an explicit prepared write scope | Use read-only relay unless the caller intentionally authorized direct edits inside the correct root |
| "The parsed file is empty, so the run failed" | Discarding the raw JSONL recovery artifact | Attempt parse recovery from the `.raw` file before reporting execution failure to the caller |

## Workflow

Follow this six-step workflow whenever an external model is involved.

### 1. Confirm The Execution Contract

Start from the caller's existing routing decision rather than reopening model selection.
Identify whether the consumer needs a one-shot relay, a background fan-out branch, or a mediated multi-turn loop.
Confirm the expected output contract before prompt assembly.
Keep integration strategy outside this skill unless the caller needs only the transport boundary clarified.

### 2. Check CLI And Helper Availability

Verify `codex` availability and version once per command execution or once per team-routing setup.
Confirm that `scripts/codex-relay.sh`, `scripts/codex-parse.sh`, and `scripts/parallel.sh` are present before depending on them.
If `codex` is unavailable, degrade to the caller's single-model fallback instead of aborting routine flows.
If a routed direct relay cannot run without the CLI, escalate immediately rather than pretending the external branch completed.

### 3. Assemble The Relay

Use the four-part relay shape of Role, Content, Methodology or Criteria, and Response Format.
Keep Role and Response Format templated and task-generic.
Insert Content and Criteria or Methodology verbatim from gathered artifacts or reference files.
Wrap untrusted external source material in structural markers when the consumer handles web or imported content.
Save the assembled prompt to a deterministic `.tmp/` path before any external branch starts.

### 4. Choose Sandbox And Thread Mode

Use `read-only` for evaluation, research, review, brainstorming, comparison, and any relay where the host owns writes.
Use `workspace-write` only when the external model itself is intentionally allowed to modify files inside the already-correct workspace or worktree.
Start a fresh thread for a new task, a new artifact target, or a changed execution scope.
Resume a thread only when the next prompt is a focused follow-up on the same external task.
Persist the `thread_id` on the first turn whenever iterative follow-up is plausible.

### 5. Invoke And Persist Artifacts

For one-shot relays, call `scripts/codex-relay.sh` with the prompt file, reasoning effort, sandbox, and output path.
Use `--output` for JSON-first consumers and `--text-output` for markdown artifact consumers.
`--meta` is auto-enabled with `--output` or `--text-output`, so thread metadata for resume is always preserved.
For iterative loops, save the first turn's thread id and reuse it through resume calls with targeted delta prompts.
Preserve the parsed output, raw JSONL, and optional thread-id artifact for every run.
Treat the parsed `--output` file as authoritative on success and the `.raw` file as authoritative for recovery.

### 6. Recover, Collect, And Hand Off

Interpret exit `0` as a parsed success, exit `1` as parse recovery, and exit `2` as execution failure.
Use `scripts/parallel.sh init` and `collect` around fan-out work so missing branches are visible before integration.
Attempt `scripts/parallel.sh recover` or direct raw-file salvage before discarding a parse-failed result.
Strip any trailing completion status block from host-agent outputs before JSON parsing, section extraction, file capture, or score extraction.
Hand the recovered payload back to the caller in the format the caller already expects.

## Decision Rules

Use stateless relay execution when the caller wants machine-readable JSON and no follow-up turns.
Use direct relay plus resume loops when the host must inspect each turn, run tests, or request targeted revisions.
Use a fresh thread when the task changed materially, the target artifact changed, or the sandbox or write scope should change.
Use resume only for follow-up questions about the same task in the same execution scope.
Save thread ids whenever a quality gate, test loop, or stage review may require a second turn.
Use `read-only` for evaluation, research, brainstorming, review, comparison, and most generation analysis passes.
Use `workspace-write` only when the external model is explicitly trusted to edit inside the prepared root and the caller wants direct mutation rather than mediated writes.
Prefer mediated writes through the host or Director when repository policy, artifact naming, or test orchestration need local control.
Request `--output` for JSON-first consumers, `--text-output` for markdown artifacts, and treat parse failure as a recovery path rather than an automatic skip.
Treat execution failure as a caller-level policy decision that may lead to fallback, skip, or circuit breaking.
Initialize `scripts/parallel.sh` manifests before multi-branch execution and collect gaps before any merge, cherry-pick, or consensus step.
Strip only the final completion block from host outputs so literal examples earlier in the response remain intact.
Do not append or request the completion block in strict JSON relay channels.
If you still need to decide whether an external model should run at all, return to `skills/core/routing/SKILL.md`.

## Reference Map

Read [`cli-contracts.md`](${CLAUDE_SKILL_DIR}/references/cli-contracts.md) for the `codex`, `codex-relay.sh`, `codex-parse.sh`, and `parallel.sh` execution surfaces.
Read [`relay-assembly.md`](${CLAUDE_SKILL_DIR}/references/relay-assembly.md) for the four-section relay construction rules and current template sources.
Read [`sandbox-and-threads.md`](${CLAUDE_SKILL_DIR}/references/sandbox-and-threads.md) for sandbox selection, thread persistence, and resume boundaries.
Read [`parse-recovery.md`](${CLAUDE_SKILL_DIR}/references/parse-recovery.md) for raw artifact handling, mechanical parse rules, and caller-level salvage.
Read [`parallel-fanout.md`](${CLAUDE_SKILL_DIR}/references/parallel-fanout.md) for manifest-backed fan-out and fan-in execution across current command consumers.
Read [`direct-relay-pattern.md`](${CLAUDE_SKILL_DIR}/references/direct-relay-pattern.md) for the SWE specialist direct relay loop used by routed stages.
Read [`completion-status-handling.md`](${CLAUDE_SKILL_DIR}/references/completion-status-handling.md) for terminal block stripping rules in parse-heavy callers.

## See Also

Use `skills/core/routing/SKILL.md` when the unresolved question is which model or integration mode to use.
Use `skills/core/collaboration/SKILL.md` when the unresolved question is controller and executor ownership after routing.
Current execution-heavy consumers include `commands/core/evaluate.md`, `commands/core/research.md`, `commands/core/generate.md`, `commands/core/absorb.md`, `commands/core/brainstorm.md`, `commands/core/upgrade.md`, `commands/swe/ship.md`, `commands/swe/tune.md`, and routed stages in `commands/swe/spiral.md`.
This skill keeps transport, recovery, and session mechanics together so routing can stay focused on decision quality.
