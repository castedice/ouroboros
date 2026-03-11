---
name: validation-methodology
description: This skill provides plugin component validation methodology. It should be activated when an agent needs to "validate a plugin component", "check frontmatter correctness", "verify naming conventions", "detect command name collisions", "audit path constraints", "pre-check before evaluation", "validate hook configuration", or "run a structural correctness check".
---

# Validation Methodology

## Core Principle

**"Correct before good."**

Validation catches structural and mechanical errors — wrong fields, invalid names, path violations, name collisions. These are binary (correct or not) and must be resolved before quality evaluation begins. A beautifully written agent with a missing `color` field will fail at load time. Validation prevents wasted evaluation and evolution cycles on components that are structurally broken.

## Validation vs Evaluation

Validation and evaluation serve different purposes and run at different stages:

| | Validation | Evaluation |
|---|---|---|
| **Question** | Is this component structurally correct? | Is this component high quality? |
| **Criteria** | Binary pass/fail rules (naming, fields, paths) | Graded quality criteria (C1-C5) |
| **When** | Before evaluation, after generation, during absorption | After validation passes |
| **Output** | Error list with fix instructions | Score + reasoning + improvements |
| **Failure mode** | Component will not load or will malfunction | Component works but underperforms |

Run validation first. If validation fails, fix structural errors before investing in evaluation.

## Validation Workflow

### Step 1: Identify Component Type

Determine the target type from location and file structure:

| Location Pattern | Type | Key Indicator |
|---|---|---|
| `commands/{module}/*.md` | Command | Markdown with phase-structured body |
| `agents/{module}/*.md` | Agent | Has `name`, `model`, `color` in frontmatter |
| `skills/{module}/SKILL.md` | Skill | Has `name`, `description` in frontmatter, `references/` sibling |
| `hooks/hooks.json` | Hook | JSON array with `event`, `matcher`, `command` entries |
| `plugin.json` | Plugin manifest | JSON with `name`, paths configuration |

### Step 2: Run Type-Specific Checks

Load the validation checklist for the identified type from [frontmatter-and-fields.md](./references/frontmatter-and-fields.md).
Execute each check. Record pass/fail with specific evidence for failures.

### Step 3: Run Cross-Cutting Checks

Apply checks that span all component types:

1. **Naming conventions** — verify against regex rules (see [naming-and-collision.md](./references/naming-and-collision.md))
2. **Path constraints** — relative paths only, no `../` traversal
3. **Command name collisions** — check against built-in command list
4. **Inter-component references** — verify referenced agents/skills/templates exist

### Step 4: Produce Validation Report

```markdown
## Validation Report: {component name}

**Type**: {command|agent|skill|hook|plugin}
**Result**: {PASS|FAIL} ({n} errors, {m} warnings)

### Errors (must fix)

| # | Check | Expected | Actual | Fix |
|---|-------|----------|--------|-----|
| 1 | {check name} | {expected value} | {actual value} | {how to fix} |

### Warnings (recommended)

| # | Check | Issue | Recommendation |
|---|-------|-------|----------------|
| 1 | {check name} | {what was found} | {suggestion} |
```

Errors are structural failures that prevent correct operation. Warnings are deviations from
best practices that do not break functionality but reduce quality.

## Required Frontmatter Fields

Quick reference for all component types. For the complete field specification with examples and edge cases, see [frontmatter-and-fields.md](./references/frontmatter-and-fields.md).

| Type | Required Fields | Recommended Fields |
|---|---|---|
| Agent | `name`, `description`, `model`, `color` | `tools` |
| Skill | `name`, `description` | — |
| Command | — | `description`, `allowed-tools`, `argument-hint` |
| Hook (JSON) | `event`, `matcher`, `command`, `timeout` | `description` |

Note the asymmetry: agent frontmatter has 4 required fields while command frontmatter has none strictly required (all recommended). This reflects their different roles — agents must be discoverable and routable, commands are invoked explicitly by name.

## Common Pitfalls

Eight pitfalls extracted from official plugin development guidance and real plugin analysis.
For detailed examples and fix patterns, see [common-pitfalls.md](./references/common-pitfalls.md).

| # | Pitfall | Type | Detection | Fix |
|---|---------|------|-----------|-----|
| 1 | Empty `.mcp.json` | Plugin | File exists but contains `{}` or `[]` | Delete file entirely — empty MCP config causes load errors |
| 2 | Unnecessary `name` in command | Command | `name` field present but matches filename | Remove `name` — only override when avoiding collision |
| 3 | Generic skill description | Skill | Fewer than 5 trigger phrases in double quotes | Add 5+ specific trigger phrases in third person |
| 4 | Missing agent `tools` | Agent | No `tools` field in frontmatter | Add explicit tool list following minimum privilege |
| 5 | `../` in paths | Any | Path contains `../` traversal | Use `./` prefix relative paths only |
| 6 | Absolute paths | Any | Path starts with `/` | Convert to relative path from plugin root |
| 7 | Missing agent `color` | Agent | No `color` field in frontmatter | Add `color` — it is a required field |
| 8 | Built-in name collision | Command | Filename matches reserved command | Add `name: prefix:command` in frontmatter |

## Path Constraint Rules

All paths within plugin configuration must follow these rules:

| Rule | Valid | Invalid | Rationale |
|---|---|---|---|
| Relative paths only | `./commands/core/` | `/Users/x/plugin/commands/` | Portability across machines |
| No parent traversal | `./lib/utils.sh` | `../shared/utils.sh` | Security — prevent filesystem escape |
| `./` prefix required | `./agents/core/` | `agents/core/` | Explicit relative marker |
| `${CLAUDE_PLUGIN_ROOT}` for scripts | `${CLAUDE_PLUGIN_ROOT}/scripts/fmt.sh` | `/opt/plugin/scripts/fmt.sh` | Hook script portability |

Paths in `plugin.json` are additive to defaults, not replacements. Specifying `"commandsPath": ["./commands/"]` adds to the built-in command discovery, it does not replace it.

## Hook Validation Rules

Hooks have the most constrained validation because they execute automatically without user confirmation. Invalid hooks can block tools or crash sessions.

| Field | Valid Values | Common Mistake |
|---|---|---|
| `event` | Any of 17 supported events (see [frontmatter-and-fields.md](./references/frontmatter-and-fields.md) for full list) | Misspelled event name (silent failure) |
| `matcher` | Exact tool name or OR pattern (`Write\|Edit`) — some events use regex | Wildcard `*` matching all tools (performance) |
| `timeout` | 10-60s (typical), always required | Omitted timeout (risk of infinite hang) |
| `command` | Script path with `${CLAUDE_PLUGIN_ROOT}` | Hardcoded absolute path |

Hook scripts must handle JSON parse failure gracefully — `exit 0` on stdin parse error to allow the tool invocation to proceed. A script that crashes on malformed input will block every matched tool call.

## Naming Conventions

| Target | Rule | Regex | Example |
|---|---|---|---|
| Plugin name | Lowercase hyphenated | `/^[a-z][a-z0-9]*(-[a-z0-9]+)*$/` | `my-plugin`, `code-review` |
| Agent name | Lowercase hyphenated, 3-50 chars | `/^[a-z][a-z0-9-]{1,48}[a-z0-9]$/` | `evaluator`, `code-review-agent` |
| Command name | Filename-based (no extension) | Alphanumeric + hyphens | `evaluate`, `generate` |
| Collision override | `prefix:command` in frontmatter | — | `name: workflows:plan` |

### Built-in Commands (Reserved — Cannot Override)

```text
/help  /plan  /review  /init  /clear  /compact  /cost
/doctor  /login  /logout  /memory  /status  /mcp
/config  /permissions  /vim  /terminal-setup  /listen  /fast
```

Before naming any command, check this list. If a collision exists, add a `name` field in the command frontmatter with a namespaced prefix: `name: prefix:command`.

## Validation Checklist

Use this checklist to verify structural correctness of any plugin component:

### Universal Checks

- [ ] File is valid markdown (commands, agents, skills) or valid JSON (hooks, plugin.json)
- [ ] YAML frontmatter parses without errors (no tabs, proper quoting)
- [ ] All paths are relative with `./` prefix, no `../` traversal
- [ ] No absolute filesystem paths
- [ ] Referenced components (agents, skills, templates) exist at specified paths

### Agent Checks

- [ ] `name` field present (required)
- [ ] `description` field present with trigger condition (required)
- [ ] `model` field present with appropriate value (required)
- [ ] `color` field present (required)
- [ ] `tools` list follows minimum privilege principle
- [ ] Agent name matches regex: 3-50 chars, lowercase hyphenated

### Skill Checks

- [ ] `name` field present (required)
- [ ] `description` field present with 5+ trigger phrases in double quotes (required)
- [ ] Description uses third-person form (not second-person)
- [ ] SKILL.md exists as the main file
- [ ] `references/` directory exists if skill has detailed content

### Command Checks

- [ ] Command filename does not collide with built-in commands
- [ ] If collision exists, `name: prefix:command` override is present
- [ ] `description` field provides specific one-line summary
- [ ] `allowed-tools` follows minimum privilege
- [ ] `argument-hint` describes expected input format

### Hook Checks

- [ ] `event` is a valid event type
- [ ] `matcher` targets specific tools (no wildcard `*`)
- [ ] `timeout` is specified and within reasonable range
- [ ] `command` uses `${CLAUDE_PLUGIN_ROOT}` for script paths
- [ ] Script handles JSON parse failure with `exit 0`
- [ ] `description` field documents the hook's purpose

## See Also

- **evaluator agent** (`agents/core/evaluator.md`) — Runs structural validation checks before evaluation scoring
- **evaluate command** (`commands/core/evaluate.md`) — Phase 2.5 Structural Validation; invokes this skill's workflow as a pre-evaluation gate
- **generate command** (`commands/core/generate.md`) — Phase 5.5 structural validation; validates generated components before finalization
- **evaluation-methodology** (`skills/core/evaluation/SKILL.md`) — Quality scoring that follows validation; evaluation assumes structural correctness
- **plugin-component-quality-patterns** (`docs/specs/knowledge/plugin-component-quality-patterns.md`) — HIGH vs LOW quality patterns per component type
- **compound-engineering-plugin-patterns** (`docs/specs/knowledge/compound-engineering-plugin-patterns.md`) — Namespace collision avoidance pattern
