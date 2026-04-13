---
name: validation-methodology
description: This skill provides plugin component validation methodology. It should be activated when an agent needs to "validate a plugin component", "check frontmatter correctness", "verify naming conventions", "detect command name collisions", "audit path constraints", "pre-check before evaluation", "validate hook configuration", or "run a structural correctness check".
summary: Guides structural plugin validation for frontmatter, naming, paths, references, hooks, and blocking error reports.
version: 1
tags: [core, methodology, validation, frontmatter, structural-checks]
preamble_tier: 4
---

# Validation Methodology

## Core Rule

If you are running as a subagent dispatched by a command, skip loading this skill.
Commands already embed the relevant methodology inline.

**"Correct before good."**

Validation catches structural and mechanical failures before anyone spends time scoring quality.
If validation fails, fix the structure first and delay evaluation until the component is loadable, name-safe, and path-safe.
Use this file for operating rules, and load the mapped references when you need the detailed check matrix, field rules, or post-generation gate procedure.
The method is intentionally binary because structural correctness is not a matter of style.

## Gotchas

These are the failures most likely to block discovery, loading, or safe execution.

| Pitfall | Type | Prevention |
|---------|------|------------|
| Empty `.mcp.json` left in place | Plugin | Delete empty MCP configs entirely instead of keeping placeholders |
| Missing or path-mismatched command `name` | Command | Derive the `name` directly from the file path |
| Generic skill description | Skill | Use specific third-person trigger phrases in double quotes |
| Missing agent `tools` | Agent | Add an explicit minimum-privilege tool list |
| Parent-directory traversal in paths | Any | Reject `../` and keep paths rooted under `./` |
| Absolute filesystem paths | Any | Convert them to relative paths or `${CLAUDE_PLUGIN_ROOT}` where appropriate |
| Missing agent `color` | Agent | Treat `color` as required, not optional |
| Built-in command collision risk | Command | Let namespacing from the path prevent collisions |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The component loads in practice, so the field mismatch is cosmetic" | Downgrading required frontmatter or naming failures to warnings | Treat required fields, names, and path mismatches as blocking errors |
| "Evaluation will catch the important problems" | Skipping structural validation before quality scoring | Run validation first and delay evaluation until loadability and references are correct |
| "The path works on this machine" | Keeping absolute or parent-traversal paths in component metadata | Convert paths to rooted relative forms or `${CLAUDE_PLUGIN_ROOT}` as required by the path policy |

## Workflow

Run type-specific checks first so the cross-cutting checks do not produce misleading noise.

1. Identify the component type from its location, structure, and frontmatter.
2. Run the type-specific field and format checks for that component class.
3. Run cross-cutting checks for naming, paths, and referenced-component existence.
4. Produce a PASS or FAIL report that separates blocking errors from non-blocking warnings.

Do not continue into evaluation until the blocking errors are gone.

## Decision Rules

Use these rules to separate hard failures from secondary cleanup.

| Decision Point | Rule |
|----------------|------|
| Validation vs evaluation | Validation always runs first because structural failure blocks meaningful scoring |
| Type detection | Use the path and frontmatter together, and stop if the component still does not classify cleanly |
| Blocking failures | Missing required fields, invalid names, bad paths, and broken references are errors, not warnings |
| Command naming | Standard command files require `{module}:{command}`, router files require `{module}`, and descriptions must start with `Use when` |
| Path policy | Use `./` for relative paths, reject `../`, and use `${CLAUDE_PLUGIN_ROOT}` for hook script paths |
| Hook safety | Hooks need valid events, targeted matchers, explicit timeouts, and fail-open script behavior on parse errors |
| Reference existence | Missing linked agents, skills, or templates are structural errors because they break runtime navigation |

## Reference Map

Load the combined matrix for the summary view, then pull the deeper references only for the failing area.
That keeps validation work narrow and prevents unnecessary context loading.

| Need | Reference |
|------|-----------|
| Combined validation matrix, report format, path rules, and checklists | `${CLAUDE_SKILL_DIR}/references/validation-check-matrix.md` |
| Detailed field requirements and edge cases by component type | `${CLAUDE_SKILL_DIR}/references/frontmatter-and-fields.md` |
| Naming rules and collision prevention | `${CLAUDE_SKILL_DIR}/references/naming-and-collision.md` |
| Real pitfall examples and fixes | `${CLAUDE_SKILL_DIR}/references/common-pitfalls.md` |
| Post-generation validation gate procedure | `${CLAUDE_SKILL_DIR}/references/quality-gate-procedure.md` |

## See Also

These components are the most common callers or downstream consumers of validation results.

- **evaluator agent** (`agents/core/evaluator.md`) - Runs structural validation before quality scoring
- **evaluate command** (`commands/core/evaluate.md`) - Calls structural validation as the pre-evaluation gate
- **generate command** (`commands/core/generate.md`) - Uses validation before presenting generated artifacts
- **evaluation-methodology** (`skills/core/evaluation/SKILL.md`) - Quality scoring that assumes structural correctness
- **plugin-component-quality-patterns** (`docs/specs/knowledge/plugin-component-quality-patterns.md`) - Useful once the component is structurally valid and ready for quality analysis
- **compound-engineering-plugin-patterns** (`docs/specs/knowledge/compound-engineering-plugin-patterns.md`) - Documents the namespacing patterns that validation enforces
