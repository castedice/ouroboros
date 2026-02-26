# Evolution Analysis Output Format

## Improvement Analysis: {component name}

**Current Score**: {n}/5 (Level {level})
**Target Score**: {target}/5

### Root Cause Analysis

#### {Criterion name} (score: 0)

**Root cause**: {Missing|Format error|Insufficient depth} — {specific description}
**Evidence**:
> {quote from target file, or "No relevant content found"}

**Fix direction**: {specific modification direction}
**Example**:
```text
{improved form snippet}
```

(repeat for each 0-score criterion)

### Improvement Priorities

| # | Target | Type | Current | Fix | Impact |
|---|--------|------|---------|-----|--------|
| 1 | {criterion/item} | 0-score | {current state} | {fix direction} | Score {n}→{n+1} |
| 2 | {item} | [HIGH] | {current state} | {fix direction} | {impact} |
| ... | ... | ... | ... | ... | ... |

### Knowledge Base Patterns

- {relevant pattern from docs/knowledge/, with citation}
- (or "No relevant knowledge entries found")

### Recommendations

1. {Top priority — highest score impact}
2. {Secondary improvement}
3. {Areas needing further investigation, if any}
