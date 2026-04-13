---
name: swe:spec
description: "Use when you need one command to turn a task into a complete implementation specification before coding starts"
argument-hint: "<task-description> [--fast] [--depth <global|per-stage>]"
allowed-tools: Read, Glob, Grep, Write, Task
---

# Spec — Specification Composite (Stages 1-4)

Orchestrate the 4 specification stages sequentially — Understand, Constrain, Design, Interface — to produce a complete artifact chain from problem description to interface contracts.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|------------|------|
| 1 | — (command) | Input parsing |
| 1.5 | Read + Write (command) | Ambiguity scoring via `templates/swe/ambiguity-rubric.md` and persistence to `.swe/active/00-ambiguity.md` |
| 2 | — (command) | Depth planning |
| 3 | analyst | Stage 1 — Domain analysis (Understand) |
| 4 | analyst | Stage 2 — Constraint enumeration (Constrain) |
| 5 | analyst | Stage 3 — Architecture design (Design) |
| 6 | analyst | Stage 4 — Contract definition (Interface) |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass analyst artifact paths and inline contents on every call.
Use named return payloads rather than prose-only summaries.
The command owns artifact writes, retries, and degraded continuation state.
Internal analyst calls use `Agent(subagent_type: "ouroboros:swe:analyst")`.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:swe:analyst` | 3, 4, 5, and 6 | `task`, `depth_level`, `upstream_artifacts`, stage contract path, project-model summary, and `constraint_profile` when downstream stages require it | One stage payload containing exactly one of `context_document`, `constraint_profile`, `architecture_spec`, or `interface_contracts`, plus any `unresolved_questions[]` needed for recovery |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text | Required — abort if empty |
| `--fast` | Shortcut for `--depth Light` with relaxed skip conditions | Off |
| `--depth` | Depth specification | Standard (global) |

**`--fast` mode**: Sets all stages to Light depth and enables relaxed skip conditions in each primitive stage. If both `--fast` and `--depth` are present, `--depth` takes precedence.

`--depth` accepts two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Global | `--depth Deep` | All 4 stages at Deep depth |
| Per-stage | `--depth U:Std C:Std D:Deep I:Std` | Individual stage depths (U=Understand, C=Constrain, D=Design, I=Interface) |

Parse and validate `--depth` using `skills/swe/methodology/references/depth-procedure.md`.
Apply the `/swe spec` composite shape from that reference: one global depth expands to all 4 stages, `U:` / `C:` / `D:` / `I:` pairs override named stages, and omitted stages default to `Standard`.
Abort immediately on malformed shapes, unknown stage abbreviations, or invalid depth values.

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe spec <task-description> [--depth <global|U:level C:level D:level I:level>]`"
- Abort

## Phase 1.5: Ambiguity Assessment

Score the task against `templates/swe/ambiguity-rubric.md`.

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| `task` is empty | 1 | Abort with the usage error and do not write artifacts. |
| `--depth` format, stage abbreviation, or depth value is invalid | 1 | Abort with the validation error and do not write artifacts. |
| Initial ambiguity score is `<= 0.2` | 1.5, 2-8 | Mark `PASS`, save `.swe/active/00-ambiguity.md`, and continue. |
| Initial ambiguity score is `> 0.2` and `<= 0.5` | 1.5 | Mark `CLARIFY`, ask exactly 3 targeted questions on the weakest axis, rescore, and continue only if the rescored value is `<= 0.5`. |
| Initial or rescored ambiguity score is `> 0.5` | 1.5 | Mark `ABORT`, save `.swe/active/00-ambiguity.md`, report the missing information, and stop before Stage 1. |
| `--depth` is provided | 2 | Use the parsed global or per-stage depths. |
| `--fast` is provided without `--depth` | 2 | Force Light depth across all four stages and enable relaxed skip behavior downstream. |
| Neither `--depth` nor `--fast` is provided | 2 | Build the per-stage depth plan from `skills/swe/methodology/references/depth-system.md`. |
| Stage 1 validation fails after one retry | 3 | Abort the composite and recommend `/swe understand` standalone. |
| Stage 2 validation fails after one retry | 4 | Offer degraded continuation with a flagged Constraint Profile placeholder or abort the composite. |
| Stage 3 validation fails after one retry | 5 | Abort the composite and recommend `/swe design` standalone. |
| Stage 4 validation fails after one retry | 6-8 | Preserve Stages 1-3 artifacts, mark the chain as partial, and recommend `/swe interface` standalone. |
| All four stages succeed | 7, 8 | Present the full artifact chain for review and hand off to `/swe dev`. |
| User approves degraded Stage 2 continuation | 4-8 | Write `.swe/active/02-constrain.md` as `missing — design may be over/under-scoped` and continue with explicit risk markers in later outputs. |

## Phase 2: Depth Planning

1. If `--depth` was provided, use parsed values
2. If `--fast` was provided (and no `--depth`), set all stages to Light and enable `fast_mode=true` — skip depth matrix scoring entirely
3. If neither, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md` independently for each stage:
   - Score 5 factors once (they apply to the task overall)
   - Apply stage-specific minimum depth triggers for each stage
   - Apply escalation rules
4. Build Depth Plan:

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

### Stage Orchestration Contract

Use the primitive stage contracts as the execution boundary instead of restating their full domain procedures here.
Each row below names the source contract, the artifact it must produce, the validation gate, and the bounded recovery rule this composite applies.

| Composite phase | Stage contract path | Shared instruction path | Input handoff | Output artifact | Validation gate | Failure handling |
|-----------------|---------------------|-------------------------|---------------|-----------------|-----------------|------------------|
| 3 | `commands/swe/understand.md` | `skills/swe/methodology/references/agent-instructions.md` | Task + Stage 1 depth + project-domain summary when present | `.swe/active/01-understand.md` | `Problem Statement` and `Affected Components` must exist | Retry once at Light depth, then abort the composite. |
| 4 | `commands/swe/constrain.md` | `skills/swe/methodology/references/agent-instructions.md` | Task + Context Document + Stage 2 depth + project-constraints summary when present | `.swe/active/02-constrain.md` | Standard+ depth must cover all 6 categories | Retry once with explicit category coverage, then offer degraded continuation or abort. |
| 5 | `commands/swe/design.md` | `skills/swe/methodology/references/agent-instructions.md` | Task + Context Document + Constraint Profile + Stage 3 depth + project-architecture summary when present | `.swe/active/03-design.md` | If a Constraint Profile exists, at least 1 design decision must trace to it | Retry once with explicit traceability requirements, then abort the composite. |
| 6 | `commands/swe/interface.md` | `skills/swe/methodology/references/agent-instructions.md` | Task + Architecture Spec + Constraint Profile + Stage 4 depth + project-interfaces summary when present | `.swe/active/04-interface.md` | At least 1 interface must be defined and all must have explicit type definitions | Retry once with explicit contract/testability requirements, then preserve the partial chain and stop. |

### Shared Stage Execution Pattern

Phases 3-6 use the same composite execution loop from `skills/swe/methodology/references/composite-checkpoint-rules.md`.
Stage behavior comes from `skills/swe/methodology/references/pipeline-spec-stages.md` and agent prompting comes from `skills/swe/methodology/references/agent-instructions.md`.

1. Read the relevant row from the Stage Orchestration Contract.
2. Build only the listed `Input handoff` packet for that stage.
3. Delegate through the listed `Shared instruction path`.
4. Write the listed `Output artifact`.
5. Apply the listed `Validation gate`.
6. If validation fails, apply the listed `Failure handling` exactly once.

## Phase 3: Stage 1 — Understand

Use the Shared Stage Execution Pattern with the Phase 3 row from the Stage Orchestration Contract.
Input handoff: task + Stage 1 depth + project-domain summary when present.
Success log: "Stage 1 complete. Context Document written."

If Stage 1 still fails after its single retry, abort the composite with: "Stage 1 (Understand) failed. Cannot proceed without Context Document. Run `/swe understand` standalone for diagnostics."

## Phase 4: Stage 2 — Constrain

Use the Shared Stage Execution Pattern with the Phase 4 row from the Stage Orchestration Contract.
Input handoff: task + `.swe/active/01-understand.md` + Stage 2 depth + project-constraints summary when present.
Success log: "Stage 2 complete. Constraint Profile written. {n} constraints across {m}/6 categories."

If Stage 2 still fails after its single retry, offer degraded continuation.
"Stage 2 (Constrain) failed. Options: (A) Proceed to Design without constraints and write `.swe/active/02-constrain.md` as `missing — design may be over/under-scoped`. (B) Abort and run `/swe constrain` standalone."

## Phase 5: Stage 3 — Design

Use the Shared Stage Execution Pattern with the Phase 5 row from the Stage Orchestration Contract.
Input handoff: task + `.swe/active/01-understand.md` + `.swe/active/02-constrain.md` + Stage 3 depth + project-architecture summary when present.
Success log: "Stage 3 complete. Architecture Spec written. {n} decisions, {m} traced to constraints."

If Stage 3 still fails after its single retry, abort the composite with: "Stage 3 (Design) failed. Architecture Spec required for Interface stage. Run `/swe design` standalone for diagnostics."

## Phase 6: Stage 4 — Interface

Use the Shared Stage Execution Pattern with the Phase 6 row from the Stage Orchestration Contract.
Input handoff: task + `.swe/active/03-design.md` + `.swe/active/02-constrain.md` + Stage 4 depth + project-interfaces summary when present.
Success log: "Stage 4 complete. Interface Contracts written. {n} interfaces defined."

If Stage 4 still fails after its single retry, preserve the completed Stage 1-3 artifacts and stop with: "Stage 4 (Interface) failed, but Stages 1-3 completed successfully. Run `/swe interface` standalone to complete the specification."

## Output Contracts

| Mode | Trigger | Payload location | Required sections or fields |
|------|---------|------------------|-----------------------------|
| Full specification | Ambiguity gate passes and Stages 1-4 complete | Phase 7 review plus Phase 8 report | `Artifact Chain`, `Key Highlights`, `Contract Chain Validation`, `Next Steps`, and `See Also`. |
| Ambiguity abort | Initial or rescored ambiguity score is `> 0.5` | `.swe/active/00-ambiguity.md` plus a blocking message | `Status`, score breakdown, weakest axis, missing information summary, and stop reason. |
| Degraded continuation | Stage 2 fails and the user chooses option A | `.swe/active/02-constrain.md` placeholder plus downstream artifacts if produced | `Artifact Chain` with Stage 2 marked `degraded`, unconstrained-design risk, placeholder path, and recovery command `/swe constrain`. |
| Partial chain | Stage 4 fails after Stage 1-3 succeed | Phase 7 review plus Phase 8 report | `Artifact Chain` with partial statuses, completed artifact paths, missing Interface stage, exact recovery command `/swe interface`, and next-step guidance. |
| Fatal stage failure | Stage 1 or Stage 3 fails after retry, or the user aborts after Stage 2 failure | User-facing error only beyond already-written artifacts | Last valid artifact, failed stage, stop reason, and exact standalone resume command. |

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
**Pre-spec gate**: `.swe/active/00-ambiguity.md`
**Artifacts**: 4 stage files in `.swe/active/`

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

### See Also
- **Analyst agent** (`agents/swe/analyst.md`) — executes specification analysis
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
- **Artifact Contracts** (`skills/swe/methodology/references/artifact-contracts.md`) — stage input/output specifications

## Rules

- Each stage delegates to the analyst agent — the command orchestrates, not executes
- Artifacts are written sequentially: the pre-spec ambiguity gate writes `.swe/active/00-ambiguity.md`, then each stage's output becomes the next stage's input
- Artifact paths use `.swe/active/00-ambiguity.md` for the pre-spec gate and `.swe/active/{NN}-{stage}.md` for the Stage 1-4 chain
- User checkpoint occurs once at Phase 7 (Review) — individual stages do not pause for user review when run as part of spec
- Backward transitions within spec: if a downstream stage reveals upstream gaps, the command re-runs the upstream stage (not the primitive command) with additional context
- Failure isolation: each stage can fail independently. Prior completed artifacts remain valid
- Graceful degradation: Stage 2 failure offers unconstrained design option. Stage 4 failure preserves Stages 1-3 artifacts
