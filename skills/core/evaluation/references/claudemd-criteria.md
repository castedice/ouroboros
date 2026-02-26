# CLAUDE.md Static Evaluation Criteria

> Reference for the evaluation skill. 14 binary criteria (0 or 1) across 3 tiers.
> Tier 1 Foundation gates Tier 2/3: Foundation < 5 caps at Level 2.
> CLAUDE.md has no output (runtime) concept, so only static evaluation applies.

## Tier 1: Foundation (5)

### F1: Actionable Commands

Are instructions copy-pasteable and executable?

- **1**: Build/test/deploy commands provided in code blocks. Includes specific file paths and commands. "Do this" is immediately executable
- **0**: Only abstract instructions like "write good tests." No actually executable commands

### F2: Architecture Clarity

Are project structure and module relationships clearly described?

- **1**: Directory tree, module relationships, key file roles are described. AI can understand the overall structure before exploring the codebase
- **0**: No structure description, or insubstantial like "code is in the src/ directory"

### F3: Non-obvious Patterns

Are traps, quirks, and conventions that can't be seen from code alone documented?

- **1**: 1 or more gotchas, non-obvious rules, or project-specific patterns documented. Content that qualifies as "not visible in code but important"
- **0**: Only repeats what's directly readable from code. Or lists only generic coding guidelines

### F4: Conciseness

Is it concise, given that it's loaded on every request?

- **1**: One concept per line, minimal unnecessary prose, table/list-centric. High information density. Within 500 words or equivalent density
- **0**: Verbose explanations, repetition, content that doesn't need reading. Noticeable token waste

### F5: Currency

Does it accurately reflect the current codebase state?

- **1**: Described structure, commands, and patterns match the current code. No references to deleted files or outdated rules
- **0**: References non-existent files, rules that have changed are not updated, or last modified long ago (after structural changes)

## Tier 2: Craft (6)

### Q1: Session Workflow Coverage

Does it cover the full session lifecycle?

- **1**: All three phases addressed: session start (what to read/do first), during session (working principles and constraints), session end (what to update/record). Each phase has concrete actions, not just general advice
- **0**: Only general guidelines without lifecycle structure. Or covers only 1-2 of the 3 phases

### Q2: Cross-Reference System

Are relationships to other project documents explicitly mapped?

- **1**: References to related documents include file paths and reading triggers (when/why to read each document). Document roles clearly distinguished with no overlapping responsibilities
- **0**: No cross-references to other documents, or references without context on when to use them

### Q3: Prohibition Clarity

Are forbidden actions explicitly stated?

- **1**: At least 2 explicit prohibitions using "never", "do not", or equivalent strong language. Prohibitions are specific enough to prevent accidental violations (not just "be careful")
- **0**: No explicit prohibitions. Or prohibitions are vague ("avoid doing X when possible")

### Q4: Mental Model Provision

Does it provide internalizeable rules for the AI to operate by?

- **1**: At least 1 one-line classification or decision rule that captures a key concept (e.g., "Commands=orchestration, Skills=knowledge, Agents=execution"). Rules are memorable, immediately applicable, and reduce need for case-by-case lookup
- **0**: Only detailed instructions without distilled principles. AI must synthesize its own mental model from individual rules

### Q5: Priority Signaling

Is relative importance of different instructions clear?

- **1**: Most critical rules visually distinguished (bold, dedicated headers, or explicit priority markers). Information ordered from most to least important within sections. Reader can identify the top 3 most important rules by scanning
- **0**: All instructions presented at same priority level. Critical rules buried among less important ones with no visual distinction

### Q6: Boundary Definition

Does it define what's in scope AND what's out of scope?

- **1**: At least 1 bidirectional boundary ("What goes in X / What does NOT go in X" pattern). Scope limits explicitly stated for ambiguous areas where the AI might over-apply or under-apply rules
- **0**: Only positive scope defined (what to do). No explicit exclusions or out-of-scope statements

## Tier 3: Excellence (3)

### E1: Rule-Implementation Alignment

Do documented conventions match actual implementation?

- **1**: Every stated convention (formatting rules, naming patterns, process rules) is actually followed in the codebase. No rules that exist only in documentation while being violated in practice
- **0**: Documents rules that are violated in implementation. Gap between stated conventions and actual project state

### E2: Token Efficiency

Is every line worth its context window cost?

- **1**: No redundant information between sections. Abstract principles backed by concrete implications. Every sentence either defines a rule, provides an example, or offers a reference. No filler paragraphs or abstract slogans without actionable follow-through
- **0**: Contains abstract slogans without actionable implications, redundant restatements across sections, or verbose prose where a table would suffice

### E3: Adaptability Guidance

Does it provide decision frameworks for novel situations?

- **1**: Includes principles or decision trees that help the AI handle situations not explicitly covered. "When in doubt" rules or escalation paths (e.g., "discuss with user before significant decisions") with clear trigger criteria
- **0**: Only explicit rules for known scenarios. AI has no guidance for edge cases or situations outside documented rules

## Severity Gate Thresholds

| F (0-5) | Q (0-6) | E (0-3) | Level |
|---|---|---|---|
| ≤ 3 | — | — | **1 — Poor** |
| 4 | — | — | **2 — Needs Work** (cap) |
| 5 | ≤ 2 | — | **2 — Needs Work** |
| 5 | 3-4 | — | **3 — Good** |
| 5 | ≥ 5 | ≤ 1 | **3 — Good** |
| 5 | ≥ 5 | ≥ 2 | **4 — Excellent** |
