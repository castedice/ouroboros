---
title: Brainstorm-Composite Integration — 3-Way Multi-Model Exploration
tags: [brainstorm, composite-commands, architecture, multi-model, pipeline-design]
source: /brainstorm --multi (Claude + Codex gpt-5.2 high + Gemini gemini-3-pro-preview), 33 ideas from 3 models
created: 2026-02-21
status: active
related: [cross-model-cli-integration-patterns.md]
---

# Brainstorm-Composite Integration — 3-Way Multi-Model Exploration

3-way brainstorm (Claude 13 ideas + Codex 12 ideas + Gemini 8 ideas = 33 total) exploring whether composite commands (absorb, upgrade, adopt, onboard) should integrate brainstorm as a creative exploration step.

## Key Findings

### 3-Way Convergent (all 3 models independently)

1. **Post-composite brainstorm suggestion**: All models agree brainstorm belongs in composite Report phases as a "Next Actions" suggestion, not embedded in the pipeline. Trivial to implement, zero risk.
2. **Brainstorm as external pre-step, not internal phase**: Matches compound-engineering's brainstorm → plan → work → review pattern. Composites should stay focused execution pipelines.

### 2-Way Convergent (2 models independently)

3. **Structured brainstorm output** (Codex + Gemini): The output format mismatch (conversational vs pipeline-consumable) is the fundamental blocker for deeper integration. Both propose artifact-oriented output (decision memo / BRAINSTORM.md).
4. **Ambiguity-triggered brainstorm** (Codex + Gemini): Auto-trigger only when earlier phases detect high uncertainty, not always. Preserves latency for common case.
5. **Opt-in flag** (Codex + Gemini): `--explore`/`--diverge` flag for composites, making creative step optional.
6. **Non-interactive brainstorm mode** (Claude + Codex): Bounded exploration (3-5 ideas, fixed-size output) compatible with DR-024 turnkey execution.
7. **Keep onboard pure** (Claude + Codex): onboard's read-only/no-agent nature should be preserved, brainstorm offered as follow-up suggestion.

### Unique Perspectives

8. **Brainstormer skill extraction** (Claude): Extract divergent/convergent methodology into a skill reference, enabling "micro-brainstorm" at decision points without full pipeline overhead. Follows DR-031 extraction pattern.
9. **Decision memo as compounding asset** (Codex): Recorded brainstorm memos improve future runs even when not used to steer current run. Brainstorm fits better as input to evaluator (choice among alternatives) than as replacement for planner logic.
10. **Devil's Advocate Validator** (Gemini): Use brainstorm for counter-arguments/regression scenarios in upgrade, not just creative generation. Creativity applied to finding flaws.
11. **Post-work brainstorming** (Gemini): Running brainstorm after completion to seed the next cycle aligns with Ouroboros "self-eating snake" philosophy better than pre-work brainstorming.

## Practical Applications

### Immediate (zero code change)

- Add `/brainstorm` to each composite's Report phase "Next Actions" list
- Add "Creative Exploration" workflow section to `/onboard` showing brainstorm as pre-step

### Short-term (small code change)

- Create micro-brainstorm procedure in brainstorming skill — 3-5 ideas, quick ranking, for use at existing decision points (absorb Phase 5 design, upgrade CONFLICT-B, adopt Phase 4 plan)
- Add brainstorm suggestion to post-composite reports with context-specific topics

### Future (requires design work)

- Structured brainstorm output schema (decision memo format) for pipeline consumption
- Ambiguity detection heuristics for auto-triggered brainstorm
- `--explore` flag on absorb/adopt

## Trade-offs

- **Embedding vs external**: Internal integration adds complexity and conflicts with DR-024 (turnkey); external pre/post-step is simpler but relies on user initiative
- **Structured vs conversational output**: Structured enables pipeline consumption but may reduce creative quality; conversational preserves creativity but can't be automated
- **Always vs conditional**: Always-on brainstorm adds latency/cost; conditional (ambiguity-triggered) is smarter but requires defining reliable ambiguity signals
- **Onboard transformation risk**: Gemini uniquely suggested making onboard generative (suggest tasks), but this fundamentally changes onboard's identity — Claude and Codex both recommend keeping it pure

## References

- compound-engineering plugin pattern: brainstorm as separate pre-plan stage (`docs/knowledge/compound-engineering-plugin-patterns.md`)
- DR-016: Command Taxonomy — Primitives and Composites
- DR-024: 2-Phase Execution Model with Git Worktree Isolation
- DR-038: Brainstorm Promotion to Core
