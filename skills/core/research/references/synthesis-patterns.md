# Synthesis Patterns

Four techniques for combining research findings into actionable knowledge. Applied during Step 4 (Synthesis) of the research workflow.

## Technique Selection Guide

| Technique | Best For | Starting Point | Output |
|-----------|----------|----------------|--------|
| Triangulation | Validating specific claims | A claim appearing in multiple sources | Confidence rating per claim |
| Gap Analysis | Finding blind spots | Complete set of collected findings | List of unanswered questions |
| Pattern Extraction | Identifying recurring themes | Broad topic with diverse sources | Named patterns with evidence |
| Contradiction Resolution | Handling disagreements | Two credible sources that disagree | Resolved position with reasoning |

**Recommended sequence**: Pattern Extraction first (broad sweep), then Triangulation (validate key claims), then Gap Analysis (identify what's missing), then Contradiction Resolution (handle disagreements found during earlier steps).

---

## 1. Triangulation

**Definition**: Validate a claim by finding independent supporting evidence from multiple sources. Confidence increases with the number and independence of confirming sources.

**When to use**: When a finding is important enough to act on and you need to assess how reliable it is. Not every claim needs triangulation — focus on claims that would change decisions.

**Procedure**:

1. Extract the claim in precise, falsifiable form
2. Identify which sources support, contradict, or are silent on the claim
3. Assess independence of supporting sources (see Source Evaluation: Independence Test)
4. Assign confidence level:
   - **Strong**: 3+ independent sources agree, no credible contradictions
   - **Moderate**: 2 independent sources agree, or 1 high-credibility primary source
   - **Weak**: Single source, or multiple non-independent sources
   - **Contested**: Credible sources disagree (escalate to Contradiction Resolution)

**Example**: Claim: "Separating command orchestration from domain knowledge improves maintainability."
- Source A (plugin architecture paper): supports with maintenance cost data
- Source B (ouroboros DR-012): supports with design rationale
- Source C (monolith blog post): silent on this specific claim
- **Confidence**: Strong (2 independent sources with evidence)

**Pitfalls**:

- Counting non-independent sources as separate confirmations — 5 blog posts citing the same paper are 1 source
- Treating absence of contradiction as confirmation — silence is not agreement

---

## 2. Gap Analysis

**Definition**: Identify what questions remain unanswered after synthesis. Gaps are not failures — they are explicit boundaries of current knowledge that guide future research.

**When to use**: After initial synthesis, to assess completeness and identify follow-up research directions.

**Procedure**:

1. List the original research questions (from Step 1: Scope Definition)
2. For each question, assess coverage:
   - **Answered**: Strong or moderate confidence finding addresses it
   - **Partially answered**: Some evidence, but incomplete or weak confidence
   - **Unanswered**: No collected source addresses this question
3. For unanswered and partially answered questions:
   - Is the gap due to insufficient collection (more sources exist but weren't found)?
   - Is the gap due to the topic being genuinely under-explored?
   - Is the gap outside the current research scope (note for future research)?
4. Prioritize gaps by impact: which unanswered questions would most change decisions?

**Gap classification**:

| Gap Type | Cause | Action |
|----------|-------|--------|
| **Collection gap** | Sources exist but weren't found | Targeted follow-up search |
| **Knowledge gap** | Topic is genuinely under-explored | Note as "open question" in knowledge entry |
| **Scope gap** | Question is out of current scope | Note for future `/research` invocation |

**Pitfalls**:

- Treating gaps as failures that must be filled before reporting — explicit gaps are more honest than false completeness
- Ignoring gaps that challenge the emerging narrative — uncomfortable gaps are often the most important

---

## 3. Pattern Extraction

**Definition**: Identify recurring themes, conventions, or approaches across multiple sources. A pattern is a named, reusable insight that appears in 2+ independent contexts.

**When to use**: When researching a broad topic where multiple approaches or conventions exist. Pattern extraction is the primary synthesis technique for most research tasks.

**Procedure**:

1. Read through all evaluated sources, noting recurring themes
2. For each candidate pattern:
   - **Name it**: A concise, descriptive label (e.g., "Inline Skill Embedding", "Tiered Validation Gate")
   - **Evidence**: Cite specific passages from 2+ sources using `>` block quotes
   - **Frequency**: How many sources exhibit this pattern?
   - **Variations**: How does the pattern differ across sources?
   - **Trade-offs**: What are the benefits and costs of this pattern?
   - **Applicability**: How does this pattern apply to the ouroboros context?
3. Classify patterns by type:
   - **Structural**: Organization, layout, naming conventions
   - **Behavioral**: How processes work, control flow, decision points
   - **Quality**: Standards, criteria, validation approaches
4. Rank patterns by actionability: which can be directly applied vs. which need adaptation?

**Pattern quality test**: A well-extracted pattern should be:

- **Named**: Has a descriptive label, not a vague description
- **Evidenced**: Cites specific source content, not "many sources do this"
- **Assessed**: Includes trade-offs and applicability, not just existence

**Pitfalls**:

- Extracting surface similarities as patterns — "both use markdown" is an observation, not a pattern
- Naming patterns too vaguely — "good structure" is not a pattern; "Phase-Gate Command Architecture" is

---

## 4. Contradiction Resolution

**Definition**: When two credible sources disagree on a factual claim or recommended approach, determine which position is better supported and why.

**When to use**: When Triangulation reveals contested claims between sources that both score Medium or High credibility.

**Procedure**:

1. State both positions precisely, citing each source
2. Assess evidence quality for each position:
   - Is the evidence empirical or theoretical?
   - Is the evidence based on the same context as our research question?
   - Is one source more recent with access to newer information?
3. Check for false contradictions:
   - Are the sources discussing the same context? ("X is good for small projects" vs. "X is bad for large projects" is not a contradiction)
   - Are the sources using different definitions? (Terminology mismatch)
   - Are the sources discussing different time periods? (Historical vs. current)
4. Resolve:
   - **Context-dependent**: Both are correct in different contexts → note the conditions under which each applies
   - **Evidence-weighted**: One position has stronger evidence → adopt with acknowledgment of the alternative
   - **Unresolvable**: Evidence is genuinely balanced → present both positions and note as open question

**Resolution template**:

```markdown
### Contradiction: {topic}

**Position A** ({source}): {claim}
**Position B** ({source}): {claim}

**Analysis**: {why they disagree — context, definitions, evidence quality}

**Resolution**: {which position we adopt and why, or "context-dependent" with conditions}
```

**Pitfalls**:

- Defaulting to the more recent source — newer is not always better
- Splitting the difference — "the truth is somewhere in the middle" is rarely a valid resolution
- Ignoring the contradiction — unresolved contradictions should be flagged, not hidden

---

## Knowledge Entry Structuring

After synthesis, structure findings into the standard knowledge entry format:

### Frontmatter Fields

| Field | Source | Purpose |
|-------|--------|---------|
| `title` | Derived from research question | Discovery by title search |
| `tags` | Extracted from patterns + existing tag vocabulary | Discovery by tag overlap |
| `source` | Original research target (path, URL, topic) | Provenance tracking |
| `created` | Today's date | Freshness assessment |
| `status` | `active` (default) | Lifecycle management |
| `related` | Knowledge entries with 30%+ tag overlap | Cross-reference network |

### Body Structure

1. **Overview**: What was researched and why (2-3 sentences)
2. **Key Patterns**: Named patterns with evidence (the core of the entry)
3. **Practical Applications**: How findings apply to the target domain
4. **Trade-offs**: Limitations, caveats, and conditions
5. **References**: Source citations with credibility notes

### Actionability Test

Before finalizing, verify each finding passes the actionability test: "Can someone who reads only this entry (not the original sources) take a concrete action based on this finding?" If not, the finding needs more specificity or context.
