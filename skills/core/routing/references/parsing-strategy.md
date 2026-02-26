# Parsing Strategy — External Model Output

> 3-tier parsing: Script (mechanical) → Script fallback → LLM fallback (intelligent)

## Core Principle

**"Parse mechanically first. Let the LLM handle what scripts cannot."**

External CLIs produce inconsistent output formats — JSONL with metadata, mixed stdout/stderr, intermittent code fences, partial JSON. Mechanical parsing handles the common cases cheaply. When it fails, the raw output file persists for LLM-level inspection, which can understand structure that regex and jq cannot.

## 3-Tier Architecture

| Tier | Handler | Cost | Capability |
|------|---------|------|------------|
| 1 — Primary | `invoke-model.sh` (jq) | Zero tokens | Structured JSON extraction |
| 2 — Fallback | `invoke-model.sh` (alternative jq) | Zero tokens | Alternative extraction paths |
| 3 — LLM | Command reads raw file | Token cost | Understands arbitrary text structure |

Tier 1-2 run inside the script. Tier 3 runs at the command level — the LLM reads the raw output file and extracts evaluation data using its language understanding.

## Script Interface

```text
scripts/invoke-model.sh <provider> <model> <prompt-file> <output-file>
```

| Parameter | Description | Example |
|-----------|-------------|---------|
| provider | CLI tool name | `codex`, `gemini` |
| model | Model identifier | `gpt-5.2`, `gemini-3-flash-preview` |
| prompt-file | Relay prompt text file | `.tmp/a1b2c3d4_relay.txt` |
| output-file | Parsed JSON destination | `.tmp/a1b2c3d4_codex_eval.json` |

### Exit Codes

| Code | Meaning | Raw file | Command action |
|------|---------|----------|----------------|
| 0 | Parse success | Preserved | Read output-file, use JSON directly |
| 1 | Parse failed | Preserved | Read raw file, LLM extracts scores |
| 2 | CLI error | May exist | Skip model, log error type |

### Side Effect

Always creates `{output-file}.raw` containing raw CLI output. This file persists regardless of exit code — it is the foundation for both debugging and LLM fallback.

## Provider-Specific Parsing

### Codex (JSONL format)

Raw output is newline-delimited JSON. Each line is an event object.

**Primary parse** — extract `agent_message` item:

```bash
jq -s 'map(select(.item?.type? == "agent_message")) | .[0].item.text' -r
```

**Fallback parse** — try last (not first) agent_message:

```bash
jq -s 'map(select(.item?.type? == "agent_message")) | .[-1].item.text' -r
```

**Known patterns**:

- `type: "thread.started"` — session metadata, skip
- `type: "item.completed"` + `item.type: "reasoning"` — thinking trace, skip
- `type: "item.completed"` + `item.type: "agent_message"` — actual response
- `type: "error"` — error message in `.message` field
- `type: "turn.failed"` — fatal error in `.error.message` field

### Gemini (mixed stdout/stderr)

Raw output mixes log lines with a JSON response object.

**Primary parse** — skip non-JSON prefix, extract `.response`, strip code fences:

```bash
awk '/^\{/{found=1} found{print}' | jq -r '.response' | sed 's/^```json//;s/^```$//'
```

**Fallback parse** — try direct JSON extraction (skip `.response` wrapper):

```bash
awk '/^\{/{found=1} found{print}' | jq -s '.[] | select(.criteria? or .response?) | ...'
```

**Known patterns**:

- `Loaded cached credentials.` — log line prefix, always skip
- `Error when talking to Gemini API` — error line, extract for classification
- `{"session_id": "...", "response": "..."}` — normal response wrapper
- `.response` value occasionally wrapped in ` ```json ``` ` — sed strip required
- 429 retry messages — CLI retries automatically; may still produce valid response

## LLM Fallback Protocol

When the script exits with code 1, the command (LLM) reads the raw output file directly.

### Instructions for the LLM

1. Read the raw file via Read tool
2. Identify the model response section (skip metadata, logs, error traces)
3. Extract evaluation scores — look for patterns like:
   - `"C1"`, `"score": 1`, `"reasoning": "..."`
   - Or any structured scoring data, even in prose form
4. Construct a partial result object with whatever was recoverable
5. Log which criteria were recovered and which were lost
6. If nothing is recoverable, skip the model entirely

### Partial Results

Partial extraction is valid. If only 3 of 5 criteria are parseable:

- Use the 3 recovered scores in consensus
- Mark the 2 missing criteria as `"-"` (unavailable) in the report
- Note in the report: "{model}: partial result (3/5 criteria recovered from malformed output)"

## Error Classification

Errors are classified from extracted error lines only — never from full output (stack trace paths like `googleQuotaErrors.js` cause false positives).

| Pattern | Classification | Action |
|---------|---------------|--------|
| auth, login, credentials, PermissionDenied | AUTH_ERROR | Skip, show setup hint |
| not found, not supported | MODEL_ERROR | Skip, check model name |
| 429, RESOURCE_EXHAUSTED | RATE_LIMIT | Parse anyway (CLI may have retried) |
| timeout, DNS, ECONNREFUSED | NETWORK_ERROR | Skip model |

**Codex error extraction**: `jq -r 'select(.type == "error" or .type == "turn.failed") | .message'`
**Gemini error extraction**: `grep -m1 -E "^Error|ModelNotFoundError|AuthenticationError"`

## File Naming Convention

All temp files use session-scoped naming within the workspace `.tmp/` directory:

```text
.tmp/{SESSION_ID}_relay.txt          # Assembled relay prompt
.tmp/{SESSION_ID}_codex_eval.json    # Parsed Codex result (if success)
.tmp/{SESSION_ID}_codex_eval.json.raw  # Raw Codex CLI output (always)
.tmp/{SESSION_ID}_gemini_eval.json   # Parsed Gemini result (if success)
.tmp/{SESSION_ID}_gemini_eval.json.raw # Raw Gemini CLI output (always)
```

Session ID: first segment of a UUID (`uuidgen | cut -d- -f1`), 8 hex characters.
Cleanup: `rm -f .tmp/{SESSION_ID}_*` at command end.

## See Also

- **invocation-protocol.md** — Prompt Relay pattern, CLI command syntax
- **routing-table.md** — Task category × stake level → model selection
- **invoke-model.sh** (`scripts/`) — Script implementation of Tier 1-2
