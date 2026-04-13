---
name: swe:design
description: "Use when you need to choose an architecture, algorithm, or data shape within known constraints"
argument-hint: "<task-description> [--fast] [--depth Skip|Light|Standard|Deep] [--artifact <constraint-profile-path>]"
allowed-tools: Read, Glob, Grep, Write, Task
---

# Design — Architecture Design (Stage 3)

Make architecture decisions, select algorithms and data structures, all bounded by the Constraint Profile, to produce an Architecture Spec.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 4 | analyst | Architecture analysis — pattern evaluation, alternative comparison, constraint traceability |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text | Required — abort if empty |
| `--depth` | Explicit depth override | None (decided in Phase 2) |
| `--artifact` | Path to Constraint Profile (Stage 2 output) | None |

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe design <task-description> [--depth Skip|Light|Standard|Deep] [--artifact <constraint-profile-path>]`"
- Abort

Validate `--depth` if provided. If invalid: error and abort.

## Phase 2: Depth Decision

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| `task` is empty | 1 | Abort with the usage error and do not write artifacts. |
| `--depth` value is invalid | 1 | Abort with the validation error and do not write artifacts. |
| `--depth` is provided | 2 | Use the explicit depth and skip automatic scoring. |
| `--fast` is active and the task fits an existing pattern with no new structural decisions | 2, 5, 6 | Take the skip path, write the minimal design artifact, and jump to Phase 6. |
| `--fast` is active but structural decisions are still required | 2 | Force Light depth and continue with normal analysis. |
| Explicit `Skip` depth is requested and no new components or modules are introduced | 2, 5, 6 | Take the skip path and write the minimal design artifact. |
| Explicit `Skip` depth is requested but structural changes are required | 2 | Override Skip to Light and continue with normal analysis. |
| Neither `--depth` nor `--fast` is provided | 2 | Score the task via `skills/swe/methodology/references/depth-system.md` and apply stage-specific triggers. |
| `--artifact` is provided and readable | 3 | Load the Constraint Profile and use it for traceability checks. |
| `--artifact` is provided but missing | 3 | Warn and continue without the Constraint Profile. |
| `.swe/active/01-understand.md` exists | 3 | Load the Context Document at summary-only Light depth or full Standard+ depth. |
| No Constraint Profile is available from `--artifact` or `.swe/active/02-constrain.md` | 3 | Continue with unconstrained design and warn that traceability will be incomplete. |
| `docs/specs/project/architecture.md` exists | 4 | Include its `## Summary` in the analyst input packet. |
| Analyst times out or errors | 4 | Retry once with the Light-depth fallback prompt, then stop and report the failure. |
| Constraint traceability is missing while a Constraint Profile exists | 4 | Retry once with an explicit traceability requirement. |
| Standard+ depth returns only one alternative | 4 | Retry once with an explicit minimum of two alternatives. |
| Command is invoked standalone | 5, 6 | Present the artifact review checkpoint before the final report. |
| Command is invoked by `/swe spec` | 5, 6 | Skip the Phase 5 review checkpoint and continue directly to the Phase 6 report. |

### Depth Scoring

If no `--depth` override, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md` (score 5 factors → sum → map to depth level). Stage-specific triggers:

- Deep when architecture or data model changes across bounded contexts
- Escalation: P95 < 200ms at 1000+ RPS

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

## Phase 3: Context Gathering

1. **Upstream artifact**: If `--artifact` is provided, read the Constraint Profile
   - Extract Hard constraints, Soft constraints, conflict resolutions
   - If artifact is missing: warn "Constraint Profile not found at {path}. Design without constraints risks over/under-engineering. Consider running `/swe constrain` first."
2. **Context Document**: Read `.swe/active/01-understand.md` if it exists. At Light depth, read summary only (`Read(file, limit: 15)`) per the Selective Load Matrix in `artifact-contracts.md`. At Standard+ depth, read in full. Extract domain model and affected components
3. **Codebase architecture**: Survey existing architecture patterns:
   - Module/package structure and dependency relationships
   - Existing architectural patterns (layered, hexagonal, event-driven, etc.)
   - Data model definitions (schemas, types, interfaces)
   - Prior architecture decision records (ADRs) if present

If no Constraint Profile available (no `--artifact`, no matching file):

- Log: "No Constraint Profile found. Proceeding with unconstrained design — all design decisions will lack traceability. Consider running `/swe constrain` first."

## Phase 4: Analysis

> Agent: **analyst**

Delegate architecture design to the analyst agent via Task tool:

- **Input**: Task description + Constraint Profile content (if available) + Context Document content (if available) + codebase architecture signals + depth level + Project Context (if `docs/specs/project/architecture.md` exists, include its `## Summary` section)
- **Instructions**: "Start your output with a `## Summary` section (3-5 sentences capturing the chosen architectural pattern, key decisions, and constraint traceability), then continue with full content. Execute Procedure 3 (Design) at {depth} depth. Follow the template at `templates/swe/architecture-spec.md` — include sections matching the depth markers for this depth level. Consider 2-3 alternatives (minimum 2 for Standard/Deep). Evaluate against the Constraint Profile. Design top-down: System > Component > Code. At Deep depth, use the 3-field ADR format (Context/Decision/Consequences). Ensure every design decision traces to at least one constraint in the Traceability Matrix. Return the artifact content as structured markdown."
- **Expected output**: Architecture Spec content (structured markdown)

### Recovery

Recovery is bounded to 2 analyst attempts total per invocation: the initial run plus 1 retry.

| Failure | Max Retries | Stagnation Detection | Stop Behavior |
|---------|-------------|----------------------|---------------|
| Agent timeout or error | 1 | The retry also times out or returns another execution error. | Retry once with the Light-depth fallback prompt, then report failure and do not write an artifact. |
| Missing constraint traceability while a Constraint Profile exists | 1 | The retry still leaves any design decision without a constraint reference. | Retry once with an explicit Traceability Matrix requirement, then stop and tell the user to repair the constraint inputs first. |
| Standard+ output contains only one alternative | 1 | The retry still returns only one distinct alternative or no trade-off comparison. | Retry once with an explicit minimum of 2 alternatives, then stop and surface the incompleteness. |
| Constraint Profile is unavailable | 0 | Stagnation does not apply because missing inputs are not improved by retry. | Continue with a warning, mark traceability as unavailable in the artifact, and recommend `/swe constrain` before downstream stages. |

## Phase 5: Output

Write the Architecture Spec artifact:

1. Output path: `.swe/active/03-design.md`
2. Wrap analyst output in artifact template:

```markdown
# Architecture Spec: {task summary}

**Stage**: 3 — Design (DDD)
**Depth**: {depth}
**Task**: {task description}
**Upstream**: {constraint profile path or "none"}
**Date**: {date}

---

{analyst output content}

---

**Exit Criteria Check**:
- [ ] Every design decision traces to at least one constraint (Standard+)
- [ ] No orphan decisions without justification (Standard+)
- [ ] Complexity and failure modes acknowledged (Standard+)
- [ ] Interface definitions sufficient to start Stage 4 without ambiguity (Standard+)
- [ ] {At Deep} All significant decisions have ADRs
- [ ] {At Deep} Deployment view covers build → package → deliver

**Critical Rule**: No code written at the Design stage.
```

3. Write to output path

Present artifact to user:

```markdown
## Architecture Spec: {task summary}

**Depth**: {depth}
**Path**: `.swe/active/03-design.md`

### Summary
**Pattern**: {selected architectural pattern}
**Key decisions**: {count}
**Alternatives evaluated**: {count}
**Constraint traceability**: {n}/{total} decisions traced

### Key Decisions
{top 3-5 design decisions with driving constraints}

Review the artifact and confirm to proceed, or request revisions.
```

## Phase 6: Report

```markdown
## Stage 3 Complete: Design

**Artifact**: `.swe/active/03-design.md`
**Depth**: {depth}

### Next Stage
Run Stage 4 (Interface) to define contracts between the designed components:
`/swe interface "{task}" --depth {recommended_depth} --artifact .swe/active/03-design.md`

### See Also
- `/swe constrain "{task}"` — revisit Stage 2 if design reveals new constraints
- `/swe spec "{task}"` — run all 4 specification stages
- `/swe understand "{task}"` — revisit Stage 1 if design reveals domain gaps
- **Analyst agent** (`agents/swe/analyst.md`) — executes architecture design
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
```

## Rules

- Analyst agent is read-only — only the command writes artifacts
- Architecture Spec is the input contract for Stage 4 (Interface) — see `skills/swe/methodology/references/artifact-contracts.md`
- **Never write code at the Design stage** — resist the urge to prototype. Design produces decisions, not implementation
- Constraint traceability is mandatory when a Constraint Profile exists — orphan design decisions (no constraint reference) must be flagged
- When invoked by `/swe spec`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6
