---
description: "Stage 3 — Architecture decisions, algorithm and data structure selection, bounded by constraints (DDD)"
argument-hint: "<task-description> [--depth Skip|Light|Standard|Deep] [--artifact <constraint-profile-path>]"
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

If `--depth` was provided, use directly. Log: "Depth override: {depth}."

Otherwise, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md`:

1. Score 5 factors, sum (5-15), map to depth
2. Check stage-specific minimum depth triggers:
   - Deep when architecture or data model changes across bounded contexts
3. Check escalation rules (P95 < 200ms at 1000+ RPS escalates Design)

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

### Skip Handling

If depth is **Skip**: Verify — "Implementation within existing architecture, no structural decisions" per `depth-system.md`. If task involves new components, modules, or significant data model changes:

- Log: "Skip not applicable — task requires structural decisions. Defaulting to Light."
- Set depth to Light

Otherwise: produce minimal skip artifact noting "No architecture changes — implementation within existing structure" and jump to Phase 6.

## Phase 3: Context Gathering

1. **Upstream artifact**: If `--artifact` is provided, read the Constraint Profile
   - Extract Hard constraints, Soft constraints, conflict resolutions
   - If artifact is missing: warn "Constraint Profile not found at {path}. Design without constraints risks over/under-engineering. Consider running `/swe constrain` first."
2. **Context Document**: Read `.swe/active/01-understand.md` if it exists. Extract domain model and affected components
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

- **Input**: Task description + Constraint Profile content (if available) + Context Document content (if available) + codebase architecture signals + depth level
- **Instructions**: "Execute Procedure 3 (Design) at {depth} depth. Follow the template at `templates/swe/architecture-spec.md` — include sections matching the depth markers for this depth level. Consider 2-3 alternatives (minimum 2 for Standard/Deep). Evaluate against the Constraint Profile. Design top-down: System > Component > Code. At Deep depth, use the 3-field ADR format (Context/Decision/Consequences). Ensure every design decision traces to at least one constraint in the Traceability Matrix. Return the artifact content as structured markdown."
- **Expected output**: Architecture Spec content (structured markdown)

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once: "Produce a Light-depth Architecture Spec: key design decision + rationale in 3-5 sentences." If retry fails: report error |
| Missing constraint traceability | Log gap. If Constraint Profile was provided: retry with explicit instruction to add traceability matrix. If no Constraint Profile: accept without traceability but warn in artifact |
| Single alternative only (Standard+ depth) | Retry with instruction: "Consider at least 2 alternatives with trade-off comparison." |

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
```

## Rules

- Analyst agent is read-only — only the command writes artifacts
- Architecture Spec is the input contract for Stage 4 (Interface) — see `skills/swe/methodology/references/artifact-contracts.md`
- **Never write code at the Design stage** — resist the urge to prototype. Design produces decisions, not implementation
- At Standard/Deep depth, require minimum 2 architectural alternatives with trade-off analysis
- Constraint traceability is mandatory when a Constraint Profile exists — orphan design decisions (no constraint reference) must be flagged
- Backward transition: if design reveals constraint gaps, recommend returning to Stage 2 (Constrain)
- When invoked by `/swe spec`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6
