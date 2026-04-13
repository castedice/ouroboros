---
name: routing-methodology
description: This skill provides multi-model routing methodology. It should be activated when a command needs to "route a task to an external model", "invoke Codex CLI", "select the right model for a task", "integrate results from multiple models", "build a consensus from multi-model outputs", or "handle external model failure gracefully".
summary: Guides multi-model task routing, relay construction, external invocation, result integration, and failure recovery.
version: 1
tags: [core, routing, multi-model, consensus, failure-recovery]
preamble_tier: 4
---

# Routing Methodology

## Core Rule

If you are running as a subagent dispatched by a command, skip loading this skill.
Commands already embed the relevant methodology inline.

**"The right model for the right task."**

Claude remains the orchestrator and priority order is **Claude > Codex**.
Routing exists to choose the smallest model set that improves the task, while keeping prompt bias, parsing failures, and cost under control.
Multi-model invocation is command-level only and stays opt-in through explicit flags such as `--multi`.

## Gotchas

| Risk | Prevention |
|------|------------|
| Paraphrasing task content in the relay prompt | Relay raw content instead of Claude summaries |
| Letting one model see another model's result before scoring | Keep scoring independent and integrate only after all runs finish |
| Treating `--multi` as always better | Use single-model mode for routine or reversible work |
| Retrying failed CLI calls indefinitely | Use a circuit breaker after one failed attempt |
| Ignoring parse failures | Fall back from script parse to raw output reading to LLM-assisted extraction |
| Assuming every external CLI is installed | Check availability and degrade gracefully instead of aborting |
| Letting Claude overrate its own work | Use independent external scoring for evaluation and review tasks |
| Treating agreement as ground truth | Track disagreement reasoning and watch for systematic model blind spots |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "Multi-model is safer, so use it everywhere" | Routing routine, reversible work through unnecessary external fan-out | Classify the task and stake level, then choose the smallest model set that improves the result |
| "Claude can summarize the task better for Codex" | Paraphrasing task content in the relay prompt | Relay raw task content and template only the role and response shape |
| "Both models agree, so the answer is settled" | Treating consensus as proof without checking reasoning quality | Compare evidence and disagreement traces for shared blind spots before accepting the result |
| "The CLI failed once, so skip that branch" | Dropping an external run without parse or raw-output recovery | Follow the recovery ladder and record the failure if the branch still cannot be salvaged |
| "This is generation, so external writes will be faster" | Letting external models modify files from routing | Keep routing to model selection and hand execution mechanics to external-models or collaboration |

## Workflow

### 1. Classify The Task

Determine the category first.
Use `evaluation`, `comparison`, `decision`, `extraction`, `review`, or `generation` so the routing table can stay stable.

### 2. Assess The Stake Level

Pick `low`, `medium`, or `high` based on reversibility and impact.
Stake level controls how many models are worth involving.

### 3. Select Models From The Routing Table

Look up the category and stake pairing in `${CLAUDE_SKILL_DIR}/references/routing-table.md`.
Prefer Codex coding models for code-heavy work and `gpt-5.2` for non-code external perspectives.

### 4. Construct The Prompt Relay

Build the external prompt with the relay protocol.
Only the role and response-shape sections should be templated by Claude.
Task content must stay raw to reduce framing bias.

### 5. Invoke External Models

Use `scripts/codex-relay.sh` for execution, timeout handling, and mechanical fallback.
If the script fails, read the raw output artifact directly and recover via the parsing strategy instead of silently discarding the run.

### 6. Integrate Results

Choose cherry-pick, majority consensus, unanimous consensus, or synthesis based on the task type.
Integration happens after independent scoring or review, never during collection.

## Decision Rules

### Category And Stake

| Category | Typical mode |
|----------|--------------|
| Evaluation | Independent consensus |
| Comparison | Independent consensus |
| Decision | Two-way debate or synthesis |
| Extraction | Cherry-pick or single external |
| Review | Adversarial external review |
| Generation | Host-only by default |

| Stake | Use when | Model count |
|-------|----------|-------------|
| Low | Reversible, exploratory, or routine | 1 |
| Medium | Stored, recorded, or influential | 2 |
| High | Architectural, irreversible, or user-facing | 2 with high reasoning |

### Routing Defaults

| Task | Primary external | Reasoning |
|------|------------------|-----------|
| Static evaluation | Codex `gpt-5.4` | `xhigh` |
| Code review | Codex `gpt-5.4` | `high` |
| Non-code brainstorm | `gpt-5.2` | `high` |

### Architecture And Cost Constraints

Command-level only: agents stay single-model because they cannot own Bash or network execution.
Claude stays the final decision-maker, and external models never modify files directly or override host evaluation.
Cost scales from about `1x` in single mode to about `1.5x` with one external model, so warn before batch fan-out work.

### Integration And Validation

Use cherry-pick for mutually exclusive outputs, majority consensus for fast independent scoring, unanimous consensus for quality-critical convergence, and synthesis when the best answer combines strengths.
Validate that task classification happened first, the routing table was consulted, the relay used raw content, results were parsed with fallback, integration mode matched the task, and cost warnings were issued for batch `--multi` runs.

## Reference Map

- `${CLAUDE_SKILL_DIR}/references/routing-table.md` — Task-by-stake model selection defaults and model profiles.
- `${CLAUDE_SKILL_DIR}/references/invocation-protocol.md` — CLI invocation rules, relay construction, and version assumptions.
- `${CLAUDE_SKILL_DIR}/references/parsing-strategy.md` — Three-tier recovery path for structured and raw external output.
- `${CLAUDE_SKILL_DIR}/references/consensus-protocol.md` — Cherry-pick, majority, unanimous, and synthesis integration procedures.
- `${CLAUDE_SKILL_DIR}/references/relay-response-schemas.md` — Expected response schemas for evaluation, comparison, and review relays.
- `${CLAUDE_SKILL_DIR}/references/relay-prompt-templates.md` — Command-specific relay templates for reconciler-style workflows.
- `${CLAUDE_SKILL_DIR}/references/parallel-execution-pattern.md` — Fan-out and fan-in pattern for independent external runs.
- `${CLAUDE_SKILL_DIR}/references/completion-status-protocol.md` — Terminal status block format required for routed execution chains.

## See Also

- `commands/core/evaluate.md` — Uses routing for multi-model evaluation.
- `commands/core/evolve.md` — Uses routing for research and validation passes in `--multi` mode.
- `commands/core/brainstorm.md` — Uses routing for two-model brainstorming.
- `commands/core/upgrade.md` — Uses relay templates and response schemas for reconciler-style routing.
