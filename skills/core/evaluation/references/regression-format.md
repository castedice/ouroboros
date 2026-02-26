# Regression Result Format

Reference specification for evaluation result persistence and session-to-session comparison.

## JSON Schema

Each evaluation run produces a single JSON file capturing the complete snapshot:

```json
{
  "version": "1",
  "run_id": "003",
  "timestamp": "2026-02-20T14:30:00+09:00",
  "git_sha": "5a03e80",
  "module": "core",
  "components": [
    {
      "path": "agents/core/evaluator.md",
      "type": "agent",
      "content_hash": "sha256:a1b2c3...",
      "level": 4,
      "scores": { "F": [5, 5], "Q": [7, 7], "E": [3, 4] },
      "criteria": [
        { "id": "F1", "name": "Description Trigger Quality", "score": 1, "reasoning": "Observe: ... Compare: ... Judge: ..." }
      ],
      "strengths": ["Persona coherence is strong across all procedures"],
      "improvements": [
        { "priority": "MED", "criterion": "E2", "description": "Reduce repetition in output format section" }
      ],
      "output_evaluation": {
        "output_hash": "sha256:d4e5f6...",
        "output_source": "dev/test-outputs/evaluator/2026-02-20-basic.md",
        "score": [4, 5],
        "criteria": [
          { "id": "C1", "name": "Role Adherence", "score": 1, "reasoning": "..." }
        ],
        "strengths": ["..."],
        "improvements": [{ "priority": "MED", "description": "..." }]
      }
    }
  ],
  "summary": {
    "total": 16,
    "level_distribution": { "1": 0, "2": 1, "3": 7, "4": 8 },
    "output_evaluated": 3,
    "output_avg_score": [3.7, 5]
  }
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Schema version. Currently `"1"`. Versioning for backward compatibility deferred to production-ready phase |
| `run_id` | string? | Optional. 3-digit zero-padded monotonic run number (e.g., `"003"`). Assigned by `regression.sh save` to ensure unique filenames. Not present in legacy files |
| `timestamp` | string | ISO 8601 with timezone |
| `git_sha` | string | Short SHA of HEAD at evaluation time |
| `module` | string | Module name (e.g., `"core"`) |
| `components` | array | Per-component evaluation results |
| `summary` | object | Aggregate statistics |

### Component Fields

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Relative path from plugin root |
| `type` | string | Component type: `agent`, `skill`, `command`, `hook`, `claudemd` |
| `content_hash` | string | `sha256:{hex}` — hash of file content at evaluation time |
| `level` | number | Overall level (1-4) from severity gate |
| `scores` | object | Per-tier scores as `[achieved, max]` pairs. Keys: `F`, `Q`, `E`. Skipped tiers omitted |
| `criteria` | array | Per-criterion detail: `id`, `name`, `score` (0/1), `reasoning` |
| `strengths` | array | Positive observations from evaluator |
| `improvements` | array | Each with `priority` (HIGH/MED/LOW), `criterion` (id), `description` |
| `output_evaluation` | object? | Optional. Output evaluation results (Mode D with `--save`). See Output Evaluation Fields |

### Output Evaluation Fields

Present only when `output_evaluation` exists on a component:

| Field | Type | Description |
|-------|------|-------------|
| `output_hash` | string | `sha256:{hex}` — hash of output content at evaluation time |
| `output_source` | string | Path to the output file that was evaluated |
| `score` | array | `[achieved, max]` — flat C1-C5 output scoring |
| `criteria` | array | Per-criterion detail: `id`, `name`, `score` (0/1), `reasoning` |
| `strengths` | array | Positive observations from output evaluation |
| `improvements` | array | Each with `priority` (HIGH/MED/LOW), `description` |

### Summary Fields

| Field | Type | Description |
|-------|------|-------------|
| `total` | number | Total component count |
| `level_distribution` | object | Count per level: `{"1": n, "2": n, "3": n, "4": n}` |
| `output_evaluated` | number? | Optional. Count of components with output evaluation |
| `output_avg_score` | array? | Optional. `[avg_achieved, max]` across output-evaluated components |

## File Naming Convention

```text
dev/evaluations/{module}-{NNN}-{YYYY-MM-DD}-{short-sha}.json
dev/evaluations/{module}-latest.json  → symlink to most recent
```

`NNN` is a 3-digit zero-padded monotonic run number per module, assigned by `regression.sh save`. This ensures every evaluation run produces a unique file, even when multiple runs occur on the same day with the same git SHA.

Examples:

- `dev/evaluations/core-001-2026-02-20-5a03e80.json`
- `dev/evaluations/core-002-2026-02-20-5a03e80.json` (second run, same day/SHA)
- `dev/evaluations/core-latest.json` → `core-002-2026-02-20-5a03e80.json`

**Legacy compatibility**: Files without a run number (e.g., `core-2026-02-20-5a03e80.json`) remain valid. The counter accounts for both old and new format files when computing the next number.

For single-component evaluations (Mode A with `--save`):

- Same directory, same naming convention
- The `components` array contains only the single evaluated component
- `summary.total` is 1

## Script Actions

`regression.sh` provides the following actions for evaluation result management:

| Action | Usage | Description |
|--------|-------|-------------|
| `enumerate <module>` | List components | JSON array of `{ path, type }` objects for evaluatable components |
| `hash <file>` | Content hash | `sha256:{hex}` of file content |
| `save <module>` | Save result | Read stdin JSON, assign run number, write to `dev/evaluations/`, update symlink |
| `latest <module>` | Get latest | Print resolved path to the latest result file |
| `list <module>` | List runs | Table of all evaluation runs: file, timestamp, SHA, component count |
| `history <module> [--limit N]` | Show trends | Reverse-chronological history with level distribution and inter-run trends (↑/↓/=) |

## Comparison Methodology

Regression comparison operates at 3 granularity levels, from coarse to fine:

### Level 1: Run-level

Compare aggregate metrics between baseline and current:

| Metric | Baseline | Current | Delta |
|--------|----------|---------|-------|
| Total components | n | n | ±n |
| Average level | x.x | x.x | ±x.x |
| Level distribution | {1:a, 2:b, ...} | {1:a, 2:b, ...} | changes |

**New/removed components**: If a component exists in current but not baseline (or vice versa), flag it separately — it is not a regression, it is a structural change.

### Level 2: Component-level

For each component present in both runs, compare:

| Field | Change Type | Interpretation |
|-------|-------------|----------------|
| `level` | ↑ | Improvement |
| `level` | ↓ | **Regression** — highlight in report |
| `level` | = | Stable |
| `scores.F` | any change | Foundation shift — significant |
| `scores.Q` | any change | Craft shift |
| `scores.E` | any change | Excellence shift |
| `content_hash` | changed | Component was modified between runs |
| `content_hash` | unchanged | Component is identical |

### Level 2.5: Output Evaluation (when present)

For components with `output_evaluation` in both runs:

| Field | Change Type | Interpretation |
|-------|-------------|----------------|
| `output_evaluation.score` | ↑ | Output quality improved |
| `output_evaluation.score` | ↓ | **Output regression** — highlight in report |
| `output_evaluation.score` | = | Stable output quality |
| `output_hash` | unchanged + score changed | Evaluator variance (output) |

Components without `output_evaluation` are simply skipped in output comparison.

### Level 3: Criterion-level (regression only)

Drill into criterion-level detail **only when a score drops** (1→0):

- Show the criterion id, name, and reasoning from both runs
- If `content_hash` is unchanged, the score change is evaluator variance (not a real regression)
- If `content_hash` changed, the score change may be a genuine regression

## Evaluator Variance Detection

When `content_hash` is identical between runs but scores differ:

- **Label**: "evaluator variance" (not regression or improvement)
- **Action**: Note in report but do not count as regression
- **Threshold**: If >20% of components show variance on the same criterion, flag the criterion as unreliable

This distinction is critical: a score change on unchanged content means the evaluator is inconsistent, not that the component degraded. Tracking variance over time reveals which criteria need tighter specification.

## Comparison Report Format

```markdown
## Regression Report: {module}

**Baseline**: {baseline-file} ({timestamp})
**Current**: {current-file} ({timestamp})

### Run-level Summary

| Metric | Baseline | Current | Delta |
|--------|----------|---------|-------|
| Components | {n} | {n} | {±n} |
| Avg Level | {x.x} | {x.x} | {±x.x} |
| Level 4 | {n} | {n} | {±n} |
| Level 3 | {n} | {n} | {±n} |

### Component Changes

{For each component with level or score change:}

#### {path} — Level {old}→{new} {↑|↓|=}

| Tier | Baseline | Current | Delta |
|------|----------|---------|-------|
| F | {n}/5 | {n}/5 | {±n} |
| Q | {n}/{max} | {n}/{max} | {±n} |
| E | {n}/{max} | {n}/{max} | {±n} |

Content: {modified|unchanged}
{If unchanged + score changed: "⚠ Evaluator variance detected"}

{For regressions (score drops), show criterion-level detail:}

**Regressions:**

- {id} ({name}): 1→0 — Baseline: "{reasoning}" → Current: "{reasoning}"

### Structural Changes

- **Added**: {paths of components in current but not baseline}
- **Removed**: {paths of components in baseline but not current}

### Evaluator Variance Summary

{If any variance detected:}

- {n} components with score changes on unchanged content
- Affected criteria: {list}
```
