---
title: Personal Profile
description: Human-readable rendering of `.pa/personal-profile.json` for year-plus direction review and profile inspection
---

# Personal Profile Template

PA commands use this template when rendering `.pa/personal-profile.json` into a human-readable summary for inspection, refresh, or year-plus direction review.
This template is read-only by default.
The JSON profile remains the machine-readable source of truth.
If the user wants changes, the caller should route them through interview confirmation or proposal-only enrichment rather than direct markdown editing.

## Rendering Rules

1. Lead with stable identity before current focus.
2. Render confirmed facts first and keep uncertain items visibly provisional.
3. Show `direction.long_term_direction` before any per-area breakdown so the profile reads as one arc instead of scattered goals.
4. Render `direction.directions_by_area` as a table sorted by the order of `identity.core_areas`, then alphabetically for extra keys.
5. Show `direction.paused_areas` explicitly instead of silently omitting them.
6. Render `identity.values_and_principles` as short bullets or a compact comma-separated list, not as long prose.
7. Keep `Identity Summary` and `Profile Metadata` present even when some fields are blank, and use `Not yet confirmed.` for required unresolved values instead of inventing detail.
8. Round all confidence values to the nearest `0.05`.
9. If `direction.last_direction_review` is missing or older than one year, show a short staleness note in `Profile Metadata`.
10. Omit optional sections according to the `Section Omission Rules` table instead of rendering repeated empty placeholders.
11. If this render is saved as a vault note, align the note title with `.pa/vault-profile.json -> naming_rules.note_title_style`.
12. If this render is saved as a vault note and `.pa/vault-profile.json -> frontmatter.enabled = true`, emit only caller-requested frontmatter fields and keep them aligned with `frontmatter.common_fields`.
13. If the caller includes note references, render them using the syntax implied by `.pa/vault-profile.json -> linking_style.prefer_wikilinks`.

## Output Format

```markdown
{{profile_frontmatter}}
# Personal Profile - {{profile_label}}

> Updated: {{updated}} | Last interview: {{last_interview}} | Mode: {{interview_mode_used}}

## Identity Summary

- Current roles: {{identity.current_roles}}
- Life stage: {{identity.life_stage}}
- Core areas: {{identity.core_areas}}
- Communication style: {{identity.communication_style}}
- Enrichment posture: {{identity.enrichment_posture}}

## Identity Patterns

{{identity_pattern_lines}}

## Direction Map

**Long-term direction**: {{direction.long_term_direction}}

| Area | Direction | Status |
|------|-----------|--------|
| {{direction_rows}} |

## Constraints & Fears

{{direction.constraints_and_fears}}

## Values & Principles

{{identity.values_and_principles}}

## Current Focus

- Active priorities: {{focus.current_focus}}
- Current commitments: {{focus.current_commitments}}
- Review cadence: {{focus.review_cadence}}

## Profile Metadata

| Field | Value |
|-------|-------|
| Overall confidence | {{confidence.overall}} |
| Identity confidence | {{confidence.identity}} |
| Direction confidence | {{confidence.direction}} |
| Focus confidence | {{confidence.focus}} |
| Last direction review | {{direction.last_direction_review}} |
| Created | {{created}} |
```

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `profile_frontmatter` | Render from `.pa/vault-profile.json -> frontmatter.enabled` and `frontmatter.common_fields` when the caller saves this as a note | Omit for inline preview |
| `profile_label` | Caller-supplied label, user name, or a saved-note title aligned with `.pa/vault-profile.json -> naming_rules.note_title_style` | `"Personal Profile"` |
| `updated` | `.pa/personal-profile.json -> updated` | Current render timestamp |
| `confidence.overall` | `.pa/personal-profile.json -> confidence.overall` | `0.0` |
| `last_interview` | `.pa/personal-profile.json -> last_interview` | `Never` |
| `interview_mode_used` | `.pa/personal-profile.json -> interview_mode_used` | `unknown` |
| `identity.current_roles` | `.pa/personal-profile.json -> identity.current_roles` | `Not yet confirmed.` |
| `identity.life_stage` | `.pa/personal-profile.json -> identity.life_stage` | `Not yet confirmed.` |
| `identity.core_areas` | `.pa/personal-profile.json -> identity.core_areas` | `Not yet confirmed.` |
| `identity.communication_style` | `.pa/personal-profile.json -> identity.communication_style` | `unknown` |
| `identity.enrichment_posture` | `.pa/personal-profile.json -> identity.enrichment_posture` | `standard` |
| `identity_pattern_lines` | Render non-empty lines from `.pa/personal-profile.json -> identity.patterns.*` in stable schema order | Omit the section |
| `direction.long_term_direction` | `.pa/personal-profile.json -> direction.long_term_direction` | `Not yet confirmed.` |
| `direction_rows` | Rendered from `.pa/personal-profile.json -> direction.directions_by_area` plus `direction.paused_areas` | One row with `General`, the long-term direction, and `active` when area rows are missing |
| `direction.constraints_and_fears` | `.pa/personal-profile.json -> direction.constraints_and_fears` | Omit the section |
| `identity.values_and_principles` | Render short bullets from `.pa/personal-profile.json -> identity.values_and_principles` | Omit the section |
| `focus.current_focus` | `.pa/personal-profile.json -> focus.current_focus` | `Not yet confirmed.` |
| `focus.current_commitments` | `.pa/personal-profile.json -> focus.current_commitments` | `Not yet confirmed.` |
| `focus.review_cadence` | `.pa/personal-profile.json -> focus.review_cadence` | `month` |
| `confidence.identity` | `.pa/personal-profile.json -> confidence.identity` | `confidence.overall` |
| `confidence.direction` | `.pa/personal-profile.json -> confidence.direction` | `confidence.overall` |
| `confidence.focus` | `.pa/personal-profile.json -> confidence.focus` | `confidence.overall` |
| `direction.last_direction_review` | `.pa/personal-profile.json -> direction.last_direction_review` | `Not yet reviewed.` |
| `created` | `.pa/personal-profile.json -> created` | `unknown` |

## Section Omission Rules

| Optional Section | Include When | Omit When |
|------------------|--------------|-----------|
| `Identity Patterns` | At least one field in `identity.patterns.*` is non-empty | All pattern fields are empty or blank |
| `Direction Map` | `direction.long_term_direction` is non-empty, `direction.directions_by_area` has at least one key, or `direction.paused_areas` is non-empty | All three direction signals are empty |
| `Constraints & Fears` | `direction.constraints_and_fears` has at least one confirmed item | The array is empty |
| `Values & Principles` | `identity.values_and_principles` has at least one confirmed item | The array is empty |
| `Current Focus` | `focus.current_focus` or `focus.current_commitments` has content, or `focus.review_cadence` was explicitly set away from the schema default | Both arrays are empty and cadence is only the default `month` |

## Section Notes

`Direction Map` should mark a row as `paused` when the area appears in `direction.paused_areas`.
`Direction Map` should mark a row as `active` otherwise.
When a core area lacks a per-area direction, render `Direction not yet confirmed.` for that row instead of leaving it blank.
`Identity Patterns` should render only the non-empty pattern lines in stable schema order.
`Constraints & Fears` should stay as short bullets, not a paragraph of interpretation.
If the caller saves this render as a note and `linking_style.prefer_wikilinks = false`, convert any note references to markdown links instead of wikilinks.

## Good Example

The example below shows a well-populated render with optional sections included only when they add signal.
Assume the caller is saving a note in a vault where `.pa/vault-profile.json -> frontmatter.enabled = true`.

```markdown
---
created: 2026-03-18T09:20:00Z
published: false
---

# Personal Profile - Mina Park

> Updated: 2026-03-18T09:20:00Z | Last interview: 2026-03-17T18:00:00Z | Mode: deep

## Identity Summary

- Current roles: founder, partner, parent
- Life stage: scaling a small company while protecting family rhythm
- Core areas: work, family, health, writing
- Communication style: direct, structured, low-fluff
- Enrichment posture: standard

## Identity Patterns

- Motivations: building durable tools, long-horizon mastery, calm competence
- Decision style: writes down options, sleeps on high-impact choices, then commits
- Energy sources: quiet mornings, long walks, shipping small increments
- Energy drains: context switching, overbooked calendars
- Active transitions: moving from hands-on operator work toward team stewardship

## Direction Map

**Long-term direction**: Build a calm and durable life that supports meaningful products, family presence, and physical health.

| Area | Direction | Status |
|------|-----------|--------|
| Work | Build a small high-trust software business with fewer parallel bets | active |
| Family | Protect dinner and weekend time as non-negotiable anchors | active |
| Health | Rebuild consistent strength and sleep routines before adding new stretch goals | active |
| Public writing | Publish one durable essay per month instead of scattered posts | paused |

## Constraints & Fears

- Overcommitting to interesting work and losing recovery time.
- Letting short-term client pressure crowd out long-term product direction.

## Values & Principles

- Calm over urgency.
- Depth over scattered activity.
- Keep promises visible.
- Build systems that reduce future friction.

## Current Focus

- Active priorities: ship v1, restore sleep, protect two deep-work mornings
- Current commitments: client delivery, weekly family planning, therapy, strength training
- Review cadence: month

## Profile Metadata

| Field | Value |
|-------|-------|
| Overall confidence | 0.75 |
| Identity confidence | 0.80 |
| Direction confidence | 0.75 |
| Focus confidence | 0.70 |
| Last direction review | 2026-03-01 |
| Created | 2026-02-10T08:00:00Z |
```

## Common Mistakes

| Mistake | Why It Fails | Prevention |
|---------|--------------|------------|
| Rendering values as long prose | It hides the user's actual principles inside summary language | Keep values short and close to the user's wording |
| Omitting paused areas | The profile looks more coherent than the user's real life | Render paused areas explicitly |
| Treating low confidence as missing detail to fill creatively | The template becomes fiction | Use `Not yet confirmed.` and keep the gap visible |
| Flattening per-area direction into one global goal | Different areas often move at different speeds | Keep the table and the long-term direction both visible |
| Leading with current focus instead of identity and direction | The review becomes operational instead of strategic | Keep the section order stable |

## Design Rationale

Why this template starts with identity and direction: year-plus review needs context before priorities.
Why `Direction Map` is separate from `Current Focus`: the user needs to see whether their present workload matches their intended path.
Why metadata stays visible: confidence and recency tell the reader how much to trust the profile.
Why the template is read-only by default: profile changes should pass through interview confirmation or explicit patch approval.

## Bias Mitigation

| Bias | Rendering Risk | Countermeasure |
|------|----------------|----------------|
| Coherence bias | The profile reads as a cleaner life than the user actually described | Keep paused areas, fears, and unconfirmed fields visible |
| Present bias | Current commitments overshadow long-term direction | Put `Direction Map` before `Current Focus` |
| Precision bias | Confidence looks more exact than the evidence supports | Round to `0.05` and keep missing sections explicit |
| Assistant framing bias | The template rewrites the user's wording into assistant jargon | Prefer short phrases close to confirmed source language |

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-profiling/SKILL.md` | Parent methodology - lifecycle, confidence, and gap detection |
| `skills/pa/personal-profiling/references/profile-schema.md` | Source schema for placeholders and field meanings |
| `skills/pa/interviewing/SKILL.md` | Upstream source of the interview evidence behind the profile |
| `commands/pa/review.md` | Likely renderer for year-plus direction checkpoints |
| `commands/pa/init.md` | Likely renderer for initial profile confirmation |
