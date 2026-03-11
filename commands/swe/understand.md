---
description: "Stage 1 — Analyze requirements, model the problem domain, and survey existing code (DDD)"
argument-hint: "<task-description> [--fast] [--depth Skip|Light|Standard|Deep] [--artifact <path>]"
allowed-tools: Read, Glob, Grep, Write, Task
---

# Understand — Domain Analysis (Stage 1)

Analyze requirements, model the problem domain, and survey existing code to produce a Context Document.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 4 | analyst | Domain analysis — requirements parsing, domain modeling, codebase survey |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--fast` | Fast mode flag | false |
| `--depth` | Explicit depth override | None (decided in Phase 2) |
| `--artifact` | Path to upstream artifact (none for Stage 1) | None |

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe understand <task-description> [--depth Skip|Light|Standard|Deep]`"
- Abort

If `--depth` is provided, validate it is one of: Skip, Light, Standard, Deep. If invalid:

- Output: "Error: Invalid depth '{value}'. Must be one of: Skip, Light, Standard, Deep."
- Abort

## Phase 2: Depth Decision

**Precedence**: `--depth` always overrides `--fast`. When both are present, `--depth` wins.

| Condition | Depth |
|-----------|-------|
| `--depth` provided | Use that value directly. Log: "Depth override: {depth}." |
| `--fast` provided (no `--depth`) | Set depth to Light. Log: "Fast mode: depth set to Light." |
| Neither | Apply depth decision matrix below |

When neither flag is provided, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md`:

1. Score 5 factors (Task Scope, Risk Level, Domain Familiarity, Team Impact, Reversibility) based on the task description and codebase signals
2. Sum scores (range 5-15) and map to depth level:

| Score | Depth |
|-------|-------|
| 5-6 | Light |
| 7-10 | Standard |
| 11-15 | Deep |

3. Check stage-specific minimum depth triggers from `depth-system.md`:
   - Deep when domain terms are unstable or requirements conflict
4. Check escalation rules (security/compliance, migration size, etc.)

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

If depth is **Skip**: Log "Stage 1 (Understand) cannot be skipped per pipeline rules — Understand is always required. Defaulting to Light." Set depth to Light.

## Phase 3: Context Gathering

Survey the codebase to build analysis context:

1. **Codebase survey**: Use Glob and Grep to identify files related to the task description
   - Search for key terms from the task in file names and content
   - Identify affected modules, packages, or directories
   - Read key files (up to 10 most relevant) to understand current state
2. **Existing artifacts**: If `--artifact` is provided, read the file. For Stage 1 there is no mandatory upstream artifact, but a prior Context Document may exist for iteration
3. **Project conventions**: Check for `AGENTS.md`, `CLAUDE.md`, or project-specific documentation that establishes domain vocabulary

Log: "Context gathered: {n} relevant files identified across {m} modules."

If no relevant files found: Log "No existing code found related to this task. Proceeding with greenfield analysis."

## Phase 4: Analysis

> Agent: **analyst**

Delegate domain analysis to the analyst agent via Task tool:

- **Input**: Task description + gathered context (relevant file contents + file list) + depth level + Project Context (if `docs/specs/project/domain.md` exists, include its `## Summary` section)
- **Instructions**: "Start your output with a `## Summary` section (3-5 sentences capturing the problem, key domain concepts, and affected components), then continue with full content. Execute Procedure 1 (Understand) at {depth} depth. Follow the template at `templates/swe/context-document.md` — include sections matching the depth markers for this depth level. Use the exact column schemas and section formats defined in the template. Return the artifact content as structured markdown."
- **Expected output**: Context Document content (structured markdown)

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Produce a Light-depth Context Document: problem statement, affected files, key terms." If retry fails: report error to user |
| Incomplete output (missing required sections) | Log missing sections. If Problem Statement or Success Criteria missing: retry. Otherwise: proceed with partial artifact and note gaps |

## Phase 5: Output

Write the Context Document artifact:

1. Determine output path: `.swe/active/01-understand.md`
2. Wrap analyst output in artifact template:

```markdown
# Context Document: {task summary}

**Stage**: 1 — Understand (DDD)
**Depth**: {depth}
**Task**: {task description}
**Date**: {date}

---

{analyst output content}

---

**Exit Criteria Check**:
- [ ] Ubiquitous language stable enough to write constraints
- [ ] Component/context boundaries explicit
- [ ] Unknowns enumerated with resolution owners
- [ ] {At Standard+} Success criteria are measurable
- [ ] {At Deep} Context Map relationships defined
```

3. Write to output path via Write tool

Present artifact to user for review:

```markdown
## Context Document: {task summary}

**Depth**: {depth}
**Path**: `.swe/active/01-understand.md`

### Summary
{brief summary of key findings: problem, affected components, domain model highlights}

### Exit Criteria
{checklist status — which items are satisfied}

Review the artifact and confirm to proceed, or request revisions.
```

## Phase 6: Report

After user confirms (or on auto-proceed for composite invocation):

```markdown
## Stage 1 Complete: Understand

**Artifact**: `.swe/active/01-understand.md`
**Depth**: {depth}

### Next Stage
Run Stage 2 (Constrain) to enumerate design boundaries:
`/swe constrain "{task}" --depth {recommended_depth} --artifact .swe/active/01-understand.md`

### See Also
- `/swe spec "{task}"` — run all 4 specification stages in sequence
- `/swe design` — Stage 3 (after Constrain)
- **Analyst agent** (`agents/swe/analyst.md`) — executes domain analysis
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
- **Composed by**: `/swe spec` orchestrates this stage with Stages 2-4
```

## Rules

- Analyst agent is read-only during analysis — only the command writes artifacts
- Stage 1 (Understand) can never be skipped per pipeline methodology
- Context Document is the input contract for Stage 2 (Constrain) — see `skills/swe/methodology/references/artifact-contracts.md`
- Depth decision must be logged with factor scores for traceability
- Output path follows `.swe/active/{NN}-{stage}.md` convention
- When invoked by `/swe spec`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6
