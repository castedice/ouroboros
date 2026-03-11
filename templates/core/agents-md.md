---
title: AGENTS.md Template
description: Multi-model compatible AI agent instructions template for project adoption
---

# AI Agent Guidelines — ${PROJECT_NAME}

> Instructions for AI agents (Claude Code, Codex CLI) working on this project.

## Project Overview

- **Name**: ${PROJECT_NAME}
- **Language**: ${LANGUAGE}
- **Framework**: ${FRAMEWORK}
- **Architecture**: ${ARCHITECTURE}
- **Build Tool**: ${BUILD_TOOL}
- **Test Framework**: ${TEST_FRAMEWORK}

## Coding Conventions

### Style

${STYLE_RULES — language-specific naming, formatting, and idiom conventions}

### Code Organization

${CODE_ORGANIZATION — module structure, import patterns, layer separation}

### Error Handling

${ERROR_HANDLING — error handling patterns specific to the language/framework}

## Testing

- **Test runner**: ${TEST_COMMAND}
- **Test location**: ${TEST_LOCATION}
- **Naming convention**: ${TEST_NAMING}

${TESTING_GUIDELINES — coverage expectations, test types, mocking patterns}

## Documentation

${DOCUMENTATION_STANDARDS — doc style, comment conventions, README expectations}

## Git Conventions

- **Commit messages**: ${COMMIT_STYLE}
- **Branch naming**: ${BRANCH_NAMING}

## AI Agent Rules

### Do

${DO_RULES — positive guidelines for AI agents working on this project}

### Don't

${DONT_RULES — anti-patterns and forbidden practices}

### Security

${SECURITY_RULES — security considerations specific to the tech stack}

## Tool Guidance

### Code Navigation

When a `.lsp.json` is configured for this project, prefer LSP tools over text search:

- `lsp_goto_definition` → faster and more precise than Grep for finding definitions
- `lsp_find_references` → find all usages of a symbol
- `lsp_hover` → check types and documentation without reading the full file
- `lsp_diagnostics` → catch errors immediately after edits, before running builds

Fall back to Grep/Glob when LSP is unavailable or for cross-file pattern searches.

### Agent Routing

- Use Explore agents (`model: "sonnet"`) for broad codebase searches requiring 3+ queries
- Use Grep/Glob directly for targeted 1-2 query searches
- Delegate WebFetch/WebSearch to sonnet agents to avoid context pollution

### LSP Setup

${LSP_SETUP — if .lsp.json was generated, reference the installed language server and install command. If not, note that LSP can be configured later with .lsp.json}

## Multi-model Compatibility

This file is the shared instruction source for all AI coding tools:

| Tool | How it reads this file | Additional config |
|------|----------------------|-------------------|
| Claude Code | Auto-loaded from project root | `CLAUDE.md` for Claude-specific rules |
| Codex CLI | Natively supported as first-class file | None needed |
| Cursor | Configure in settings | `.cursorrules` for Cursor-specific rules |
| GitHub Copilot | Configure in settings | `.github/copilot-instructions.md` |

For tool-specific rules (hooks, model routing, memory policies, etc.), use each tool's own config file rather than adding them here.

## Recommended Claude Code Settings

Add to `.claude/settings.json` for optimal ouroboros experience:

```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "90"
  }
}
```

| Setting | Value | Effect |
|---------|-------|--------|
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `"90"` | Compact at 90% context capacity instead of 95%, giving more headroom for large tool responses |

Optional personal settings (add to `~/.claude/settings.json`):

| Setting | Value | When to use |
|---------|-------|-------------|
| `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` | `"1"` | tmux users — prevents Claude Code from overwriting window names |

## Ouroboros Integration

### Recommended Workflows

${WORKFLOWS — ouroboros workflows suited for this project}

### Knowledge Base

- `docs/specs/knowledge/` — accumulated patterns and research findings
- `docs/decisions/` — architectural and design decision records
- `docs/personal/` — personal notes (gitignored)
