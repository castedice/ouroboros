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
