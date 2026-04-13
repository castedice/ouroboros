---
name: personal-profiling
description: This skill provides profile management methodology for PA. It should be activated when an agent needs to "manage a personal profile", "detect profile gaps", "refresh stale profile fields", "propose profile enrichment", "assess profile confidence", or "map interview output into personal-profile.json".
summary: Maintains a small evidence-backed personal profile through gap detection, signal weighting, minimal patches, and explicit confirmation.
version: 1
tags: [pa, profiling, profile, confidence, consent]
preamble_tier: 2
---

# Personal Profiling

## Core Rule

**"The profile serves the user's direction, not the assistant's convenience."**

The profile exists so PA can remember the user's direction, current reality, and interaction preferences with less repetition.
It is not a persona mask, a psychographic dossier, or a place to store every interesting interpretation.
A smaller true profile is more useful than a richer invented one.

## Gotchas

| Risk | Phase | Prevention |
|------|-------|------------|
| Treating `bootstrap` as a finished profile | Lifecycle | Keep confidence low and preserve explicit gaps |
| Using one conversation to refresh every field | Refresh | Ask only about stale, missing, or contradictory fields |
| Letting vault activity override direct statements | Signal evaluation | Anchor evidence outranks supporting evidence |
| Rewriting long-horizon direction because of one busy week | Patch drafting | Treat direction as stickier than current focus |
| Updating current focus without checking commitments | Patch drafting | Review the whole focus layer when priorities move |
| Forgetting lifecycle metadata such as `last_direction_review` | Persistence | Update metadata together with approved field changes |
| Storing what is convenient for PA instead of what helps the user | Patch drafting | Ask whether the field improves future support before adding it |
| Flattening contradictions into one tidy story | Synthesis | Keep per-area conflicts visible until the user resolves them |
| Letting weak inference accumulate into false certainty | Confidence | Keep inference deltas small and require confirmation before persistence |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The profile is sparse, so useful guesses are better than blanks" | Filling profile fields for assistant convenience without user-backed evidence | Leave gaps explicit or ask the narrowest confirming question |
| "This busy week changed the user's long-term direction" | Rewriting direction from one short-term operational pattern | Treat the signal as current-focus evidence and preserve long-horizon direction |
| "Vault activity contradicts the profile, so update it" | Letting supporting evidence override a direct or confirmed statement | Surface the conflict and ask which signal is current |

## Workflow

### 1. Load Or Initialize The Profile

Start from `.pa/personal-profile.json` when it exists, or from the minimal schema when it does not.
Do not fill empty fields just because the schema has room for them.

### 2. Detect Gaps And Staleness

Identify missing, stale, low-confidence, or contradictory fields before asking anything new.
Choose the narrowest interview or enrichment path that can resolve the important gaps.

### 3. Gather Strong Signals

Use direct user answers first.
Support them with vault activity, specialist patterns, or memory observations only when those signals help choose the next question or justify a proposal.

### 4. Draft A Minimal Patch

Convert evidence into the smallest useful patch.
Change only fields that genuinely moved, and tie every proposed edit to a user statement or clearly described supporting pattern.

### 5. Confirm And Persist

Present the patch before applying it.
Approved changes update both value and confidence, and declined proposals leave the stored value untouched.

## Decision Rules

### Lifecycle And Confidence

| Stage | Trigger | Typical output | Confidence target |
|-------|---------|----------------|-------------------|
| `bootstrap` | `/pa init` or missing profile | Minimum viable profile seed | `0.4` |
| `enrich` | Clear conversational signal | One small proposal-only patch | `+0.02` to `+0.05` |
| `refresh` | Staleness or `/pa survey` | Focused delta patch | `0.6` on touched fields |
| `review` | Direction review or year-plus check | Updated direction map | `0.7` on direction |
| `deepen` | Explicit deepening consent | High-confidence pattern enrichments | `0.8+` on touched fields |

Use `0.0-0.35` as effectively unknown, `0.4-0.55` as early but usable, `0.6-0.75` as moderately confirmed, and `0.8+` as strong until contradiction appears.
Raise confidence only on fields that were actually discussed or confirmed.

### Signal Hierarchy And Gap Detection

| Signal class | Weight | Use |
|--------------|--------|-----|
| Anchor | 3 | Explicit statements, confirmed corrections, repeated self-description |
| Supporting | 2 | Vault activity patterns or repeated note themes |
| Contextual | 1 | Tone, one-off remarks, or indirect inference |

| Gap type | Detection rule | Response |
|----------|----------------|----------|
| Missing | Field is empty or absent | Ask the narrowest question that fills it |
| Stale focus | Current focus no longer matches recent statements or cadence | Run `catch-up` or a focused proposal |
| Stale direction | Direction review is absent or older than a year | Run `direction` interview |
| Low confidence | Confidence is below what the current task needs | Ask before relying on it |
| Contradiction | New explicit statement conflicts with stored value | Surface the conflict and ask which is current |
| Specialist pattern signal | Repeated same-status specialist insight | Use it to nominate one catch-up question, not to write directly |

Memory observations with `profile-hint`, `work-change`, or `direction-shift` can support proposals, but they do not bypass the anchor-over-supporting-over-contextual hierarchy.

### Enrichment Limits

Propose at most one enrichment per session.
Prefer direct statements over clever inference.
Never rewrite long-horizon direction from one-off operational chatter.
Treat declined proposals as signal about assistant behavior, not as evidence about the user's life.

Validation checks: keep the profile small enough for a human to review quickly, surface contradictions instead of hiding them, update metadata with approved changes, and use proposal-only handling for conversational enrichment.

## Reference Map

- `${CLAUDE_SKILL_DIR}/references/profile-schema.md` — Profile contract, field guide, and lifecycle interpretation for `personal-profile.json`.
- `${CLAUDE_SKILL_DIR}/references/enrichment-rules.md` — Proposal-only enrichment workflow for conversational updates.
- `${CLAUDE_SKILL_DIR}/references/memory-signals.md` — Memory observation taxonomy and signal handling rules.
- `${CLAUDE_SKILL_DIR}/references/feedback-learning.md` — Ledger-pattern rules for behavioral adaptation and learning feedback.
- `${CLAUDE_SKILL_DIR}/references/feedback-learning-protocol.md` — End-to-end loop from proposal feedback capture to approved learned preferences and context profiles.

## See Also

- `commands/pa/init.md` — Seeds the initial profile.
- `commands/pa/survey.md` — Refreshes stale or contradictory profile areas.
- `commands/pa/review.md` — Uses profile state during direction review.
- `skills/pa/interviewing/SKILL.md` — Produces the high-confidence signals that feed profile updates.
