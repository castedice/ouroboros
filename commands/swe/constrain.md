---
description: "Stage 2 — Enumerate constraints and design boundaries using constraint-first methodology (SDD)"
argument-hint: "<task-description> [--depth Skip|Light|Standard|Deep] [--artifact <context-document-path>]"
allowed-tools: Read, Glob, Grep, Write, Task
---

# Constrain — Constraint Enumeration (Stage 2)

Enumerate constraints and boundaries before design, using the constraint-first methodology to produce a Constraint Profile.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 4 | analyst | Constraint enumeration — systematic category sweep, classification, conflict analysis |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text | Required — abort if empty |
| `--depth` | Explicit depth override | None (decided in Phase 2) |
| `--artifact` | Path to Context Document (Stage 1 output) | None |

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe constrain <task-description> [--depth Skip|Light|Standard|Deep] [--artifact <context-document-path>]`"
- Abort

If `--depth` is provided, validate against: Skip, Light, Standard, Deep. If invalid:

- Output: "Error: Invalid depth '{value}'. Must be one of: Skip, Light, Standard, Deep."
- Abort

## Phase 2: Depth Decision

If `--depth` was provided, use that value directly. Log: "Depth override: {depth}."

Otherwise, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md`:

1. Score 5 factors based on task description and available context
2. Sum scores (5-15) and map: 5-6 = Light, 7-10 = Standard, 11-15 = Deep
3. Check stage-specific minimum depth triggers:
   - Standard when any external dependency exists
4. Check escalation rules (security/compliance in scope escalates Constrain)

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

### Skip Handling

If depth is **Skip**: Verify skip is valid — "Pure refactoring with no new constraints" per `depth-system.md`. If the task description mentions new functionality, requirements, or external interfaces:

- Log: "Skip not applicable — task introduces new constraints. Defaulting to Light."
- Set depth to Light

Otherwise: produce a minimal skip artifact noting "No new constraints — pure refactoring" and jump to Phase 6.

## Phase 3: Context Gathering

1. **Upstream artifact**: If `--artifact` is provided, read the Context Document
   - Validate it contains required fields: Problem Statement, Affected Components
   - Extract domain model, success criteria, and ubiquitous language for constraint analysis context
   - If artifact is missing or unreadable: warn "Context Document not found at {path}. Proceeding without upstream context — constraint analysis may be less precise."
2. **Codebase survey**: Search for constraint-relevant signals:
   - Configuration files (limits, thresholds, timeouts)
   - Existing test assertions that encode implicit constraints
   - CI/CD configuration (deployment targets, build requirements)
   - Dependency manifests (technology constraints)
3. **If no upstream artifact and no `--artifact` flag**: Log "No Context Document provided. Consider running `/swe understand` first for better constraint coverage. Proceeding with task description only."

## Phase 4: Analysis

> Agent: **analyst**

Delegate constraint enumeration to the analyst agent via Task tool:

- **Input**: Task description + Context Document content (if available) + codebase constraint signals + depth level
- **Instructions**: "Execute Procedure 2 (Constrain) at {depth} depth. Follow the template at `templates/swe/constraint-profile.md` — include sections matching the depth markers for this depth level. Use the fixed column schema for all category tables. Sweep all 6 categories using detection questions from `skills/swe/constraint/references/constraint-categories.md`. Classify on 3 axes per `skills/swe/constraint/SKILL.md`. Identify conflicts per `skills/swe/constraint/references/conflict-resolution-patterns.md`. Populate the Open Questions Resolution section by resolving every A{n} from the upstream Context Document. Return the artifact content as structured markdown."
- **Expected output**: Constraint Profile content (structured markdown)

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once: "Produce a Light-depth Constraint Profile: bullet list of 3-5 dominant constraints with Hard/Soft classification." If retry fails: report error |
| Missing categories (fewer than 6 evaluated) | Log gap. If Standard+ depth: retry with explicit instruction to cover all 6. If Light: accept partial coverage |
| No constraints identified | Log warning: "No constraints found — verify this is a pure refactoring task. If not, consider `/swe understand` first for better context." |

## Phase 5: Output

Write the Constraint Profile artifact:

1. Output path: `.swe/active/02-constrain.md`
2. Wrap analyst output in artifact template:

```markdown
# Constraint Profile: {task summary}

**Stage**: 2 — Constrain (SDD)
**Depth**: {depth}
**Task**: {task description}
**Upstream**: {context document path or "none"}
**Date**: {date}

---

{analyst output content}

---

**Exit Criteria Check**:
- [ ] All 6 categories swept (Standard+)
- [ ] 3-axis classification on every constraint (Standard+)
- [ ] Measurable thresholds on all Hard constraints
- [ ] Conflict analysis complete with resolution strategies (Standard+)
- [ ] Stage 1 Open Questions resolved or escalated (Standard+)
- [ ] Assumption registry populated (Standard+)
- [ ] {At Deep} Priority ranking covers all constraints
- [ ] {At Deep} Trade-off matrices for major decisions
```

3. Write to output path

Present artifact to user for review:

```markdown
## Constraint Profile: {task summary}

**Depth**: {depth}
**Path**: `.swe/active/02-constrain.md`

### Summary
**Hard constraints**: {count} | **Soft constraints**: {count} | **Assumptions**: {count}
**Conflicts identified**: {count}

### Key Constraints
{top 3-5 most impactful constraints}

### Conflicts
{brief conflict summary if any}

Review the artifact and confirm to proceed, or request revisions.
```

## Phase 6: Report

```markdown
## Stage 2 Complete: Constrain

**Artifact**: `.swe/active/02-constrain.md`
**Depth**: {depth}
**Coverage**: {n}/6 categories evaluated

### Next Stage
Run Stage 3 (Design) to make architecture decisions bounded by these constraints:
`/swe design "{task}" --depth {recommended_depth} --artifact .swe/active/02-constrain.md`

### See Also
- `/swe understand "{task}"` — revisit Stage 1 if constraints reveal domain gaps
- `/swe spec "{task}"` — run all 4 specification stages
- `/swe interface` — Stage 4 (after Design)
```

## Rules

- Analyst agent is read-only — only the command writes artifacts
- Constraint Profile is the input contract for Stage 3 (Design) — see `skills/swe/methodology/references/artifact-contracts.md`
- At Standard+ depth, all 6 constraint categories must be evaluated — enforce via analyst instructions
- Constraints must follow the quality standard from `skills/swe/constraint/SKILL.md`: Specific, Measurable, Time-bounded, Owned, Evidence-backed
- Backward transition: if constraint enumeration reveals domain understanding gaps, recommend returning to Stage 1 (Understand) rather than proceeding
- When invoked by `/swe spec`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6
