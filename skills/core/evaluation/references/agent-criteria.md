# Agent Static Evaluation Criteria

> Reference for the evaluation skill. 16 binary criteria (0 or 1) across 3 tiers.
> Tier 1 Foundation gates Tier 2/3: Foundation < 5 caps at Level 2.

## Tier 1: Foundation (5)

### F1: Description Trigger Quality

Does the agent activate in the correct situations?

- **1**: Explicit trigger condition in `"Use this agent when..."` form + 2 or more `<example>` blocks (including proactive/reactive)
- **0**: Single-line functional description only, vague trigger conditions, or no examples

### F2: System Prompt Depth

Does the body (system prompt) specify behavior concretely enough?

- **1**: Contains 4 or more of the following — (1) expert persona declaration, (2) core principles/rules, (3) step-by-step workflow, (4) output format definition, (5) edge case handling, (6) scope boundary statement. Total 300+ words
- **0**: 3 or fewer of the above elements, or under 100 words of brief description only

### F3: Model Match

Is the selected model appropriate for the agent's role complexity?

- **1**: Complex reasoning (architecture, evaluation, deep analysis) → opus, balanced execution+analysis → sonnet, fast assistance → haiku. Or inherit (parent inheritance) is reasonable
- **0**: Opus for simple tasks, haiku for complex reasoning, etc. Or model unspecified with unclear intent

### F4: Tool Minimum Privilege

Do the agent's tools follow the principle of least privilege?

- **1**: Only tools required for the role. Read-only analysis → `[Read, Grep, Glob]` level. Bash included only when explicitly needed
- **0**: Unnecessary write tools included (Write/Edit on an analysis agent), or tools unspecified, or full tool list enumerated

### F5: Structured Instructions

Are instructions structured for easy AI compliance?

- **1**: Uses structural formats like numbered steps, tables, checklists. Imperative/infinitive form. Clear role boundaries
- **0**: Prose-only with no structural format. Primarily second-person ("you should"). Unclear role boundaries

## Tier 2: Craft (7)

### Q1: Trigger Precision

Does the trigger activate precisely — not too broad, not too narrow?

- **1**: Trigger phrases distinguish from other agents in the same module. Specific use cases, not generic capabilities
- **0**: Overlaps with another agent's trigger, or generic phrases like "help with tasks", or so narrow it misses common use cases

### Q2: Workflow Executability

Is every workflow step actionable without ambiguity?

- **1**: Each step specifies concrete action (read X, compare Y with Z, produce format W). Conditional branches have explicit conditions. No "analyze appropriately" type steps
- **0**: Contains vague steps ("adjust as needed"), conditional branches without clear conditions, or references to undefined concepts

### Q3: Output Format Specification

Is the expected output format concretely defined?

- **1**: Output defined as template, markdown structure, or structured schema with section headers/field names. Consumer can predict what they'll receive
- **0**: Output described only as "produce a report" or "provide analysis" without structural specification

### Q4: Scope Boundary Clarity

Is the agent's scope explicitly bounded?

- **1**: Explicitly states what the agent does NOT do, or defines boundaries with other agents/commands (e.g., "evaluate only, never modify files")
- **0**: Scope defined only by what it does. No boundaries mentioned

### Q5: Error & Edge Case Handling

Does the agent address non-happy-path scenarios?

- **1**: At least 2 of: (1) malformed/missing input handling, (2) tool failure fallback, (3) "when in doubt" decision rules, (4) domain-specific boundary cases
- **0**: Only happy path described. No mention of unexpected input, tool errors, or ambiguous situations

### Q6: Example Diversity

Do examples cover varied usage scenarios?

- **1**: 2+ distinct usage patterns (proactive+reactive, simple+complex, different callers). At least 1 edge case or unusual scenario
- **0**: All examples follow the same pattern or show only the most common case

### Q7: Evidence-Based Decision Rules

Are judgment/decision criteria based on observable evidence?

- **1**: Scoring, classification, or decisions reference specific observable evidence (quotes, metrics, structural features). Reproducible — different evaluator, same rules → same conclusion
- **0**: Subjective criteria ("looks good", "is appropriate") without specifying what evidence constitutes meeting/failing

## Tier 3: Excellence (4)

### E1: Persona Coherence

Does the expert persona remain consistent throughout?

- **1**: Declared role reflected in vocabulary, judgment style, and output format throughout. No sections with generic instructions inconsistent with persona
- **0**: Persona declared but not sustained. Later sections use generic language or contradict the role

### E2: Context Efficiency

Is the prompt token-efficient without sacrificing clarity?

- **1**: No redundant information. Heavy details delegated to reference files. Body focuses on workflow and judgment rules. Length proportional to role complexity
- **0**: Repetition across sections, verbose where table/list suffices, or reference-separable content embedded in body

### E3: Cross-Component Integration

Does the agent document its place in the larger system?

- **1**: Mentions which commands invoke it, how it receives input, how output is consumed. Relationship with related agents/skills/templates documented
- **0**: Described as standalone. No mention of callers, consumers, or peer components

### E4: Calibration Anchors

Does the agent include concrete quality anchors for its own output?

- **1**: Good vs bad output examples, score calibration cases, or reference outputs ("0-point response looks like X, 1-point looks like Y")
- **0**: Abstract rules only. Quality standards must be entirely self-interpreted

## Severity Gate Thresholds

| F (0-5) | Q (0-7) | E (0-4) | Level |
|---|---|---|---|
| ≤ 3 | — | — | **1 — Poor** |
| 4 | — | — | **2 — Needs Work** (cap) |
| 5 | ≤ 3 | — | **2 — Needs Work** |
| 5 | 4-5 | — | **3 — Good** |
| 5 | ≥ 6 | ≤ 2 | **3 — Good** |
| 5 | ≥ 6 | ≥ 3 | **4 — Excellent** |
