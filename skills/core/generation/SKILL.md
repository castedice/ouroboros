---
name: generation-methodology
description: This skill provides generation methodology knowledge. It should be activated when an agent needs to "mine patterns from reference implementations", "design a module architecture", "scaffold before fleshing out content", "generate quality-first components", or "apply evaluation criteria during generation".
---

# Generation Methodology

## Core Principle

**"Mine patterns from the best, scaffold before you flesh, validate before you ship."**

Generation is a three-phase discipline: study existing excellence (pattern mining), build the skeleton before the muscle (scaffold-then-flesh), and check quality before committing (quality-first). Generating without studying references produces inconsistent output. Generating detail before structure produces incoherent output. Generating without quality checks produces output that fails on first evaluation.

The cycle is: **Mine → Design → Scaffold → Flesh → Gate**. Each stage has a distinct purpose. The temptation to jump directly from a description to full content must be resisted — the intermediate stages exist because they catch problems early when changes are cheap.

## Generation Workflow

Five stages executed in order. Each stage has a defined input, process, and output. For detailed pattern mining procedures, see `references/pattern-mining.md`.

### Step 1: Pattern Mining

**Input**: Reference module or components + evaluation criteria.
**Output**: Extracted patterns (structural, style, relationship, convention).

- Read 2-3 reference components of the same type as the generation target
- Extract structural patterns: section order, heading levels, frontmatter fields
- Extract style patterns: tone, detail level, formatting conventions
- Extract relationship patterns: how components cross-reference each other
- Read evaluation criteria to understand what "good" looks like for this type

Pattern mining is not copying. The goal is to understand the conventions that make existing components consistent and high-quality, then apply those conventions to new content. See `references/pattern-mining.md` for the four extraction dimensions.

### Step 2: Architecture Design

**Input**: Extracted patterns + module/component spec + knowledge base entries.
**Output**: Component inventory with roles and relationships.

- Map requested capabilities to component types (command, agent, skill, template)
- Determine agent strategy: reuse core agents or create module-specific ones
- Identify skill needs: what domain knowledge should be codified
- Define inter-component relationships: which commands delegate to which agents, which agents consume which skills
- Apply the minimum viable module rule: 1 command + agent strategy + README minimum

Architecture design prevents over-engineering. The question is not "what components could exist?" but "what is the minimum set that delivers the requested capabilities?"

### Step 3: Scaffold

**Input**: Architecture design + structural patterns from Step 1.
**Output**: Complete file structure with section headers, frontmatter, and placeholder content.

- Create frontmatter with all required fields (name, description, model, tools for agents; description, allowed-tools for commands; name, description for skills)
- Lay out all section headers following the reference structural pattern
- Add placeholder markers for content sections: `{TODO: procedure steps}`, `{TODO: output format}`
- Verify scaffold completeness against evaluation criteria: does every Foundation criterion have a corresponding section?

Scaffolding separates structure from content. A complete scaffold should pass F1-F3 (structural criteria) even with placeholder content. If it can't, the structure is wrong — fix the skeleton before adding muscle.

### Step 4: Content Generation

**Input**: Scaffold + style patterns + knowledge base entries + domain description.
**Output**: Fully fleshed content in every section.

- Fill each section following the style patterns from Step 1
- Incorporate domain-specific knowledge from knowledge base entries and research findings
- Ensure each procedure step has clear input/output and concrete examples
- Cross-reference related components using the relationship patterns from Step 1
- Apply the evaluation criteria as a live checklist: for each criterion, verify the content meets it before moving to the next section

Content generation is criteria-aware. Before writing each section, check which evaluation criteria it affects. This pre-check is cheaper than post-generation evaluation and retry.

### Step 5: Quality Gate

**Input**: Complete generated content + evaluation criteria.
**Output**: Validated content ready for file write, or specific revision targets.

- Pre-evaluate against all Foundation (F) criteria: all 5 must pass
- Check Craft (Q) criteria: target >= 3 for a passing first draft
- If any Foundation criterion scores 0: identify the gap and revise before submission
- If Craft score < 3: identify the weakest criteria and revise
- Document what was revised in a change summary

The quality gate is self-applied, not deferred to the evaluator. The generator should catch obvious quality gaps before the formal evaluation. This reduces retry cycles and improves first-pass quality.

## Pattern Mining Approach

Four extraction dimensions applied to reference implementations. See `references/pattern-mining.md` for the detailed procedure.

| Dimension | What to Extract | Example |
|-----------|----------------|---------|
| **Structural** | Section order, heading levels, frontmatter fields | Commands use Phase N: Name pattern; agents use Step N: Name |
| **Style** | Tone, detail level, sentence structure | Skills use imperative tone in procedures; agents use second-person |
| **Relationship** | Cross-references, delegation patterns | Commands reference agents by name in delegation sections |
| **Convention** | Naming rules, formatting standards, required sections | Agent descriptions start with "Use this agent when..." |

**Extraction priority**: Structural > Convention > Relationship > Style. Structure and conventions must be followed exactly; style can be adapted to the domain.

## Scaffold-then-Flesh Strategy

Why scaffold first? Three reasons:

1. **Structure errors are cheaper to fix early**. Moving a section in a scaffold costs one line; moving it in a 200-line file requires rethinking surrounding content
2. **Completeness is visible at the scaffold level**. Missing sections are obvious in a scaffold; they hide in dense content
3. **Parallel generation is possible from a scaffold**. Multiple sections can be fleshed independently once the structure is locked

### Scaffold Completeness Checklist

Before fleshing, verify the scaffold against the target type's Foundation criteria:

| Component Type | Scaffold Must Include |
|---------------|---------------------|
| **Command** | Frontmatter (description, allowed-tools), Phase headers, Agent delegation section, Rules section |
| **Agent** | Frontmatter (name, description with triggers + examples, model, tools), Persona line, Procedure headers, Output format section, Scope boundary |
| **Skill** | Frontmatter (name, description with triggers), Core Principle, Workflow steps, Bias Mitigation table, Validation Checklist, See Also |
| **Template** | Frontmatter, Section headers matching output structure, Placeholder variables |

## Quality-First Generation

Quality-first means checking criteria before and during generation, not only after.

### Pre-Generation Criteria Check

Before generating content for a component type, read the applicable criteria file:

| Type | Criteria File |
|------|--------------|
| Agent | `skills/core/evaluation/references/agent-criteria.md` |
| Command | `skills/core/evaluation/references/command-criteria.md` |
| Skill | `skills/core/evaluation/references/skill-criteria.md` |

For each Foundation criterion, verify the scaffold has the corresponding section. For each Craft criterion, note what content quality is needed. This creates a generation checklist that prevents common failures.

### Common Quality Failures in Generation

| Failure | Criterion Affected | Prevention |
|---------|-------------------|------------|
| Agent description missing trigger phrases | F1 | Include "Use this agent when..." with 3+ quoted triggers |
| Agent missing examples in description | F1 | Add 2+ `<example>` blocks with context/user/assistant/commentary |
| Command missing error handling | Q3 | Add explicit error cases with abort conditions per phase |
| Skill missing bias mitigation | Q5 | Add Bias Mitigation table with phase-specific countermeasures |
| Component missing See Also references | Q6 | Add See Also section linking to related commands, agents, skills |

## Bias Mitigation

Generation involves design choices that carry systematic bias risks:

| Bias | Phase | Symptom | Countermeasure |
|------|-------|---------|----------------|
| Template fixation | Mining | New components are carbon copies of reference with names changed | Extract patterns (conventions), not content; generate domain-specific procedures |
| Over-abstraction | Design | Components are too generic to be useful | Apply minimum viable module rule; each component must have concrete procedures |
| Feature creep | Design | Module grows beyond the original spec | Stick to the requested capabilities; flag extras as "future candidates" in rationale |
| Familiarity bias | Mining | Only studying 1 reference instead of 2-3 | Mine patterns from at least 2 different components of the same type |
| Quality theater | Gate | Superficially meeting criteria without real quality | Quality gate checks content, not just section existence; "has a bias table" is not enough — it must contain real biases |

## Common Pitfalls

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Generating without reading references | Mining | Always read 2+ reference components before generating any content |
| Skipping scaffold step | Scaffold | Create section headers and frontmatter before writing any body content |
| Ignoring evaluation criteria | Content | Read criteria file and use as live checklist during generation |
| Generating all components from one sitting | Content | For modules, generate and self-evaluate each component before starting the next |
| Copy-pasting reference content | Content | Mine patterns, don't copy content; generated content must be domain-specific |
| Missing inter-component references | Content | Verify See Also sections and agent/command cross-references after generation |
| Overly generic procedures | Content | Each procedure step must have concrete input, output, and domain-specific actions |

## Validation Checklist

- [ ] 2+ reference components of the same type studied before generation
- [ ] Structural, style, relationship, and convention patterns extracted
- [ ] Architecture designed with minimum viable module rule applied
- [ ] Scaffold created with all section headers and frontmatter before content
- [ ] Scaffold verified against Foundation criteria for the target type
- [ ] Content follows style patterns from reference components
- [ ] Domain-specific knowledge incorporated from knowledge base entries
- [ ] Evaluation criteria used as live checklist during content generation
- [ ] All Foundation criteria pass (self-assessed) before submission
- [ ] Craft criteria target >= 3/5 (self-assessed)
- [ ] Inter-component references (See Also, agent delegation) are correct and complete
- [ ] Change summary documents any revisions made during quality gate

## See Also

- **generator agent** (`agents/core/generator.md`) — Primary consumer; executes pattern mining, scaffold creation, and content generation procedures
- **generate command** (`commands/core/generate.md`) — Orchestrates the full generation pipeline: context gathering → generation → quality validation → worktree management
- **validation-methodology** (`skills/core/validation/SKILL.md`) — Structural validation that runs before evaluation; generated components must pass validation first
- **evaluation-methodology** (`skills/core/evaluation/SKILL.md`) — Evaluation criteria that define what "good" looks like for each component type
