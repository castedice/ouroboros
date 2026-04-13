# Runtime Contract — Command-to-Agent Delegation

This reference defines the standard delegation contract between command orchestrators and agent subprocesses.
Every command that dispatches agent calls should follow this contract shape unless a module-specific extension overrides a field.

## Universal Rules

| Rule | Requirement |
|------|-------------|
| No hidden context | Pass artifact paths and inline file contents. Never rely on conversation memory as hidden context. |
| Named return payload | Agent returns a structured payload with explicitly named fields, not prose. |
| File ownership | The command writes all files and mutates state. The agent never writes files directly. |
| Explicit delegation form | Every call uses `Agent(subagent_type: "ouroboros:{module}:{agent}")` with the fully qualified name. |
| Context per call | Every call includes the required context fields defined by the command's contract, not assumed from prior calls. |

Treat the command as the source of truth for orchestration state, artifact persistence, and side effects.
Treat the agent as a bounded reasoning subprocess that returns data the command can parse and act on.

## Contract Section Template

Commands should include a dedicated `## Delegation Contracts` section.
Commands with complex multi-agent flows may use `## Agent Delegation Contract` instead.

| Column | Required | Description |
|--------|----------|-------------|
| Agent | yes | Qualified agent name. |
| Phases | yes | Which command phases invoke this agent. |
| Input | yes | Artifact paths, inline contents, budget or state snapshots, and reference file paths. |
| Expected Output | yes | Named fields the agent must return in its payload. |

Use one row per agent or per phase variant when the input shape or payload fields differ materially.
When a Bash relay or external model branch exists, document it as additive evidence rather than as a replacement for the named internal agent contract.

## Standard Output Fields

These field names should be reused across modules whenever the concept applies.

| Field | Used by | Meaning |
|-------|---------|---------|
| `artifact_draft` | generators | The primary artifact content the command will write to disk. |
| `verdict` | evaluators and critics | `accept`, `revise`, or `reject`. |
| `blocking_issues` | evaluators and critics | Issues that prevent acceptance. |
| `required_revisions` | evaluators and critics | Specific changes needed for a `revise` verdict. |
| `accepted_strengths` | evaluators and critics | What passed review and should be preserved. |
| `improvements` | evaluators | Prioritized improvement list with `HIGH`, `MED`, or `LOW`. |
| `unresolved_questions` | any | Questions the agent cannot resolve alone. |
| `operational_state` | any | Behavioral pressure classification: `calm`, `strained`, `blocked`, or `unsafe-to-continue`. |

Add module-specific fields only when downstream parsing needs them.
Prefer a short stable schema over freeform narrative even when the human-facing report includes prose.
Prefer stable `snake_case` field names that downstream commands can address without prose parsing.
If a field is optional, omit it deliberately or return an empty list instead of inventing a replacement name.

## Operational State

`operational_state` is a behavioral proxy for execution pressure, not emotion telemetry.
Use it to surface quality risk before retry loops, context pressure, or shortcut temptation degrade output quality.

| State | Meaning | Command Action |
|-------|---------|----------------|
| `calm` | Normal operation with no active pressure signals. | Continue normally. |
| `strained` | Repeated failures, shrinking context, or accumulating complexity. | Continue cautiously, preserve constraints, and add validation or bounded review. |
| `blocked` | Unrecoverable obstacle or explicit constraint impossibility. | Pause and escalate the blocker or missing context. |
| `unsafe-to-continue` | Shortcut pressure detected and quality degradation is likely. | Hard stop until review, constraint reset, or a lower-risk plan is approved. |

## Completion Status Codes

Every agent delegation must return a `status` field from this enum. Commands use the status to decide the next step without parsing prose.

| Status | Meaning | Command Action |
|--------|---------|----------------|
| `DONE` | Task completed successfully. All acceptance criteria met. | Proceed to next phase. |
| `DONE_WITH_CONCERNS` | Task completed but the agent flagged issues worth reviewing. | Proceed, but surface `concerns[]` to the user or the next gate. |
| `NEEDS_CONTEXT` | Agent cannot proceed without additional information. | Command supplies the requested context via `missing_context[]` and retries once. If still `NEEDS_CONTEXT`, escalate to user. |
| `BLOCKED` | Agent encountered an unrecoverable obstacle. | Command stops the current phase, surfaces `blocking_reason`, and does not retry. |

### Status Field Contract

```json
{
  "status": "DONE_WITH_CONCERNS",
  "concerns": ["Test coverage below 80% threshold"],
  "blocking_reason": null,
  "missing_context": []
}
```

- `concerns` is populated only when status is `DONE_WITH_CONCERNS`. Empty list otherwise.
- `blocking_reason` is a single string populated only when status is `BLOCKED`. Null otherwise.
- `missing_context` is populated only when status is `NEEDS_CONTEXT`. Each entry names the specific artifact, file, or question needed.

Commands that already use `verdict` (evaluators, critics) should map: `accept` → `DONE`, `revise` → `DONE_WITH_CONCERNS`, `reject` → `BLOCKED`. The `verdict` field remains for evaluator-specific semantics; `status` is the universal envelope.

## Module Extensions

Modules may add required context fields beyond the universal rules.

| Module | Additional required fields | Reason |
|--------|---------------------------|--------|
| `rnd` | `session_id`, `current_stage`, `archive_dir`, `budget.json` | Session-based stateful workflow. |
| `swe` | `depth_level`, `upstream_artifacts` | Depth-aware stage pipeline. |
| `pa` | `vault_profile`, `permission_envelope` | Vault posture governance. |
| `core` | Varies by command. | No universal session, so context stays per invocation. |

Keep extensions explicit in the command-local table instead of hiding them in phase prose.
If a command needs to override the default file-ownership rule, name the exception directly in its delegation section.

## Reusable Sub-Protocols

When a gate pattern repeats across phases, extract it into a named subsection and reference it instead of rewriting the logic.
Use the named protocol to define stop conditions, retry bounds, and the authoritative verdict source.

### Example: Critic Gate Protocol

1. Delegate the artifact and all required context to the critic.
2. If the critic returns `accept`, continue to the next phase.
3. If the critic returns `revise`, apply one bounded revision pass and rerun the same gate once.
4. If the critic still blocks after the bounded retry, stop and surface the blocker instead of looping silently.

Commands with evaluation gates such as `/evaluate` or `/evolve` should name their gate protocol in the same style.
Commands should reference that named protocol from each phase that reuses it.
