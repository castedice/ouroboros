---
name: generation-methodology
description: This skill provides generation methodology knowledge. It should be activated when an agent needs to "mine patterns from reference implementations", "design a module architecture", "scaffold before fleshing out content", "generate quality-first components", or "apply evaluation criteria during generation".
summary: Guides quality-first component generation through pattern mining, architecture design, scaffolding, focused content, and criteria-based gates.
version: 1
tags: [core, methodology, generation, pattern-mining, scaffolding]
preamble_tier: 3
---

# Generation Methodology

## Core Rule

**"Mine patterns from the best, scaffold before you flesh, validate before you ship."**

Generation is a disciplined sequence of Mine -> Design -> Scaffold -> Flesh -> Gate.
Skipping the reference study produces inconsistency, skipping the scaffold produces incoherent structure, and skipping the gate produces low-quality first drafts.
Use this file for operating rules, and load the mapped references when you need pattern detail, scaffold checks, or quality-gate guidance.
The sequence matters because each stage reduces a different class of failure before the next stage adds more detail.

## Gotchas

Most generation failures are sequencing failures rather than creativity failures.

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Generating before reading references | Mining | Study at least two same-type references before drafting |
| Skipping the scaffold | Scaffold | Lock frontmatter and section headers before writing prose |
| Ignoring evaluation criteria | Gate | Read the relevant criteria file and keep it as a live checklist |
| Copying reference content instead of mining patterns | Flesh | Reuse conventions, not the source text |
| Missing inter-component references | Flesh | Verify See Also links and delegation references before handoff |
| Overly generic procedures | Flesh | Every major step needs concrete actions, inputs, or outputs |
| Generating every file in one pass without checks | Gate | Self-check each component before starting the next |

Treat missing structure as a stop signal rather than something to patch later in prose.

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "I know this component type already" | Drafting before mining same-type references | Read two or three strong references and extract reusable patterns before writing |
| "The prose can define the structure as it goes" | Fleshing content before frontmatter and section scaffolding are locked | Create the scaffold first, then fill domain-specific content into the approved shape |
| "It reads well, so the gate will pass" | Skipping criteria-based self-checks after generation | Run the Foundation and Craft gate against the generated artifact before handoff |

## Workflow

Each step should leave an artifact that makes the next step cheaper and safer.

1. Mine patterns from two or three high-quality references of the same component type.
2. Design the minimum viable component set that satisfies the requested capability.
3. Scaffold the files with correct frontmatter, section order, and placeholders before writing body content.
4. Flesh the scaffold with domain-specific procedures, examples, and cross-references.
5. Run the quality gate, revise obvious gaps, and only then hand the result forward.

Do not collapse Mine and Scaffold into one step just because the target seems familiar.

## Decision Rules

These rules keep generation concrete and prevent filler from masquerading as completeness.

| Decision Point | Rule |
|----------------|------|
| Reference count | Use at least two same-type references, and prefer three when the pattern is not yet obvious |
| Architecture scope | Build the minimum viable module rather than every plausible supporting artifact |
| Scaffold completeness | Every Foundation criterion must have an obvious landing spot before fleshing begins |
| Content generation | Write domain-specific procedures, not generalized filler or copied source prose |
| First-draft gate | Require Foundation to pass and target Craft >= 3 before handoff |
| Revision focus | Revise the weakest criteria first instead of polishing already-passing sections |
| Placeholder discipline | Remove or resolve every placeholder before handoff unless the user explicitly requested a scaffold-only artifact |
| Relationship integrity | Check that delegation, See Also links, and cross-file references match the architecture design |

## Reference Map

Use these references as stage companions rather than reading all of them up front.
That keeps context focused on the stage you are actually executing.

| Need | Reference |
|------|-----------|
| Pattern extraction dimensions and mining procedure | `${CLAUDE_SKILL_DIR}/references/pattern-mining.md` |
| Architecture heuristics, scaffold checklist, and quality-gate details | `${CLAUDE_SKILL_DIR}/references/scaffold-and-quality-gate.md` |
| Skill criteria for generated skills | `../evaluation/references/skill-criteria.md` |
| Command and agent criteria for generated runtime artifacts | `../evaluation/references/command-criteria.md`, `../evaluation/references/agent-criteria.md` |

## See Also

These components commonly generate, validate, or score the artifacts produced by this workflow.

- **generator agent** (`agents/core/generator.md`) - Primary consumer of pattern mining, scaffolding, and content generation rules
- **generate command** (`commands/core/generate.md`) - Orchestrates the full generation pipeline and post-generation checks
- **validation-methodology** (`skills/core/validation/SKILL.md`) - Structural validation that should run before evaluation
- **evaluation-methodology** (`skills/core/evaluation/SKILL.md`) - Defines the quality bar that generation should target before handoff
