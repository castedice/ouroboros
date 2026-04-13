# Command Static Evaluation Criteria

> Reference for the evaluation skill.
> 16 binary criteria (0 or 1) across 3 tiers.
> This file defines the canonical v2 command criteria bundle.
> Tier 1 Foundation gates Tier 2/3, so Foundation < 5 caps at Level 2.

## Tier 1: Foundation (5)

### F1: Phase Structure

Does the command define its workflow with clear phase structure?

- **1**: The command is composed of 3 or more named phases whose purposes and logical flow are clear, such as Discovery → Analysis → Implementation.
- **0**: There is no real phase separation, or tasks are mixed into a single phase.

### F2: Agent Delegation

Does it delegate specialized work to appropriate agents?

- **1**: The command includes at least 1 agent delegation using an agent table or `> Agent: **name**` format, and each delegated role is specific.
- **0**: All tasks are performed by the command itself, or the delegation relationship is vague.

### F3: User Decision Boundaries

Does the command define explicit points where it must stop and ask the user?

- **1**: At least 1 explicit stop-and-ask boundary exists for approval, disambiguation, or consequential choice, and the command says when to ask the user instead of inferring missing intent.
- **0**: The command proceeds through consequential choices or ambiguous inputs without an explicit user decision boundary, or ends without presenting results and next choices.

### F4: Context Gathering

Does it systematically collect the context needed for execution?

- **1**: The command explicitly states context collection steps such as `$ARGUMENTS` usage, file system exploration, or git status checks, and it defines default behavior when input is missing.
- **0**: Work starts immediately without context collection, or only `$ARGUMENTS` is mentioned without a fallback for insufficient input.

### F5: Frontmatter Completeness

Is the command frontmatter complete?

- **1**: All 4 required fields are present, namely `name`, `description`, `allowed-tools`, and `argument-hint`, `name` follows `{module}:{command}`, `description` starts with `Use when`, and `allowed-tools` follows minimum privilege.
- **0**: Required fields are missing, `name` breaks the contract, `description` does not start with `Use when`, or `allowed-tools` includes unnecessary tools.

## Tier 2: Craft (7)

### Q1: Agent Delegation Specificity

Does each agent delegation specify input, instructions, and expected output?

- **1**: Agent calls include all three elements, namely what to feed, how to process it through specific instructions, procedure references, or methodology pointers, and what to return through an explicit output format, section list, or template reference.
- **0**: Agent delegations use generic instructions such as "Perform analysis" or "Produce a report" without specifying input, process, or output structure.

### Q2: Error & Edge Case Coverage

Does the command handle non-happy-path scenarios?

- **1**: The command covers at least 2 of the following, namely input validation with specific error messages and alternative suggestions, runtime failure handling, cleanup guarantees on abort or error, or boundary case handling for empty results, ambiguous input, or conflicting flags.
- **0**: The command describes only the happy path and does not address invalid input, agent failures, or abnormal termination.

### Q3: Mode Detection Robustness

Is mode detection validated beyond argument parsing?

- **1**: Mode detection includes state verification such as file or directory existence or prerequisite checks, and edge cases produce specific error messages with alternative command suggestions, while single-mode commands auto-pass.
- **0**: Mode is determined solely by argument presence or absence, with no state validation or ambiguous-case handling.

### Q4: Output Contract Precision

Is the review or output structure concretely specified for each materially distinct output mode?

- **1**: Each materially distinct report path defines a reconstructable output contract using at least one of the following, namely a markdown template, an ordered list of required sections, fields, tables, or bullets with explicit grouping, or an explicit reference to a named base template or subordinate report together with either a statement that it is used unchanged or clearly stated additions, omissions, or conditional sections.
- **0**: Any materially distinct mode leaves the output shape implicit or underspecified, such as "present results" or "show summary" without naming required sections or fields, or relies on an inherited template or subordinate report without stating whether it is reused unchanged or what is reused, added, omitted, or conditional.

### Q5: Shared Protocol And Machine-Contract Integration

Does the command explicitly integrate shared skills, references, protocols, and machine-consumer contracts when needed?

- **1**: References to shared skills, reference files, or protocols include explicit file paths, agent instructions specify which methodology or criteria to apply, and parse-heavy or machine-consumed outputs name the authoritative payload location or file contract plus the required consensus or completion-status handling rules.
- **0**: Shared protocols are implicit instead of named, or parse-heavy or machine-consumed outputs omit the authoritative payload location or required consensus or status-handling rules.

### Q6: Conditional Branch Clarity

Are execution path branches clearly documented?

- **1**: All conditional branches such as modes, flags, or outcome variants are presented in table or decision-tree form, and each branch specifies the condition, affected phases, and resulting behavior.
- **0**: Branches are described inline in prose, or conditions are scattered across phases without a consolidated view.

### Q7: Recovery And Convergence Detection

Does the command define bounded recovery and detect non-convergence?

- **1**: Recovery paths use bounded retries or bounded fallback loops, and the command defines how to detect stagnation, non-convergence, or repeated failure before escalating or stopping.
- **0**: Retries are unbounded, repeated failure is treated as ordinary progress, or there is no stagnation or convergence rule.

## Tier 3: Excellence (4)

### E1: Orchestration Boundary Discipline

Does the command stay at the orchestration layer while remaining concretely executable?

- **1**: Inline shell or tool snippets are occasional and subordinate to declarative phase instructions, staying limited to invocation mechanics such as calling a named script or command, binding args or paths, checking state, capturing output locations, or routing artifacts between phases, while domain logic, parsing, transformation, scoring, and policy live in agents, scripts, or referenced procedures.
- **0**: The command implements substantive logic inline, or shell or tool snippets dominate a phase or recur enough that the phase stops reading as declarative orchestration and instead reads like an inline executor script.

### E2: Structural Economy

Is the command compact relative to its branch complexity, with duplication limited to what preserves local executability?

- **1**: Shared logic is centralized, tabulated, or referenced, and repetition appears only where a mode, outcome, or user-facing template must restate locally executable instructions because the condition, affected phases, artifacts, or output contract materially differ, while naming conventions may be declared once and later instantiated in concrete commands without counting as redundancy.
- **0**: Identical or near-identical instructions are repeated across phases or modes without material branch-specific value, large blocks differ mostly by token substitution, consolidation would not make any branch materially harder to execute, or reference-separable content remains embedded inline.

### E3: System Integration Documentation

Does the command make its place in the larger command system explicit?

- **1**: The command documents upstream or downstream commands, boundary rules with adjacent commands, and the artifacts or state it consumes and produces, so composability within the command taxonomy is explicit.
- **0**: The command is presented as standalone, and relationships to adjacent commands, workflow boundaries, or produced or consumed artifacts are missing or implicit.

### E4: Actionable Review Phase

Does the review phase provide context-aware next steps?

- **1**: Next actions include specific command invocations with context variables populated from the current run, such as `/evolve {path} --focus {area}`, and the causal connection between results and recommended action is clear.
- **0**: The command offers only generic suggestions such as "run /evaluate" or provides no next-action guidance.

## Severity Gate Thresholds

| F (0-5) | Q (0-7) | E (0-4) | Level |
|---|---|---|---|
| ≤ 3 | — | — | **1 — Poor** |
| 4 | — | — | **2 — Needs Work** (cap) |
| 5 | ≤ 3 | — | **2 — Needs Work** |
| 5 | 4-5 | — | **3 — Good** |
| 5 | ≥ 6 | ≤ 2 | **3 — Good** |
| 5 | ≥ 6 | ≥ 3 | **4 — Excellent** |

## Evaluation Operating Rules

### Criterion-Local Evidence Rule

For command criteria F3, Q5, E1, E2, and E3, a score must be justified with criterion-local evidence.

A criterion score may change between runs only when:
1. The cited evidence for that criterion changed.
2. New text elsewhere directly contradicts the prior evidence.

If the file changed but the criterion-local evidence did not, label the delta as evaluator variance rather than regression.

## Rubric-Change Governance

### Required Classification

Every future change to criterion text, pass conditions, fail conditions, severity gates, or evaluation operating rules must declare one of two classifications. A `measurement fix` keeps the intended quality bar the same and only improves precision, evidence locality, or inter-evaluator consistency. A `policy shift` intentionally changes the bar, whether by raising it, lowering it, broadening scope, or narrowing scope.

### Proof Burden

A proposed `measurement fix` must identify the scoring defect in the prior wording and explain why the old and new text preserve the same passing standard. If that case cannot be made concretely, the change must be classified as a `policy shift`.

### Versioning And Baselines

Any classified rubric change must increment `criteria_version` and require a full rebaseline for the affected scope before regression comparison resumes. Do not compare scores across different `criteria_version` values, even when the newer bundle is declared a `measurement fix`.

### Current Bundle Declaration

`command-criteria-2026-03-30` is classified as a `measurement fix` bundle. This bundle finalizes canonical v2 by clarifying user-decision boundaries, output contract precision, machine-consumer contract integration, orchestration boundary discipline, structural economy, and system integration documentation, and by adding criterion-local evidence and rubric-change governance without intentionally changing the severity thresholds or pass bar.
