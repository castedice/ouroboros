---
name: swe:interface
description: "Use when you need to define contracts between components, including types, invariants, and error handling"
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

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| `task` is empty | 1 | Abort with the usage error and do not write artifacts. |
| `--depth` value is invalid | 1 | Abort with the validation error and do not write artifacts. |
| `--depth` is provided | 2 | Use the explicit depth and skip automatic scoring. |
| `--fast` is active and the change stays within one module boundary with no public contract changes | 2, 5, 6 | Take the skip path, write the minimal interface artifact, and jump to Phase 6. |
| `--fast` is active but exported signatures, types, or schemas change | 2 | Force Light depth and continue with normal analysis. |
| Explicit `Skip` depth is requested and the task is internal refactoring only | 2, 5, 6 | Take the skip path and write the minimal interface artifact. |
| Explicit `Skip` depth is requested but new public APIs, changed signatures, or new schemas appear | 2 | Override Skip to Light and continue with normal analysis. |
| Neither `--depth` nor `--fast` is provided | 2 | Score the task via `skills/swe/methodology/references/depth-system.md` and apply stage-specific triggers. |
| `--artifact` is provided and readable | 3 | Load the Architecture Spec and use it as the primary contract source. |
| `--artifact` is provided but missing | 3 | Warn and continue without Architecture Spec context. |
| Prior Stage 1 or Stage 2 artifacts exist | 3 | Load them at summary-only Light depth or full Standard+ depth to inform naming and SLA contracts. |
| No Architecture Spec is available from `--artifact` or `.swe/active/03-design.md` | 3 | Continue from existing codebase patterns and warn that contract alignment may drift. |
| `docs/specs/project/interfaces.md` exists | 4 | Include its `## Summary` in the analyst input packet. |
| Analyst times out or errors | 4 | Retry once with the simplified Light-depth fallback prompt, then stop and report the failure. |
| Output contains `any` or untyped public structures | 4 | Retry once with explicit precision requirements. |
| Interfaces are still not testable without implementation | 4 | Retry once with explicit testability instructions, then stop and report the gap if it remains. |
| Command is invoked standalone | 5, 6 | Present the artifact review checkpoint before the final report. |
| Command is invoked by `/swe spec` | 5, 6 | Skip the Phase 5 review checkpoint and continue directly to the Phase 6 report. |
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

Recovery is bounded to 2 analyst attempts total per invocation: the initial run plus 1 retry.

| Failure | Max Retries | Stagnation Detection | Stop Behavior |
|---------|-------------|----------------------|---------------|
| Agent timeout or error | 1 | The retry also times out or returns another execution error. | Retry once with the Light-depth fallback prompt, then report failure and do not write an artifact. |
| Missing type precision (`any` or untyped structures) | 1 | The retry still contains `any`, untyped dictionaries, or other imprecise public types. | Retry once with explicit precision requirements, then stop and surface the blocking gap to the user. |
| Non-testable interfaces | 1 | The retry still requires implementation knowledge to write or run contract tests. | Retry once with explicit testability instructions, then stop and recommend returning to Stage 3. |
| Missing Delta from Design section | 1 | The retry still omits signature or type changes from the Architecture Spec. | Retry once with an explicit Delta requirement, then stop and report the artifact as incomplete. |

## Output Contracts

| Mode | Trigger | Payload location | Required sections or fields |
|------|---------|------------------|-----------------------------|
| Normal | Phase 4 completes with a non-skip result | `.swe/active/04-interface.md` | `# Interface Contracts: {task summary}`, `**Stage**`, `**Depth**`, `**Task**`, `**Upstream**`, `**Date**`, analyst body, and `**Exit Criteria Check**`. |
| Skip | Fast-mode skip or validated Skip depth | `.swe/active/04-interface.md` | `# Interface Contracts: {task summary}`, `**Stage**`, `**Depth**`, `**Task**`, `**Upstream**`, `**Date**`, `## Summary`, `## Skip Reason`, `## Existing Interface Boundary`, and `## Next Stage Guidance`. |
| Error | Parse failure or unrecoverable analyst failure | User-facing error only | `Error`, `Failed Phase`, `Blocking Condition`, `Artifact Write: none`, and `Next Command`. |
| Composite handoff | Invoked by `/swe spec` | Same artifact as Normal or Skip plus the Phase 6 report | Artifact path, resolved depth, contract-chain completion status, next-stage command, and `See Also`. |

Phase 5 writes `.swe/active/04-interface.md` only for Normal or Skip mode.

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
