# Convergent Analysis Criteria

Structured framework for evaluating and ranking ideas generated during the divergent phase. All assessments must cite specific reasons — intuition alone is not valid.

## Feasibility × Impact Matrix

The primary evaluation tool. Plot each idea on the 2×2 matrix to establish a priority ranking.

|  | **High Feasibility** | **Low Feasibility** |
|---|---|---|
| **High Impact** | **Do First** — clear wins, prioritize immediately | **Invest** — high reward justifies research/prototyping effort |
| **Low Impact** | **Quick Wins** — easy but marginal, do if time permits | **Avoid** — high cost, low reward, deprioritize |

### Feasibility Assessment

Score each idea's feasibility based on four factors:

| Factor | High | Medium | Low |
|--------|------|--------|-----|
| **Technical complexity** | Uses existing tools/patterns | Requires moderate new work | Requires fundamental new capability |
| **Existing resources** | Leverages current codebase directly | Needs adaptation of existing code | Requires building from scratch |
| **Dependencies** | No external dependencies | Manageable dependencies (1-2) | Heavy dependency chain or blocking dependencies |
| **Reversibility** | Easy to undo if it fails | Partially reversible | Irreversible or very costly to undo |

An idea is **High Feasibility** when 3+ factors are High. **Low Feasibility** when 2+ factors are Low.

### Impact Assessment

Score each idea's impact based on three factors:

| Factor | High | Medium | Low |
|--------|------|--------|-----|
| **User value** | Directly solves a user pain point or enables a new workflow | Improves existing workflow noticeably | Marginal improvement or internal-only benefit |
| **Scope of effect** | Affects multiple commands/agents/modules | Affects one component significantly | Affects one component marginally |
| **Compound potential** | Creates foundation for future improvements | Some reuse potential | One-time benefit, no compounding |

An idea is **High Impact** when 2+ factors are High. **Low Impact** when all factors are Low or Medium.

## Risk Assessment

Apply to top candidates (typically the top 3 from the Feasibility × Impact matrix). Risk assessment refines the ranking but does not override it — a High Impact/High Feasibility idea with moderate risk still ranks above a Low Impact/High Feasibility idea with no risk.

| Dimension | Questions to Ask |
|-----------|-----------------|
| **Technical risk** | Does this depend on unproven technology? Could it fail silently? Are there known failure modes? |
| **Dependency risk** | Does this require external services, APIs, or tools that we don't control? Could a dependency change break this? |
| **Reversibility risk** | If this doesn't work, can we roll it back cleanly? Does it create migration burden for users? |
| **Interaction risk** | Could this interfere with existing functionality? Does it change behavior that other components depend on? |

## Alignment Assessment

Verify that top candidates align with the broader system's design philosophy. Alignment is a filter, not a ranking criterion — misaligned ideas should be flagged, not silently deprioritized.

| Dimension | Assessment |
|-----------|-----------|
| **Philosophy fit** | Does this idea align with the system's core principles? (For ouroboros: co-evolution, compound growth, right-sized abstraction) |
| **Architecture fit** | Does this idea respect the existing architecture? (For ouroboros: modular monolith, command/skill/agent separation, read-only agents) |
| **User value alignment** | Does this serve the user's stated goals, or is it internally motivated? |

An idea that scores High on Feasibility × Impact but fails Alignment should be presented with the misalignment noted, not silently dropped. The user may decide the misalignment is acceptable.

## Effort Estimation

Rough categorization for planning purposes. Not a precise estimate — brainstorming is not the place for detailed estimation.

| Category | Description | Typical Scope |
|----------|-------------|---------------|
| **Trivial** | Configuration change or minor edit | < 1 hour, 1-2 files |
| **Small** | Single component addition or modification | 1 session, 3-5 files |
| **Medium** | Multi-component change or new capability | 2-3 sessions, 5-10 files |
| **Large** | Architectural change or new module | Multiple sessions, 10+ files |

## Decision Framework

When the top 3 ideas are close in ranking, use these tiebreakers in order:

1. **Reversibility**: Prefer ideas that can be undone if they fail
2. **Compound potential**: Prefer ideas that create foundations for future work
3. **Simplicity**: When all else is equal, the simpler idea wins
4. **User energy**: Does the user seem excited about one idea? Motivation is a legitimate factor

When two ideas are complementary rather than competing, note that they can be pursued sequentially rather than forcing a choice.

## Extended Evaluation Tools

Five additional evaluation tools for situations where the Feasibility × Impact matrix needs supplementary analysis. These tools do not replace the primary matrix — they refine rankings when the matrix alone produces ties or when specific evaluation dimensions matter.

### Novelty Assessment

**Description**: Evaluates how genuinely new an idea is compared to existing implementations, prior brainstorm results, and industry norms. Novelty is not inherently good — incremental improvements are often more valuable than novel but unproven approaches. Use Novelty Assessment to distinguish between ideas that are new-to-us (we haven't tried it, but others have) and ideas that are new-to-everyone (genuinely uncharted).

**Assessment dimensions**:

| Dimension | High Novelty | Medium Novelty | Low Novelty |
|-----------|-------------|----------------|-------------|
| **vs. Current system** | Nothing like this exists in the codebase | Extends an existing pattern in a new direction | Variation of something already implemented |
| **vs. Prior brainstorms** | Never proposed before | Proposed but not attempted | Proposed and attempted (re-surfacing) |
| **vs. Industry** | No known implementations elsewhere | Implemented elsewhere, not in this domain | Common pattern applied straightforwardly |

**Scoring guide**: High Novelty on 2+ dimensions = genuinely novel. Low Novelty on all dimensions = incremental. Medium on all = moderate novelty (the most common and often most practical zone).

**When to prefer over Feasibility × Impact**: When the brainstorm goal is explicitly innovation-oriented (e.g., "explore new approaches" rather than "improve existing system"). When multiple ideas score identically on Feasibility × Impact, novelty breaks the tie by revealing which ideas push the system forward vs. staying in place.

---

### TRIZ Contradiction Check

**Description**: Evaluates whether an idea genuinely resolves a contradiction or merely shifts the trade-off to a different parameter. Based on TRIZ principles — the best solutions eliminate contradictions rather than compromising between them. An idea that improves Parameter A at the cost of Parameter B has shifted the contradiction, not resolved it.

**Assessment dimensions**:

| Dimension | Resolved | Shifted | Compromised |
|-----------|----------|---------|-------------|
| **Primary parameter** | Improves as intended | Improves as intended | Partially improves |
| **Secondary parameter** | Also improves or stays neutral | Worsens (new trade-off) | Partially worsens |
| **System side effects** | No new problems introduced | New problems in a different area | Known limitations accepted |

**Scoring guide**: Resolved = ideal (both parameters improve). Shifted = acceptable if the new trade-off is less severe than the original. Compromised = weakest — should be ranked below Resolved and Shifted alternatives.

**When to prefer over Feasibility × Impact**: When the brainstorming topic was framed as a contradiction or trade-off (e.g., "evaluation thoroughness vs. speed"). In these cases, how completely an idea resolves the contradiction is more diagnostic than generic feasibility/impact scoring. Also useful as a secondary filter: among ideas with equal Feasibility × Impact, prefer those that resolve contradictions over those that shift them.

---

### Weighted Decision Matrix

**Description**: A multi-criteria scoring system that assigns different weights to different evaluation criteria based on their importance for the specific brainstorming context. Unlike Feasibility × Impact (which uses two fixed dimensions), the Weighted Decision Matrix supports 3-7 custom dimensions with explicit weights. More precise but more time-consuming — use it only when the extra precision matters.

**Assessment dimensions** (example — customize per context):

| Criterion | Weight | Score 1-5 | Weighted Score |
|-----------|--------|-----------|----------------|
| Technical feasibility | 30% | — | — |
| User impact | 25% | — | — |
| Architectural fit | 20% | — | — |
| Implementation risk | 15% | — | — |
| Compound potential | 10% | — | — |
| **Total** | **100%** | — | **Σ** |

**Scoring guide**: Define 3-7 criteria relevant to the brainstorm topic. Assign weights summing to 100%. Score each idea 1-5 on each criterion. Multiply score × weight, sum for total. Rank by total weighted score. Two ideas within 5% of each other should be treated as tied — the precision of 1-5 scoring does not support finer distinctions.

**When to prefer over Feasibility × Impact**: When 3+ evaluation criteria matter and their relative importance is unequal. Feasibility × Impact treats both dimensions as equally important, which is a reasonable default but may not match the context. For example, if architectural fit matters far more than implementation speed, a Weighted Decision Matrix captures this priority structure. Do not use for fewer than 3 criteria — Feasibility × Impact is simpler and sufficient.

---

### Time-to-Value

**Description**: Evaluates how quickly an idea delivers its first meaningful value. Time-to-Value is distinct from feasibility (which asks "can we do it?") — an idea can be highly feasible but have a long time-to-value because its benefits only materialize after extensive adoption or integration. Conversely, a moderately feasible idea might deliver value immediately upon completion.

**Assessment dimensions**:

| Dimension | Fast (days) | Medium (weeks) | Slow (months) |
|-----------|------------|----------------|----------------|
| **Implementation to first value** | Value appears as soon as code is merged | Value appears after integration with other components | Value appears after ecosystem adoption or behavioral change |
| **Value growth curve** | Full value immediately | Value grows as usage increases | Value only meaningful at scale |
| **Dependency chain** | No dependencies — standalone value | Requires 1-2 other changes first | Requires significant prerequisite work |

**Scoring guide**: Fast on all dimensions = immediate value. Slow on "Implementation to first value" = deferred value regardless of other dimensions. An idea with Fast implementation but Slow growth curve delivers a small win quickly, then grows — often a good strategy for building momentum.

**When to prefer over Feasibility × Impact**: When prioritizing a roadmap or sprint — Feasibility × Impact tells you what to build, Time-to-Value tells you what to build first. Also useful when stakeholder patience is limited: ideas with fast time-to-value build credibility for tackling slower, larger initiatives. Particularly relevant for ouroboros development where compound growth means early infrastructure investments pay off over time.

---

### Pareto Priority

**Description**: Identifies which ideas deliver 80% of the value with 20% of the effort — the Pareto principle applied to brainstorm output. Pareto Priority is a resource-optimization lens: given limited time and energy, which ideas give the most return per unit of investment?

**Assessment dimensions**:

| Dimension | High Pareto | Medium Pareto | Low Pareto |
|-----------|------------|---------------|------------|
| **Effort** | Trivial (config change, minor edit) | Moderate (1 session, focused work) | Substantial (multi-session, complex) |
| **Value coverage** | Addresses the core of the problem | Addresses a significant aspect | Addresses an edge case or secondary concern |
| **Diminishing returns** | First implementation of this type — full value | Adds to existing capability — partial value | Refinement of something already good — marginal value |

**Scoring guide**: High Pareto on all dimensions = strong Pareto candidate (do this first). Low Pareto on "value coverage" = probably not worth the effort regardless of how easy it is. The key question is: "If we could only do one thing, would this be enough?" High Pareto ideas answer yes.

**When to prefer over Feasibility × Impact**: When resources are severely constrained — limited time, limited context window, limited human attention. Pareto Priority explicitly optimizes for effort-to-value ratio rather than absolute impact. A Medium Impact idea that takes 10 minutes may have better Pareto Priority than a High Impact idea that takes 3 sessions. Also useful for selecting the "quick win" from the Feasibility × Impact matrix when multiple quick wins are available.
