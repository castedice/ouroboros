# Naming Conventions and Collision Prevention

> Reference for the validation-methodology skill. Naming rules, regex patterns, built-in command list, and collision resolution strategies.

## Plugin Name

### Rules

| Constraint | Value |
|---|---|
| Regex | `/^[a-z][a-z0-9]*(-[a-z0-9]+)*$/` |
| Start | Lowercase letter |
| Body | Lowercase letters, digits, hyphens |
| Hyphens | No consecutive hyphens, no trailing hyphen |
| Examples (valid) | `ouroboros`, `code-review`, `my-plugin-v2` |
| Examples (invalid) | `MyPlugin`, `code_review`, `123-plugin`, `plugin-` |

### Validation Procedure

```text
1. Check regex match
2. Verify no consecutive hyphens (--)
3. Verify first character is a letter
4. Verify last character is not a hyphen
```

---

## Agent Name

### Rules

| Constraint | Value |
|---|---|
| Regex | `/^[a-z][a-z0-9-]{1,48}[a-z0-9]$/` |
| Length | 3-50 characters |
| Format | Lowercase hyphenated |
| Start/End | Must start and end with alphanumeric |
| Uniqueness | Unique within the entire plugin (not just the module) |

### Naming Patterns

| Pattern | When to Use | Example |
|---|---|---|
| `{role}` | Single-purpose agent | `evaluator`, `researcher` |
| `{domain}-{role}` | Domain-specific variant | `code-reviewer`, `security-sentinel` |

### DO / DON'T

| DO | DON'T |
|----|-------|
| Use descriptive role names | Use generic names like `agent-1` |
| Keep names under 30 chars when possible | Create 50-char names that are hard to reference |
| Verify uniqueness across all modules | Assume module directories provide namespace isolation |

---

## Command Name

### Rules

| Constraint | Value |
|---|---|
| `name` field | Required on every command file |
| Standard format | `{module}:{command}` |
| Standard regex | `^[a-z][a-z0-9-]*:[a-z][a-z0-9-]*$` |
| Path invariant | `commands/core/evaluate.md` -> `core:evaluate` |
| Router exception | `commands/{module}.md` -> `name: {module}` |
| Legacy prefix | `ouroboros:` is invalid |

### Built-in Commands (Reserved)

These commands are built into Claude Code and cannot be overridden by plugin commands.
Mandatory namespacing prevents accidental collisions, so treat this list as a reserved-name sanity check rather than a conditional naming branch.

```text
/help           /plan           /review         /init
/clear          /compact        /cost           /doctor
/login          /logout         /memory         /status
/mcp            /config         /permissions    /vim
/terminal-setup /listen         /fast
```

**Total**: 17 reserved command names.

### Naming Procedure

```text
1. Every command file must declare `name`
2. For `commands/{module}/{command}.md`, set `name: {module}:{command}`
3. For `commands/{module}.md`, set `name: {module}`
4. Verify the declared name exactly matches the path-derived value
5. Reject legacy prefixes such as `ouroboros:`
```

### Examples

| Path | Required `name` | Notes |
|---|---|---|
| `commands/core/evaluate.md` | `core:evaluate` | Standard core command |
| `commands/swe/spec.md` | `swe:spec` | Standard SWE command |
| `commands/pa/ask.md` | `pa:ask` | Standard PA command |
| `commands/pa.md` | `pa` | Top-level router exception |

### Router Exception

Top-level router files represent the module entry point rather than a leaf command.
Use `name: {module}` with no colon for these files.
Example: `commands/pa.md` -> `name: pa`.

### Legacy Prefix Guidance

The old `ouroboros:` prefix is invalid under the v2.0.0 convention update.
Replace `name: ouroboros:pa:init` with `name: pa:init`.

### DO / DON'T

| DO | DON'T |
|----|-------|
| Set `name` on every command file | Omit `name` because the filename looks unique |
| Derive `name` from the file path | Hand-write unrelated names such as `core:research` in `commands/core/evaluate.md` |
| Use `name: pa` for `commands/pa.md` | Use `name: pa:router` for a router file |
| Use `name: pa:init` for `commands/pa/init.md` | Use `name: ouroboros:pa:init` |

---

## Path Naming

### Rules

| Constraint | Description |
|---|---|
| Prefix | All paths start with `./` |
| Traversal | No `../` allowed |
| Separator | Forward slash `/` only (no backslash) |
| Variables | Plugin-root variable for script references in hooks |
| Case | Lowercase directory and file names |

### Plugin.json Path Fields

| Field | Default | Override Example |
|---|---|---|
| `commands` | `["./commands/"]` | `["./commands/", "./extra-commands/"]` |
| `agents` | `["./agents/"]` | `["./agents/"]` |
| `skills` | `["./skills/"]` | `["./skills/"]` |

Paths are **additive** to defaults, not replacements. Specifying a custom path adds
a discovery location; it does not disable the default path.

### Validation Procedure

```text
1. Check all paths start with "./" or use the plugin-root variable for hook script calls
2. Check no path contains "../"
3. Check no path is absolute (starts with "/")
4. Check no backslashes in paths
5. For hooks: verify script files exist at referenced paths
```
