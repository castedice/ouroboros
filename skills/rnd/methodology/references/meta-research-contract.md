# Meta-Research Contract

This reference defines the v3.5.0 meta-research contract for measuring how the RnD harness performs across completed studies.
The contract is descriptive and advisory.
It exists to surface reusable process patterns without mutating the harness automatically.

## Per-Study Metrics

Each completed study may emit `.rnd/sessions/{id}/study-metrics.json`.
The producer is the `meta-learn` stage or an equivalent `--meta extract` action run after completion.

| Section | Required fields | Notes |
|---------|-----------------|-------|
| `budget` | Per-dimension `used`, `limit`, and `utilization` for `wall_clock`, `web_search`, `web_fetch`, `model_route`, and `probes` | Utilization is the canonical ratio surface for cross-study comparison |
| `stage_durations` | Per-stage `seconds` and `fraction`, plus the duration source | Prefer `budget.json` phase timings and fall back to `state.json` transitions when timing is sparse |
| `resource_efficiency` | Planned and executed probe counts, success or partial or failure counts, and per-probe-type performance | Probe-type performance uses the planned probe type as the primary grouping key |
| `quality` | `C1` through `C5`, final verdict, and optional summary score | Quality comes from `archive-index.json` when available or from direct `review.md` parsing otherwise |
| `derived_ratios` | Ratios such as probes per claim, sources per claim, sources per probe, and success rates | Derived ratios normalize studies with different scope sizes |
| `meta_learning` | `ML-XX` and `DC-XX` counts, plus stable id arrays when available | Promotion logic works on stable ids rather than prose similarity |
| `process_signals` | Loopbacks used, critic revision fires, exhausted budget dimensions, and other low-cardinality process flags | These fields support pattern detection rather than report prose |

## Cross-Study Aggregate

The aggregate file lives at `.rnd/meta-aggregate.json`.
The producer is the `aggregate` action in `scripts/rnd-meta.sh`.

| Section | Required fields | Notes |
|---------|-----------------|-------|
| `study_count` | Count of extracted studies included in the aggregate | Only extracted studies count toward confidence |
| `budget_utilization_distribution` | Mean, min, max, and raw values per budget dimension | Values remain visible for auditability |
| `stage_time_distribution` | Mean, min, max, and raw values for stage seconds and fractions | Stage fraction is the primary surface for policy checks |
| `quality_distribution` | Per-criterion score distributions and verdict counts | Calibration checks operate on repeated score shapes |
| `efficiency_trends` | Cross-study distributions for derived ratios and per-probe-type success rates | Probe strategy suggestions use this section |
| `process_patterns` | Loopback usage, critic revision frequency, budget exhaustion frequency, and timing-source counts | Use counts, not prose summaries |
| `meta_learning_patterns` | Lesson counts, deferred change counts, and repeated `DC-XX` frequency | Promotion suggestions operate on repeated deferred changes |

## Suggestion Taxonomy

Suggestions are identified by category-specific prefixes.
Every suggestion entry is a hypothesis about process improvement rather than an approved change.

| Prefix | Category | Trigger |
|--------|----------|---------|
| `SUG-BDG-` | Budget Default | Utilization `< 0.15` or `> 0.95` for the same dimension across `2+` studies |
| `SUG-STG-` | Stage Policy | A stage stays below `8%` of time across `2+` studies, or critic revision fires never occur |
| `SUG-PRB-` | Probe Strategy | Success rate differs by more than `0.30` between probe types across `2+` studies |
| `SUG-CAL-` | Evaluator Calibration | The same criterion keeps receiving the same score across `3+` studies |
| `SUG-PRC-` | Process Pattern | Loopbacks are never used, or the same budget dimension exhausts repeatedly |
| `SUG-PRM-` | Lesson Promotion | The same `DC-XX` deferred change appears in `2+` studies |

## Graduated Confidence

Suggestion confidence is based only on the number of supporting studies.

| Supporting study count | Confidence label |
|------------------------|------------------|
| `1` | `observation` |
| `2` | `tentative` |
| `3-4` | `moderate` |
| `5+` | `strong` |

Confidence grades do not imply approval strength.
They only describe evidence depth inside the archive.

## Evaluator Recalibration Signals

Evaluator recalibration is a special suggestion class because it questions the measurement surface itself.

| Signal | Trigger | Interpretation |
|--------|---------|----------------|
| Ceiling collapse | A criterion receives the same maximum score across `3+` studies | The criterion may be too lenient or too coarse to distinguish quality |
| Floor collapse | A criterion receives the same minimum score across `3+` studies | The criterion may be too punitive or blocked by a recurring artifact defect |
| Range compression | A criterion stays within a one-point range across `3+` studies | The rubric may not be separating weak, medium, and strong work clearly enough |

Recalibration suggestions should point to repeated score patterns, not to a single surprising review.

## Advisory Boundary

All suggestions are hypothesis-grade.
The meta-research module never auto-edits prompts, commands, skills, or scripts.
