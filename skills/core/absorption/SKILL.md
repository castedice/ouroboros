---
name: absorption-methodology
description: This skill provides absorption methodology knowledge. It should be activated when an agent needs to "map external concepts to module components", "perform gap analysis against existing modules", "design integration strategies for external sources", "determine when to create new vs extend existing components", or "validate absorption completeness".
summary: Maps external capabilities into native components through capability analysis, gap detection, integration design, and verification.
version: 1
tags: [core, methodology, absorption, integration, gap-analysis]
preamble_tier: 3
---

# Absorption Methodology

## Core Rule

**"Understand before integrating, map before generating, validate before merging."**

Absorption translates external capabilities into native ouroboros components instead of copying source implementations.
The operating cycle is **Analyze → Map → Identify Gaps → Design → Verify**.
Skipping analysis creates copy-paste translation, skipping mapping creates redundancy, and skipping verification leaves integration debt.
Absorb what the target module is missing, not everything the source happens to contain.

## Gotchas

| Risk | Stage | Prevention |
|------|-------|------------|
| Copying source structure before understanding its capabilities | Analysis | Produce a domain-neutral capability catalog first |
| Treating novelty as value | Analysis | Judge capabilities against target-module needs, not against source novelty |
| Dismissing useful ideas because "we do it differently" | Mapping | Map the capability first, then judge fit |
| Missing existing coverage because only filenames were checked | Gap ID | Read component contents, not just names |
| Generating redundant components | Mapping | Check both name overlap and capability overlap |
| Marking every non-overlap as mandatory work | Gap ID | Prioritize gaps and defer medium or low work when appropriate |
| Generating before reading the existing module fully | Design | Finish overlap and conflict detection before drafting components |
| Ignoring downstream integration effects | Verification | Check cross-references, namespace collisions, and follow-up evolution needs |
| Skipping knowledge capture because no component was generated | All | Always preserve research findings in a knowledge entry |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The source already has clean categories, so reuse them" | Copying external component boundaries into the target module | Translate each source category into neutral capabilities, then map them to native component types |
| "No filename matches, so this must be a gap" | Classifying a gap from names without reading existing contents | Check capability overlap inside the relevant commands, agents, skills, and templates before prioritizing the gap |
| "This idea is interesting, so absorb it now" | Promoting novelty over target-module need | Tie the capability to a critical or high-priority gap, or record it as deferred knowledge |

## Workflow

### 1. Source Analysis

Input: research findings, component inventory, and source architecture notes.
Output: a domain-neutral capability catalog.
Review what the source actually offers, translate source-specific terms into neutral capabilities, and note which capabilities are tightly coupled versus independently extractable.

### 2. Knowledge Mapping

Input: capability catalog plus the existing target module.
Output: a capability-to-component mapping.
Map each capability to the ouroboros type it would become, identify overlap with existing components, and flag design conflicts instead of resolving them implicitly.

### 3. Gap Identification

Input: capability mapping plus actual module contents.
Output: gaps, overlaps, conflicts, and priorities.
Treat uncertain coverage as a provisional gap because false positives are safer than missed capabilities.

### 4. Component Design

Input: prioritized gaps plus target-module patterns and evaluation criteria.
Output: component specs ready for generation.
Design only the critical and high-priority work needed now, and keep track of which additions require follow-up evolution in existing components.

### 5. Integration Verification

Input: generated components, existing module, and research findings.
Output: a verification report.
Confirm that critical gaps are covered, references are coherent, names do not collide, and non-generated insights still land in a knowledge entry.

## Decision Rules

### Concept To Component Mapping

| External concept | Native target | Use when |
|------------------|---------------|----------|
| User-facing workflow or pipeline | `command` | The capability needs orchestration and user interaction |
| Specialized analysis or generation procedure | `agent` | The capability is delegated work with a distinct procedure |
| Shared methodology or domain knowledge | `skill` | The knowledge should be reused instead of embedded inline |
| Repeatable structured output | `template` | The capability standardizes a document shape |

Minimum completeness signals: every user-facing workflow needs a command, every distinct delegated procedure needs an agent, shared knowledge should move into a skill, and repeated output formats should become templates.

### Gap Classification And Priority

| Case | Meaning | Action |
|------|---------|--------|
| Gap | No existing component covers the capability | Candidate for generation |
| Overlap | Existing components already cover it | No generation needed |
| Conflict | Capability contradicts an accepted design decision | Escalate to the user |

| Priority | Use when | Typical example |
|----------|----------|-----------------|
| Critical | A core workflow step does not exist | Missing command or missing required agent |
| High | An existing workflow gains a major new capability | New analysis dimension or shared methodology |
| Medium | The module gets convenience or depth | Enrichment skill or secondary template |
| Low | The capability is useful but not workflow-shaping | Edge-case format or optional helper |

### Integration Strategy

| Situation | Strategy | Rationale |
|-----------|----------|-----------|
| Capability is entirely new | Create a new component | Nothing coherent exists to extend |
| Scope increase is under about 30% | Evolve the existing component | The original component remains focused |
| Scope increase is over about 30% | Create new and evolve the old one to delegate | Large additions dilute the original role |
| Design contradicts an accepted decision | Stop and ask the user | Conflicts are not safe to auto-resolve |

Validation checks: read the existing module before designing, prioritize critical and high gaps first, keep evidence for every classification, avoid namespace collisions, and always identify follow-up evolution for affected components.

## Reference Map

- `${CLAUDE_SKILL_DIR}/references/integration-patterns.md` — Detailed concept-to-component mapping rules, ambiguous cases, and create-versus-evolve procedures.
- `${CLAUDE_SKILL_DIR}/references/gap-analysis-relay-prompt.md` — Prompt relay template for structured gap-analysis handoff.
- `${CLAUDE_SKILL_DIR}/references/researcher-relay-prompt.md` — Prompt relay template for handing source-analysis work to the researcher.

## See Also

- `agents/core/generator.md` — Generates the components designed during absorption.
- `agents/core/researcher.md` — Produces the analysis that feeds source understanding and capability extraction.
- `commands/core/absorb.md` — Orchestrates the full absorption pipeline.
- `skills/core/generation/SKILL.md` — Governs how approved gap-filling components are generated.
- `skills/core/research/SKILL.md` — Governs how source material is collected, evaluated, and synthesized before mapping.
