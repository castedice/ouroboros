# Skill Static Evaluation Criteria

> Reference for the evaluation skill. 16 binary criteria (0 or 1) across 3 tiers.
> Tier 1 Foundation gates Tier 2/3: Foundation < 5 caps at Level 2.

## Tier 1: Foundation (5)

### F1: Trigger Description Quality

Does the description define when the skill should activate with enough precision?

- **1**: Frontmatter `description` uses third-person form and names the job, main contexts, and distinguishing activation signals. Pass is based on specificity and boundary clarity, not raw trigger count
- **0**: Description is generic (`"Provides guidance for X"`), second-person, or too broad or narrow to separate this skill from adjacent skills

### F2: Standard Structure And Progressive Disclosure

Does `SKILL.md` follow the standardized Phase 4 shape and keep details delegated?

- **1**: `SKILL.md` uses the 6-section order `Core Rule → Gotchas → Workflow → Decision Rules → Reference Map → See Also`. Body stays within the 80-140 line target and never exceeds the 180 line hard cap. Detailed material is delegated to `references/`
- **0**: Old section names or order remain, body exceeds 180 lines, body is too thin to execute the method, or detailed content stays inline instead of using progressive disclosure

### F3: Writing Style

Is the knowledge delivery style appropriate?

- **1**: Uses imperative or infinitive form with concise operational language. Employs 2 or more of quick reference tables, DO or DON'T lists, or worked examples. `Core Rule`, `Workflow`, and `Decision Rules` stay quick-reference dense
- **0**: Conversational second-person ("You should") style. Prose-only without tables/lists. Or excessively abstract

### F4: Reference Map And Path Portability

Does the skill expose its references through a portable `Reference Map`?

- **1**: `Reference Map` states what each reference is for and when to load it. Same-skill references use the skill-root variable form for portability. Cross-skill or shared references use stable relative or repo paths where appropriate
- **0**: No `Reference Map`, references are listed without load guidance, or skill-local references use brittle hard-coded paths

### F5: Frontmatter And Meta Contract

Do the frontmatter and meta-behavior contract match the new skill architecture?

- **1**: Required frontmatter includes `description` and `preamble_tier`, and the tier matches the skill's depth. Tier 4 meta skills include an explicit `SUBAGENT-STOP` guard or equivalent "do not load when delegated" rule
- **0**: `preamble_tier` is missing or mismatched, or a Tier 4 skill lacks the required meta-skill guard

## Tier 2: Craft (7)

### Q1: Trigger Specificity

Does the trigger description use domain-specific terms that precisely activate in relevant contexts?

- **1**: Activation language includes domain-specific nouns such as tool names, platform concepts, or methodology terms. Each trigger distinguishes this skill from other skills in the same module
- **0**: Generic verb+noun combinations ("help with X", "improve Y") that could activate for unrelated contexts. No domain vocabulary

### Q2: Methodology Reproducibility

Can the methodology be followed step-by-step to produce consistent results?

- **1**: `Workflow` and `Decision Rules` provide named procedure steps with concrete actions. Conditional branches have explicit conditions. Another AI following the same steps and named references would produce structurally equivalent output
- **0**: Abstract principles without step-by-step procedure, or steps that rely on "as appropriate" or "use judgment" without specifying what to judge

### Q3: Decision Rule Quantification

Are judgment criteria expressed with measurable thresholds rather than subjective terms?

- **1**: At least 3 decision points use numeric thresholds, counts, line caps, or other measurable criteria such as `80-140 lines`, `>= 3/5`, or `max 2 retries`
- **0**: Decisions rely on subjective terms ("significant", "appropriate", "adequate") without measurable bounds

### Q4: Gotchas Quality

Does the `Gotchas` section document failure modes in a structured, operational way?

- **1**: `Gotchas` uses structured form such as a table or numbered pattern. Each entry includes the risk, prevention or correction, and a link back to a relevant workflow step or decision rule. A `phase` column is optional, not required
- **0**: No `Gotchas` section, warnings appear only as unstructured prose, or the gotchas are detached from the actual workflow and decision logic

### Q5: Reference File Self-Containment

Can each reference file be understood without reading SKILL.md first?

- **1**: Each reference file includes a header or summary stating its purpose and relationship to the parent skill. It contains enough local context to be useful standalone, and the `Reference Map` tells the caller when that file becomes relevant
- **0**: Reference files assume `SKILL.md` context, lack purpose headers, or the `Reference Map` does not help route them

### Q6: Failure & Edge Case Policy

Does the methodology address what to do when things go wrong?

- **1**: At least 1 of the following appears in `Workflow`, `Decision Rules`, `Gotchas`, or references. Retry policy with conditions for when to retry versus stop. Escalation path for unresolvable cases. Explicit edge case handling for domain boundary conditions
- **0**: Only happy-path methodology described. No guidance for failure, stalemate, or ambiguous situations

### Q7: Rationalization Defense

Does the skill defend against self-justifying shortcuts in judgment-heavy work?

- **1**: Judgment-heavy skills include a `Rationalization Red Flags` table or equivalent structured boundary. It names common rationalizations, the forbidden move, and the required corrective action. Non-judgment skills may satisfy this with an equivalent anti-drift rule set tied to decision integrity
- **0**: Skills that score, judge, evolve, or grant exceptions lack explicit anti-rationalization guards, or the guard exists only as slogans without trigger conditions and required response

## Tier 3: Excellence (4)

### E1: Bias Mitigation Awareness

Does the skill acknowledge and counter systematic errors in its methodology?

- **1**: Identifies at least 1 bias pattern specific to the methodology, such as recency bias in research, self-enhancement in evaluation, or anchoring in comparison, with a concrete countermeasure in `Gotchas`, `Decision Rules`, or references
- **0**: No bias awareness. Methodology presented as bias-free

### E2: Multi-Axis Classification

Does the skill define explicit decision axes for its domain?

- **1**: At least 1 classification axis with named categories, such as static or dynamic, error or warning, or low or medium or high stake. The axis determines different treatment paths in `Workflow` or `Decision Rules`
- **0**: Flat methodology without dimensional classification. All inputs treated uniformly regardless of characteristics

### E3: Context Efficiency

Is the skill body token-efficient while maintaining actionability?

- **1**: `SKILL.md` body stays focused on `Core Rule`, `Gotchas`, `Workflow`, `Decision Rules`, `Reference Map`, and `See Also`. Detailed reference material is properly delegated. No information is repeated between body and references
- **0**: Body contains material that should live in references, or the same guidance is duplicated between body and reference content

### E4: Operational Integration

Does the skill document how it plugs into the operational system around it?

- **1**: `See Also` names concrete consumers or peer components and how they interact with the skill. The skill is structured so hooks, scripts, and future local overlays such as `learned.md` or `gotchas.md` can consume or extend it without rewriting the body
- **0**: No `See Also`, no consumer guidance, or the skill is written as isolated prose with no operational extension points

## Severity Gate Thresholds

| F (0-5) | Q (0-7) | E (0-4) | Level |
|---|---|---|---|
| ≤ 3 | — | — | **1 — Poor** |
| 4 | — | — | **2 — Needs Work** (cap) |
| 5 | ≤ 3 | — | **2 — Needs Work** |
| 5 | 4-5 | — | **3 — Good** |
| 5 | ≥ 6 | ≤ 2 | **3 — Good** |
| 5 | ≥ 6 | ≥ 3 | **4 — Excellent** |
