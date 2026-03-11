# Calibration Examples — Good vs Bad Agent Output

Centralized calibration anchors for SWE pipeline agents. Each agent's definition references this file for its Good/Bad examples, keeping the agent body focused on procedures and principles.

This reference is self-contained. For agent definitions, see `agents/swe/`. For stage procedures, see `pipeline-stages.md`.

## How Agents Reference This File

Agent definitions include a pointer in their Calibration section:

```text
## Calibration

See calibration examples at `skills/swe/methodology/references/calibration-examples.md` — Analyst section.
```

---

## Analyst Agent

### Constraint Enumeration (Stage 2) — Bad Example

> Input: "Add caching to the API" at Standard depth.

```markdown
## Constraint Profile

### Performance
- System should be fast
- Caching should improve response times

### Technology
- We need to use Redis or something similar

### Scope
- Should be done soon
```

**Why bad**: "Should be fast" is unmeasurable — violates SMTOE quality standard (not Specific, not Measurable, not Time-bounded). "Redis or something similar" is vague — not classified by Rigidity/Source/Controllability. Only 3 of 6 categories swept — Operations, Team, and Business categories skipped entirely. No conflict analysis. No evidence from codebase survey.

### Constraint Enumeration (Stage 2) — Good Example

> Input: "Add caching to the API" at Standard depth.

```markdown
## Constraint Profile

### Performance
| Constraint | Rigidity | Source | Controllability | Threshold |
|-----------|----------|--------|----------------|-----------|
| P95 response time < 200ms for cached endpoints | Hard | Explicit (SLA) | External | Measured via APM |
| Cache invalidation latency < 5s for write-through | Soft | Implicit (industry) | Controllable | Acceptable staleness window |

### Technology
| Constraint | Rigidity | Source | Controllability | Threshold |
|-----------|----------|--------|----------------|-----------|
| Must use existing Redis 7.x cluster (shared infra) | Hard | Explicit (ops team) | Shared | No new infrastructure provisioning |
| Client library must support async/await pattern | Soft | Discovered (codebase uses async throughout) | Controllable | Checked via `grep -r "async def" src/` |

### Conflict Analysis
| Constraint A | Constraint B | Tension | Resolution |
|-------------|-------------|---------|------------|
| P95 < 200ms | Cache invalidation < 5s | Aggressive TTL vs freshness | **Tier**: hot paths get 1s TTL, cold paths get 30s TTL |
```

**Why good**: Every constraint has 3-axis classification and measurable threshold. Evidence cited from codebase (`grep` results) and external sources (SLA). Conflict analysis identifies specific tension with named resolution strategy from `conflict-resolution-patterns.md`. All 6 categories swept (remaining categories would follow in full artifact).

### Architecture Design (Stage 3) — Bad Example

> Input: "Add caching to the API" with Constraint Profile available.

```markdown
## Architecture Spec

### Design
We should add a caching layer using Redis. It will sit between the API and the database.
This is the standard approach and should work well for our use case.
```

**Why bad**: Only one alternative considered — no comparison basis. No constraint traceability ("should work well" references no constraint). No component breakdown or data model. "Standard approach" is an unsupported claim — no evidence. Orphan decision: no driving constraint documented.

### Architecture Design (Stage 3) — Good Example

> Input: "Add caching to the API" with Constraint Profile available.

```markdown
## Architecture Spec

### Alternatives Considered
| Alternative | Hard Constraints Met | Soft Constraints Met | Trade-offs |
|------------|---------------------|---------------------|------------|
| A: Read-through cache (Redis) | P95 ✓, Redis cluster ✓ | Async ✓, Invalidation ✓ | Added complexity in cache key management |
| B: Application-level memoization | P95 ✓ | Async ✓ | No shared state across instances; invalidation ✗ |

**Selected**: Alternative A — satisfies all Hard constraints and cache invalidation Soft constraint that B cannot meet.

### Constraint Traceability
| Design Decision | Driving Constraint(s) | Rationale |
|----------------|----------------------|-----------|
| Redis read-through pattern | P95 < 200ms (Hard), existing Redis cluster (Hard) | Leverages shared infra, meets latency SLA |
| TTL-based invalidation with tiered expiry | Cache invalidation < 5s (Soft), P95 < 200ms (Hard) | Resolves Tier strategy from Constraint Profile conflict analysis |
```

**Why good**: Two alternatives evaluated against specific constraints from the Constraint Profile. Selection justified by Hard constraint coverage. Every design decision traces to at least one constraint with rationale. Tiered TTL decision references the conflict resolution from Stage 2, demonstrating artifact chain continuity.

---

## Implementer Agent

### Stage 5 (Test) — Bad Example

> Input: Interface with a `search(query: &str) -> Vec<SearchResult>` method.

```rust
#[test]
fn test_search() {
    let engine = SearchEngine::new();
    let results = engine.search("hello");
    assert!(results.len() > 0);
}
```

**Why bad**: Generic test name — not behavior-based (`test_search` says nothing about what behavior is tested). No AAA pattern separation. `assert!(len > 0)` is a weak assertion — does not verify actual behavior, any non-empty result passes. No edge cases tested (empty query, no matches, multiple matches). No error path testing. No Red phase validation documented. Single test cannot characterize the interface contract.

### Stage 5 (Test) — Good Example

```rust
#[test]
fn test_search_when_query_matches_title_should_return_matching_documents() {
    // Arrange
    let engine = SearchEngine::new();
    engine.index(Document::new("rust-guide", "# Rust Programming Guide\nLearn Rust..."));

    // Act
    let results = engine.search("Rust Programming");

    // Assert
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].document_id, "rust-guide");
    assert!(results[0].score > 0.0);
}

#[test]
fn test_search_when_no_match_should_return_empty() {
    // Arrange
    let engine = SearchEngine::new();
    engine.index(Document::new("rust-guide", "# Rust Guide"));

    // Act
    let results = engine.search("python");

    // Assert
    assert!(results.is_empty());
}
```

**Why good**: Behavior-based naming following the `test_<behavior>_when_<condition>_should_<expected>` convention. Clear AAA pattern with comments. Tests specific behavior with precise assertions (`assert_eq!` over `assert!`). Includes both positive case (match found) and negative case (no match). Each test is independent with its own setup. Verifiable and reproducible.

### Stage 6 (Implement) — Bad Example

> Input: Tests for basic search functionality.

```rust
impl SearchEngine {
    pub fn search(&self, query: &str) -> Vec<SearchResult> {
        // Full-text search with BM25 ranking, stemming,
        // fuzzy matching, and result highlighting
        let tokens = self.tokenize(query);
        let stemmed = self.stem(&tokens);
        let fuzzy_matches = self.fuzzy_search(&stemmed);
        let ranked = self.bm25_rank(&fuzzy_matches);
        let highlighted = self.highlight(&ranked, &tokens);
        highlighted.into_iter().map(|h| h.into_result()).collect()
    }
}
```

**Why bad**: Over-implemented far beyond what tests require. Added BM25 ranking, stemming, fuzzy matching, and highlighting — none of which have test coverage. Violates "minimal code to pass tests" principle. Introduces untested code paths that may contain bugs. If these features are needed, they should be specified in Interface Contracts and tested in Stage 5 first.

### Stage 6 (Implement) — Good Example

```rust
impl SearchEngine {
    pub fn search(&self, query: &str) -> Vec<SearchResult> {
        let query_lower = query.to_lowercase();
        self.documents
            .iter()
            .filter(|doc| doc.content.to_lowercase().contains(&query_lower))
            .map(|doc| SearchResult {
                document_id: doc.id.clone(),
                score: 1.0,
            })
            .collect()
    }
}
```

**Why good**: Minimal code that makes existing tests pass. Case-insensitive substring matching is the simplest approach that satisfies the test assertions. No features beyond what tests verify — no ranking, no stemming, no fuzzy matching. Simple, correct, and readable. Can be optimized later in Stage 8 if profiling shows need and the Constraint Profile has performance targets that require it.

---

## Reviewer Agent

### Bad Finding

```text
### PERF-1: Performance concern

**Severity**: P1
**Location**: src/search.rs
**Finding**: This function might be slow
**Suggestion**: Consider optimizing it
```

**Why bad**: No evidence ("might be slow" — based on what?). No specific line number. No impact assessment. P1 severity without justification. Suggestion is vague ("consider optimizing" — how?). No constraint reference. This finding is unactionable noise.

### Good Finding

```text
### PERF-1: O(n*m) nested iteration in search ranking

**Severity**: P2
**Perspective**: Performance
**Location**: src/search/ranking.rs:42-58
**Finding**: The `rank_results` function iterates over all documents (outer loop) and for each document iterates over all query terms (inner loop), producing O(n*m) complexity where n=documents, m=terms. With the expected corpus size of 10K documents and average 5 terms per query, this processes 50K iterations per search.
**Impact**: At Standard depth Constraint Profile target of p95 < 200ms, this approach is marginal. At 100K documents it will exceed the target.
**Suggestion**: Pre-compute a term-to-document inverted index during indexing. This converts search from O(n*m) to O(m*k) where k is average documents per term (typically << n). Change `rank_results` to look up the inverted index instead of scanning all documents.
```

**Why good**: Specific location with line numbers. Evidence-based complexity analysis with concrete numbers. Impact assessment tied to Constraint Profile targets. Severity calibrated correctly (P2, not P1 — currently marginal, not broken). Concrete fix suggestion with expected improvement.
