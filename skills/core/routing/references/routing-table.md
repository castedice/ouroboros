# Routing Table — Task to Model Mapping

This reference defines which model handles which task. The table is a guideline — commands may override for specific needs. Evolve this file as real-world usage reveals better mappings.

**Priority order**: Claude > Codex. When adding multi-model support, Codex is the external model to integrate.

**Subscription assumption**: Paid ChatGPT Pro/Plus subscription for Codex. Free tier models have insufficient capability and rate limits for meaningful multi-model work — if a user is on free tier, fall back to Claude-only.

**Role differentiation**:

- **Coding tasks** (implementation, code review, debugging, refactoring) → Codex `-codex` models
- **Non-coding tasks** (design, evaluation, brainstorming, broad analysis) → gpt-5.2 (general-purpose)

## Model Profiles

### Host Model (Always Available)

| Model | Strength | Context | Use For |
|-------|----------|---------|---------|
| Claude Opus | Deep reasoning, nuance, instruction following | 200K | Orchestration, synthesis, complex evaluation, design |
| Claude Sonnet | Balanced speed/quality | 200K | Standard execution, most agent tasks |
| Claude Haiku | Fast, cheap | 200K | Pre-screening, simple summarization |

### External Models — Codex (Priority 1, Coding Focus)

**Coding models** — for implementation, code review, debugging, refactoring, test writing:

| Model | CLI Flag | Strength | Context | Availability | Use For |
|-------|----------|----------|---------|-------------|---------|
| gpt-5.4 | Default | Most capable agentic coding + reasoning | 400K | ChatGPT subscription | Code review, code-focused evaluation |
| gpt-5.3-codex-spark | `-m gpt-5.3-codex-spark` | Real-time (1000+ tok/s), text-only | 400K | ChatGPT Pro (research preview) | Fast code sanity checks |
| gpt-5.1-codex-max | `-m gpt-5.1-codex-max` | Long-horizon agentic coding, enhanced reasoning | 400K | ChatGPT subscription | Complex multi-file analysis, long-running tasks |
| gpt-5.2-codex | `-m gpt-5.2-codex` | Advanced coding, stable API access | 400K | API key | CI/CD automation |
| gpt-5.1-codex | `-m gpt-5.1-codex` | Long-running agentic coding (succeeded by Max) | 400K | ChatGPT subscription | Fallback |

**General-purpose model** — for design, evaluation, brainstorming, non-code analysis:

| Model | CLI Flag | Strength | Context | Availability | Use For |
|-------|----------|----------|---------|-------------|---------|
| gpt-5.2 | `-m gpt-5.2` | General agentic model, cross-industry | 400K | API key | Design evaluation, architecture analysis, brainstorming |

gpt-5.2 is general-purpose. Use it as the primary external model for design/evaluation work. Codex `-codex` models are coding-only.

**Reasoning effort**: Codex supports tunable reasoning via `-c model_reasoning_effort="{level}"`:

- `low` — fastest, minimal deliberation
- `medium` — default, good balance for interactive coding
- `high` — deep reasoning for complex tasks
- `xhigh` — maximum deliberation, non-latency-sensitive tasks

Example: `codex exec -c model_reasoning_effort="high" --json "prompt"`

### Model Selection Defaults

When no specific model variant is requested:

- **Codex default**: gpt-5.4 with medium reasoning (strongest, general purpose)
- **Codex for hard tasks**: gpt-5.4 with high/xhigh reasoning
- **Codex for evaluation**: gpt-5.4 with xhigh reasoning (DR-035: consistently strict on borderline criteria, 2.6× faster than gpt-5.2 xhigh, no coding-model bias detected)
- **Codex for bulk evaluation**: gpt-5.4 with medium reasoning (regression suite — same core discrimination, E4 fluctuates, 2× faster than xhigh)
- **Codex for research**: gpt-5.4 with high reasoning (DR-036: 44% faster than xhigh, minimal quality gap, cherry-pick mode compensates)
- **Codex for generation**: gpt-5.4 with high reasoning (DR-036: 1.7× faster than xhigh, structural parity, downstream /evaluate validates output)
- **Codex for reconciliation**: gpt-5.4 with high reasoning (DR-036: 3.5× faster than xhigh, identical merge quality, Opus orchestrator validates merged content)
- **High-stake override**: gpt-5.4 with high reasoning

### Free Tier Handling

If external CLI returns authentication or quota errors suggesting free tier limitations:

- Log: "External model rate limited. Falling back to Claude-only evaluation."
- Skip the external model entirely — degraded free tier responses add noise, not signal
- Do NOT retry or queue — free tier limits recover slowly

## Routing Table

### By Task Category (Role-Aware)

Priority: Claude > Codex (gpt-5.2 for non-code, codex models for code).

| Task Category | Stake: Low | Stake: Medium | Stake: High |
|---------------|-----------|--------------|------------|
| **Code Evaluation** | Claude only | Claude + Codex 5.3 (consensus) | Claude + Codex 5.3 xhigh (consensus) |
| **Design Evaluation** | Claude only | Claude + gpt-5.2 (consensus) | Claude + gpt-5.2 high (consensus) |
| **Comparison** | Claude only | Claude + Codex 5.3 (consensus) | Claude + Codex 5.3 + gpt-5.2 (consensus) |
| **Architecture Decision** | Claude only | Claude + gpt-5.2 (debate) | Claude + gpt-5.2 high (debate) |
| **Code Review** | Claude only | Claude + Codex 5.3 (adversarial) | Claude + Codex 5.3 + gpt-5.2 (adversarial) |
| **Design Brainstorming** | Claude only | Claude + gpt-5.2 (synthesis) | Claude + gpt-5.2 high (synthesis) |
| **Pattern Extraction** | Claude or Codex Spark | Claude + Codex 5.3 high (cherry-pick) | Claude + Codex 5.3 high + gpt-5.2 (synthesis) |
| **Bulk Scanning** | Claude only | Claude + Codex Spark (cherry-pick) | Claude + Codex 5.3 (synthesis) |
| **Code Generation** | Claude only | Claude only | Claude (generate) + Codex 5.3 (review) |

### By Ouroboros Command

Concrete routing for each core command when `--multi` is active:

| Command | Multi-model Phase | Models Used | Integration Mode |
|---------|------------------|-------------|-----------------|
| `/evaluate` (code component) | Phase 3: External Scoring | Claude + Codex 5.3 (xhigh) | Consensus | DR-035 |
| `/evaluate` (non-code) | Phase 3: External Scoring | Claude + Codex 5.3 (xhigh) | Consensus | DR-035 |
| `/evaluate` (before/after) | Phase 3: External Pairwise | Claude + Codex 5.3 (xhigh) | Consensus | DR-035 |
| `/evolve` | Phase 3: Analysis | Claude + Codex 5.3 (high) | Cherry-pick | DR-036 (researcher routing) |
| `/evolve` | Phase 6: Validation | Claude + Codex 5.3 (xhigh) | Consensus (before/after) | DR-035 (evaluation routing) |
| `/research` | Phase 3: Pattern Extraction | Claude + Codex 5.3 (high) | Cherry-pick | DR-036 |
| `/generate` | Phase 6: Quality Pre-check | Claude + Codex 5.3 (xhigh) | Consensus | DR-035 (evaluation routing) |
| `/generate` | Phase 3: Content Generation | Claude + Codex 5.3 (high) | Cherry-pick | DR-036 |
| `/absorb` | Phase 3: Research | Claude + Codex 5.3 (high) | Cherry-pick | DR-036 (research routing) |
| `/absorb` | Phase 5: Gap Analysis | Claude + Codex 5.3 (high) | Synthesis | DR-036 |
| `/upgrade` | Phase 4-5: Conflict Analysis | Claude + Codex 5.3 (high) | Cherry-pick | DR-036 (reconciler routing) |
| `/adopt` | Phase 3: Project Analysis | Claude + Codex 5.3 (high) | Cherry-pick | DR-036 (research routing) |
| `/brainstorm` | Phase 3: Idea Generation | Claude + gpt-5.2 (high) | Cherry-pick | Design brainstorming (non-coding creative task) |

Note: Effort levels are evidence-based per DR-035 (evaluator) and DR-036 (researcher, generator, reconciler).

## Selection Logic

### 3-Step Process

```text
1. CLASSIFY: What type of task?
   → code evaluation, design evaluation, comparison, architecture decision,
     code review, design brainstorming, pattern extraction, bulk scanning, generation

2. ASSESS: What's the stake level?
   → Low (exploratory), Medium (recorded), High (irreversible)

3. LOOKUP: Table[category][stake] → model(s) + integration mode
   → Also consider: is this a coding task (→ Codex -codex models) or design/broad task (→ gpt-5.2)?
```

### Override Rules

The routing table is a default. Commands may override when:

1. **User specifies model**: `--model codex-spark` overrides table selection
2. **CLI unavailable**: Degrade gracefully (see invocation-protocol.md)
3. **Cost constraint**: User sets `--budget` to limit model count
4. **Speed constraint**: Use Spark/Flash variants regardless of stake level

### When NOT to Route

Some tasks should always stay single-model (Claude):

- **File modification**: Only Claude can write/edit files in the plugin context
- **Worktree operations**: Git operations require host model access
- **User interaction**: Prompts, confirmations, choices stay with Claude
- **Context-heavy tasks**: Tasks requiring full conversation history stay with Claude
- **Agent delegation**: Task tool agents are always Claude (single-model constraint)
