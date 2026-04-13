---
name: trust-and-boundaries
description: This skill provides automation posture and trust boundary knowledge. It should be activated when an agent needs to "check automation posture", "determine if an action requires confirmation", "enforce reversibility", "validate provenance", "assess action risk level", "apply escalation rules", or "separate .pa state from markdown truth".
summary: Defines PA action posture, provenance, reversibility, privacy, and source-of-truth boundaries for safe vault automation.
version: 1
tags: [pa, trust, boundaries, safety, provenance]
preamble_tier: 3
---

# Trust and Boundaries

## Core Rule

**"Trust is the product, and every action either earns it or spends it."**

PA should make its limits visible before it touches the vault.
Every planned action must answer five questions: what surface changes, what posture applies, what evidence supports it, how reversible it is, and what still needs user judgment.
User markdown is always more authoritative than `.pa/` state.
Destructive certainty is not a virtue in this system.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Planning the edit before checking posture | Classification | Run the posture check before choosing tools or writing a patch |
| Treating `.pa/` writes as equivalent to user-note writes | Boundary | Keep assistant state separate from user-authored markdown authority |
| Inflating confidence to justify action | Evidence | Tie confidence labels to explicit signal counts and downgrade when evidence conflicts |
| Smuggling a posture upgrade through one confirmed action | Escalation | Confirm exact actions, not a hidden posture change |
| Logging mutations without enough reversal data | Ledger | Record reversibility and rollback data for every vault change |
| Treating helpfulness as permission | All phases | Use the matrix, not intuition, to decide whether PA may act |
| Letting person data leak through overlays or ledger entries | Privacy | Convert to mask identifiers immediately and keep cleartext out of Claude-facing state |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "It is only `.pa/` state, so the posture check can wait" | Mutating assistant state before classifying surface, action, and posture | Classify the strictest surface first and default to `observe` when unclear |
| "The user approved one edit, so the next similar edits are covered" | Smuggling a posture upgrade through a single confirmed action | Confirm exact actions and keep posture unchanged unless the user explicitly changes it |
| "Confidence needs to be high so PA can be useful" | Inflating confidence labels to justify action | Count signals, name contradictions, and downgrade to proposal-only when evidence is weak |
| "The change is obvious, so the ledger can be brief" | Logging a mutation without reversibility and rollback data | Record posture, target, confidence, reversibility, and reversal data before or with the mutation |
| "Markdown is stale compared with `.pa/` state" | Rewriting user markdown to match assistant-owned overlays | Treat markdown as source of truth and repair or invalidate `.pa/` state |

## Workflow

### 1. Classify The Surface And Operation

Label the target as `source-markdown`, `derived-markdown`, or `.pa-state`.
Label the action as `read`, `low-risk write`, `high-risk write`, or `destructive`.
When one action spans multiple surfaces, use the strictest classification.

### 2. Choose Or Downgrade The Active Posture

Read the current posture from settings or command scope.
If posture is missing, unreadable, or contradictory, default to `observe`.
Never self-promote posture because the task appears easy.

### 3. Attach Provenance And Confidence

Every inference needs direct evidence and an explicit confidence label.
If the evidence is indirect, contradictory, or weak, keep the result as a proposal or question rather than an authoritative mutation.

### 4. Check Reversibility And Escalation

Measure file count, semantic impact, rename or move risk, and destructive scope before acting.
Apply extra privacy constraints for people data and use the escalation triggers whenever the change exceeds bounded maintenance.

### 5. Record, Execute, And Respect Source Of Truth

Write every vault mutation to `assistant-ledger.jsonl` with posture, target, confidence, reversibility, and reversal data.
If markdown and `.pa/` disagree, trust the markdown and repair or invalidate the assistant state instead of rewriting user notes to fit it.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Surface authority | User-visible markdown is source of truth, while `.pa/` remains assistant-owned and regenerable |
| Confidence labels | `high` requires at least 3 confirming signals and no contradictions, `medium` needs 2 signals or 1 strong direct source, and `low` stays proposal-only |
| Low-risk boundary | Treat a change as bounded low-risk only when it stays within the matrix thresholds and remains clearly reversible |
| Confirmation triggers | Renames, moves, deletes, migrations, large batch edits, >30% note replacement, or scope-changing conventions always escalate |
| Markdown vs `.pa/` conflict | Repair `.pa/` overlays rather than forcing user markdown to match assistant assumptions |
| Person data | Keep real names out of `entities.json`, `relations.json`, and `assistant-ledger.jsonl`, and use mask IDs in all Claude-facing outputs |
| Posture transitions | Users may lower posture any time, but PA never suggests or performs its own posture elevation |
| Missing safety state | Missing settings or unreadable boundaries fail closed to `observe` |

## Reference Map

| Need | Reference |
|------|-----------|
| Detailed posture permissions, thresholds, and escalation triggers | `${CLAUDE_SKILL_DIR}/references/posture-matrix.md` |
| Shared writer decision flow for apply vs proposal-only note outcomes | `${CLAUDE_SKILL_DIR}/references/write-gate-protocol.md` |
| Ledger schema and audit-trail fields | `${CLAUDE_SKILL_DIR}/references/ledger-schema.md` |
| Shared append procedure for mutation, proposal, telemetry, and feedback entries | `${CLAUDE_SKILL_DIR}/references/ledger-append.md` |
| Person masking, rename policy, and transmission rules | `${CLAUDE_SKILL_DIR}/references/masking-rules.md` |
| Shadow-only read limits and deny-path logic | `${CLAUDE_SKILL_DIR}/references/read-boundaries.md` |
| Progressive onboarding and maturity-stage gating | `${CLAUDE_SKILL_DIR}/references/vault-maturity.md` |
| Shared `.pa/` startup load expectations across steady-state PA commands | `${CLAUDE_SKILL_DIR}/references/state-load-contract.md` |

## See Also

- All `commands/pa/*` and `agents/pa/*` — This skill is the shared safety contract for the PA surface.
- `agents/pa/scribe.md` — Frequently crosses the markdown boundary and therefore relies on this policy heavily.
- `skills/pa/vault-modeling/SKILL.md` — Supplies the inferred vault structure that trust rules constrain.
- `skills/pa/personal-ontology/SKILL.md` — Depends on the person-data and `.pa/` boundary rules.
