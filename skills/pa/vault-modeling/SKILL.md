---
name: vault-modeling
description: This skill provides vault structure inference methodology. It should be activated when an agent needs to "infer vault archetype", "profile vault structure", "infer folder roles", "detect daily note patterns", "analyze frontmatter field frequency", "estimate vault link density", or "generate a vault-profile.json".
summary: Infers vault structure conservatively from folder roles, naming patterns, frontmatter, link density, and archetype evidence.
version: 1
tags: [pa, vault, modeling, structure, profiling]
preamble_tier: 2
---

# Vault Modeling

## Core Rule

**"Observe the vault as it is, not as it should be."**

A vault profile is an adapter for safe assistance, not a judgment about whether the user's system is good.
The model should capture repeated structure, naming, and placement patterns that later commands can trust.
Wrong confident inference is worse than explicit uncertainty because it pushes PA to create notes the user would never write.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Classifying from familiar folder names alone | Archetype scoring | Weight repeated behavior and note placement over labels |
| Sampling only the noisiest recent subtree | Scan | Stratify across the root and the largest authored folders |
| Treating every dated file as a daily note | Pattern detection | Require both dominant naming and dominant placement |
| Letting `.pa/`, `.obsidian/`, or archives dominate the counts | Scan | Exclude assistant, config, archive, and import-dump zones from primary scoring |
| Forcing a named archetype when signals conflict | Classification | Prefer `hybrid` or `custom` when evidence does not clearly separate candidates |
| Counting frontmatter keys by repetition inside one note | Feature analysis | Count by unique note presence instead |
| Filling uncertain schema fields because the schema exists | Assembly | Omit or flag low-confidence fields instead of inventing detail |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The folder name says Projects, so the archetype is clear" | Classifying the vault from familiar labels alone | Weight repeated placement, note behavior, and content signals over names |
| "The active recent subtree is representative enough" | Sampling only the noisiest current area | Stratify across the root and every major authored folder |
| "The schema wants a value here" | Filling weakly supported profile fields with defaults or guesses | Omit the field or mark it low-confidence for user confirmation |

## Workflow

### 1. Scan And Sample The Vault

Map the top-level tree, authored-note distribution, and obvious date-like files.
Inspect all notes when the vault is small, and otherwise use a stratified sample across the root and major authored folders.

### 2. Infer Folder Roles Before Archetype

Identify likely daily, template, attachment, reference, clipping, category, and authored-root zones from both names and contents.
Treat a role as high confidence only when at least two independent signals agree.

### 3. Detect Naming, Frontmatter, And Linking Patterns

Test dominant daily-note and timestamp conventions with both regex and placement.
Measure frontmatter field frequency by note presence, estimate link density from prose notes, and infer navigation style from repeated behavior.

### 4. Score Archetypes Conservatively

Compare the observed signals against the archetype cards and false-positive checks.
Use `hybrid` when multiple patterns remain stable together, and use `custom` when local logic is real but does not fit the named set.

### 5. Assemble And Confirm The Phase 1 Profile

Populate only the fields the evidence actually supports.
Mark low-confidence fields for user confirmation, explain what PA should avoid changing automatically, and let the user correct the profile before finalizing it.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Signal hierarchy | Anchor signals dominate, supporting signals refine, and contextual hints never override anchor evidence alone |
| Sampling | Inspect all notes when there are 30 or fewer, otherwise use a stratified sample with root plus every major authored folder represented |
| Folder-role confidence | High-confidence roles require at least 2 agreeing signals, and content beats labels when they disagree |
| Daily-note dominance | A daily pattern is dominant only when at least 80% of date-like names match one pattern and at least 70% live in one folder family |
| Link density | Median links per prose note `< 2` is `low`, `2-6` is `medium`, and `> 6` is `high` |
| Archetype thresholds | Use a named archetype only when the top score clears the confidence threshold, prefer `hybrid` when two patterns stay close, and prefer `custom` when the vault is sparse or idiosyncratic |
| Schema population | Use observed values first, defaults second, and omission over invention when evidence is weak |
| User checkpoint | Any field below `0.6` confidence requires confirmation before PA should depend on it |

## Reference Map

| Need | Reference |
|------|-----------|
| Archetype cards, role heuristics, timestamp patterns, and false positives | `${CLAUDE_SKILL_DIR}/references/archetype-heuristics.md` |
| Phase 1 `vault-profile.json` schema and field population rules | `${CLAUDE_SKILL_DIR}/references/profile-schema.md` |
| Survey bootstrap write order, refresh merge, registry refresh, and shadow setup | `${CLAUDE_SKILL_DIR}/references/survey-bootstrap-contract.md` |

## See Also

- `agents/pa/cartographer.md` — Primary profiler that builds the vault model.
- `commands/pa/survey.md` and `commands/pa/init.md` — Main command consumers for inference and confirmation.
- `skills/pa/trust-and-boundaries/SKILL.md` — Uses the resulting profile to decide what PA may safely change.
