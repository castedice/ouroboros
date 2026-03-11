---
name: absorption-methodology
description: This skill provides absorption methodology knowledge. It should be activated when an agent needs to "map external concepts to module components", "perform gap analysis against existing modules", "design integration strategies for external sources", "determine when to create new vs extend existing components", or "validate absorption completeness".
---

# Absorption Methodology

## Core Principle

**"Understand before integrating, map before generating, validate before merging."**

Absorption transforms external knowledge into internal module components. It is not copying — it is translation. External sources have their own conventions, assumptions, and context; absorbing them requires understanding what they do, mapping that to ouroboros conventions, and generating components that are native to the monolith. Skipping the understanding phase produces components that don't fit. Skipping the mapping phase produces redundant components.

The cycle is: **Analyze → Map → Identify Gaps → Design → Verify**. Each stage builds on the previous. The critical insight is that absorption is not "add everything from the source" but "add what's missing from the target." Gap analysis is the stage that prevents bloat.

## Absorption Workflow

Five stages executed in order. Each stage has a defined input, process, and output. For detailed integration patterns, see `references/integration-patterns.md`.

### Step 1: Source Analysis

**Input**: Research findings from the researcher agent (patterns, component inventory, architectural decisions).
**Output**: Capability catalog — what the external source offers, expressed in domain-neutral terms.

- Review the research analysis report for key patterns and component inventory
- Translate source-specific terminology into domain-neutral capability descriptions
- Identify the source's architectural decisions that differ from ouroboros conventions
- Note which capabilities are tightly coupled vs. independently extractable

Source analysis transforms "what does the source do?" into "what capabilities does the source provide?" This abstraction is essential — you're absorbing capabilities, not implementations.

### Step 2: Knowledge Mapping

**Input**: Capability catalog + existing module structure.
**Output**: Capability-to-component mapping for each source capability.

- For each source capability, determine the ouroboros component type it maps to (command, agent, skill, template)
- Apply the mapping rules from `references/integration-patterns.md`
- Identify capabilities that map to existing components (overlap detection)
- Identify capabilities that require new components (gap candidates)
- Identify capabilities that conflict with existing design decisions

Knowledge mapping answers "if this capability existed in ouroboros, what form would it take?" This is the translation step — converting external patterns into the monolith's native language.

### Step 3: Gap Identification

**Input**: Capability-to-component mapping + existing module contents.
**Output**: Classified capabilities (gaps, overlaps, conflicts) with priority.

- **Gaps**: Capabilities not covered by any existing component — candidates for generation
- **Overlaps**: Capabilities already covered by existing components — no action needed
- **Conflicts**: Capabilities that contradict existing design decisions — require user decision

Gap identification is conservative: when uncertain whether a capability is covered, classify it as a gap. False positive gaps (generating something that turns out to overlap) are caught in review; missed gaps (not generating something needed) require re-running the pipeline.

**Priority ranking for gaps**:

| Priority | Criterion | Example |
|----------|----------|---------|
| **Critical** | Enables a core workflow that currently doesn't exist | New command that fills a pipeline step |
| **High** | Significantly enhances an existing workflow | Agent that adds a new analysis dimension |
| **Medium** | Adds convenience or depth | Skill reference that enriches methodology knowledge |
| **Low** | Nice-to-have without workflow impact | Template for an edge-case output format |

### Step 4: Component Design

**Input**: Prioritized gaps + reference module patterns + evaluation criteria.
**Output**: Component specifications ready for generation.

- For each gap, design the component following generation methodology (see `skills/core/generation/SKILL.md`)
- Apply pattern mining from the reference module to ensure structural consistency
- Pre-check designs against evaluation criteria to avoid quality gate failures
- Determine which components can be generated independently vs. which have dependencies

Design is the bridge between analysis and generation. A well-designed component spec should contain enough detail for the generator to produce a passing component on the first attempt.

### Step 5: Integration Verification

**Input**: Generated components + existing module + research findings.
**Output**: Verification report confirming completeness and consistency.

- Verify all critical and high-priority gaps are addressed by generated components
- Check inter-component consistency: do new components reference existing ones correctly?
- Verify no namespace collisions: component names don't conflict across modules
- Confirm knowledge entry captures patterns that weren't generated as components
- Identify existing components that should be evolved to integrate the new additions

Integration verification ensures the absorption is complete and coherent. A verified absorption should leave no critical gaps and no broken cross-references.

## Knowledge Mapping Approach

How external concepts translate to ouroboros component types. See `references/integration-patterns.md` for the full mapping rules.

| External Concept | Maps To | When |
|-----------------|---------|------|
| User-facing workflow or pipeline | **Command** | The concept involves multi-phase orchestration with user interaction |
| Specialized analysis or generation procedure | **Agent** | The concept involves read-only analysis or content creation delegated by a command |
| Domain knowledge or methodology | **Skill** | The concept is reference knowledge consumed by agents during procedures |
| Structured output format | **Template** | The concept defines a repeatable document structure |

**Ambiguity resolution**: When a concept could map to multiple types, prefer the type that most closely matches existing patterns in the target module. If the module has 3 commands and 0 skills, a methodology concept should still map to a skill — don't force it into a command to match the module's current shape.

## Gap Analysis for Module Completeness

A complete module covers its domain with no critical workflow gaps. Gap analysis compares source capabilities against the target module to find what's missing.

### Completeness Model

| Component | Minimum | Completeness Signal |
|-----------|---------|-------------------|
| Commands | 1 | Every user-facing workflow has an entry point |
| Agents | 1 per distinct procedure type | No command phase delegates to a non-existent agent |
| Skills | 0-1 per domain knowledge area | Agents don't embed methodology inline that should be a shared skill |
| Templates | 0-1 per structured output | No agent generates a format that should be standardized |

### Gap Detection Signals

| Signal | Indicates |
|--------|-----------|
| Command phase says "manually do X" | Missing agent for that procedure |
| Agent procedure embeds domain knowledge inline | Missing skill that should be referenced |
| Two agents produce similar output formats | Missing template that should be shared |
| Source capability has no module counterpart | Gap to fill or conscious exclusion to document |

## Integration Patterns

When to create new components vs. extend existing ones. See `references/integration-patterns.md` for detailed decision procedures.

| Situation | Strategy | Rationale |
|-----------|----------|-----------|
| Capability is entirely new to the module | **Create** new component | No existing component to extend |
| Capability extends an existing component's scope by <30% | **Evolve** the existing component | Extension is proportional; the component remains coherent |
| Capability extends an existing component's scope by >30% | **Create** new + **evolve** existing to delegate | Large extensions dilute the original component's focus |
| Capability contradicts an existing component | **Flag** for user decision | Design conflicts cannot be resolved automatically |

## Bias Mitigation

Absorption involves judgment about what to include, creating systematic bias risks:

| Bias | Phase | Symptom | Countermeasure |
|------|-------|---------|----------------|
| Novelty | Analysis | Over-valuing source capabilities because they're new and interesting | Evaluate each capability against existing module needs, not inherent novelty |
| NIH syndrome | Mapping | Dismissing source capabilities because "we do it differently" | Map capabilities first, then evaluate fit; don't pre-filter based on implementation style |
| Scope creep | Design | Absorbing everything from the source regardless of fit | Apply gap priority; only critical and high gaps justify generation |
| Premature integration | Design | Generating components before understanding existing module fully | Read all existing module components before designing new ones |
| Completionism | Gap ID | Marking every non-overlap as a gap that must be filled | Low-priority gaps can be documented and deferred; not every gap needs immediate generation |

## Common Pitfalls

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Absorbing without understanding (copy-paste translation) | Analysis | Produce a capability catalog in domain-neutral terms before mapping |
| Generating redundant components | Mapping | Scan all existing components thoroughly; check name and capability, not just name |
| Missing existing coverage | Gap ID | Read component contents, not just filenames; a capability may be covered inside a broader component |
| Generating too many components at once | Design | Limit to critical + high priority gaps; defer medium/low to follow-up absorptions |
| Ignoring integration effects | Verification | Check how new components affect existing ones; produce integration plan for follow-up evolution |
| Skipping knowledge entry | All | Always produce a knowledge entry even if no components are generated; research is never wasted |

## Validation Checklist

- [ ] Research analysis reviewed and capability catalog produced in domain-neutral terms
- [ ] Each capability mapped to an ouroboros component type (command, agent, skill, template)
- [ ] Existing module components read thoroughly (contents, not just filenames)
- [ ] Capabilities classified as gaps, overlaps, or conflicts with evidence
- [ ] Gaps prioritized (critical, high, medium, low) with rationale
- [ ] Only critical and high gaps selected for generation (medium/low deferred)
- [ ] Component designs follow reference module patterns and target evaluation criteria
- [ ] No namespace collisions with existing components across all modules
- [ ] Knowledge entry produced capturing all research findings
- [ ] Integration plan identifies existing components that need follow-up evolution
- [ ] All conflicts flagged for user decision (not auto-resolved)

## See Also

- **generator agent** (`agents/core/generator.md`) — Generates components from absorption designs; executes Module Generation (Procedure 1) or Component Generation (Procedure 3)
- **researcher agent** (`agents/core/researcher.md`) — Produces the research analysis that feeds Step 1; handles source content analysis and pattern extraction
- **absorb command** (`commands/core/absorb.md`) — Orchestrates the full absorption pipeline: gather → research → gap analysis → generate → quality gate → review
- **research-methodology** (`skills/core/research/SKILL.md`) — Research is the first phase of absorption; findings drive the capability catalog
- **generation-methodology** (`skills/core/generation/SKILL.md`) — Generation methodology governs how gap-filling components are created
