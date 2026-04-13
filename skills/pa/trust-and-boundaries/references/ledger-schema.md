# Assistant Ledger Schema — Audit Trail for PA Actions

> Purpose: Reference for `trust-and-boundaries` skill — defines the append-only JSONL schema for `.pa/assistant-ledger.jsonl`. This reference is standalone. For posture rules, see `skills/pa/trust-and-boundaries/SKILL.md`.

## Scope

This reference defines the schema, logging points, and integrity rules for the PA assistant ledger. The ledger records every PA write action (including proposals and blocks) for audit, trust calibration, and user feedback tracking.

## File Location

`{vault}/.pa/assistant-ledger.jsonl` — one JSON object per line, append-only.

## Schema

Each line is a JSON object with these fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ts` | string (ISO 8601) | yes | Timestamp of the event |
| `run_id` | string (UUID segment) | yes | Groups related events in one command invocation |
| `command` | string | yes | Command that triggered the action (`capture`, `draft`, etc.) |
| `agent` | string | no | Agent that performed the work (`scribe`, `curator`, etc.) |
| `action` | string | yes | Action type (see Action Types below) |
| `status` | string | yes | `completed`, `proposed`, `blocked`, `failed` |
| `posture` | string | yes | Active posture at time of action (`observe`, `propose`, `apply-low-risk`, `operate`) |
| `risk_class` | string | yes | `low-risk write`, `high-risk write`, `destructive` |
| `target_paths` | string[] | yes | Vault paths affected (empty array for no-note outcomes) |
| `confidence` | string | no | `high`, `medium`, `low`, `none` |
| `why` | string | no | Brief rationale for the action (1-2 sentences) |
| `reversible` | boolean | yes | Whether the action can be undone |
| `reversal_hint` | string | no | How to undo (e.g., "delete notes/2026-03-16 1430.md") |
| `content_hash_before` | string | no | SHA-256 of target file before modification (revisions only) |
| `content_hash_after` | string | no | SHA-256 of target file after modification |
| `user_feedback` | string | no | `accepted`, `rejected`, `modified` — added as a follow-up event |

### Context Telemetry (Optional)

Commands may record which `.pa/` state files were loaded and used during execution:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `state_files_loaded` | string[] | no | Files read during Phase 2 |
| `state_files_used` | string[] | no | Files whose content influenced the output |
| `estimated_context_chars` | number | no | Approximate character count of loaded state |

## Feedback Recording Contract

Write-capable commands that produce proposals must record user feedback after presentation.

### When to Record

Record feedback only when the command outcome was `proposed` (not `completed`, `failed`, or `blocked`).
If the conversation ends without a response, write no feedback entry — absence is neutral.

### Feedback Entry

Append a follow-up entry to `assistant-ledger.jsonl` sharing the same `run_id` as the original proposal:

| Field | Value |
|-------|-------|
| `action` | `feedback` |
| `user_feedback` | `accepted`, `rejected`, or `modified` |
| `feedback_tags` | Optional array: `too-many`, `not-now`, `wrong-target`, `too-broad`, `helpful` |

### Command Integration

After the presentation phase, if the outcome was `proposed`:
1. Ask the user: "이 제안을 적용할까요? (적용/거절/수정)"
2. Map response to `user_feedback` value.
3. Append the feedback entry.
4. In unattended mode (scheduler/autopilot), skip feedback recording.

### Commands That Record Feedback

| Command | Feedback Phase | Trigger Condition |
|---------|---------------|-------------------|
| `draft.md` | Phase 9 | outcome = `proposed` |
| `capture.md` | Phase 9 | outcome = `proposed` or `proposal-only` |
| `link.md` | Phase 6 | suggestions presented |
| `day.md` | Phase 6 | morning/evening produced vault write proposal |

## Action Types

| Action | When Logged | Status |
|--------|------------|--------|
| `note_created` | New note written to vault | `completed` |
| `note_revised` | Existing note section modified | `completed` |
| `note_appended` | Section appended to existing note | `completed` |
| `proposal_generated` | Note content produced but not written (posture block or low confidence) | `proposed` |
| `posture_blocked` | Action downgraded or blocked by posture gate | `blocked` |
| `capture_triaged` | Curator completed triage (even if no note created) | `completed` |
| `no_note` | Input had no capturable content | `completed` |
| `response_presented` | Read-only answer or report presented with no vault mutation | `completed` |
| `failed` | Agent error, QMD failure, or timeout | `failed` |
| `feedback` | User accepted, rejected, or modified a prior proposal | `completed` |

## 4-Point Logging

Commands log at these points:

1. **Proposal/preview creation** — when rendered content is generated (even if not written)
2. **Posture block/downgrade** — when posture prevents direct write
3. **Successful mutation** — when a note is actually written or modified
4. **Failure/abort** — when an error prevents completion

A single command invocation may produce 1-4 ledger entries sharing the same `run_id`.
Read-only commands may append a single `response_presented` entry when they need audit or context-telemetry coverage.

## Integrity Rules

- **Append-only**: Never modify or delete existing entries. Corrections are new entries linked by `run_id`.
- **Single writer**: Only the calling command appends entries, never agents. This prevents race conditions.
- **Log after agent return**: The command logs after receiving the agent's result, not during agent execution.
- **Feedback as follow-up**: User acceptance/rejection of a proposal is a new `feedback` entry with the same `run_id` as the original proposal.
- **No sensitive content**: The ledger records metadata (paths, actions, confidence), not note content. The `why` field should be a brief rationale, not a content summary.

## Example Entries

```jsonl
{"ts":"2026-03-16T14:30:00+09:00","run_id":"a1b2c3","command":"capture","agent":"curator","action":"note_created","status":"completed","posture":"apply-low-risk","risk_class":"low-risk write","target_paths":["notes/2026-03-16 1430.md"],"confidence":"high","why":"Single idea capture routed to timestamp-note","reversible":true,"reversal_hint":"delete notes/2026-03-16 1430.md","content_hash_after":"sha256:abc123"}
{"ts":"2026-03-16T15:00:00+09:00","run_id":"d4e5f6","command":"draft","agent":"scribe","action":"posture_blocked","status":"blocked","posture":"propose","risk_class":"low-risk write","target_paths":["notes/design-patterns.md"],"confidence":"medium","why":"Posture is propose — presenting as proposal only","reversible":true}
{"ts":"2026-03-16T15:01:00+09:00","run_id":"d4e5f6","command":"draft","action":"proposal_generated","status":"proposed","posture":"propose","risk_class":"low-risk write","target_paths":["notes/design-patterns.md"],"confidence":"medium","why":"New note proposal for user review","reversible":true}
```
