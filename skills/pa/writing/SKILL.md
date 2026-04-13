---
name: writing
description: This skill provides vault-native writing rules and voice adaptation methodology. It should be activated when an agent needs to "match vault writing style", "adapt voice to target note", "analyze style fingerprint from exemplars", "apply the precedent ladder for voice selection", "check note portability", "preserve local note structure during revision", or "prevent model-voice leakage in authored markdown".
summary: Adapts drafted markdown to vault-native voice using local exemplars, style fingerprints, and revision-scope discipline.
version: 1
tags: [pa, writing, vault-voice, style, drafting]
preamble_tier: 1
---

# Writing

## Core Rule

**"Write as the vault writes, not as a language model writes."**

PA-authored notes should be indistinguishable from user-authored notes.
Every style choice should come from local exemplars or vault defaults, not from model training habits.
Voice fidelity matters because accurate content in the wrong voice still damages vault coherence and trust.

## Gotchas

| Risk | Phase | Prevention |
|------|-------|------------|
| Skipping exemplar analysis because the note looks simple | Exemplar selection | Walk the precedent ladder for every writing task |
| Falling to vault defaults when local exemplars exist | Exemplar selection | Check Levels 1 through 4 before using Level 5 |
| Treating one exemplar as a convention | Fingerprint extraction | Require 2 or more agreeing exemplars to confirm a pattern |
| Blending styles from multiple precedent levels | Drafting | Use one level at a time instead of synthesizing a style that exists nowhere |
| Imposing "good markdown" defaults from model training | Drafting | Trace each style choice to an exemplar or vault-profile field |
| Reformatting untouched sections during revision | Verification | Diff against the original and keep untouched content byte-identical |
| Adding frontmatter or plugin syntax the vault does not use | Drafting | Add only fields or syntax supported by repeated vault evidence |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "This note is simple, so default markdown style is fine" | Skipping the precedent ladder before drafting | Select the highest available exemplar level first |
| "These exemplars each have useful style pieces" | Blending style conventions across multiple precedent levels | Use one precedent level at a time and leave conflicting dimensions unconstrained |
| "Formatting cleanup is harmless outside the requested section" | Reformatting untouched content during a revision | Diff against the original and keep untouched sections byte-identical |

## Workflow

### 1. Locate Exemplars

Find the highest available precedent level for the task.
For revisions, start with the target note itself.
For new notes, start with the same note family, then the same folder, then linked canonical notes, and only then the vault profile.

### 2. Extract A Style Fingerprint

Analyze 3 to 5 exemplars at the selected level.
Record only dimensions that show agreement in at least 2 exemplars, and lower confidence when fewer than 3 dimensions stabilize.

### 3. Draft The Content

Apply the fingerprint to heading depth, bullet or prose ratio, task syntax, link syntax, frontmatter, and sentence compression.
When the fingerprint is silent on a dimension, use the vault-profile default.
When neither fingerprint nor profile provides guidance, choose the simplest portable option.

### 4. Verify Against The Fingerprint

Check every confirmed dimension against the draft.
For revisions, confirm that only the requested sections changed and that untouched sections remain byte-identical.

## Decision Rules

### Precedent Ladder

| Level | Source | Use when |
|-------|--------|----------|
| 1 | Target note | Revising an existing note |
| 2 | Same note family | Matching notes with similar naming or structure |
| 3 | Same folder exemplars | Local authored notes in the destination folder |
| 4 | Linked canonical notes | Nearby linked notes with consistent style |
| 5 | `vault-profile.writing_style` | No usable local exemplars exist |

If exemplars at the same level disagree, leave that dimension unconstrained and fall back to the vault profile.
If the user explicitly requests a style, that instruction overrides the ladder.

### Fingerprint And Portability

The fingerprint tracks title shape, heading depth, bullet or prose ratio, task syntax, link syntax, callout usage, sentence compression, and frontmatter density.
A dimension enters the fingerprint only at 2-plus exemplar agreement.
Do not introduce `tags`, `aliases`, `cssclass`, app-specific syntax, or structural flourishes unless the vault already uses them repeatedly.

Validation checks: confirm the selected precedent level before drafting, keep unconstrained dimensions simple, match link syntax to the vault convention, lower confidence when evidence is sparse, and ensure the result stays readable in plain markdown without Obsidian-specific rendering.

## Reference Map

- `${CLAUDE_SKILL_DIR}/references/style-fingerprint.md` — Dimension definitions, agreement thresholds, and style-analysis rules.
- `${CLAUDE_SKILL_DIR}/references/writing-rules.md` — Frontmatter, markdown portability, and content-convention rules for drafted notes.

## See Also

- `agents/pa/scribe.md` — Primary consumer of this writing methodology.
- `commands/pa/draft.md` — Uses writing rules for new note creation and revision.
- `commands/pa/capture.md` — Uses vault-native writing constraints when rendering captured material.
- `skills/pa/capture-distillation/SKILL.md` — Supplies the durable units that writing renders into vault notes.
- `skills/pa/vault-modeling/SKILL.md` — Supplies vault-profile defaults when local precedent is missing.
