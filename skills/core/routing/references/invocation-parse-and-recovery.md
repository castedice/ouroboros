# Invocation Protocol — Parse And Recovery

This reference covers how routed outputs are parsed, validated, and recovered when external execution goes wrong.

## Output Parsing

Codex JSON mode emits JSONL.
The usable response is the `item.completed` event whose `item.type` is `agent_message`.

Example stream:

```jsonl
{"type":"thread.started","thread_id":"..."}
{"type":"turn.started"}
{"type":"item.completed","item":{"id":"item_0","type":"reasoning","text":"thinking..."}}
{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"The actual response"}}
{"type":"turn.completed","usage":{"input_tokens":1234,"output_tokens":567}}
```

Extract the `agent_message` line, parse it as JSON, and then parse `.item.text` as the actual payload.

### Parse Strategy

1. Parse stdout as JSON directly when the model returned plain JSON.
2. If that fails, extract JSON from fenced code blocks.
3. If both fail, log a warning and exclude the model from consensus.

### Codex JSONL Extraction

```bash
echo "$OUTPUT" | jq -s 'map(select(.item?.type? == "agent_message")) | .[0].item.text' -r | jq '.'
```

## Validation After Parse

After parsing, validate:

- `criteria` exists and has the expected number of entries.
- Each criterion has `id`, `name`, `score`, and non-empty `reasoning`.
- `overall_score` matches the summed criterion scores.
- `strengths` and `improvements` exist as arrays.
- `context_used` is present when possible, but its absence is informational rather than fatal.

If validation fails, log the missing fields and use any still-valid partial data conservatively.

## Error Taxonomy

| Error Type | Detection | Response | Log Level |
|-----------|-----------|----------|-----------|
| CLI not installed | `which` fails | Skip model and continue | INFO |
| CLI version mismatch | Version differs from expected | Warn and continue | WARN |
| CLI execution timeout | No response in 300 seconds | Kill process and skip | WARN |
| Authentication failure | Stderr mentions auth or login | Skip model and show setup hint | ERROR |
| Rate limit or quota | Stderr mentions `429` or quota | Skip model and suggest upgrade | WARN |
| JSON parse failure | Parse throws | Try code-fence extraction | WARN |
| Persistent parse failure | Fallback also fails | Exclude from consensus | WARN |
| Network error | Stderr mentions DNS or timeout | Skip model and continue | WARN |
| Empty response | Stdout is empty | Skip model and continue | WARN |

## Circuit Breaker

`codex-relay.sh` handles retries inside one invocation.
Command-level logic owns the circuit breaker across multiple invocations.

If the same CLI fails twice in one command execution, skip the rest of that command's invocations for that model.
Log the model name, failure count, and version when the breaker trips.
