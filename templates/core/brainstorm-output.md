# Brainstorm Analysis Output Format

When used with `--output`, include this frontmatter at the top of the file:

```yaml
---
topic: "{topic}"
framework: "{framework used or 'default'}"
date: "{YYYY-MM-DD}"
tags: [{relevant tags}]
models: ["{models used}"]
---
```

## Brainstorm Analysis: {topic}

**Context summary**: {1-2 sentences on what was explored and what context was available}

### Generated Ideas

{8-15 ideas, each with technique attribution and one-sentence description}

| # | Idea | Technique | Description |
|---|------|-----------|-------------|
| 1 | {idea name} | {technique name from divergent-techniques.md} | {one sentence} |
| 2 | ... | ... | ... |

### Clusters

#### {Cluster 1 Name}

Ideas: #{n}, #{m}, ...

{Why these ideas belong together. What theme unites them.}

#### {Cluster 2 Name}

Ideas: #{n}, #{m}, ...

{Why these ideas belong together.}

(repeat for each cluster; standalone ideas noted separately)

### Convergent Assessment

| # | Idea | Feasibility | Impact | Risk | Rationale |
|---|------|-------------|--------|------|-----------|
| {n} | {idea name} | High/Med/Low | High/Med/Low | High/Med/Low | {specific reason} |

### Top 3 Recommendations

#### 1. {Idea name}

**Why recommended**: {specific rationale citing feasibility, impact, alignment}
**Weakness**: {at least one honest weakness or risk}
**Next action**: `/{suggested-command} {args}` — {what this achieves}

#### 2. {Idea name}

**Why recommended**: {rationale — why this is #2, not #1}
**Weakness**: {weakness}
**Next action**: `/{suggested-command} {args}`

#### 3. {Idea name}

**Why recommended**: {rationale — why worth considering despite ranking}
**Weakness**: {weakness}
**Next action**: `/{suggested-command} {args}`

### Not Selected

{Brief note on what ideas were explored but not recommended, and why — prevents information loss}
