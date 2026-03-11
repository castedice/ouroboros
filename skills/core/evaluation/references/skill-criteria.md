# Skill Static Evaluation Criteria

> Reference for the evaluation skill. 16 binary criteria (0 or 1) across 3 tiers.
> Tier 1 Foundation gates Tier 2/3: Foundation < 5 caps at Level 2.

## Tier 1: Foundation (5)

### F1: Trigger Phrases

Does the skill auto-activate in the correct situations?

- **1**: Third-person description + 5 or more specific trigger phrases (enclosed in double quotes). Contains keywords that naturally activate in relevant contexts
- **0**: 2 or fewer trigger phrases, overly generic ("Provides guidance for X"), or uses second person

### F2: Progressive Disclosure

Are core knowledge and detailed content properly separated?

- **1**: SKILL.md is within 1,500-2,500 words. Detailed content separated into `references/`. Body maintains quick-reference density
- **0**: Single file of 10,000+ words, or conversely under 100 words with insufficient content. References unused

### F3: Writing Style

Is the knowledge delivery style appropriate?

- **1**: Uses imperative/infinitive form (third person). Employs 2 or more of: quick reference tables, DO/DON'T lists, code examples. Concise with high information density
- **0**: Conversational second-person ("You should") style. Prose-only without tables/lists. Or excessively abstract

### F4: Reference Organization

Are reference files systematically organized?

- **1**: Reference files in `references/` directory organized by logical categories. Each file covers a clear single topic with coherent scope. SKILL.md explicitly guides to reference files
- **0**: References unused (all content in SKILL.md), or reference files exist but SKILL.md doesn't mention them

### F5: Validation Checklist

Does the skill include validation criteria for its methodology?

- **1**: Checklist or quality criteria for verifying methodology application exists in body or references
- **0**: Only "do this" instructions with no "how to verify it was done correctly"

## Tier 2: Craft (7)

### Q1: Trigger Specificity

Do trigger phrases use domain-specific terms that precisely activate in relevant contexts?

- **1**: Trigger phrases include domain-specific nouns (tool names, platform concepts, methodology terms). Each trigger distinguishes this skill from other skills in the same module
- **0**: Generic verb+noun combinations ("help with X", "improve Y") that could activate for unrelated contexts. No domain vocabulary

### Q2: Methodology Reproducibility

Can the methodology be followed step-by-step to produce consistent results?

- **1**: Numbered or named procedure steps with concrete actions at each step. Conditional branches have explicit conditions. Another AI following the same steps would produce structurally equivalent output
- **0**: Abstract principles without step-by-step procedure, or steps that rely on "as appropriate" or "use judgment" without specifying what to judge

### Q3: Decision Rule Quantification

Are judgment criteria expressed with measurable thresholds rather than subjective terms?

- **1**: At least 3 decision points use numeric thresholds, word counts, file counts, or other measurable criteria (e.g., "1,500-2,000 words", "≥ 3/5", "max 2 retries")
- **0**: Decisions rely on subjective terms ("significant", "appropriate", "adequate") without measurable bounds

### Q4: Common Pitfalls Structure

Are known failure modes documented with prevention strategies?

- **1**: Pitfalls presented in structured form (table with pitfall/phase/prevention columns, or numbered list with cause → effect → remedy). Connected to specific workflow phases
- **0**: No pitfall documentation, or pitfalls listed as unstructured prose without prevention strategies

### Q5: Reference File Self-Containment

Can each reference file be understood without reading SKILL.md first?

- **1**: Each reference file includes a header/summary stating its purpose and relationship to the parent skill. Contains enough context to be useful standalone
- **0**: Reference files assume SKILL.md context. Missing headers or unclear purpose without reading parent skill

### Q6: Failure & Edge Case Policy

Does the methodology address what to do when things go wrong?

- **1**: At least 1 of: (1) retry policy with conditions for when to retry vs stop, (2) escalation path for unresolvable cases, (3) explicit edge case handling for boundary conditions in the domain
- **0**: Only happy-path methodology described. No guidance for failure, stalemate, or ambiguous situations

### Q7: Rationale Transparency

Are methodological choices explained with reasoning?

- **1**: At least 2 "why" explanations for design choices (why this threshold, why this order, why this approach over alternatives). Reasoning is evidence-based (research citations, empirical observations, or logical arguments)
- **0**: Rules stated without reasoning. Reader must accept them on authority

## Tier 3: Excellence (4)

### E1: Bias Mitigation Awareness

Does the skill acknowledge and counter systematic errors in its methodology?

- **1**: Identifies at least 1 bias pattern specific to the methodology (e.g., recency bias in research, self-enhancement in evaluation, anchoring in comparison) with concrete countermeasure
- **0**: No bias awareness. Methodology presented as bias-free

### E2: Multi-Axis Classification

Does the skill define explicit decision axes for its domain?

- **1**: At least 1 classification axis with named categories (e.g., static/dynamic, error/warning, low/medium/high stake). Axis determines different treatment paths
- **0**: Flat methodology without dimensional classification. All inputs treated uniformly regardless of characteristics

### E3: Context Efficiency

Is the skill body token-efficient while maintaining actionability?

- **1**: SKILL.md body focuses on workflow and decision rules. Detailed reference material properly delegated to reference files. No information repeated between body and references
- **0**: Body contains material that should be in references. Duplication between body and reference content

### E4: Cross-Component Integration

Does the skill document how it connects to commands and agents?

- **1**: States which commands/agents reference this skill. Documents input expectations and how output is consumed. "See Also" or integration section present
- **0**: Described as standalone knowledge. No mention of consumers or integration points

## Severity Gate Thresholds

| F (0-5) | Q (0-7) | E (0-4) | Level |
|---|---|---|---|
| ≤ 3 | — | — | **1 — Poor** |
| 4 | — | — | **2 — Needs Work** (cap) |
| 5 | ≤ 3 | — | **2 — Needs Work** |
| 5 | 4-5 | — | **3 — Good** |
| 5 | ≥ 6 | ≤ 2 | **3 — Good** |
| 5 | ≥ 6 | ≥ 3 | **4 — Excellent** |
