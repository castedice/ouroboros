# Command Static Evaluation Criteria

> Reference for the evaluation skill. 16 binary criteria (0 or 1) across 3 tiers.
> Tier 1 Foundation gates Tier 2/3: Foundation < 5 caps at Level 2.

## Tier 1: Foundation (5)

### F1: Phase Structure

Does the command define its workflow with clear phase structure?

- **1**: Composed of 3 or more named phases. Each phase's purpose is clear. Logical flow like Discovery → Analysis → Implementation
- **0**: No phase separation, just a list of instructions. Or all tasks mixed in a single phase

### F2: Agent Delegation

Does it delegate specialized work to appropriate agents?

- **1**: At least 1 agent delegation exists. Delegation relationship specified via agent table or `> Agent: **name**` format. Each agent's role is specific
- **0**: All tasks performed by the command itself without agent delegation. Or delegation relationship is vague

### F3: User Checkpoints

Does it provide confirmation/decision opportunities to the user?

- **1**: User confirmation or choice requested at important decision points. 1 or more checkpoints like "Ask the user", "After user approval" exist
- **0**: Fully automatic from start to finish without user involvement. Or ends without presenting results

### F4: Context Gathering

Does it systematically collect the context needed for execution?

- **1**: Context collection steps explicitly stated: `$ARGUMENTS` usage, file system exploration, git status check, etc. Default behavior defined when input is missing
- **0**: Work starts immediately without context collection. Or only $ARGUMENTS exists with no fallback for insufficient input

### F5: Frontmatter Completeness

Is the command frontmatter complete?

- **1**: All 3 fields present: `description`, `allowed-tools`, `argument-hint`. Description is specific (clear what it does in one line). Allowed-tools follows minimum privilege
- **0**: Required fields missing, description too generic, or allowed-tools includes unnecessary tools

## Tier 2: Craft (7)

### Q1: Agent Delegation Specificity

Does each agent delegation specify input, instructions, and expected output?

- **1**: Agent calls include all three: what to feed (input data/files), how to process (specific instructions, procedure references, or methodology pointers), what to return (output format with section names or template reference)
- **0**: Agent delegations use generic instructions ("Perform analysis", "Produce a report") without specifying input format, processing methodology, or output structure

### Q2: Error & Edge Case Coverage

Does the command handle non-happy-path scenarios?

- **1**: At least 2 of: (1) input validation with specific error messages and alternative suggestions, (2) runtime failure handling (agent/tool errors, missing files), (3) cleanup guarantee on abort/error, (4) boundary case handling (empty results, ambiguous input, conflicting flags)
- **0**: Only happy path described. No handling for invalid input, agent failures, or abnormal termination

### Q3: Mode Detection Robustness

Is mode detection validated beyond argument parsing?

- **1**: Mode detection includes state verification (file/directory existence, prerequisite check). Edge cases produce specific error messages with alternative command suggestions. For single-mode commands: auto-pass
- **0**: Mode determined solely by argument presence/absence. No state validation or ambiguous-case handling

### Q4: Output Template Precision

Is the review/output phase format concretely specified?

- **1**: Output defined as markdown template with named sections. Mode-specific variations have distinct templates or clearly marked conditional sections
- **0**: Output described as "show results" or "present summary" without structural specification

### Q5: Skill/Reference Integration

Does the command explicitly reference shared skills or reference files?

- **1**: References to skill procedures or reference files include file paths. Agent instructions specify which methodology or criteria to apply (e.g., "Apply quality gate per quality-gate-procedure.md")
- **0**: No references to shared skills/references, or references are implicit (agent expected to find them independently)

### Q6: Conditional Branch Clarity

Are execution path branches clearly documented?

- **1**: All conditional branches (modes, flags, outcome variants) presented in table or decision tree form. Each branch specifies the condition, which phases are affected, and the resulting behavior
- **0**: Branches described inline within prose. Conditions scattered across multiple phases without consolidated view

### Q7: Recovery Design

Does the command define behavior for degraded or failed outcomes?

- **1**: At least 1 of: (1) automatic retry with modified approach based on failure context, (2) graduated escalation (auto-fix → user choice → abort), (3) graceful degradation (continue with reduced scope or quality)
- **0**: Command either succeeds fully or stops entirely. No retry, escalation, or graceful degradation path

## Tier 3: Excellence (4)

### E1: Separation of Concerns Purity

Does the command maintain clear orchestration role without embedding implementation details?

- **1**: No inline implementation logic (Bash scripts, parsing algorithms, complex calculations). Heavy lifting delegated to agents, scripts, or skill references. Command body reads as a workflow recipe — what happens and when, not how
- **0**: Contains implementation details that belong in agents/scripts/skills. Inline logic that could be extracted and independently evolved

### E2: Context Efficiency

Is the command specification token-efficient without sacrificing executability?

- **1**: No redundant information across phases. Shared patterns referenced (not duplicated). Length proportional to orchestration complexity. Each phase adds distinct value
- **0**: Repetition across phases, verbose where table/list suffices, or reference-separable content embedded inline

### E3: System Integration Documentation

Does the command document its relationships within the larger system?

- **1**: Documents which other commands compose it (or which it composes), boundary rules with related commands, and what artifacts it produces/consumes. Composability is explicit
- **0**: Described as standalone. No mention of how it relates to other commands or the broader command taxonomy

### E4: Actionable Review Phase

Does the review phase provide context-aware next steps?

- **1**: Next actions include specific command invocations with context variables populated from the current run (e.g., "/evolve {path} --focus {area}"). Causal connection between results and recommended action
- **0**: Generic suggestions ("run /evaluate") or no next-action guidance

## Severity Gate Thresholds

| F (0-5) | Q (0-7) | E (0-4) | Level |
|---|---|---|---|
| ≤ 3 | — | — | **1 — Poor** |
| 4 | — | — | **2 — Needs Work** (cap) |
| 5 | ≤ 3 | — | **2 — Needs Work** |
| 5 | 4-5 | — | **3 — Good** |
| 5 | ≥ 6 | ≤ 2 | **3 — Good** |
| 5 | ≥ 6 | ≥ 3 | **4 — Excellent** |
