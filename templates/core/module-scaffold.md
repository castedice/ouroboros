---
title: Module Scaffold Guide
description: Structure and conventions for generating new plugin modules
---

# Module Scaffold Guide

Reference for the generator agent when creating new plugin modules.

## Directory Structure

A module named `{module}` creates directories under the shared namespace:

```text
commands/{module}/       # User-invoked slash commands (orchestration)
agents/{module}/         # Specialized sub-agents (execution)
skills/{module}/         # Auto-triggered methodology knowledge
templates/{module}/      # Document templates for the module
```

Only create directories that contain at least one file. Empty directories are not scaffolded.

## Minimum Viable Module

Every module must have at least:

1. **One command** — the primary user entry point (`commands/{module}/{verb}.md`)
2. **Agent strategy** — either a module-specific agent (`agents/{module}/`) OR reuse of a core agent (researcher, evaluator, generator, reconciler)
3. **Module README** — `commands/{module}/README.md` with purpose, usage, and component list

Optional but recommended:

- Skills for methodology knowledge that the module's agents reference
- Templates for structured outputs the module produces

## Naming Conventions

| Component | Convention | Examples |
|-----------|-----------|----------|
| Commands | **verb** or **verb-noun** | `survey.md`, `synthesize.md`, `annotate-source.md` |
| Agents | **noun** (role) | `surveyor.md`, `annotator.md`, `synthesizer.md` |
| Skills | **noun** or **noun-phrase** (knowledge area) | `survey-methodology.md`, `citation-format.md` |
| Templates | **noun-type** (document kind) | `survey-report.md`, `annotation-entry.md` |

Module name itself: **lowercase noun or noun-phrase**, hyphen-separated (`research`, `code-review`, `test-strategy`).

## Core Agent Reuse

Before creating a module-specific agent, check if a core agent can fulfill the role:

| Core Agent | Reuse When... |
|------------|---------------|
| researcher | Module needs analysis, pattern extraction, or knowledge synthesis |
| evaluator | Module needs quality assessment or validation |
| generator | Module needs content/component generation from specs |
| reconciler | Module needs version comparison or merge resolution |

Create a module-specific agent only when the domain requires specialized procedures that differ significantly from core agent capabilities.

## Component Relationships

```text
User → /command (orchestration: what to do, in what order)
         ↓ delegates via Task tool
       agent (execution: performs the specialized work)
         ↓ references
       skill (knowledge: methodology, criteria, patterns)
         ↓ uses
       template (structure: output document format)
```

Commands define the workflow. Agents do the work. Skills provide domain knowledge. Templates structure the output.

## Frontmatter Requirements

### Command Frontmatter

```yaml
---
description: One-line description of what the command does
argument-hint: <required-arg> [--optional-flag <value>]
allowed-tools: Read, Glob, Grep, Write, Bash, Task
---
```

### Agent Frontmatter

```yaml
---
name: agent-name
description: |
  Use this agent when you need to "action phrase 1", "action phrase 2", or "action phrase 3".

  <example>
  Context: When this agent is invoked
  user: [What the caller provides]
  assistant: What the agent does and produces.
  commentary: Why this is a good use case for this agent.
  </example>
model: opus|sonnet|haiku
tools:
  - Read
  - Grep
  - Glob
color: cyan|green|yellow|red|blue|magenta
---
```

### Skill Description

Third-person trigger phrases for auto-triggering. Not user-invoked.

### Template Frontmatter

```yaml
---
title: Template Name
description: What this template is used for
---
```

## Quality Targets

Generated components should meet these minimum quality levels:

- Commands: >= 3/5 on command-criteria (clear phases, proper input handling, error cases)
- Agents: >= 3/5 on agent-criteria (trigger description, examples, appropriate tools/model)
- Skills: >= 3/5 on skill-criteria (progressive disclosure, actionable content)

The `/generate` command enforces a 3/5 quality gate. Components below this threshold trigger a retry cycle.
