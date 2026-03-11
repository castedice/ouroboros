---
name: routing-methodology
description: This skill provides multi-model routing methodology. It should be activated when a command needs to "route a task to an external model", "invoke Codex CLI", "select the right model for a task", "integrate results from multiple models", "build a consensus from multi-model outputs", or "handle external model failure gracefully".
---

# Routing Methodology

## Core Principle

**"The right model for the right task."**

No single model excels at everything. Claude has deep reasoning and instruction following, Codex brings strong code expertise and fast execution. Routing selects the optimal model (or combination) for each task, while the host model (Claude) always orchestrates. Priority order: **Claude > Codex**.

This principle drives every design choice: task classification determines model selection, independent scoring prevents anchoring bias, and graceful degradation ensures no external dependency blocks the workflow.

## Routing Workflow

The standard workflow for routing a task to external models:

### Step 1: Classify Task

Determine the task category and stake level:

| Category | Examples | Typical Mode |
|----------|----------|-------------|
| Evaluation | Static scoring, output assessment | Consensus (independent) |
| Comparison | Before/after, pairwise judgment | Consensus (independent) |
| Decision | Architecture choice, trade-off analysis | 2-way debate (Claude + Codex) |
| Extraction | Pattern analysis, bulk scanning | Cherry-pick or single-model |
| Review | Code review, security audit | Adversarial (external as devil's advocate) |
| Generation | Component creation, template filling | Single-model (host) |

### Step 2: Assess Stake Level

Stake level determines how many models to involve:

| Stake | Criteria | Models |
|-------|----------|--------|
| Low | Reversible, exploratory, routine | 1 (host only, or single external) |
| Medium | Stored/recorded, influences future work | 2 (host + 1 external) |
| High | Architectural, irreversible, user-facing decision | 2 (Claude + Codex, high reasoning) |

### Step 3: Lookup Routing Table

Consult `references/routing-table.md` for the task category x stake level mapping. Key defaults:

| Task | Primary External | Reasoning Effort | Notes |
|------|-----------------|-----------------|-------|
| Evaluation (static) | Codex gpt-5.4 | xhigh | Independent scoring, strict on borderline |
| Code review | Codex gpt-5.4 | high | Coding model strength |
| Brainstorm | Codex gpt-5.2 | high | Non-coding: general-purpose model |

Priority order: Claude > Codex. Codex coding models (`-codex`) for code tasks, `gpt-5.2` for non-code tasks.

### Step 4: Construct Prompt Relay

Build the prompt for external models using the Prompt Relay pattern from `references/invocation-protocol.md`. Critical rule: relay raw content, never Claude-paraphrased summaries. This mitigates framing bias.

### Step 5: Invoke External Models

Call external CLIs via `scripts/invoke-model.sh`. The script handles invocation, parsing, and fallback mechanically. If the script fails (exit 1), the command reads the raw output file directly and extracts scores using LLM understanding. See `references/parsing-strategy.md` for the 3-tier parsing architecture and `references/invocation-protocol.md` for prompt patterns.

### Step 6: Integrate Results

Apply the appropriate integration mode from `references/consensus-protocol.md`:

- **Cherry-pick**: Select the best output
- **Consensus (majority)**: Independent scoring + majority rule — fast path
- **Consensus (unanimous)**: Identify divergence → ask divergent model for reasoning → iterate until convergence — quality path
- **Synthesis**: Combine strongest aspects from each model

## Architecture Constraints

### Command-Level Only

Multi-model invocation happens exclusively at the **command level** via Bash tool. Background Task agents cannot access Bash or network — this is a fundamental Claude Code constraint. Commands orchestrate external calls; agents remain read-only and single-model.

```text
Command (orchestration) ──Bash──> External CLI (Codex)
         │
         └──Task──> Agent (read-only, single-model)
```

### Host Model Supremacy

Claude is always the orchestrator. External models provide perspectives but never:

- Make final decisions
- Modify files directly
- Access the user's codebase without Claude mediating
- Override Claude's evaluation

### Opt-in Pattern

Multi-model routing is always opt-in via explicit flags (e.g., `--multi`). Default behavior of all commands remains single-model (host only). This respects cost sensitivity (1.3-2.5x multiplier) and external CLI dependency.

## Bias Mitigation

Multi-model routing introduces new bias risks alongside the biases it mitigates:

| Bias | Risk | Mitigation |
|------|------|------------|
| Self-enhancement | Claude overrates its own output (~10% higher) | Use external model as independent judge |
| Framing bias | Claude's prompt construction biases external model | Prompt relay with raw content, no paraphrasing |
| Anchoring | Seeing one model's result influences scoring of others | Independent scoring — no model sees others' results |
| Authority bias | Treating one model as "ground truth" | Equal weight in consensus; no model is privileged |
| Availability cascade | Repeated multi-model agreement creates false confidence | Track agreement rate over time; watch for systematic patterns |

### Framing Bias Deep Dive

The most insidious bias in multi-model routing: Claude constructs the prompt that external models receive. If Claude summarizes or paraphrases content, its perspective leaks into the prompt.

**Mitigation**: The Prompt Relay pattern (Step 4) uses 4 sections, where Sections 2 and 3 are raw file content read directly from disk — never filtered through Claude's understanding. Only Sections 1 (role assignment) and 4 (response format) are constructed by Claude, and these are generic templates that carry no task-specific opinion.

## Cost Awareness

Multi-model invocation multiplies token costs:

| Mode | Approximate Multiplier |
|------|----------------------|
| Single (default) | 1x |
| Host + 1 external | ~1.5x |
| Module scan × multi | ~1.5 × N components |

Cost controls:

1. `--multi` is opt-in, never default
2. Routing table recommends lighter models (Spark, Flash) for low-stake tasks
3. Module scan with `--multi` warns user before invoking N × M model calls
4. Future: evaluation caching by content hash prevents redundant evaluations

## Common Pitfalls

| Pitfall | Prevention |
|---------|------------|
| Paraphrasing content in relay prompt | Use raw file content in Sections 2-3 |
| Sharing Model A's result with Model B | Independent scoring — never cross-pollinate |
| Retrying failed CLI calls indefinitely | Circuit breaker — skip after 1 failure, log warning |
| Treating `--multi` as always better | Single-model is fine for most tasks; multi adds value for evaluation and high-stake decisions |
| Ignoring parse failures | 3-tier fallback: script parse → script fallback → LLM reads raw file |
| Assuming all CLIs are installed | Check availability first (`which`); degrade gracefully |

## Consumers

Commands and agents that integrate this skill:

| Consumer | Usage | Flag |
|----------|-------|------|
| `commands/core/evaluate.md` | Multi-model evaluation (Phase 3 parallel fan-out/fan-in) | `--multi` |
| `commands/core/evolve.md` | Multi-model researcher analysis (Phase 3) + validation (Phase 6) | `--multi` |
| `commands/core/brainstorm.md` | 2-way brainstorm (Claude + Codex) | `--multi` |

Agents do not use this skill directly — multi-model routing is command-level only (see Architecture Constraints).

## Validation Checklist

Use this checklist to verify that routing methodology is applied correctly:

- [ ] Task correctly classified (category + stake level)
- [ ] Routing table consulted for model selection
- [ ] Prompt relay uses raw content (Sections 2-3 not paraphrased)
- [ ] External model invoked via Bash with proper timeout
- [ ] JSON output parsed successfully (with code fence fallback)
- [ ] CLI unavailability handled gracefully (skip, not abort)
- [ ] Results integrated using the correct mode (cherry-pick/consensus-majority/consensus-unanimous/synthesis)
- [ ] Self-enhancement bias flagged when Claude scores higher than all external models
- [ ] Cost warning issued for batch operations with `--multi`
- [ ] Report includes per-model scores and agreement rate
