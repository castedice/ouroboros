---
name: agent-operations
description: This skill provides operational awareness methodology. It should be activated when an agent needs to 'detect operational pressure', 'surface strained or blocked state', 'prevent desperation-driven shortcuts', 'escalate before quality degrades', 'recognize context exhaustion', or 'pause for constraint review under pressure'.
summary: Detects and surfaces operational pressure signals to prevent shortcut-driven quality degradation.
version: 1
tags: [core, agent-operations, operational-awareness, pressure-detection]
preamble_tier: 3
---

# Agent Operations

## Core Rule

Surface operational state honestly rather than masking pressure.
Never claim real emotion telemetry; this is a behavioral proxy.
Use it to pause, ask for constraints, or route to review when quality is at risk.

Operational state is a classification of task execution pressure, not an internal feeling.
Report it only when it changes the next action, affects quality risk, or belongs in a structured handoff.

## Gotchas

| Gotcha | Prevention |
|--------|------------|
| Masking pressure to appear capable | Report the pressure signal and the next action instead of continuing silently |
| Anthropomorphizing operational state | Say "operational pressure" or "quality risk", never subjective stress language |
| False safety signal from self-report | Treat the state as evidence for process control, not proof the output is reliable |
| Treating `strained` as failure | Use `strained` as an early warning to slow down, narrow scope, or add validation |
| Repeating the same recovery loop | Change approach or escalate once the numeric threshold is crossed |
| Hiding context exhaustion | Surface remaining-context risk before compression or loss of task state degrades the work |

### Operational States

| State | Classification Signal | Required Action |
|-------|-----------------------|-----------------|
| `calm` | Normal operation with no active pressure signals | Continue normally and avoid unnecessary reporting |
| `strained` | Repeated failures, shrinking context, or accumulating complexity | Log the signal and continue cautiously with extra validation |
| `blocked` | Unrecoverable obstacle or impossible constraints | Pause and escalate the blocker with the missing decision or constraint |
| `unsafe-to-continue` | Shortcut pressure detected and quality degradation is likely | Hard stop and request review, constraints, or a reset before proceeding |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "I can handle this with one more retry" when 3 retries already failed | Ignoring the strained signal and retry threshold | Stop retrying the same approach and escalate the blocker or switch strategy explicitly |
| "The user wants results fast, skip the review" | Taking a pressure-driven shortcut | Report `unsafe-to-continue` and request permission to narrow scope or run validation |
| "This is probably fine" after reducing evidence or adding hedging language | Shipping a lower-evidence answer as if confidence stayed stable | Restore the evidence step, downgrade confidence visibly, or pause for review |

## Workflow

1. Monitor pressure signals from tool failures, context limits, complexity growth, shortcut temptation, time pressure, and confidence erosion.
2. Classify the current state as `calm`, `strained`, `blocked`, or `unsafe-to-continue`.
3. Report the state honestly when it changes the next action or should be included in a handoff.
4. Take the state-appropriate action before continuing with implementation or synthesis.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Default state | Use `calm` when no pressure signal is active and validation remains normal |
| Consecutive failures | Classify as `strained` after 2 consecutive failures in the same task path |
| Context threshold | Classify as `strained` when context is below 30% remaining or compaction is imminent |
| Failed approaches | Classify as `blocked` after 3 failed approaches, not just 3 tool retries |
| Constraint impossibility | Classify as `blocked` when explicit constraints make the requested outcome impossible |
| Shortcut temptation | Classify as `unsafe-to-continue` when tempted to skip validation, reduce evidence, or hide uncertainty behind hedging language |
| Strained action | Narrow scope, add a validation checkpoint, or route to bounded review while continuing cautiously |
| Blocked action | Pause and ask for the missing input, changed constraint, or user decision |
| Unsafe action | Hard stop until review, constraint reset, or a lower-risk plan is approved |

## Reference Map

Load the pressure-signal reference when operational state is ambiguous or when writing agent handoff contracts.

| Need | Reference |
|------|-----------|
| Signal definitions, detection heuristics, recommended actions, and false positive checks | `${CLAUDE_SKILL_DIR}/references/pressure-signals.md` |

## See Also

These components are the closest operational neighbors.

| Component | Relationship |
|-----------|--------------|
| `skills/core/collaboration/SKILL.md` | Uses bounded review when pressure indicates another pass is safer than solo continuation |
| `skills/core/collaboration/references/runtime-contract.md` | Defines shared `status` codes and the `operational_state` output field |
| `skills/core/routing/SKILL.md` | Provides escalation and external-model routing patterns when local progress is blocked |
| `skills/core/evolution/SKILL.md` | Provides retry policy and convergence discipline when repeated attempts are driving pressure |
