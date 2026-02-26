# Quality Gate Procedure — Post-Generation Validation

> Reference for the validation-methodology skill. Standard procedure for validating generated components against evaluation criteria with threshold-based retry logic.

## When to Apply

After generating or regenerating components via the **generator** agent. Used by `/generate` (Phase 6) and `/absorb` (Phase 8).

Templates are excluded from evaluation — only commands, agents, and skills are validated.

## Inputs

| Input | Description |
|-------|-------------|
| Component files | Generated files in the worktree (paths + contents) |
| Component types | Type of each file (command, agent, skill) |

## Procedure

### Step 1: Evaluate Components

For each generated command, agent, and skill:

1. Read the file from the worktree
2. Launch **evaluator** agent via Task tool:
   - Input: component file content + component type
   - Instructions: "Load criteria reference for this component type. Apply tiered criteria (F→Q→E) with CoT-first scoring and severity gate. Return evaluation report with level."
3. Record the level

### Step 2: Quality Gate Check

- **Pass threshold**: Level ≥ 2 (Needs Work) per component — Foundation must be complete
- All components pass → check Step 2.5
- Any component fails (Level 1 — Poor) → continue to Step 3

### Step 2.5: Inline Fix (optional)

When a component passes (Level ≥ 2) but evaluation reveals a clear, small fix — apply it directly in the worktree before proceeding to merge. This avoids a separate `/evolve` cycle for obvious improvements.

**When to apply**: The fix is mechanical and well-scoped (e.g., add missing reference files for F4, remove duplicate content for E3). If the fix requires research, design decisions, or affects multiple components, defer to `/evolve`.

**Procedure**:

1. Apply the fix in the worktree (edit existing files, create new files as needed)
2. Re-evaluate using the **stricter model** — the model that scored lower in the original evaluation. The stricter evaluator confirms the fix actually addresses the issue rather than receiving a lenient pass
3. If multi-model evaluation was used, apply consensus with the original scores from the other model
4. Update decision entry and commit

**Rationale**: Re-evaluation by the stricter model prevents confirmation bias. The lenient model already passed the component — only the strict model's judgment matters for validating the improvement.

### Step 3: Retry (max 1 round)

For each failing component:

1. Launch **generator** agent via Task tool for Component Regeneration (Procedure 2):
   - Input: original component content + evaluation report + criteria reference
   - Instructions: "Perform Component Regeneration. Parse evaluation feedback, diagnose root causes, produce revised content."
2. Overwrite the file in worktree with revised content
3. Re-evaluate with **evaluator** agent

### Step 4: Post-Retry Decision

- Improved to >= 3/5 → **exit: proceed**
- Still < 3/5 → log the score, **proceed anyway** (user decides in review phase)

### Step 5: Log Results

```markdown
Quality Validation:

- {component-1}: {score}/5 {PASS|FAIL}
- Overall: {pass-count}/{total} passed
```

## Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Pass threshold | 3/5 | Generation creates a "starting point" — `/evolve` improves further |
| Max retry rounds | 1 | Single retry catches obvious misses; multiple retries have diminishing returns |
| Failure behavior | proceed | Present low-scoring component in review phase for user decision |

## Agents Involved

| Agent | Role | When |
|-------|------|------|
| evaluator | Score components against type-specific criteria | Step 1, Step 3 (re-evaluate) |
| generator | Regenerate failing components (Procedure 2) | Step 3 (retry) |

## See Also

- **evaluation-methodology** (`skills/core/evaluation/SKILL.md`) — How tiered scoring works (F/Q/E criteria)
- **validation-methodology** (`skills/core/validation/SKILL.md`) — Structural correctness checks (run before quality gate)
- Criteria references: `skills/core/evaluation/references/{command,agent,skill}-criteria.md`
