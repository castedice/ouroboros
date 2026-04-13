# Validation Check Matrix

## Validation vs Evaluation

Validation and evaluation answer different questions.
Validation asks whether the component is structurally correct.
Evaluation asks whether the structurally correct component is high quality.

| Dimension | Validation | Evaluation |
|-----------|------------|------------|
| Core question | Is the component structurally correct | Is the component high quality |
| Criteria style | Binary pass or fail checks | Scored quality criteria |
| Timing | Before evaluation, after generation, and during absorption | After validation passes |
| Output | Error and warning list with fixes | Scores, reasoning, strengths, and improvements |
| Failure meaning | The component may not load or may malfunction | The component works but underperforms |

## Report Format

Use a report that distinguishes blocking problems from advisory findings.

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

Errors block further evaluation or release.
Warnings record weaker practices that do not break the component today.

## Required Field Summary

| Type | Required Fields | Common Notes |
|------|-----------------|--------------|
| Agent | `name`, `description`, `model`, `color` | `tools` is strongly recommended |
| Skill | `name`, `description` | Description must use third-person trigger phrases |
| Command | `name`, `description` | `name` is path-derived and description must start with `Use when` |
| Hook entry | `event`, `matcher`, `command`, `timeout` | `description` is recommended |

## Path Constraints

| Rule | Valid | Invalid | Why |
|------|-------|---------|-----|
| Relative paths only | `./commands/core/` | `/Users/x/plugin/commands/` | Portability |
| No parent traversal | `./lib/util.sh` | `../shared/util.sh` | Security boundary |
| Explicit `./` prefix | `./agents/core/` | `agents/core/` | Unambiguous relative intent |
| Hook script root variable | `bash <plugin-root>/scripts/fmt.sh` | `/opt/plugin/scripts/fmt.sh` | Hook portability |

Paths in `plugin.json` are additive to defaults rather than replacements.

## Hook Rules

Hooks run automatically, so validation must be strict.

| Field | Requirement | Common Mistake |
|-------|-------------|----------------|
| `event` | Supported event name | Misspelled event that silently never fires |
| `matcher` | Specific tool or explicit OR pattern | Wildcard matchers that touch everything |
| `timeout` | Explicit bounded value | Missing timeout that can hang the session |
| `command` | Portable script path | Hardcoded absolute path |

Hook scripts should fail open on JSON parse errors.
They should return `exit 0` rather than blocking the matched tool call.

## Naming Conventions

| Target | Rule | Example |
|--------|------|---------|
| Plugin name | Lowercase hyphenated | `code-review` |
| Agent name | Lowercase hyphenated, 3 to 50 chars | `reviewer-agent` |
| Command name | `{module}:{command}` for normal command files | `core:evaluate` |
| Router command name | `{module}` for top-level router files | `pa` |

Reserved built-in command names still exist, but correct namespacing should already avoid collisions.
Validate the path-derived name rather than inventing special-case exceptions.

## Validation Checklist

### Universal Checks

- [ ] The file parses as valid markdown or valid JSON.
- [ ] YAML frontmatter parses without syntax errors.
- [ ] All paths use `./` or the plugin-root variable as required.
- [ ] No path uses `../`.
- [ ] No absolute filesystem path remains.
- [ ] Referenced components exist.

### Agent Checks

- [ ] `name` is present and follows the regex.
- [ ] `description` is present and describes the trigger.
- [ ] `model` is present.
- [ ] `color` is present.
- [ ] `tools` follows minimum privilege.

### Skill Checks

- [ ] `name` is present.
- [ ] `description` contains specific quoted trigger phrases in third person.
- [ ] `SKILL.md` is the main skill file.
- [ ] `references/` exists when the skill carries detailed material.

### Command Checks

- [ ] `name` matches the path-derived rule.
- [ ] Router files use the router exception only when applicable.
- [ ] `description` starts with `Use when`.
- [ ] `description` expresses trigger intent rather than workflow summary.
- [ ] `allowed-tools` and `argument-hint` are present when the command needs them.

### Hook Checks

- [ ] `event` is valid.
- [ ] `matcher` is specific.
- [ ] `timeout` is bounded and explicit.
- [ ] `command` uses a portable path.
- [ ] The script fails open on parse errors.
- [ ] `description` documents the hook's purpose when present.
