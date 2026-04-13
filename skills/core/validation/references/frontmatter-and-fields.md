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
| `summary` | string | One-sentence skill summary, ≤25 words, no trigger phrases | `Guides evidence-first component scoring with binary criteria and tier gates.` |
| `version` | integer | Schema version for update detection (not plugin SemVer) | `1` |
| `tags` | list | 3-6 lower-case hyphenated keywords, module prefix first | `[core, methodology, evaluation, scoring]` |
| `preamble_tier` | integer | Loading priority: 1=leaf, 2=standard, 3=decision-heavy, 4=meta | `4` |

Field order in frontmatter: `name`, `description`, `summary`, `version`, `tags`, `preamble_tier`.

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

### Required Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `name` | string | Path-derived command name | `core:evaluate` |
| `description` | string | Trigger-style help text that starts with `Use when` | `Use when you need to score plugin component quality` |

### Recommended Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `allowed-tools` | list | Tools the command may use | `Read, Grep, Glob, Task` |
| `argument-hint` | string | Expected argument format | `<component-path> [--focus C1,C2]` |

### `name` Rules

| Rule | Requirement |
|---|---|
| Path derivation | `commands/core/evaluate.md` -> `name: core:evaluate` |
| Standard regex | `^[a-z][a-z0-9-]*:[a-z][a-z0-9-]*$` |
| Router exception | `commands/pa.md` -> `name: pa` |
| Legacy prefix | `ouroboros:` fails validation |

### `description` Trigger Convention

Command `description` is required and must start with `Use when`.
Describe the user's trigger or intent, not the command's internal workflow.
Words such as `Stage`, `composite`, `orchestrate`, and `meta-composite` are warning signs that the line is drifting into summary text.

```yaml
# GOOD
description: Use when you need to score plugin component quality

# BAD — summary instead of trigger
description: Evaluate plugin component quality — static definition scoring, output quality assessment

# BAD — workflow language
description: Specification composite — orchestrate Stages 1-4
```

Trigger-style descriptions matter because `/help` should expose user intent quickly.
They also improve routing because the command advertises when to use it instead of how it works internally.

### `allowed-tools` Semantics

`allowed-tools` defines the scope boundary, not auto-approval:

- Tools listed are what the command **may** use
- User permission mode still applies — listed tools are not auto-approved
- Unlisted tools are blocked even if the user would approve them

### DO / DON'T

| DO | DON'T |
|----|-------|
| Add a path-derived `name` to every command | Omit `name` on commands that do not collide with built-ins |
| Start `description` with `Use when` | Write a workflow summary instead of a trigger |
| Use intent language in `description` | Lead with `Stage`, `composite`, `orchestrate`, or `meta-composite` |
| Follow minimum privilege for `allowed-tools` | List all available tools "just in case" |
| Provide `argument-hint` when input shape matters | Leave argument shape implicit when users need guidance |

---

## Template Frontmatter

### Recommended Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `title` | string | Template display name | `Focus Brief` |
| `description` | string | One-line template purpose | `Structured dossier template for a topic, project, or person` |

### Key Distinctions

Templates are rendering specifications — they define output shape, not behavior. Unlike skills and agents, templates have no trigger mechanism or model selection. Their frontmatter is minimal because they are always explicitly invoked by a command.

A template requires both `title` and `description` to be self-documenting. The description should explain what the template produces, not what command calls it.

### DO / DON'T

| DO | DON'T |
|----|-------|
| Include both `title` and `description` | Leave frontmatter empty or with only `title` |
| Write specific `description` ("Period synthesis template for timestamp notes") | Write generic description ("A template for notes") |
| Keep frontmatter minimal — templates are invoked, not discovered | Add `model`, `tools`, or `allowed-tools` (templates don't execute) |

---

## Hook Fields (hooks.json)

### Required Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `matcher` | string | Tool name or OR pattern | `Write\|Edit` |
| `type` | string | Hook type | `command` |
| `command` | string | Script to execute | `bash <plugin-root>/scripts/fmt.sh` |
| `timeout` | number | Max execution time in seconds | `30` |

### Recommended Fields

| Field | Type | Description | Example |
|---|---|---|---|
| `description` | string | Human-readable purpose | `Auto-format written files` |

### Valid Event Types

Claude Code supports 17 hook events across 4 categories:
Session lifecycle: `SessionStart`, `SessionEnd`, `Stop`.
Tool lifecycle: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`.
User interaction: `UserPromptSubmit`, `Notification`, `PreCompact`.
Agent and team: `SubagentStart`, `SubagentStop`, `TeammateIdle`, `TaskCompleted`.
Configuration and workspace: `ConfigChange`, `WorktreeCreate`, `WorktreeRemove`.
Choose the narrowest matching event instead of relying on broad catch-all wiring.

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
| Use the plugin-root variable in `command` paths | Hardcode absolute paths |
| Target specific tools in `matcher` | Use wildcard `*` matcher |
| Include `description` for documentation | Leave hooks undocumented |
| Handle JSON parse failure with `exit 0` | Let script crash on malformed stdin |
