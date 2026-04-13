# Template Static Evaluation Criteria

> Reference for the evaluation skill. 16 binary criteria (0 or 1) across 3 tiers.
> Tier 1 Foundation gates Tier 2/3: Foundation < 5 caps at Level 2.

## Tier 1: Foundation (5)

### F1: Frontmatter Completeness

Does the template have proper metadata?

- **1**: Frontmatter contains both `title` and `description`. Description is specific enough to identify the template's purpose in one line
- **0**: Missing frontmatter, or frontmatter lacks `title` or `description`, or description is generic ("A template")

### F2: Output Format Specification

Does the template define a concrete output structure?

- **1**: Contains a markdown code block showing the full output format with named placeholders (`{{placeholder}}`). All major sections are visible in the format block
- **0**: No output format block, or format is described only in prose without a structural template

### F3: Field Resolution Table

Are placeholders mapped to data sources?

- **1**: A Field Resolution table maps each placeholder to its source (where the data comes from) and fallback (what to use when the source is unavailable). Covers all placeholders in the output format
- **0**: No field resolution table, or placeholders used in the format without documenting their source

### F4: Rendering Rules

Are rendering instructions clear and numbered?

- **1**: Numbered or named rendering rules that specify how to populate each section. Rules are imperative ("Use X", "Derive from Y") rather than vague ("Fill in appropriately")
- **0**: No explicit rendering rules, or rules described only as generic prose without per-section guidance

### F5: Section Omission Rules

Does the template specify when sections should be excluded?

- **1**: A table or list defining conditions under which each optional section should be omitted. Omission prevents empty placeholder sections in output
- **0**: No omission guidance — all sections are always rendered regardless of available data

## Tier 2: Craft (7)

### Q1: Placeholder Specificity

Are placeholders descriptive and unambiguous?

- **1**: Placeholders use descriptive names (`{{source_title}}`, `{{compiled_from}}`) that indicate their content. No generic placeholders like `{{content}}` or `{{data}}` without context
- **0**: Placeholders are generic or unnamed. Reader cannot determine what data goes where without reading external documentation

### Q2: Source Type Variations

Does the template handle different input scenarios?

- **1**: When the template can receive different source types (URL vs file vs paste, or different caller contexts), a variations table documents how rendering adjusts per source type
- **0**: Template assumes one input type without acknowledging variations. Or variations exist but are undocumented. Auto-pass when the template genuinely serves only one input type

### Q3: Common Mistakes

Does the template document rendering pitfalls?

- **1**: A structured section (table or list) with at least 3 common mistakes, why they fail, and how to prevent them. Connected to specific rendering rules
- **0**: No pitfall documentation, or mistakes mentioned only as inline warnings without structured presentation

### Q4: Usage by Commands

Does the template document which commands consume it?

- **1**: A section listing the calling commands with their responsibilities (what they provide as input, what they do with the rendered output). Clear contract between template and consumer
- **0**: No mention of consumers, or only a generic "used by PA commands" without specifics

### Q5: Design Rationale

Are template design choices explained?

- **1**: At least 2 "why" explanations for design decisions (why this section exists, why this order, why this placeholder is optional). Reasoning connects to user needs or system constraints
- **0**: Template structure presented without reasoning. Reader must accept choices on authority

### Q6: Self-Documentation

Can the template be understood standalone?

- **1**: A reader can understand the template's purpose, input requirements, and output shape without reading external files. External references are for deep methodology, not basic comprehension
- **0**: Template requires reading 2+ external files before the output format makes sense. Critical context missing from the template itself

### Q7: Calibration Anchors

Does the template include quality examples?

- **1**: At least 1 good rendering example showing what a well-populated output looks like. Bonus: a bad example showing common rendering failures
- **0**: No rendered examples. Quality standards must be entirely self-interpreted from the format block

## Tier 3: Excellence (4)

### E1: Bias Mitigation

Does the template address systematic rendering risks?

- **1**: Identifies at least 1 rendering bias (compression bias, authority bias, familiarity bias, etc.) with a concrete countermeasure. Connected to the template's specific domain
- **0**: No bias awareness. Template presented as bias-free

### E2: Context Efficiency

Is the template token-efficient?

- **1**: No redundant information between sections. Rendering rules and field resolution complement rather than duplicate each other. Length proportional to output complexity
- **0**: Repetition across sections, verbose where a table suffices, or rendering rules restate field resolution content

### E3: Cross-Component Integration

Does the template document its place in the system?

- **1**: A See Also section listing upstream producers (who provides the data), downstream consumers (who uses the rendered output), and related templates. Relationship descriptions are specific
- **0**: No integration documentation. Template exists in isolation

### E4: Vault-Profile Fidelity

Does the template respect vault conventions?

- **1**: References vault-profile fields (linking_style, frontmatter, naming_rules) in rendering rules or field resolution. Output adapts to vault configuration rather than using hardcoded conventions
- **0**: Hardcoded link syntax, frontmatter fields, or naming patterns without vault-profile awareness

## Severity Gate Thresholds

| F (0-5) | Q (0-7) | E (0-4) | Level |
|---|---|---|---|
| ≤ 3 | — | — | **1 — Poor** |
| 4 | — | — | **2 — Needs Work** (cap) |
| 5 | ≤ 3 | — | **2 — Needs Work** |
| 5 | 4-5 | — | **3 — Good** |
| 5 | ≥ 6 | ≤ 2 | **3 — Good** |
| 5 | ≥ 6 | ≥ 3 | **4 — Excellent** |
