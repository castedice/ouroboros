# Dynamic Test Harness

Reference design for dogfooding dynamic skill evaluation beyond static rubric checks.

## Goal

Measure whether a skill loads when it should, drives the expected behavior during execution, improves the final output, and stays stable across revisions.

## Fixture Schema

Each fixture is a single JSON object with the following fields.

| Field | Type | Purpose |
|-------|------|---------|
| `id` | string | Stable fixture identifier used in reports and regression baselines |
| `skill` | string | Relative path to the target skill directory or `SKILL.md` |
| `query` | string | Natural-language request used to trigger the skill |
| `workspace_setup` | object or string | Files, repo state, or setup procedure required before execution |
| `expected_loads` | array | Skill or reference paths that should be read during activation or execution |
| `forbidden_loads` | array | Skill or reference paths that must not be read for this fixture |
| `expected_behaviors` | array | Observable execution behaviors such as tool usage, file creation, reference loads, or response structure |
| `judge_rubric` | string | Output-judging rubric, typically `skills/core/evaluation/references/skill-output-criteria.md` |
| `baseline_output` | string or object | Normalized baseline output snapshot used for regression comparison |

## Harness Stages

Run every fixture through the same 4 stages.

### Stage 1: Activation

Invoke Claude with `claude -p --output-format stream-json --verbose` so the harness can inspect the live event stream.

Capture the verbose trace and verify that the target skill path was read when the query should activate it.

Compare observed loads against `expected_loads` and `forbidden_loads`.

Fail the activation stage if the skill does not load, if a forbidden skill loads, or if the trace cannot prove what was read.

### Stage 2: Execution

Apply `workspace_setup` before the run so the fixture starts from a controlled state.

Evaluate execution against `expected_behaviors` using three evidence channels: trace events, final output, and produced artifacts.

Trace evidence covers reference loads, tool calls, and sequencing.

Output evidence covers structure, terminology, and required decisions.

Artifact evidence covers files written, edits made, or other workspace side effects.

Fail the execution stage when required behaviors are missing or when forbidden behaviors appear.

### Stage 3: Outcome

Judge the final output with an LLM-as-judge pass that reuses `skill-output-criteria.md`.

Use the fixture's `judge_rubric` field so the harness can swap in a different rubric later without changing the harness logic.

The judge should score the output against the rubric, summarize strengths, and list concrete misses.

This stage measures whether the skill produced a good result, not just whether it loaded.

### Stage 4: Regression

Normalize the final output before comparison so formatting noise does not create false regressions.

Store a normalized output snapshot and a trace snapshot for each passing fixture.

Compare the current normalized output and trace snapshot against `baseline_output` and the prior trace baseline.

Treat criteria or harness-protocol changes as a full rebaseline event rather than a regression.

## Normalization Guidance

Strip volatile fields such as timestamps, absolute temp paths, and run identifiers before saving comparison artifacts.

Collapse whitespace-only differences unless whitespace is itself part of the expected behavior.

Preserve ordered lists, section headers, and terminal status markers when they are part of the contract under test.

## Reporting

Each fixture report should record activation status, execution evidence, outcome score, and regression verdict.

Failures should identify the first broken stage and include the minimal evidence needed to reproduce it.
