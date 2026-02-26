---
title: oh-my-claudecode Multi-Agent Orchestration Patterns
tags: [multi-agent-orchestration, hook-middleware, xml-prompt-engineering, tiered-model-routing, skill-command-mirroring, conductor-pattern, plugin-architecture]
source: https://github.com/Yeachan-Heo/oh-my-claudecode
created: 2026-02-18
status: active
related: [compound-engineering-plugin-patterns.md]
---

# oh-my-claudecode Multi-Agent Orchestration Patterns

Analysis of oh-my-claudecode (OMC) v4.2.11, a Claude Code plugin with 30 agents, 37 skills, 33 commands, and 15 MCP tools. OMC's core philosophy is "Delegation-First Protocol" — the main LLM instance acts as a conductor, never performing work directly. This analysis extracts architectural patterns applicable to ouroboros.

## Key Patterns

### 1. Hook as Orchestration Middleware

OMC uses 6 hook event types as a programmable middleware layer:

| Event | Scripts | Purpose |
|-------|---------|---------|
| UserPromptSubmit | keyword-detector, skill-injector | Magic keyword activation + auto skill loading |
| SessionStart | session-start, project-memory | Context injection at session init |
| PreToolUse | pre-tool-enforcer | Validation before every tool call |
| PermissionRequest | permission-handler | Auto-permission for Bash commands |
| PostToolUse | post-tool-verifier, project-memory | Post-action verification + context tracking |
| SubagentStart | (agent initialization) | Agent-specific context injection |

The hook layer separates control plane (hooks) from data plane (agents/skills). UserPromptSubmit keyword detection enables "magic keywords" — users type natural words (e.g., "team fix errors") instead of slash commands.

### 2. Tiered Agent Variants (-low / -medium / -high)

Same agent role at different model tiers for cost optimization:

| Agent | -low (Haiku) | base (Sonnet) | -high (Opus) |
|-------|-------------|---------------|--------------|
| executor | Trivial fixes | Standard impl | Complex logic |
| architect | Simple lookups | Moderate analysis | Deep reasoning |
| designer | Layout tweaks | Standard design | Complex UX |

Routing decision lives in the delegation table (AGENTS.md), not individual agents. A -low variant costs ~1/60th of -high.

### 3. XML-Structured Agent Prompts

OMC agents use XML sections instead of markdown headers:

```xml
<Role> ... </Role>
<Why_This_Matters> ... </Why_This_Matters>
<Success_Criteria> ... </Success_Criteria>
<Constraints> ... </Constraints>
<Investigation_Protocol> ... </Investigation_Protocol>
<Tool_Usage> ... </Tool_Usage>
<Execution_Policy> ... </Execution_Policy>
<Output_Format> ... </Output_Format>
```

Notable sub-patterns:

- **Circuit breaker**: From architect agent — "Apply the 3-failure circuit breaker: if 3+ fix attempts fail, question the architecture rather than trying variations." Prevents infinite retry loops.
- **Explicit hand-offs**: Each agent declares delegation targets — "Hand off to: analyst (requirements gaps), planner (plan creation), critic (plan review), qa-tester (runtime verification)."
- **MCP consultation**: Agent-level cross-model validation — agents can independently consult Codex/Gemini for second opinions via MCP tools, with fallback if unavailable.

### 4. Skill-Command Mirroring

32 skills map 1:1 to 33 commands. Every user-invokable action has a companion auto-triggered knowledge component. The skill provides "how" (methodology), the command provides "when/what" (orchestration). Changes to either require updating the mirror via the cross-file dependency matrix.

### 5. Cross-File Dependency Matrix

Explicit documentation in AGENTS.md of what-changes-with-what:

| If you modify... | Also update... |
|------------------|----------------|
| agents/*.md | src/agents/definitions.ts, docs/REFERENCE.md |
| skills/*/SKILL.md | commands/*.md (mirror) |
| commands/*.md | skills/*/SKILL.md (mirror) |
| Agent prompt | Tiered variants (-low, -medium, -high) |

Multiple AGENTS.md files per directory (root, src/, skills/, docs/) form a hierarchical documentation system.

### 6. Conductor Pattern (Delegation-First)

The main LLM instance never executes directly — all work is delegated to specialized agents. From AGENTS.md: "You are a CONDUCTOR, not a performer." This maximizes Task tool (background execution) benefits but adds overhead for simple tasks.

## Practical Applications

### Immediately Adoptable

1. **Circuit breaker pattern** — Add to evaluator/researcher agents: "After 3 failed tool attempts, stop and report rather than retrying." Prevents infinite retry loops.

2. **SessionStart hook for STATUS.md** — Auto-inject STATUS.md content at session start, eliminating the manual "read STATUS.md first" workflow instruction.

3. **Companion skills for core commands** — Ensure every core command (/evaluate, /evolve, /research, /generate) has a corresponding skill with methodology knowledge. /research currently lacks a dedicated skill.

### Medium-Term Adoption

4. **Tiered evaluator variants** — evaluator-low (Sonnet) for rapid pre-screening, evaluator (Opus) for full evaluation. Reduces cost for bulk evaluations.

5. **Cross-file dependency matrix** — Document implicit dependencies (evaluation criteria -> evaluator, evolution skill -> evolve command) in CLAUDE.md as component count grows.

6. **Magic keyword detection** — UserPromptSubmit hook to detect "evaluate", "evolve", "research" as natural keywords. Risk: keyword collision with normal conversation.

### Architectural Considerations

7. **XML vs Markdown prompts** — Stay with markdown for cross-model portability. XML provides sharper section boundaries but reduces model-agnosticism, which conflicts with ouroboros's cross-model philosophy.

8. **Full conductor pattern** — Overkill for ouroboros's current 12 commands. The hybrid approach (direct execution for simple tasks, delegation for complex workflows) is more efficient at current scale.

## Trade-offs

- **Scale vs Context Cost**: 30+ agents and 37 skills create heavy context loading. ouroboros should grow component count cautiously.
- **Hook complexity ceiling**: 6 event types with Node.js scripts vs ouroboros's 2 types with shell scripts. More capable but harder to debug.
- **Mirroring maintenance**: Keeping skills and commands in sync requires automation (OMC uses `build-skill-bridge.mjs`) or discipline.
- **Conductor overhead**: Pure delegation adds latency for trivial tasks. ouroboros's hybrid approach is more pragmatic.
- **XML portability**: XML prompts are Claude-optimized; markdown is more model-agnostic.
- **Orchestration mode proliferation**: OMC has 9 execution modes (autopilot, ultrapilot, ultrawork, ultraqa, swarm, pipeline, ecomode, ralph, team) — evidence that orchestration modes multiply over time. Legacy modes (swarm, ultrapilot) are now facades routing to Team, suggesting consolidation pressure. ouroboros should anticipate mode sprawl if adding execution variants.

## References

- Repository: <https://github.com/Yeachan-Heo/oh-my-claudecode> (v4.2.11)
- Related: compound-engineering-plugin-patterns.md (pipeline orchestration comparison)
- Related: cross-model-cli-integration-patterns.md (MCP consultation tier)
- Related: plugin-component-quality-patterns.md (agent quality criteria)

---

## Appendix: Component Catalog

> Reference inventory from v4.2.11. For pattern analysis, see Key Patterns above.

### Agents (30)

| Agent | Role |
|-------|------|
| analyst | Analysis |
| api-reviewer | API review |
| architect | Architecture, debugging, root cause analysis |
| build-fixer | Build error fixing |
| code-reviewer | Code review |
| critic | Critique and improvement |
| debugger | Debugging |
| deep-executor | Deep execution |
| dependency-expert | Dependency management |
| designer | Design |
| document-specialist | Documentation, external API research |
| executor | Implementation |
| explore | Codebase exploration |
| git-master | Git operations |
| information-architect | Information architecture |
| performance-reviewer | Performance review |
| planner | Planning |
| product-analyst | Product analysis |
| product-manager | Product management |
| qa-tester | QA testing |
| quality-reviewer | Quality review |
| quality-strategist | Quality strategy |
| scientist | Data analysis/science |
| security-reviewer | Security review |
| style-reviewer | Style review |
| test-engineer | Test engineering |
| ux-researcher | UX research |
| verifier | Verification |
| vision | Vision/image analysis |
| writer | Documentation writing |

### Skills (37 — categorized)

| Category | Skills |
|----------|--------|
| Execution Modes (8) | autopilot, ultrawork, ralph, ultrapilot, swarm, pipeline, ecomode, ultraqa |
| Planning (5) | plan, ralplan, review, analyze, ralph-init |
| Code Quality (4) | code-review, security-review, tdd, build-fix |
| Exploration (3) | deepsearch, deepinit, sciomc |
| Utility (11) | orchestrate, learner, note, cancel, hud, doctor, omc-setup, mcp-setup, help, skill, trace |
| Domain (6) | frontend-ui-ux, git-master, project-session-manager, writer-memory, release, configure-telegram/discord |

### MCP Tools (15)

| Category | Tools |
|----------|-------|
| LSP (12) | lsp_hover, lsp_goto_definition, lsp_find_references, lsp_document_symbols, lsp_workspace_symbols, lsp_diagnostics, lsp_diagnostics_directory, lsp_rename, lsp_code_actions, lsp_completions, lsp_signature_help, lsp_formatting |
| AST (2) | ast_grep_search, ast_grep_replace |
| Runtime (1) | python_repl |
