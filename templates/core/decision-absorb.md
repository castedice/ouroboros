---
type: absorb
date: ${DATE}
module: ${MODULE}
source: "${SOURCE}"
source-type: ${SOURCE_TYPE}
mode: ${MODE}
intent: "${INTENT}"
evaluation-summary: "${EVALUATION_SUMMARY}"
---

## Background

${BACKGROUND — why this source was absorbed, what triggered the absorption}

## Source

- **Source**: ${SOURCE}
- **Source Type**: ${SOURCE_TYPE — local | web | topic}
- **Mode**: ${MODE — new-module | integrate}
${IF MODE=integrate: - **Target Module**: ${TARGET_MODULE}}

## Research Findings

${RESEARCH_FINDINGS — key patterns and insights extracted from the source}

- {Finding 1}
- {Finding 2}
- {Finding 3}

## Decisions

${DECISIONS — module name choice, gap selections, what was adapted vs faithfully copied}

- {Decision 1}: {rationale}
- {Decision 2}: {rationale}

${IF MODE=integrate AND CONFLICTS EXIST:}

## Conflicts

| Capability | Source | Existing | Resolution |
|------------|--------|----------|------------|
| ${capability} | ${source component} | ${existing component} | ${skipped — user decision needed} |

## Generated Components

| Path | Type | Score | Description |
|------|------|-------|-------------|
| `${COMPONENT_PATH}` | ${TYPE} | ${SCORE}/5 | ${description} |

## Knowledge Entry

- **Path**: `docs/specs/knowledge/${FILENAME}.md`
- **Tags**: ${TAGS}
- **Related entries**: ${RELATED — entries with overlapping tags, or "None"}

## Verification

- Components generated: ${COUNT}
- Quality gate: ${PASS_COUNT}/${TOTAL_COUNT} passed (>= 3/5)
- Retry used: ${yes|no}
- Previously absorbed: ${yes (date) | no}
