# Common Pitfalls — Detailed Examples and Fixes

> Reference for the validation-methodology skill. Expanded examples for each of the 8 common pitfalls with detection patterns and fix templates.

## Pitfall 1: Empty .mcp.json

### Problem

An empty or stub `.mcp.json` file exists in the plugin root. This causes MCP server initialization errors during plugin load (`/doctor` reports schema error).

### Detection

File exists but contains `{}`, `[]`, or is empty.

### Fix

Delete the file entirely. MCP configuration should only exist when MCP servers are actually configured. An absent file is safe; an empty one is not.

### DO / DON'T

| DO | DON'T |
|----|-------|
| Delete `.mcp.json` if no MCP servers are configured | Leave an empty `{}` as a placeholder |
| Add `.mcp.json` only when adding an actual MCP server | Create the file "for future use" |

---

## Pitfall 2: Unnecessary name Field in Commands

### Problem

A command includes a `name` field in its frontmatter when the filename already provides the correct command name and no collision exists.

### Detection

```yaml
# commands/core/evaluate.md
---
name: evaluate          # UNNECESSARY — filename already provides this
description: Evaluate plugin component quality
---
```

### Fix

Remove the `name` field. It is only needed when the filename collides with a built-in command.

### When name IS Needed

```yaml
# commands/dev/plan.md — "plan" collides with built-in /plan
---
name: dev:plan
description: Generate implementation plan
---
```

---

## Pitfall 3: Generic Skill Description

### Problem

Skill description is too vague to trigger auto-activation in relevant contexts.

### Detection

```yaml
# BAD — too generic, no specific trigger phrases
description: Provides guidance for plugin development.

# BAD — second person
description: Use this skill when you need to validate plugins.
```

### Fix

Rewrite with third-person form and 5+ specific double-quoted trigger phrases:

```yaml
# GOOD
description: This skill provides plugin validation methodology.
  It should be activated when an agent needs to "validate a plugin component",
  "check frontmatter correctness", "verify naming conventions",
  "detect command name collisions", or "audit path constraints".
```

### Trigger Phrase Quality Checklist

- [ ] 5 or more phrases present
- [ ] Each phrase is in double quotes
- [ ] Third-person form ("It should be activated when...")
- [ ] Phrases use action verbs ("validate", "check", "verify", "detect", "audit")
- [ ] Phrases are specific enough to match real usage contexts

---

## Pitfall 4: Missing Agent tools Field

### Problem

Agent frontmatter omits the `tools` field, causing the agent to inherit all tools from the parent context. This violates the minimum privilege principle.

### Detection

```yaml
---
name: researcher
description: ...
model: opus
color: cyan
# tools field missing — inherits everything
---
```

### Fix

Add an explicit `tools` field with only the tools the agent needs:

```yaml
---
name: researcher
description: ...
model: opus
color: cyan
tools: ["Read", "Grep", "Glob"]
---
```

### Tool Selection Guide

| Agent Role | Typical Tools | Rationale |
|---|---|---|
| Read-only analysis | `Read`, `Grep`, `Glob` | No mutation needed |
| Research with web | `Read`, `Grep`, `Glob`, `WebFetch` | External data gathering |
| Content generation | `Read`, `Write`, `Grep`, `Glob` | Creates files |
| Code execution | `Read`, `Write`, `Grep`, `Glob`, `Bash` | Needs shell access |

---

## Pitfall 5: Parent Directory Traversal in Paths

### Problem

Plugin paths use `../` to reference files outside the plugin directory.

### Detection

```json
{
  "commands": ["../shared/commands/"]
}
```

### Fix

All paths must be relative within the plugin root using `./` prefix only:

```json
{
  "commands": ["./commands/"]
}
```

If content from another location is needed, copy or symlink it into the plugin directory.

---

## Pitfall 6: Absolute Paths

### Problem

Hardcoded absolute filesystem paths break portability across machines and users.

### Detection

```json
{
  "command": "/Users/developer/plugins/my-plugin/scripts/format.sh"
}
```

### Fix

Use relative paths or `${CLAUDE_PLUGIN_ROOT}` variable:

```json
{
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh"
}
```

### Common Absolute Path Sources

| Source | Detection Pattern | Fix |
|---|---|---|
| Hook script paths | Starts with `/` in hooks.json `command` field | Use `${CLAUDE_PLUGIN_ROOT}/...` |
| Plugin.json paths | Starts with `/` in path fields | Use `./...` relative path |
| Markdown references | Starts with `/Users/` or `/home/` in body text | Convert to relative reference |

---

## Pitfall 7: Missing Agent color Field

### Problem

Agent frontmatter omits `color`, which is a required field for terminal display.

### Detection

```yaml
---
name: evaluator
description: ...
model: opus
# color field missing — required
---
```

### Fix

Add a `color` field:

```yaml
---
name: evaluator
description: ...
model: opus
color: yellow
---
```

### Color Options

Available colors: `blue`, `cyan`, `green`, `yellow`, `magenta`, `red`

Consider semantic meaning:

- `blue`/`cyan` — analysis, review, design
- `green` — execution, success-oriented
- `yellow` — verification, caution
- `red` — security, critical
- `magenta` — generation, creative

---

## Pitfall 8: Built-in Command Name Collision

### Problem

A plugin command filename matches a built-in Claude Code command. The plugin command is silently ignored — no error, no warning, just invisible failure.

### Detection

```text
commands/dev/plan.md      -> /plan collides with built-in
commands/dev/review.md    -> /review collides with built-in
commands/setup/init.md    -> /init collides with built-in
```

### Fix

Add a `name` field with a namespaced prefix:

```yaml
# commands/dev/plan.md
---
name: dev:plan
description: Generate implementation plan for a task
---
```

The command is now invoked as `/dev:plan` instead of `/plan`.

### Prevention Strategy

1. Before creating a command, check the built-in list (17 commands)
2. Use module name as prefix convention: `{module}:{command}`
3. Document the collision and resolution in the command body
4. If renaming the file is an option, choose a non-colliding name instead

### DO / DON'T

| DO | DON'T |
|----|-------|
| Check built-in list during command creation | Discover collision after deployment |
| Use consistent prefix convention (`module:name`) | Use ad-hoc prefixes per command |
| Document why the `name` override exists | Add `name` field without explanation |
| Consider alternative filenames first | Jump to `name` override without exploring alternatives |
