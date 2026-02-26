---
type: generate
date: ${DATE}
module: ${MODULE}
capabilities: [${CAPABILITIES}]
intent: "${INTENT}"
evaluation-summary: "${EVALUATION_SUMMARY}"
---

## Background

${BACKGROUND — why this module was created, domain context, knowledge base inputs}

## Decisions

${DECISIONS — architectural choices made during generation}

- {Decision 1}: {rationale}
- {Decision 2}: {rationale}

## Generated Components

| Path | Type | Score | Description |
|------|------|-------|-------------|
| `commands/${MODULE}/{name}.md` | command | ${SCORE}/5 | ${description} |
| `agents/${MODULE}/{name}.md` | agent | ${SCORE}/5 | ${description} |
| `skills/${MODULE}/{name}.md` | skill | ${SCORE}/5 | ${description} |
| `templates/${MODULE}/{name}.md` | template | — | ${description} |

## Verification

- Components generated: ${COUNT}
- Quality gate: ${PASS_COUNT}/${TOTAL_COUNT} passed (>= 3/5)
- Retry used: ${yes|no}
