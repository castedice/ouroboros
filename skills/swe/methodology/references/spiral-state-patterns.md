# Spiral State Patterns — Learning, Checkpoints, Lifecycle, and Script Interface

This reference covers the operational patterns layered on top of the spiral state schema.
Use it for checkpointing, cascade invalidation, next-turn advice, and the `spiral-state.sh` command interface.
This reference is self-contained — it can be consulted independently of the parent SKILL.md.
For the base state schema, statuses, and policy tables, see `spiral-state-schema.md`.

## Learning Delta Schema (v0.16.5)

When a spiral turn completes with team or team+probe policy, Tune generates a learning delta that feeds the next turn's depth planning.
The delta is saved to `.swe/active/learning-delta.json` and archived with other artifacts.

```json
{
  "turn": 1,
  "depth_calibration": { "spec": "ok", "dev": "under", "ship": "ok", "tune": "over" },
  "team_effectiveness": { "cross_review_value": "high", "backtrack_count": 0, "specialist_failures": 0 },
  "process_improvements": ["Builder should pre-analyze test infrastructure"]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `turn` | integer | Spiral turn number (sequential) |
| `depth_calibration` | object | Per-composite assessment: `"over"` (too much ceremony), `"under"` (too shallow), `"ok"` (well-matched) |
| `team_effectiveness` | object | Team performance metrics: cross-review value (high/medium/low), backtrack count, specialist failure count |
| `process_improvements` | array | Specific suggestions for the next turn's team workflow |

Script commands:

```bash
spiral-state.sh learning-delta save    # reads JSON from stdin, saves to .swe/active/learning-delta.json
spiral-state.sh learning-delta load    # outputs most recent delta from docs/specs/record/ or .swe/active/
```

The next turn's Phase 2 (Depth Planning) loads the delta and presents advisory depth adjustments: `"over"` suggests lowering one level, `"under"` suggests raising one level.
The user decides whether to accept.

## Checkpoint Schema

Checkpoints are created before regression — they snapshot the current artifact state so that regression can be reversed if needed.

```json
{
  "id": "cp-001",
  "after_stage": "dev_composite",
  "artifact_versions": {
    "01-understand": 1,
    "02-constrain": 1,
    "03-design": 1,
    "04-interface": 1,
    "05-test": 1,
    "06-implement": 1,
    "07-verify": 1,
    "08-optimize": 1
  },
  "parent_checkpoint": null,
  "created_at": "2026-03-02T11:15:00Z"
}
```

| Field | Description |
|-------|-------------|
| `id` | Sequential checkpoint ID: `cp-001`, `cp-002`, etc. |
| `after_stage` | The stage that completed just before this checkpoint |
| `artifact_versions` | Version number for each artifact at checkpoint time. Version 0 = artifact does not exist yet |
| `parent_checkpoint` | ID of the previous checkpoint (linked list for rewind chain) |
| `created_at` | ISO 8601 timestamp |

Artifact version files are stored at `.swe/active/.versions/{NN}-{stage}.v{N}.md`.
The canonical path `.swe/active/{NN}-{stage}.md` always holds the latest version.

## Cascade Invalidation Algorithm

When a regression causes a stage to re-execute, its downstream dependents may be affected.
The cascade algorithm uses the Selective Load Matrix from `artifact-contracts.md` to determine impact:

### Dependency Map

Derived from the Selective Load Matrix (Required = must re-execute, Optional = may preserve):

| Artifact Re-versioned | Invalidated (Required dependency) | Stale (Optional dependency) |
|-----------------------|-----------------------------------|-----------------------------|
| 01-understand | 02-constrain | 03-design, 04-interface, 06-implement, 07-verify, 08-optimize |
| 02-constrain | 03-design, 08-optimize | 04-interface, 06-implement, 07-verify |
| 03-design | 04-interface, 08-optimize | 06-implement, 07-verify |
| 04-interface | 05-test, 06-implement, 07-verify | 08-optimize |
| 05-test | 06-implement | 07-verify, 08-optimize |
| 06-implement | 07-verify | 08-optimize |
| 07-verify | 08-optimize | — |

### Algorithm

1. Identify the re-executed stage's artifact (the one that will be re-versioned)
2. Look up the artifact in the dependency map above
3. Mark each downstream stage:
   - In the "Invalidated" column → set status to `invalidated`
   - In the "Stale" column → set status to `stale`
4. Present the invalidation list to the user before proceeding:
   - **Invalidated stages** must be re-executed (mandatory)
   - **Stale stages** can be re-executed or preserved (user choice)
5. Reset invalidated stages to `pending` and re-execute in sequence

### Circuit Breaker

`regression_count >= max_regressions` (default 3) triggers the circuit breaker:

- Display: "Circuit breaker: {count}/{max} regressions reached. The spiral must abort or override."
- **Abort**: Terminate the spiral. Archive current artifacts as-is.
- **Override**: Allow one additional regression with explicit user confirmation. Does not increase `max_regressions`.

The circuit breaker prevents infinite regression loops.
If a task consistently requires more than 3 regressions, it signals that the initial Understand stage needs fundamental rework — start a new spiral turn.

## State Lifecycle

```text
spiral start → init state file
  ↓
for each composite/gate:
  update(stage, running) → execute → update(stage, completed)
  ↓
  on failure: present Decision Matrix options
    → retry: re-run same composite
    → regress: checkpoint → cascade → restore → re-enter earlier composite
    → abort: terminate
  ↓
spiral end → archive state file with artifacts
```

## Next Turn Recommendations

After a spiral turn completes, derive next-turn parameters from cycle results.
Apply the first matching row:

| Cycle Outcome | Recommended Depth | Focus |
|---------------|-------------------|-------|
| Ship had P1 overrides (Phase 8 Path C) | S:Standard D:Deep H:Deep N:Standard | Security hardening — address overridden P1 findings |
| Dev required 2+ retries or backward transitions | S:Deep D:Deep H:Standard N:Standard | Spec refinement — Interface Contracts or Architecture may need revision |
| Spec completed at Light depth | S:Standard D:Standard H:Light N:Light | Deepen specification — constraints and contracts may be underspecified |
| All composites completed clean first pass | S:Light D:Light H:Light N:Deep | Comprehensive retrospect — maximize learning extraction |
| Tune identified architectural debt | S:Deep D:Standard H:Standard N:Standard | Architecture revision — revisit Design stage decisions |

When tune retrospect provides specific recommendations, those take precedence for the task description.
The table above provides default depth recommendations when tune does not specify depth.

## Script Interface

All state operations go through `scripts/spiral-state.sh`.
The spiral command never directly manipulates the JSON file.

```bash
spiral-state.sh init <task> [--policy <name>] [--depths S:L D:L H:L N:L]
spiral-state.sh update <stage> <status>
spiral-state.sh read [--field <jq-path>]
spiral-state.sh status
spiral-state.sh checkpoint <after_stage>
spiral-state.sh restore <checkpoint_id>
spiral-state.sh cascade <stage>
spiral-state.sh team-update <specialist> <status> [--task <description>]
spiral-state.sh cross-review <reviewer> <target> <status>
spiral-state.sh stage-update <specialist> <primitive-stage> <status>
```
