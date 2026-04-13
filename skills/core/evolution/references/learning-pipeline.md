# Learning Pipeline

> Reference for the evolution-methodology skill.
> Defines the local learning storage layout, source schemas, and promotion rules for v2.3.0.

## Storage Layout

Use `${CLAUDE_PLUGIN_DATA:-$PROJECT_ROOT/.tmp}` as the learning data root.
Keep all learning data local and append-only until a later promotion step changes it.

```text
${CLAUDE_PLUGIN_DATA}/
├── sources/
│   ├── session-patterns.jsonl
│   ├── evaluations.jsonl
│   ├── friction.jsonl
│   └── corrections.jsonl
├── evolve/
│   └── promises/
│       └── RLP-YYYYMMDD-NNN.json
└── skills/
    └── {scope}/
        ├── events.jsonl
        ├── state.json
        ├── learned.md
        └── gotchas.md
```

`sources/*.jsonl` are source events.
`skills/{scope}/events.jsonl` is the routed evidence stream for one skill scope such as `core/evolution`.
`state.json` is machine state for counters, clustering state, and distillation cursors.
`learned.md` is the local distilled memory.
`gotchas.md` is the promoted local overlay.
`SKILL.md` stays Git-managed and is never updated automatically by this pipeline.

## Event ID Rules

Use prefixed event IDs with a UTC day key and a 3-digit counter.

| Source | Prefix | Format |
|--------|--------|--------|
| Evaluations | `EVL` | `EVL-YYYYMMDD-NNN` |
| Friction | `FRC` | `FRC-YYYYMMDD-NNN` |
| Corrections | `COR` | `COR-YYYYMMDD-NNN` |
| Session patterns | `SES` | `SES-YYYYMMDD-NNN` |

Counters are monotonic per prefix and UTC day.
IDs are source-local and do not replace per-skill learning IDs.

## Source JSONL Schemas

Every source row uses compact JSON on one line.
Every row must include `event_id`, `ts`, `source`, and `confidence`.
Store timestamps as ISO 8601 UTC with `Z`.

### `sources/session-patterns.jsonl`

Use for lightweight session-end patterns such as unfinished promises or a missing final artifact.
Required fields: `event_id`, `ts`, `source`, `pattern`, `session_id`, `task_key`, `confidence`, `detail`.
Use `source: "session-pattern"` and allow `task_key` to be empty when unknown.

Example:

```json
{"event_id":"SES-20260329-001","ts":"2026-03-29T11:40:00Z","source":"session-pattern","pattern":"unfinished_completion_promise","session_id":"abc123","task_key":"evolve:commands/core/evolve.md","confidence":0.60,"detail":{"promise_id":"RLP-20260329-001","status":"active","target":"commands/core/evolve.md"}}
```

### `sources/evaluations.jsonl`

Use for normalized evidence emitted after `/evaluate --save` or post-evolve validation.
Required fields: `event_id`, `ts`, `source`, `component`, `task_key`, `level`, `score`, `max_score`, `failed_criteria`, `improvements`, `content_hash`, `eval_hash`, `confidence`.
Use `source: "evaluation"`.

### `sources/friction.jsonl`

Use for repeated friction patterns distilled from message logs or permission logs.
Required fields: `event_id`, `ts`, `source`, `session_id`, `task_key`, `signal`, `pattern_hash`, `evidence_count`, `confidence`.
Use `source: "friction"`.
Never store raw user text here.
Use `pattern_hash` or other hashed evidence keys instead.

### `sources/corrections.jsonl`

Use for explicit user corrections and high-signal guidance.
Required fields: `event_id`, `ts`, `source`, `session_id`, `task_key`, `correction_type`, `pattern_hash`, `confidence`, `detail`.
Use `source: "correction"`.
`detail` may include component paths, missing deliverables, or other non-prompt metadata.
Do not store raw prompts or quoted corrections in plugin data.

## Routing Contract

The distiller routes events by checking top-level `.component` first, then `.detail.component_path`, then the `task_key` prefix and suffix.
When a source knows the component, emit `task_key` as `{source}:{component}` such as `evaluate:commands/core/evaluate.md` or `friction:commands/core/evolve.md`.
When a source does not know the component, emit `task_key` as `{source}:session:{uuid}`.
Every ingester must populate at least one routing-viable field, preferably `.component` plus a matching `task_key`, so the distiller does not fall back to `core/general`.

## Per-Skill Store

Each routed skill store lives at `${CLAUDE_PLUGIN_DATA}/skills/{scope}/`.

### `events.jsonl`

`events.jsonl` is the append-only routed feed for one skill.
Rows should preserve the source `event_id` and add any routing metadata such as `skill_scope` or `cluster_key`.

### `state.json`

`state.json` is machine state.
Keep it small and rewrite-safe.
At minimum track `version`, `skill_scope`, `next_learning_seq`, `next_gotcha_seq`, `last_distilled_at`, and `half_life_days`.

### `learned.md`

`learned.md` is the active distilled memory for one skill.
Use Markdown for readability and `state.json` for counters and cursors.

Entry format:
Heading: `### LRN-YYYYMMDD-XXX — <title>`.
Required fields: `category`, `confidence`, `first_seen`, `last_seen`, `occurrences`, `independent_tasks`, `decay_weight`, `source_context`, `learning`, `action`.
Use `category: observation | error | feature-request`.

`source_context` should reference event IDs, file paths, or hashed patterns.
`source_context` must not include raw prompts copied from plugin data.

Example:

```md
### LRN-20260329-001 — Inline mechanics keep regressing command quality
- category: observation
- confidence: 0.84
- first_seen: 2026-02-27T09:12:00Z
- last_seen: 2026-03-29T11:30:00Z
- occurrences: 5
- independent_tasks: 3
- decay_weight: 0.71
- source_context: EVL-20260329-004; SES-20260329-001; commands/core/evaluate.md
- learning: Repeated inline relay mechanics hurt maintainability and E1/E2 quality.
- action: Move repeatable mechanics into references or scripts before another evolve cycle.
```

### `gotchas.md`

`gotchas.md` is the promoted local overlay for rules strong enough to steer future work.
Use `GOTCHA-YYYYMMDD-XXX` IDs.
Required fields: `promoted_from`, `promoted_at`, `confidence`, `evidence`, `rule`, `applies_to`, `verify_with`.

Example:

```md
## GOTCHA-20260329-001 — Keep relay mechanics out of command bodies
- promoted_from: core/evolution:LRN-20260329-001
- promoted_at: 2026-03-29T12:00:00Z
- confidence: 0.84
- evidence: 5 occurrences / 3 tasks / 31 days
- rule: Keep command files orchestration-only and move repeatable mechanics into references or scripts.
- applies_to: /evolve, /generate, manual command editing
- verify_with: E1, E2
```

## Promotion Flow

Flow:

```text
sources/*.jsonl -> skills/{scope}/events.jsonl -> learned.md -> gotchas.md -> SKILL.md
```

Promote `learned.md` entries to `gotchas.md` only when all conditions are true:
`occurrences >= 3`, `independent_tasks >= 2`, active span `>= 30 days`, effective confidence `>= 0.55`, and no contradictory cluster with higher confidence.

Promotion from `gotchas.md` to `SKILL.md` is not automatic.
That step requires `/evolve` or human review.
Use that review to decide whether the rule is methodology-stable enough for the Git-managed base skill.

## Privacy And Retention

Treat `sources/*.jsonl` as short-lived evidence.
Apply a 90-day TTL to source JSONL retention.
Distilled learning in per-skill stores may outlive the raw source events that produced it.
Do not store raw prompts in `${CLAUDE_PLUGIN_DATA}`.
For friction and corrections, store only hashed patterns plus non-sensitive metadata.
Hashes use SHA-256 of the raw text before storage.

## Confidence Defaults

Start with these source defaults before clustering or decay adjusts them.

| Source | Default Confidence |
|--------|--------------------|
| Explicit user correction | `0.90` |
| Repeated evaluation pattern | `0.80` |
| Session-end pattern | `0.60` |
| Friction inference | `0.50` |
