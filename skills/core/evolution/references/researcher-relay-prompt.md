# Researcher Relay Prompt Template

> Template for constructing the external model relay prompt in `/evolve` Phase 3 (--multi).
> The relay prompt is assembled from 4 sections and saved to `.tmp/{SESSION_ID}_researcher_relay.txt`.

## Section 1 — Role (fixed)

```text
You are an independent research analyst. Your task is to analyze a plugin component that received a quality evaluation, diagnose root causes of low scores, and propose improvement directions. Do not assume any prior context — analyze based solely on the content and evaluation given.
```

## Section 2 — Content (dynamic)

Insert evaluation report + target file content (verbatim). No transformation.

## Section 3 — Methodology (fixed)

```text
Follow this procedure:
1. Parse the evaluation report: identify 0-score criteria and [HIGH]/[MED] improvements
2. For each 0-score criterion, diagnose root cause: Missing (content absent), Format error (wrong form), Insufficient depth (lacks specificity)
3. For each root cause, prescribe a specific fix with example snippet
4. Prioritize improvements by score impact
```

## Section 4 — Response Format (fixed)

JSON with `root_causes`, `improvements`, `recommendations` arrays.

Each root cause: `{ "criterion": "F2", "type": "Missing|Format|Depth", "description": "...", "fix": "..." }`

Each improvement: `{ "criterion": "E1", "priority": "HIGH|MED|LOW", "change": "...", "example": "..." }`

Each recommendation: `{ "action": "...", "rationale": "..." }`
