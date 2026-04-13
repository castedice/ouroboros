# Common Pitfalls — Foundation Cases

This reference expands the common validation failures around configuration presence, frontmatter identity, and minimum-privilege metadata.

## Pitfall 1: Empty `.mcp.json`

### Problem

An empty or stub `.mcp.json` file exists in the plugin root.
That causes MCP initialization errors during plugin load.

### Detection

The file exists but contains `{}`, `[]`, or no useful configuration.

### Fix

Delete the file entirely unless an actual MCP server is configured.
An absent file is safe, but an empty one is not.

### DO / DON'T

| DO | DON'T |
|----|-------|
| Delete `.mcp.json` if no MCP servers are configured | Leave an empty placeholder |
| Add `.mcp.json` only when a real MCP server is configured | Create it for future use |

## Pitfall 2: Missing Or Invalid Namespaced `name` In Commands

### Problem

A command omits `name`, keeps the legacy `ouroboros:` prefix, or uses a name that does not match its file path.

### Detection

Typical failures are:

- Missing `name` entirely.
- Using `ouroboros:pa:init`.
- Setting `name: core:research` inside `commands/core/evaluate.md`.

### Fix

Derive the name from the file path.
Use `{module}:{command}` for leaf commands and `{module}` for top-level router files.

### Format Rules

| File pattern | Required `name` | Valid example | Invalid example |
|---|---|---|---|
| `commands/{module}/{command}.md` | `{module}:{command}` | `core:evaluate` | `evaluate` |
| `commands/{module}.md` | `{module}` | `pa` | `pa:router` |
| Any command file | Path-derived and lowercase | `swe:spec` | `core:research` for `commands/core/evaluate.md` |
| Any command file | No legacy prefix | `pa:init` | `ouroboros:pa:init` |

## Pitfall 3: Generic Skill Description

### Problem

The skill description is too vague to trigger activation precisely.

### Detection

Failures usually look like generic summaries or second-person wording rather than quoted trigger phrases.

### Fix

Rewrite the description in third person with five or more specific double-quoted trigger phrases.

### Trigger Phrase Checklist

- Include at least five phrases.
- Put each phrase in double quotes.
- Use third-person form.
- Prefer action verbs such as `validate`, `check`, `verify`, `detect`, or `audit`.
- Keep phrases specific enough to match real usage.

## Pitfall 4: Missing Agent `tools`

### Problem

An agent without `tools` inherits the full parent toolset.
That violates minimum privilege.

### Detection

Look for agent frontmatter that declares `name`, `description`, `model`, and `color` but omits `tools`.

### Fix

Add an explicit `tools` list limited to what the agent actually needs.

### Tool Selection Guide

| Agent Role | Typical Tools | Rationale |
|---|---|---|
| Read-only analysis | `Read`, `Grep`, `Glob` | No mutation needed |
| Research with web | `Read`, `Grep`, `Glob`, `WebFetch` | External data gathering |
| Content generation | `Read`, `Write`, `Grep`, `Glob` | Creates files |
| Code execution | `Read`, `Write`, `Grep`, `Glob`, `Bash` | Needs shell access |
