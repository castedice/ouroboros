---
title: Claude Agent SDK for Python — Architecture and Integration Patterns
tags: [claude-agent-sdk, python-sdk, programmatic-agent-orchestration, hook-system, mcp-server, agent-definition, control-protocol, plugin-loading]
source: https://github.com/anthropics/claude-code-sdk-python
created: 2026-02-18
status: active
related: [claude-code-plugin-specification.md]
---

# Claude Agent SDK for Python — Architecture and Integration Patterns

The Claude Agent SDK (formerly Claude Code SDK) provides a Python interface for programmatic interaction with Claude Code. It enables building applications with bidirectional agent conversations, custom tools via in-process MCP servers, and a comprehensive hook system for deterministic processing. This analysis identifies patterns relevant to ouroboros's meta-plugin architecture and future evolution.

## Key Patterns

### 1. Dual-Level API (query vs ClaudeSDKClient)

The SDK provides two tiers of interaction:

- **`query()`**: Simple async iterator — fire-and-forget with streamed responses. Maps to ouroboros's current Task tool pattern (one-shot agent invocations).
- **`ClaudeSDKClient`**: Bidirectional context manager — supports custom tools, hooks, permission callbacks, and mid-execution control. Enables patterns impossible with Task tool alone.

This separation allows callers to pick the complexity level they need. The Task tool's one-shot invocation maps naturally to `query()`, while future interactive agent orchestration would use `ClaudeSDKClient`.

### 2. Programmatic Hook System (10 Events)

SDK hooks extend beyond CLI's `hooks.json` (shell commands) with Python async functions:

| Event | Trigger | Key Use |
|-------|---------|---------|
| PreToolUse | Before tool execution | Permission control, command blocking |
| PostToolUse | After tool execution | Output review, context injection |
| PostToolUseFailure | Tool execution failed | Error handling, retry logic |
| UserPromptSubmit | User sends prompt | Custom instruction injection |
| Stop | Agent execution ends | Post-processing, metrics |
| SubagentStop | Subagent finishes | Result collection |
| SubagentStart | Subagent begins | Context injection, monitoring |
| PreCompact | Before context compression | Custom compression instructions |
| Notification | Async notification | Progress monitoring |
| PermissionRequest | Permission needed | Fine-grained access control |

Key output fields: `permissionDecision` (allow/deny), `additionalContext` (inject context), `continue_` (halt execution), `systemMessage` (user-facing feedback), `stopReason`.

Compared to ouroboros's `hooks.json` (2 events, shell script handlers), the SDK provides a superset with richer control.

### 3. AgentDefinition as Dataclass

```python
@dataclass
class AgentDefinition:
    description: str
    prompt: str
    tools: list[str] | None = None
    model: Literal["sonnet", "opus", "haiku", "inherit"] | None = None
```

Maps directly to ouroboros's agent `.md` frontmatter (name/description/model/tools + body as prompt). Critical difference: dataclass agents are created at runtime, enabling dynamic generation without disk writes. This is relevant to `/generate`'s "test before commit" pattern.

### 4. SDK MCP Server (In-Process Tools)

```python
@tool("greet", "Greet a user", {"name": str})
async def greet_user(args):
    return {"content": [{"type": "text", "text": f"Hello, {args['name']}!"}]}

server = create_sdk_mcp_server(name="my-tools", tools=[greet_user])
```

Benefits over external MCP: no subprocess overhead, type safety, shared state, unified debugging. Relevant when ouroboros considers custom tool generation as part of module creation.

### 5. Programmatic Plugin Loading

`SdkPluginConfig(type="local", path="...")` enables loading plugins from code, replacing the CLI `--plugin-dir` flag. Enables scenarios: test-loading generated plugins, CI/CD automation of ouroboros evaluations, temporary loading for `/absorb` analysis.

### 6. ThinkingConfig and Effort Levels

SDK v0.1.36 added `effort` (low/medium/high/max) and `ThinkingConfig` (adaptive/enabled/disabled) per-agent. This achieves the same effect as oh-my-claudecode's tiered agent variants (-low/-medium/-high) without maintaining separate agent files. A single agent definition with different effort levels per invocation context.

### 7. Control Protocol (Stdin/Stdout JSON)

The SDK communicates with the bundled CLI via structured JSON messages (`SDKControl*` types) over stdin/stdout. This enables interrupt, permission decisions, file rewinding, and MCP message routing — all programmatically. The architecture is "CLI as engine, SDK as controller."

## Practical Applications

### Short-term (Phase 1 — current)

- **No SDK dependency needed**: Current plugin-file architecture works well for self-evaluation/evolution cycle. SDK's 0.1.x instability makes early adoption risky.
- **Reference for hooks.json expansion**: SDK's 10 hook events serve as a roadmap for what to request from CLI plugin format. SubagentStart and Stop are immediately useful if CLI supports them.

### Medium-term (Phase 2-3 — modules)

- **`/adopt` automation**: SDK's `SdkPluginConfig` enables programmatic plugin loading for testing external projects.
- **CI/CD integration**: `query()` pattern for automated `/evaluate` in pipelines.
- **Tiered evaluation**: Use `effort` levels instead of maintaining separate agent variants.

### Long-term (Post Phase 3)

- **Interactive agent orchestration**: `ClaudeSDKClient` for real-time evaluator-researcher coordination during `/evolve`.
- **Dynamic agent generation**: `AgentDefinition` for `/generate` dry-run testing before committing `.md` files.
- **In-process tools**: SDK MCP servers for custom analysis tools beyond shell scripts.

## Trade-offs

- **Python dependency vs simplicity**: SDK requires Python 3.10+ runtime, conflicting with ouroboros's current zero-dependency plugin design. The "single install" philosophy (VISION.md) favors the current approach.
- **Bundled CLI version conflicts**: SDK bundles CLI v2.1.44, which may differ from the user's installed version. Behavior differences between versions could cause subtle issues.
- **File-based vs code-based agents**: ouroboros's self-evaluation depends on reading agent `.md` files. SDK `AgentDefinition` agents are in code, requiring a new evaluator mode to assess.
- **Hook migration is all-or-nothing**: `hooks.json` shell hooks and SDK Python hooks cannot coexist without duplicate execution risk. Migration requires full transition.
- **API instability**: v0.1.0 already had breaking changes (type renames, system prompt changes). The 0.1.x release cadence (37 versions) suggests rapid evolution not yet stabilized.
- **Security trade-off**: SDK runs in the main process, bypassing Task tool's permission isolation. The agent sandboxing benefits of separate processes would be lost.

## References

- <https://github.com/anthropics/claude-code-sdk-python> — Source repository (MIT license)
- SDK types.py — Complete API surface with 30+ configuration fields in ClaudeAgentOptions
- SDK CHANGELOG.md — Version history showing rapid feature evolution (0.1.0-0.1.37)
- Related knowledge: oh-my-claudecode-orchestration-patterns.md (hook comparison), compound-engineering-plugin-patterns.md (pipeline patterns), cross-model-cli-integration-patterns.md (CLI integration)
