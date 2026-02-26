# Parallel Execution Pattern — Multi-Model Fan-Out/Fan-In

This reference defines the standard pattern for running Claude and external models in parallel during multi-model command execution.

## Problem

Sequential multi-model execution doubles wall-clock time: Claude evaluator runs first (~45-90s), then Codex runs second (~50-65s). Total: 95-155s.

## Key Insight: No Data Dependency

The relay prompt for external models requires only Phase 2 (Context Gathering) output:
- Section 2: target file content (already read from disk)
- Section 3: criteria reference (type already determined)
- Sections 1, 4: fixed templates

Claude's evaluation result is NOT used to build the relay prompt. Both evaluations are fully independent — enabling parallel execution.

## Pattern: Fan-Out / Fan-In

```text
Phase 2: Context Gathering
    │
    ├── Build relay prompt (from Phase 2 output only)
    │
    ├── Fan-Out ──────────────────────────────────────┐
    │                                                  │
    │   Background: Bash(invoke-model.sh,              │   Foreground: Task(evaluator agent)
    │               run_in_background=true)            │
    │   → writes result to .tmp/{id}_codex_eval.json   │   → returns evaluation report
    │                                                  │
    └── Fan-In ────────────────────────────────────────┘
    │
    │   Collect background result (file-based)
    │   Handle exit codes (0/1/2/124)
    │
    ▼
Phase 5.5: Consensus Integration
```

## Implementation Steps

### 1. Build Relay Prompt (before fan-out)

Construct the relay prompt from Phase 2 data. Save to `.tmp/{SESSION_ID}_relay.txt`. This must complete before both branches start.

### 2. Fan-Out: Launch Both Evaluations

**Background branch** — external model via Bash with `run_in_background: true`:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_relay.txt .tmp/{SESSION_ID}_codex_eval.json xhigh
```

The background task ID is stored for later collection.

**Foreground branch** — Claude evaluator via Task tool:

```
Task(evaluator agent, subagent_type=ouroboros:core:evaluator)
  Input: component content + type
  Output: evaluation report
```

Both run concurrently. The foreground Task blocks until Claude completes; background Bash runs independently.

### 3. Fan-In: Collect Results

After the foreground Task completes:

1. Check background task output (the file `.tmp/{SESSION_ID}_codex_eval.json` or exit code)
2. Handle by exit code — same error handling as sequential (LLM fallback, circuit breaker)
3. Both results now available for consensus integration

## Expected Performance

| Metric | Sequential | Parallel | Improvement |
|--------|-----------|----------|-------------|
| Wall-clock (Mode A) | 95-155s | 45-120s | ~40-50% |
| Total compute | Same | Same | None (same work) |
| Complexity | Low | Medium | Trade-off |

The bottleneck becomes whichever evaluation takes longer. Since Claude and Codex typically have similar latency (45-90s vs 50-65s), wall-clock approaches ~max(Claude, Codex) instead of sum.

## Mode-Specific Notes

### Mode A/D: Single Component

Standard fan-out/fan-in — one background + one foreground.

### Mode B: Module Scan

Per-component fan-out: for each component, launch background + foreground in parallel. Components themselves are processed sequentially (to maintain reasoning quality and circuit breaker state).

### Mode C: Before/After

Two relay prompts needed (before + after), or one combined comparative prompt. Current implementation uses a single combined prompt for Codex (Mode C relay template) alongside two sequential Claude evaluator calls. The background Codex runs while both Claude evaluations proceed.

## Applicability to Other Commands

This pattern applies wherever Claude agent + external model perform independent work on the same input:

| Command | Phase | Claude (foreground) | External (background) |
|---------|-------|--------------------|-----------------------|
| `/evaluate` | Phase 3 | evaluator agent | Codex evaluator |
| `/evolve` | Phase 6 (Validate) | evaluator before/after | Codex evaluator before/after |
| `/evolve` | Phase 3 (Analysis) | researcher agent | Codex researcher (cherry-pick) |
| `/research` | Phase 3 (Analysis) | researcher agent | Codex researcher (cherry-pick) |
| `/generate` | Phase 3 (Generate) | generator agent | Codex generator (cherry-pick) |
| `/generate` | Phase 6 (Quality) | evaluator agent | Codex evaluator (consensus) |
| `/absorb` | Phase 3 (Research) | researcher agent | Codex researcher (cherry-pick) |
| `/absorb` | Phase 5 (Gap Analysis) | evaluator agent | Codex evaluator (synthesis) |
| `/absorb` | Phase 8 (Quality) | evaluator agent | Codex evaluator (consensus) |
| `/upgrade` | Phase 4 (Classification) | reconciler agent | Codex reconciler (cherry-pick) |
| `/upgrade` | Phase 5 (Merge) | reconciler agent | Codex reconciler (cherry-pick) |
| `/upgrade` | Phase 7 (Validate) | evaluator before/after | Codex evaluator before/after |

## Constraints

- Background Bash tasks cannot access Claude Code tools (Read, Edit, etc.) — only CLI execution
- File-based communication: background writes to `.tmp/` files, foreground reads them after completion
- Circuit breaker state must be maintained across fan-in to properly skip failed models in Mode B
- Relay prompt must be fully constructed before fan-out — no lazy evaluation
