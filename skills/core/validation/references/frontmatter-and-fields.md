# Frontmatter and Required Fields Reference

> Reference for the validation-methodology skill. Complete field specifications per component type with examples and edge cases.

## Agent Frontmatter

### Required Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `name` | string | Agent identifier, lowercase hyphenated, 3-50 chars | `evaluator` |
| `description` | string | Trigger condition + usage examples | See below |
| `model` | string | LLM model selection | `inherit`, `sonnet`, `opus`, `haiku` |
| `color` | string | Terminal display color | `blue`, `cyan`, `green`, `yellow`, `magenta`, `red` |

### Recommended Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `tools` | list | Allowed tools (minimum privilege) | `["Read", "Grep", "Glob"]` |

### Description Field Pattern

The `description` field serves as the trigger mechanism for agent activation.

```yaml
description: |
  Use this agent when you need to evaluate plugin component quality.
  It performs systematic scoring against binary criteria.

  <example>
  Context: User invokes /evaluate on a skill file
  user: /evaluate skills/core/evaluation/SKILL.md
  assistant: [delegates to evaluator agent with file path and criteria]
  commentary: Proactive trigger — direct evaluation request
  </example>

  <example>
  Context: Evolution workflow needs baseline measurement
  user: The evolve command needs a baseline score for the target component
  assistant: [evaluator agent scores the component independently]
  commentary: Reactive trigger — called as part of larger workflow
  </example>
```

### DO / DON'T

| DO | DON'T |
|----|-------|
| Include 2+ `<example>` blocks with Context/user/assistant/commentary | Write a single-line functional description |
| Cover both proactive and reactive trigger scenarios | Use only proactive triggers |
| Specify model appropriate to task complexity | Default to `opus` for all agents |
| List only tools the agent actually needs | Include `Write`, `Edit` on read-only agents |
| Always include `color` field | Omit `color` — it is required, not optional |

### Edge Cases

**`tools` field omitted**: Agent inherits all tools available to the parent context. This violates minimum privilege. Always specify an explicit list, even if broad.

**`model: inherit`**: Valid — inherits the parent conversation's model. Appropriate when the agent's task complexity matches the caller's model. Avoid for agents that specifically need higher or lower capability.

**`name` field uniqueness**: Agent names must be unique within a plugin. Two agents named `reviewer` in different module directories still collide at the plugin level.

---

## Skill Frontmatter

### Required Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `name` | string | Skill identifier, lowercase hyphenated | `evaluation-methodology` |
| `description` | string | Third-person trigger phrases | See below |

### Description Field Pattern

Skill descriptions use third-person form with specific trigger phrases in double quotes:

```yaml
description: This skill provides validation methodology knowledge.
  It should be activated when an agent needs to "validate a plugin component",
  "check frontmatter correctness", "verify naming conventions",
  "detect command name collisions", or "audit path constraints".
```

### Trigger Phrase Rules

| Rule | Correct | Incorrect |
|---|---|---|
| Third-person form | "It should be activated when..." | "You should use this when..." |
| 5+ specific phrases | 5 distinct quoted phrases | 2 vague phrases |
| Double-quoted | `"validate a component"` | `validate a component` |
| Action-oriented | `"check frontmatter fields"` | `"frontmatter"` |
| Domain-specific | `"detect command name collisions"` | `"check for errors"` |

### DO / DON'T

| DO | DON'T |
|----|-------|
| Use third-person ("It should be activated when...") | Use second-person ("Use this skill when you...") |
| Include 5+ double-quoted trigger phrases | Write generic ("Provides guidance for X") |
| Make phrases match real user/agent language | Use abstract terminology unlikely to appear in prompts |

---

## Command Frontmatter

### Recommended Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `description` | string | One-line command purpose | `Evaluate plugin component quality` |
| `allowed-tools` | list | Tools the command may use | `Read, Grep, Glob, Task` |
| `argument-hint` | string | Expected argument format | `<component-path> [--focus C1,C2]` |

### Key Distinctions

Commands have no strictly required frontmatter fields — all are recommended. This reflects the command's explicit invocation model: users type `/command-name`, so discoverability through frontmatter is less critical than for agents and skills.

However, `description` is strongly recommended because:

- It appears in `/help` output
- It helps the AI understand command purpose for orchestration

### `allowed-tools` Semantics

`allowed-tools` defines the scope boundary, not auto-approval:

- Tools listed are what the command **may** use
- User permission mode still applies — listed tools are not auto-approved
- Unlisted tools are blocked even if the user would approve them

### `name` Field Override

The `name` field in commands is optional and should only appear when:

1. The filename collides with a built-in command
2. A namespace prefix is needed

```yaml
---
name: workflows:plan
description: Generate implementation plan for a task
---
```

### DO / DON'T

| DO | DON'T |
|----|-------|
| Add `name` only for collision avoidance | Add `name` to every command (unnecessary noise) |
| Follow minimum privilege for `allowed-tools` | List all available tools "just in case" |
| Write specific `description` ("Evaluate plugin quality") | Write generic description ("Does evaluation") |

---

## Hook Fields (hooks.json)

### Required Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `matcher` | string | Tool name or OR pattern | `Write\|Edit` |
| `type` | string | Hook type | `command` |
| `command` | string | Script to execute | `${CLAUDE_PLUGIN_ROOT}/scripts/fmt.sh` |
| `timeout` | number | Max execution time in seconds | `30` |

### Recommended Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `description` | string | Human-readable purpose | `Auto-format written files` |

### Valid Event Types

| Event | When It Fires | Common Use |
|---|---|---|
| `PreToolUse` | Before a tool executes | Security validation, permission checks |
| `PostToolUse` | After a tool completes | Auto-formatting, logging |
| `Stop` | When the agent stops | Completion checks, cleanup |
| `UserPromptSubmit` | When user submits a prompt | Context injection, mode setting |

### Timeout Guidelines

| Task Type | Recommended Range | Rationale |
|---|---|---|
| Simple validation | 10-15s | Quick pass/fail check |
| Formatting | 15-30s | Tool execution + file I/O |
| Security analysis | 30-60s | May need file reading + pattern matching |

### DO / DON'T

| DO | DON'T |
|----|-------|
| Always specify `timeout` | Omit timeout — risks infinite hang |
| Use `${CLAUDE_PLUGIN_ROOT}` in `command` paths | Hardcode absolute paths |
| Target specific tools in `matcher` | Use wildcard `*` matcher |
| Include `description` for documentation | Leave hooks undocumented |
| Handle JSON parse failure with `exit 0` | Let script crash on malformed stdin |
