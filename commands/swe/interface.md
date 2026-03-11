---
description: "Stage 4 — Define contracts between components: types, error conditions, invariants (SDD)"
argument-hint: "<task-description> [--fast] [--depth Skip|Light|Standard|Deep] [--artifact <architecture-spec-path>]"
allowed-tools: Read, Glob, Grep, Write, Task
---

# Interface — Contract Definition (Stage 4)

Define contracts between components — public interfaces, types, error conditions, and invariants — to produce Interface Contracts.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 4 | analyst | Interface design — contract extraction from architecture, type definition, error condition enumeration |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text | Required — abort if empty |
| `--depth` | Explicit depth override | None (decided in Phase 2) |
| `--artifact` | Path to Architecture Spec (Stage 3 output) | None |

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe interface <task-description> [--depth Skip|Light|Standard|Deep] [--artifact <architecture-spec-path>]`"
- Abort

Validate `--depth` if provided. If invalid: error and abort.

## Phase 2: Depth Decision

If `--depth` was provided, use directly. Log: "Depth override: {depth}."

Otherwise, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md`:

1. Score 5 factors, sum (5-15), map to depth
2. Check stage-specific minimum depth triggers:
   - Standard for any public API or cross-team contract
3. Check escalation rules (2+ teams depend on changed interfaces escalates Interface)

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

### Fast Mode Skip

When `fast_mode` is active (from `--fast` flag), apply relaxed skip condition: **Skip when the change is within a single module boundary with no public interface changes**. If the task modifies only internal implementation without changing any exported function signatures, types, or event schemas, produce a minimal skip artifact noting "Interface skipped — change within single module boundary" and jump to Phase 6. Otherwise, proceed at Light depth.

### Skip Handling

If depth is **Skip**: Verify — "Internal refactoring with no interface changes" per `depth-system.md`. If task involves new public APIs, changed function signatures, or new event schemas:

- Log: "Skip not applicable — task changes interfaces. Defaulting to Light."
- Set depth to Light

Otherwise: produce minimal skip artifact noting "No interface changes — internal refactoring only" and jump to Phase 6.

## Phase 3: Context Gathering

1. **Upstream artifact**: If `--artifact` is provided, read the Architecture Spec
   - Extract component breakdown, data model, and design decisions
   - If artifact is missing: warn "Architecture Spec not found at {path}. Interface design without architecture context risks misaligned contracts. Consider running `/swe design` first."
2. **Prior artifacts**: Search `.swe/active/` for Context Document and Constraint Profile to inform interface design. At Light depth, read summary only (`Read(file, limit: 15)`) per the Selective Load Matrix in `artifact-contracts.md`. At Standard+ depth, read in full:
   - Context Document: domain model, ubiquitous language (for naming interfaces)
   - Constraint Profile: performance constraints (for SLA definitions in contracts), technology constraints (for type system choice)
3. **Existing interfaces**: Survey codebase for existing interfaces:
   - Type definitions, interface files, abstract classes
   - API schemas (OpenAPI, protobuf, GraphQL)
   - Event schemas and message formats
   - Existing test assertions that encode interface expectations

If no Architecture Spec available:

- Log: "No Architecture Spec found. Interface contracts will be based on existing codebase patterns and task description. Consider running `/swe design` first."

## Phase 4: Analysis

> Agent: **analyst**

Delegate interface definition to the analyst agent via Task tool:

- **Input**: Task description + Architecture Spec content (if available) + Constraint Profile content (if available) + existing interface patterns + depth level + Project Context (if `docs/specs/project/interfaces.md` exists, include its `## Summary` section)
- **Instructions**: "Start your output with a `## Summary` section (3-5 sentences capturing interfaces defined, key type decisions, and notable error conditions), then continue with full content. Execute Procedure 4 (Interface) at {depth} depth. Follow the template at `templates/swe/interface-contracts.md` — include sections matching the depth markers for this depth level. Always populate the Delta from Design section — if types or signatures changed from the Architecture Spec, document every change with reason. Use named structs for all public return types (no raw tuples). Use precise types — no `any`, no untyped dictionaries. Verify each interface is testable without implementation. At Standard+ depth: include the Test Suggestions section with full implementation detail — constructor signatures with parameter order, source module paths for mock targeting, and parameter style (object vs positional) for each function. These details prevent test-contract mismatches during Stage 5. Return the artifact content as structured markdown."
- **Expected output**: Interface Contracts content (structured markdown)

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once: "Produce Light-depth Interface Contracts: function signatures with type annotations and docstrings." If retry fails: report error |
| Missing type precision (uses `any` or untyped) | Retry with instruction: "Replace all `any` types and untyped structures with precise type definitions." |
| Non-testable interfaces | Log warning. Retry with instruction: "Ensure each interface can be tested without implementation — add input/output examples." |

## Phase 5: Output

Write the Interface Contracts artifact:

1. Output path: `.swe/active/04-interface.md`
2. Wrap analyst output in artifact template:

```markdown
# Interface Contracts: {task summary}

**Stage**: 4 — Interface (SDD)
**Depth**: {depth}
**Task**: {task description}
**Upstream**: {architecture spec path or "none"}
**Date**: {date}

---

{analyst output content}

---

**Exit Criteria Check**:
- [ ] All types have explicit definitions — no `any` or untyped structures
- [ ] All public return types are named structs (no raw tuples)
- [ ] Delta from Design section complete (even if "no changes")
- [ ] {At Standard+} Error contract covers caller vs system with recovery
- [ ] {At Standard+} Every trait has invariants and pre/post conditions
- [ ] {At Standard+} Concurrency model explicitly documented
- [ ] {At Standard+} Usage examples cover happy + error paths
- [ ] {At Deep} Contract tests cover all invariants
```

3. Write to output path

Present artifact to user:

```markdown
## Interface Contracts: {task summary}

**Depth**: {depth}
**Path**: `.swe/active/04-interface.md`

### Summary
**Interfaces defined**: {count}
**Type definitions**: {count}
**Error conditions**: {count}

### Key Interfaces
{top 3-5 interfaces with signature summaries}

Review the artifact and confirm to proceed, or request revisions.
```

## Phase 6: Report

```markdown
## Stage 4 Complete: Interface

**Artifact**: `.swe/active/04-interface.md`
**Depth**: {depth}

### Specification Complete
All 4 specification stages are done. The artifacts form a complete contract chain:
1. Context Document → 2. Constraint Profile → 3. Architecture Spec → 4. **Interface Contracts**

### Next Stage
Run Stage 5 (Test) to write tests against these interface contracts:
`/swe test "{task}" --artifact .swe/active/04-interface.md`

### See Also
- `/swe design "{task}"` — revisit Stage 3 if interface design reveals architecture gaps
- `/swe spec "{task}"` — run all 4 specification stages in sequence
- `/swe dev "{task}"` — run Stages 5-8 (development) with these contracts
- **Analyst agent** (`agents/swe/analyst.md`) — executes interface design
- **Artifact Contracts** (`skills/swe/methodology/references/artifact-contracts.md`) — stage input/output specifications
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
```

## Rules

- Analyst agent is read-only — only the command writes artifacts
- Interface Contracts is the input contract for Stage 5 (Test) — see `skills/swe/methodology/references/artifact-contracts.md`
- **No `any` types in public interfaces** — enforce type precision via analyst instructions and recovery
- Interfaces must be testable without implementation — this is the primary quality gate
- Backward transition: if interface design reveals architecture gaps, recommend returning to Stage 3 (Design)
- When invoked by `/swe spec`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6
