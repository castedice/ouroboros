---
title: Claude Code Plugin Component Quality Patterns
tags: [plugin, quality, agent, skill, command, hook, claude-md, best-practices]
source: claude-plugins-official (plugin-dev, pr-review-toolkit, hookify, security-guidance, code-review)
created: 2026-02-17
status: active
related: [claude-code-plugin-specification.md]
---

# Plugin Component Quality Patterns

HIGH vs LOW quality patterns discovered from real plugin analysis.

## Agent

### Description (trigger conditions)

**HIGH**: `"Use this agent when..."` + 2-4 `<example>` blocks (Context/user/assistant/commentary)

- Covers both Proactive + Reactive triggers
- 200-1,000 characters

**LOW**: Single-line feature description, no examples, vague trigger conditions

### System Prompt (body)

**HIGH** (500-3,000 words):

1. Expert persona declaration (expert identity + domain + tone)
2. Core Principles / Non-negotiable rules (numbered)
3. Process / Workflow (step-by-step checklist)
4. Quality Standards (criteria list)
5. Output Format (structured template)
6. Edge Cases (conditional handling)
7. Scope boundary ("analyze only", "do not modify")

**LOW** (under 100 words): Single-sentence persona, principles only listed, output format undefined

### Model selection

| Purpose | Model |
|---------|-------|
| Complex reasoning (architecture, deep review) | opus |
| Balanced execution + analysis | sonnet |
| Fast auxiliary tasks | haiku |
| Default (inherit from parent) | inherit (recommended) |

### Tool least privilege

- Read-only analysis: `["Read", "Grep", "Glob"]`
- Code generation: `["Read", "Write", "Grep"]`
- Bash only when explicitly needed

## Skill

### Description triggers

**HIGH**: Third-person + 5 or more specific trigger phrases (wrapped in double quotes)

```yaml
description: This skill should be used when the user asks to "create a hook",
  "add a PreToolUse hook", "validate tool use", ...
```

**LOW**: Too generic ("Provides guidance for hooks"), second-person, no trigger phrases

### Knowledge Injection (body)

**HIGH** (1,500-2,000 words):

- Imperative/infinitive form (NOT second-person)
- Progressive disclosure: details → separated into references/
- Quick reference tables, DO/DON'T lists, code examples
- Validation checklist

**LOW**: 10,000 words in a single file, second-person, references unused

### Reference organization

```text
skill-name/
├── SKILL.md          (1,500-2,000 words)
├── references/       (2-5 files, detailed patterns)
├── examples/         (1-5 files, runnable code)
└── scripts/          (0-3 files, validation utilities)
```

## Command

### Phase structure (best pattern)

```text
Phase 1: Discovery    → user confirmation checkpoint
Phase 2: Analysis     → Agent delegation (parallel)
Phase 3: Clarifying   → **CRITICAL: DO NOT SKIP**
Phase 4: Design       → Agent delegation + user selection
Phase 5: Implementation → start after user approval
Phase 6: Quality Review → Agent delegation + user decision
Phase 7: Summary       → wrap up
```

### Agent delegation patterns

- **Sequential**: delegate to different agents sequentially per phase
- **Parallel specialized**: multiple agents simultaneously → aggregate
- **Tiered**: Haiku(simple) → Sonnet(complex) → confidence scoring → filter

### Context collection

- `!`backtick: dynamic context injection via `!`\`git status\``
- `$ARGUMENTS`: substitutes user input arguments

## Hook

### Appropriate usage

| Pattern | Event | Example |
|---------|-------|---------|
| Auto-format | PostToolUse + Write/Edit | per-language formatter |
| Security validation | PreToolUse + Edit/Write | block dangerous patterns |
| Session context | SessionStart | mode configuration |
| Completion check | Stop | autonomous loop control |

### Overuse (anti-pattern)

- `"matcher": "*"` (hooks on all tools)
- Complex business logic (→ agent/skill is more appropriate)
- Tasks requiring user interaction (hooks run unattended)

### Error Handling

- On JSON parse failure, use `sys.exit(0)` (allow tool to proceed)
- Use `${CLAUDE_PLUGIN_ROOT}` (portability)
- timeout: format(30s), security(60s default)

## CLAUDE.md / AGENTS.md

**Conciseness is performance** — loaded on every request → tokens = cost + latency

**HIGH quality criteria:**

- Copy-pasteable build/test/deploy commands
- Directory structure + module relationship tree
- Gotchas, quirks, pitfalls documented
- One concept per line, minimum tokens
- Reflects current codebase state
- Specific and actionable instructions
