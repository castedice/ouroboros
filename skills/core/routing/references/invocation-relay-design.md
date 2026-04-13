# Invocation Protocol — Relay Design

This reference covers the shared context assumptions and prompt relay structure used for external model calls.

## Artifact Sharing — Cross-Model Context

Both Claude Code and Codex CLI can operate in the same project context.
Use that overlap to keep instructions and artifacts aligned.

### AGENTS.md As The Shared Instruction Base

Codex reads `AGENTS.md` hierarchically from the project tree.
Claude Code reads `CLAUDE.md` from the plugin environment.
For ouroboros, `AGENTS.md` remains the canonical project instruction file.
When Codex is invoked from the same project directory, it receives the same repository conventions through `AGENTS.md`.

### Skills As Shared Methodology

Skills in `skills/` can be shared with external models when they run inside the same project.
If the external model cannot see the repo context directly, inline only the needed skill or reference content in the relay prompt.

### Tracking Context Use

Ask the external model to report which instructions or skills influenced the response.
That makes it possible to verify whether shared context was actually applied.

## Prompt Relay Design

The relay prompt has four sections.
Only the role and response-format sections are templated by Claude.
Task content and criteria stay verbatim to minimize framing bias.

### Section 1: Role

```text
You are an independent evaluator.
Your task is to assess the quality of a plugin component using the criteria provided below.
Score each criterion independently with detailed reasoning.
Do not assume any prior context.
```

### Section 2: Content

```text
## Component to Evaluate

{Read(target-file) output, copied verbatim with no summarization or annotation}
```

### Section 3: Criteria

```text
## Evaluation Criteria

{Read(skills/core/evaluation/references/{type}-criteria.md) output, copied verbatim}
```

If the external model can access ouroboros skills directly, reference the skill path instead of inlining it.

### Section 4: Response Format

```text
## Response Format

Respond ONLY with a JSON object containing:
- criteria: [{ id, name, score, reasoning }]
- overall_score
- strengths
- improvements: [{ priority, description }]
- context_used
```

The fixed response schema keeps parsing deterministic.
The `context_used` field records which instructions or skills materially affected the answer.

## Prompt Assembly

The final prompt is the four sections joined with double newlines.
For a typical component plus criteria bundle, the total input size is usually around 3000 tokens.
