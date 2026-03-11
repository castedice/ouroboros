# Invocation Protocol — External Model CLI Patterns

This reference defines how to invoke external model CLIs, construct prompts, parse outputs, and handle errors.

## CLI Version Baseline

Record the CLI versions this protocol was tested against. When invocation fails unexpectedly, check version first — CLI tools change flags frequently.

| CLI | Tested Version | Install | Check Version | Last Verified |
|-----|---------------|---------|---------------|---------------|
| Codex CLI | v0.104.0 (rust) | `npm install -g @openai/codex` | `codex --version` | 2026-02-19 |

**Update policy**: When a CLI update breaks invocation, update this file with the new version and adjusted flags. Include the date and what changed.

**Available models** (see `routing-table.md` for full profiles):

- Codex: gpt-5.4 (default), gpt-5.3-codex-spark, gpt-5.1-codex-max, gpt-5.2-codex, gpt-5.2, gpt-5.1-codex

## CLI Invocation Patterns

### Codex CLI (Priority 1)

```bash
# One-shot with JSON output (preferred)
echo 'PROMPT_TEXT' | codex exec --json -

# Alternative: inline prompt
codex exec --json "PROMPT_TEXT"

# With specific model
echo 'PROMPT_TEXT' | codex exec --json -m gpt-5.4 -

# With reasoning effort (low/medium/high/xhigh)
echo 'PROMPT_TEXT' | codex exec --json -c model_reasoning_effort="high" -

# With sandbox restriction (recommended for read-only tasks)
echo 'PROMPT_TEXT' | codex exec --json --sandbox read-only -

# Combined: specific model + high reasoning + JSON + read-only
echo 'PROMPT_TEXT' | codex exec --json -m gpt-5.4 -c model_reasoning_effort="high" --sandbox read-only -
```

**Reasoning effort levels**:

| Level | Use Case | Speed |
|-------|----------|-------|
| `low` | Quick checks, trivial tasks | Fastest |
| `medium` | Default, interactive coding | Balanced |
| `high` | Complex analysis, evaluation | Slower |
| `xhigh` | Maximum deliberation, hardest tasks | Slowest |

For ouroboros evaluation tasks, use `high` by default. Use `xhigh` for high-stake decisions.

**Timeout**: 300 seconds default (configurable via 6th argument to `invoke-model.sh`). Complex evaluation prompts with xhigh reasoning often exceed 2 minutes. The `timeout` command exits immediately when the process finishes early, so generous defaults don't slow fast tasks.

**Exit codes**:

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Parse output |
| Non-zero | Error | Log warning, skip model |

**Output format** (JSON mode): JSONL (one JSON object per line). Lines include progress events and item completions. The response is in an `item.completed` event with `item.type: "agent_message"`.

```jsonl
{"type":"thread.started","thread_id":"..."}
{"type":"turn.started"}
{"type":"item.completed","item":{"id":"item_0","type":"reasoning","text":"thinking..."}}
{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"The actual response"}}
{"type":"turn.completed","usage":{"input_tokens":1234,"output_tokens":567}}
```

Extract the line containing `"type":"agent_message"` → parse as JSON → `.item.text` is the response.

## CLI Availability Detection

Before invoking external models, verify CLI installation:

```bash
which codex 2>/dev/null && codex --version || echo "codex:unavailable"
```

Store results as boolean flags + version strings. Detection runs once per command execution (Phase 1: Parse Input). Log detected versions for debugging.

**Messaging on unavailability**:

- If `--multi` requested but Codex not found:
  `"Codex CLI not found. Proceeding with single-model (Claude only)."`
- If Codex available:
  `"Codex CLI v{version} detected. Multi-model evaluation will use Claude + Codex."`

## Artifact Sharing — Cross-Model Context

Both CLIs (Claude Code, Codex CLI) support shared artifact formats. Leverage this to provide consistent context across models.

### AGENTS.md as Single Source of Truth

Both CLIs read instruction files, but use different names:

- **Codex CLI**: reads `AGENTS.md` (root → subdirectories, hierarchical)
- **Claude Code**: reads `CLAUDE.md` (auto-injected at plugin load)

**Convention**: `AGENTS.md` is the canonical instruction file. For ouroboros:

- Maintain `AGENTS.md` as the single source of truth
- `CLAUDE.md` either symlinks to `AGENTS.md` or includes `See AGENTS.md for full instructions`
- When Codex is invoked from the same project directory, it automatically receives the same base instructions via `AGENTS.md`

This ensures all models share the same project conventions, coding style, and constraints.

### Agent Skills (Open Standard)

Agent Skills (a folder with `SKILL.md`) are supported across Claude Code, Codex CLI, and 35+ other platforms. Ouroboros skills in `skills/` can be shared with external models when they operate in the same project context.

When constructing relay prompts, reference relevant ouroboros skills:

- The external model may auto-load skills if running in the ouroboros directory
- For isolated invocations, include skill content in the relay prompt (Section 3)

### Tracking Skill/Agent Usage in Output

When an external model returns its response, request that it report which instructions or skills it applied. Add to Section 4 (Response Format):

```text
Include a "context_used" field listing any AGENTS.md instructions or skills
that influenced your response. This helps verify the model operated with
the intended context.
```

This enables verification that the external model received and applied the shared artifacts correctly.

## Prompt Relay Design

The Prompt Relay pattern constructs prompts for external models while minimizing framing bias. A relay prompt has 4 sections:

### Section 1: Role (template, generic)

```text
You are an independent evaluator. Your task is to assess the quality of a plugin component
using the criteria provided below. Score each criterion independently with detailed reasoning.
Do not assume any prior context — evaluate based solely on the content and criteria given.
```

This section is a fixed template. It provides no task-specific opinion from Claude.

### Section 2: Content (raw file content, verbatim)

```text
## Component to Evaluate

{Read(target-file) output, copied verbatim — no summarization, no paraphrasing}
```

**Critical rule**: This section MUST be the raw file content read from disk. Claude MUST NOT summarize, paraphrase, annotate, or add commentary. The command reads the file and inserts its content directly.

### Section 3: Criteria (raw criteria reference, verbatim)

```text
## Evaluation Criteria

{Read(skills/core/evaluation/references/{type}-criteria.md) output, copied verbatim}
```

**Critical rule**: Same as Section 2 — raw criteria file content, no modification. If the external model can access ouroboros skills directly (same directory), reference the skill path instead of inlining content.

### Section 4: Response Format (JSON schema, generic)

```text
## Response Format

Respond ONLY with a JSON object in the following format (no markdown, no explanation outside JSON):

{
  "criteria": [
    {
      "id": "C1",
      "name": "criterion name",
      "score": 0 or 1,
      "reasoning": "minimum 3 sentences explaining your scoring decision with specific evidence"
    }
  ],
  "overall_score": sum of all criteria scores,
  "strengths": ["specific positive point 1", "specific positive point 2"],
  "improvements": [
    { "priority": "HIGH or MED or LOW", "description": "specific improvement suggestion" }
  ],
  "context_used": ["list of AGENTS.md sections or skills referenced during evaluation"]
}
```

This section is a fixed schema template. It ensures structured output for programmatic parsing. The `context_used` field enables verification that shared artifacts were applied.

### Prompt Assembly

The complete relay prompt is the concatenation of Sections 1-4 with double newlines:

```text
{Section 1}\n\n{Section 2}\n\n{Section 3}\n\n{Section 4}
```

Total prompt size is approximately: ~200 tokens (Section 1+4) + component file size + criteria file size. For a typical component (~1500 words) + criteria (~500 words), total is ~3000 tokens input.

## Output Parsing

### Parse Strategy

1. **Primary**: Parse stdout as JSON directly
2. **Fallback**: If JSON parse fails, search for JSON within markdown code fences:

   ```text
   Extract content between ```json and ``` markers
   ```

3. **Last resort**: If both fail, log warning and exclude this model from consensus

### Codex Output Parsing

```bash
# jq pattern: slurp JSONL, find agent_message, extract inner text, parse
echo "$OUTPUT" | jq -s 'map(select(.item?.type? == "agent_message")) | .[0].item.text' -r | jq '.'
```

Multi-level parse: JSONL → jq slurp+filter → `.item.text` extraction → inner JSON parse.

### Validation After Parse

After successful parse, validate the evaluation object:

- Has `criteria` array with expected number of entries
- Each criterion has `id`, `name`, `score` (0 or 1), `reasoning` (non-empty)
- Has `overall_score` matching sum of criteria scores
- Has `strengths` and `improvements` arrays
- Has `context_used` array (informational — missing is OK, not a parse failure)

If validation fails, log which fields are missing and attempt partial use (e.g., criteria scores are usable even if improvements array is malformed).

## Error Taxonomy and Handling

| Error Type | Detection | Response | Log Level |
|-----------|-----------|----------|-----------|
| CLI not installed | `which` returns non-zero | Skip model, continue | INFO |
| CLI version mismatch | Version != expected | Log warning with expected vs actual, continue | WARN |
| CLI execution timeout | No response in 300s (configurable) | Kill process, exit 2, no retry | WARN |
| Authentication failure | Stderr contains "auth" or "login" | Skip model, show setup hint | ERROR |
| Rate limit / quota | Stderr contains "429" or "quota" | Skip model (likely free tier), suggest upgrade | WARN |
| JSON parse failure | Parse throws exception | Try code fence extraction | WARN |
| Persistent parse failure | Fallback also fails | Skip model, exclude from consensus | WARN |
| Network error | Stderr contains "DNS" or "timeout" | Skip model, continue | WARN |
| Empty response | Stdout is empty or whitespace | Skip model, continue | WARN |

### Circuit Breaker

`invoke-model.sh` is stateless — it handles a single invocation with retry (max 2 retries, exponential backoff 1s/2s). Circuit breaker logic across multiple invocations is the **caller's responsibility** (command level).

If the same CLI fails on consecutive invocations within a single command execution (e.g., during a module scan with `--multi`), stop attempting after 2 failures:

```text
failure_count[model] >= 2 → skip all remaining invocations for that model in this command run
Log: "{model} CLI failed {n} times (v{version}). Skipping for remainder of this evaluation."
```

**Retry vs Circuit Breaker boundary**: `invoke-model.sh` retries transient failures (empty response, network hiccup) within a single task. The command tracks failures across tasks and applies the circuit breaker pattern.

## Graceful Degradation Levels

| Available Models | Behavior | Report Label |
|-----------------|----------|-------------|
| Claude + Codex | Bilateral consensus (2-way) | "Multi-model (2)" |
| Claude only | Standard single-model | "Single-model (Codex unavailable)" |

Multi-model is always **additive**. Claude's evaluation always runs first and completes regardless of external model availability. External models add perspective but never block.

## Settings Requirements

For multi-model to work, the user's `settings.json` must allow Bash invocations:

```json
{
  "permissions": {
    "allow": [
      "Bash(which codex)",
      "Bash(codex *)",
      "Bash(echo * | codex *)"
    ]
  }
}
```

These permissions should be documented in `/onboard` output and the plugin README. Future `/setup` command could automate this configuration.
