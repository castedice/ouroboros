# Source Evaluation Criteria

Detailed rubric for assessing source quality across three dimensions. Applied during Step 3 (Source Evaluation) of the research workflow.

## Credibility Assessment

Credibility measures how trustworthy a source's claims are, independent of whether those claims are relevant to the research question.

### Credibility Indicators

| Indicator | High Credibility | Medium Credibility | Low Credibility |
|-----------|-----------------|-------------------|----------------|
| **Provenance** | Official documentation, original author | Reputable tech blog, conference talk | Anonymous post, no attribution |
| **Methodology** | Shows how conclusions were reached | Provides some reasoning | Asserts without evidence |
| **Peer status** | Peer-reviewed, widely cited | Referenced by credible sources | No external validation |
| **Internal consistency** | Claims are consistent throughout | Minor inconsistencies | Self-contradictory |
| **Transparency** | Acknowledges limitations | Partially acknowledges | Presents as absolute truth |

### Credibility Scoring

- **High (3)**: 4+ high indicators. Source can be cited directly
- **Medium (2)**: Mix of high and medium indicators. Source is useful but claims should be cross-referenced
- **Low (1)**: 2+ low indicators. Source should not be used as sole evidence for any claim

### Special Cases

**Source code as source**: Repository code is high-credibility evidence for "what exists" but low-credibility evidence for "what works well" — code existence doesn't imply quality. Assess code quality separately from code existence.

**AI-generated content**: Treat with medium credibility at best. Cross-reference all factual claims against primary sources. AI content is useful for identifying topics and framing questions, not for establishing facts.

## Cross-Referencing Strategy

Cross-referencing validates claims by checking them against independent sources. A claim supported by a single source is a data point; supported by three independent sources, it's a finding.

### Cross-Reference Procedure

1. **Identify key claims**: Extract the 3-5 most important claims from each source
2. **Check independence**: Sources that cite each other are not independent — trace back to the original
3. **Compare across sources**: For each claim, check how many independent sources support it
4. **Rate confidence**:

| Independent confirmations | Confidence | Treatment |
|--------------------------|------------|-----------|
| 3+ sources agree | **High** | Include as established finding |
| 2 sources agree | **Medium** | Include with "supported by N sources" note |
| 1 source only | **Low** | Include only if high-credibility source; mark as "single-source claim" |
| Sources disagree | **Contested** | Flag for Contradiction Resolution in synthesis |

### Independence Test

Two sources are independent if:

- They do not cite each other
- They are not authored by the same person or organization
- They were produced at different times without knowledge of each other

Blog posts that summarize the same conference talk are NOT independent — they are the same source with different wrappers.

## Relevance Scoring

Relevance measures how directly a source addresses the research question. A Nobel Prize paper on an unrelated topic has zero relevance.

### Relevance Tiers

| Tier | Definition | Treatment |
|------|-----------|-----------|
| **Direct (3)** | Addresses the research question head-on | Full inclusion in synthesis; highest weight |
| **Tangential (2)** | Addresses a related topic; insights transferable | Partial inclusion; extract only applicable patterns |
| **Background (1)** | Provides context but doesn't answer the question | Context only; do not cite as evidence for findings |

### Relevance Decision Matrix

| Credibility | Relevance | Action |
|-------------|-----------|--------|
| High | Direct | **Core source** — full synthesis inclusion |
| High | Tangential | **Supporting source** — extract transferable insights |
| High | Background | **Context source** — reference for framing only |
| Medium | Direct | **Key source** — include but cross-reference claims |
| Medium | Tangential | **Optional source** — include if it adds unique perspective |
| Low | Any | **Exclude** — unreliable regardless of relevance |
| Any | Background | **Context only** — never cite as primary evidence |

## Freshness Evaluation

Freshness matters differently by topic type. Foundational concepts (design patterns, algorithms) age slowly; implementation details (API versions, library syntax) age quickly.

### Freshness Categories

| Category | Half-life | Examples |
|----------|----------|---------|
| **API/Library** | 6-12 months | Framework APIs, SDK versions, cloud service configs |
| **Best practices** | 2-3 years | Design patterns for specific tech stacks, testing strategies |
| **Foundational** | 5-10+ years | Algorithms, data structures, architectural principles |
| **Timeless** | N/A | Mathematical proofs, formal logic, core CS theory |

### When Freshness Matters

- **Fast-moving topic** (AI tools, cloud services): Prioritize sources from the last 12 months. Older sources are background context only
- **Stable topic** (design patterns, architectural principles): Sources from the last 5 years are equally valid. Seminal older papers may be more valuable than recent rehashes
- **Mixed topic** (plugin architecture for AI tools): Apply freshness to implementation details but not to architectural principles

### Stale Source Handling

When a source scores High credibility but Low freshness:

1. Check if the claims are time-sensitive (API specifics, version-dependent behavior)
2. If time-sensitive: down-weight to Background relevance, note "may be outdated"
3. If not time-sensitive: retain original relevance score, note publication date for context
