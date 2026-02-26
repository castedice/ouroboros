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
| Derivation | Filename without `.md` extension |
| Format | Lowercase, hyphens allowed |
| Override | `name` field in frontmatter |
| Invocation | `/command-name` or `/prefix:command-name` |

### Built-in Commands (Reserved)

These commands are built into Claude Code and cannot be overridden by plugin commands.
If a plugin command filename matches one of these, it will be silently ignored.

```text
/help           /plan           /review         /init
/clear          /compact        /cost           /doctor
/login          /logout         /memory         /status
/mcp            /config         /permissions    /vim
/terminal-setup /listen         /fast
```

**Total**: 17 reserved command names.

### Collision Detection Procedure

```text
1. Extract command name from filename (strip .md extension)
2. Check against built-in command list above
3. If collision found:
   a. Add `name: prefix:command` to frontmatter
   b. Choose prefix from module name or plugin name
   c. Example: commands/dev/plan.md -> name: dev:plan
4. If no collision -> no `name` field needed (avoid unnecessary overrides)
```

### Collision Resolution Examples

| Filename | Collision | Resolution |
|---|---|---|
| `commands/dev/plan.md` | `/plan` (built-in) | `name: dev:plan` -> invoked as `/dev:plan` |
| `commands/dev/review.md` | `/review` (built-in) | `name: dev:review` -> invoked as `/dev:review` |
| `commands/core/evaluate.md` | No collision | No `name` field needed |
| `commands/workflows/init.md` | `/init` (built-in) | `name: workflows:init` -> invoked as `/workflows:init` |

### DO / DON'T

| DO | DON'T |
|----|-------|
| Check built-in list before naming | Discover collision after deployment |
| Use module name as namespace prefix | Use arbitrary prefixes (`my:plan`) |
| Add `name` field only when collision exists | Add `name` to every command preventively |
| Document the collision in the command body | Silently rename without explanation |

---

## Path Naming

### Rules

| Constraint | Description |
|---|---|
| Prefix | All paths start with `./` |
| Traversal | No `../` allowed |
| Separator | Forward slash `/` only (no backslash) |
| Variables | `${CLAUDE_PLUGIN_ROOT}` for script references in hooks |
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
1. Check all paths start with "./" or use "${CLAUDE_PLUGIN_ROOT}"
2. Check no path contains "../"
3. Check no path is absolute (starts with "/")
4. Check no backslashes in paths
5. For hooks: verify script files exist at referenced paths
```
