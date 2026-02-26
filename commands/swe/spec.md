---
description: "Specification composite — orchestrate Stages 1-4 (Understand, Constrain, Design, Interface) to produce a complete specification"
argument-hint: "<task-description> [--depth <global|per-stage>]"
allowed-tools: Read, Glob, Grep, Write, Task
---

# Spec — Specification Composite (Stages 1-4)

Orchestrate the 4 specification stages sequentially — Understand, Constrain, Design, Interface — to produce a complete artifact chain from problem description to interface contracts.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | analyst | Stage 1 — Domain analysis (Understand) |
| 4 | analyst | Stage 2 — Constraint enumeration (Constrain) |
| 5 | analyst | Stage 3 — Architecture design (Design) |
| 6 | analyst | Stage 4 — Contract definition (Interface) |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text | Required — abort if empty |
| `--depth` | Depth specification | Standard (global) |

`--depth` accepts two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Global | `--depth Deep` | All 4 stages at Deep depth |
| Per-stage | `--depth U:Std C:Std D:Deep I:Std` | Individual stage depths (U=Understand, C=Constrain, D=Design, I=Interface) |

Parsing rules:

- If single word (Skip/Light/Standard/Deep): apply to all 4 stages
- If colon-separated pairs: parse each. Missing stages default to Standard
- If any stage abbreviation is invalid: error and abort
- If any depth value is invalid: error and abort

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe spec <task-description> [--depth <global|U:level C:level D:level I:level>]`"
- Abort

## Phase 2: Depth Planning

1. If `--depth` was provided, use parsed values
2. If no `--depth`, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md` independently for each stage:
   - Score 5 factors once (they apply to the task overall)
   - Apply stage-specific minimum depth triggers for each stage
   - Apply escalation rules
3. Build Depth Plan:

```text
Depth Plan: U:{level} C:{level} D:{level} I:{level}
Rationale: {key drivers}
Escalation Triggers: {list if any}
```

Log the Depth Plan. Present to user for confirmation:

```markdown
## Depth Plan

| Stage | Depth | Rationale |
|-------|-------|-----------|
| 1. Understand | {level} | {reason} |
| 2. Constrain | {level} | {reason} |
| 3. Design | {level} | {reason} |
| 4. Interface | {level} | {reason} |

Proceed with this plan, or adjust depths?
```

## Phase 3: Stage 1 — Understand

Execute the Understand stage by delegating to the analyst agent:

> Agent: **analyst**

- **Input**: Task description + depth level for Understand
- **Instructions**: Same as `commands/swe/understand.md` Phase 4 analyst instructions, at the planned depth
- **Expected output**: Context Document content

1. Survey codebase for task-relevant context (same as understand.md Phase 3)
2. Delegate to analyst
3. Write Context Document to `.swe/active/01-understand.md`
4. Validate output: Problem Statement and Affected Components must be present. If missing: retry once at Light depth
5. Log: "Stage 1 complete. Context Document written."

### Stage 1 Failure

If analyst fails after retry: abort composite. Output: "Stage 1 (Understand) failed. Cannot proceed without Context Document. Run `/swe understand` standalone for diagnostics."

## Phase 4: Stage 2 — Constrain

Execute the Constrain stage, passing the Context Document forward:

> Agent: **analyst**

- **Input**: Task description + Context Document content + depth level for Constrain
- **Instructions**: Same as `commands/swe/constrain.md` Phase 4 analyst instructions, at the planned depth. Reference the Context Document for domain context
- **Expected output**: Constraint Profile content

1. Delegate to analyst with Context Document as input context
2. Write Constraint Profile to `.swe/active/02-constrain.md`
3. Validate: At Standard+ depth, all 6 categories must have entries. If gap: retry with explicit category coverage instruction
4. Log: "Stage 2 complete. Constraint Profile written. {n} constraints across {m}/6 categories."

### Stage 2 Failure

If analyst fails after retry: offer degraded mode. "Stage 2 (Constrain) failed. Options: (A) Proceed to Design without constraints (risk: unconstrained design). (B) Abort and run `/swe constrain` standalone."

If user chooses A: proceed with empty Constraint Profile flagged as "missing — design may be over/under-scoped."

## Phase 5: Stage 3 — Design

Execute the Design stage, passing the Constraint Profile forward:

> Agent: **analyst**

- **Input**: Task description + Context Document content + Constraint Profile content + depth level for Design
- **Instructions**: Same as `commands/swe/design.md` Phase 4 analyst instructions, at the planned depth. Use Constraint Profile as design boundary. Reference Context Document for domain model
- **Expected output**: Architecture Spec content

1. Survey existing architecture patterns (same as design.md Phase 3)
2. Delegate to analyst with both upstream artifacts
3. Write Architecture Spec to `.swe/active/03-design.md`
4. Validate: If Constraint Profile exists, check constraint traceability — at least 1 design decision must reference a constraint. If 0 traceability: retry
5. Log: "Stage 3 complete. Architecture Spec written. {n} decisions, {m} traced to constraints."

### Stage 3 Failure

If analyst fails after retry: abort composite. Output: "Stage 3 (Design) failed. Architecture Spec required for Interface stage. Run `/swe design` standalone for diagnostics."

## Phase 6: Stage 4 — Interface

Execute the Interface stage, passing the Architecture Spec forward:

> Agent: **analyst**

- **Input**: Task description + Architecture Spec content + Constraint Profile content (for performance SLAs) + depth level for Interface
- **Instructions**: Same as `commands/swe/interface.md` Phase 4 analyst instructions, at the planned depth. Extract component boundaries from Architecture Spec. Reference Constraint Profile for performance contracts
- **Expected output**: Interface Contracts content

1. Survey existing interfaces (same as interface.md Phase 3)
2. Delegate to analyst with upstream artifacts
3. Write Interface Contracts to `.swe/active/04-interface.md`
4. Validate: At least 1 interface defined. All interfaces have type definitions. If validation fails: retry
5. Log: "Stage 4 complete. Interface Contracts written. {n} interfaces defined."

### Stage 4 Failure

If analyst fails after retry: present partial results. All prior artifacts remain valid. "Stage 4 (Interface) failed, but Stages 1-3 completed successfully. Run `/swe interface` standalone to complete the specification."

## Phase 7: Review

Present the complete specification for user approval:

```markdown
## Specification Complete: {task summary}

### Artifact Chain

| # | Stage | Depth | Artifact | Status |
|---|-------|-------|----------|--------|
| 1 | Understand | {depth} | `.swe/active/01-understand.md` | {done/failed} |
| 2 | Constrain | {depth} | `.swe/active/02-constrain.md` | {done/failed/degraded} |
| 3 | Design | {depth} | `.swe/active/03-design.md` | {done/failed} |
| 4 | Interface | {depth} | `.swe/active/04-interface.md` | {done/failed} |

### Key Highlights
- **Domain**: {key domain concepts from Context Document}
- **Constraints**: {hard constraint count} hard, {soft count} soft constraints
- **Architecture**: {selected pattern}
- **Interfaces**: {interface count} contracts defined

### Contract Chain Validation
- [ ] Context Document → Constraint Profile: domain terms consistent
- [ ] Constraint Profile → Architecture Spec: all hard constraints addressed
- [ ] Architecture Spec → Interface Contracts: all component boundaries have contracts

Review the specification artifacts, or approve to proceed.
```

## Phase 8: Report

```markdown
## Spec Complete: {task summary}

**Depth Plan**: U:{level} C:{level} D:{level} I:{level}
**Artifacts**: 4 files in `.swe/active/`

### Next Steps
Run development stages (Test, Implement, Verify, Optimize):
`/swe dev "{task}" --artifact .swe/active/04-interface.md`

### Individual Stage Review
- `/swe understand "{task}"` — revisit domain analysis
- `/swe constrain "{task}"` — revisit constraints
- `/swe design "{task}"` — revisit architecture
- `/swe interface "{task}"` — revisit contracts

### See Also
- `/swe spiral "{task}"` — full engineering cycle (spec + dev + ship + tune)
```

## Rules

- Each stage delegates to the analyst agent — the command orchestrates, not executes
- Artifacts are written sequentially: each stage's output becomes the next stage's input
- Artifact paths follow `.swe/active/{NN}-{stage}.md` convention
- User checkpoint occurs once at Phase 7 (Review) — individual stages do not pause for user review when run as part of spec
- Backward transitions within spec: if a downstream stage reveals upstream gaps, the command re-runs the upstream stage (not the primitive command) with additional context
- Failure isolation: each stage can fail independently. Prior completed artifacts remain valid
- Graceful degradation: Stage 2 failure offers unconstrained design option. Stage 4 failure preserves Stages 1-3 artifacts
