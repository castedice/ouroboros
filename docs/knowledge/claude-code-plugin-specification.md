---
title: Claude Code Plugin Specification Reference
tags: [plugin-specification, frontmatter-reference, plugin-json, command-format, agent-format, skill-format, hook-format]
source: dev/references/plugin-dev-guide.md
created: 2026-02-19
status: active
related: [claude-agent-sdk-python-patterns.md, plugin-component-quality-patterns.md]
---

# Claude Code Plugin Specification Reference

A canonical reference for Claude Code plugin structure, frontmatter fields, naming rules, path constraints, and configuration formats. Complements `plugin-component-quality-patterns.md` (which defines HIGH vs LOW quality) by documenting the exact specification — what fields exist, which are required, and what values are valid.

## Key Patterns

- **Three-Layer Architecture**: Commands (user invocation) -> Agents (delegated execution) <- Skills (knowledge injection). Commands orchestrate, agents execute, skills inject methodology knowledge
- **Frontmatter asymmetry**: Agents have 4 required frontmatter fields (name, description, model, color), skills have 2 (name, description), commands have 0 strictly required (all recommended)
- **Plugin name regex**: `/^[a-z][a-z0-9]*(-[a-z0-9]+)*$/` — kebab-case, starts with letter, no trailing hyphens
- **Path additivity**: plugin.json paths are additive to defaults, not replacements. Custom paths add discovery locations without disabling the default
- **Built-in collision**: 17 reserved command names (/help, /plan, /review, etc.) cannot be overridden. Use `name: prefix:command` in frontmatter for collision avoidance
- **MCP empty file trap**: Empty `.mcp.json` causes `/doctor` errors. Delete the file entirely if no MCP servers are configured

## Practical Applications

- **Generator agent**: Reference when generating new module components — ensures frontmatter correctness, proper naming, path compliance
- **Evaluator agent**: Cross-reference when assessing structural correctness beyond quality scoring
- **Validation skill**: Primary source for the validation-methodology skill's rules and checklists
- **Module scaffold**: Informs the module scaffold template with correct field specifications

## Trade-offs

- **Specification vs quality**: This entry documents "what is correct" while `plugin-component-quality-patterns.md` documents "what is good." Both are needed — a component can be correct but low quality, or high quality but structurally broken
- **Monolith vs standalone**: Some specifications (plugin.json customization, MCP configuration) are more relevant for standalone plugin generation than for monolith module development
- **disable-model-invocation**: Available for both commands and skills but rarely needed. Consider for commands that should never auto-trigger (e.g., destructive operations)

## References

- Source: `dev/references/plugin-dev-guide.md` (compiled from official Claude Code plugin-dev plugin + marketplace analysis, verified 2026-02-11)
- Related: `plugin-component-quality-patterns.md` (quality patterns per component type)
- Related: `compound-engineering-plugin-patterns.md` (namespace collision pattern)
- Related: `oh-my-claudecode-orchestration-patterns.md` (hook middleware patterns)
