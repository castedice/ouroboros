---
title: Timestamp Note
description: Quick capture template for short-form intake that adapts to vault-profile placement, title, and automation rules
---

# Timestamp Note Template

PA agents use this template when creating a short-form capture note for quick intake, low-confidence material, or mixed scraps that do not yet justify a more specific note type.
Every placeholder below is resolved from the user's `vault-profile.json` at render time.

## Rendering Rules

1. **Placement**: Resolve the parent directory in this order: `{{proven_timestamp_parent}}` -> daily-note family under `{{placement_rules.daily_dir}}` when `{{journal_style.timestamp_notes_enabled}}` is `true` and `{{journal_style.mode}}` is `fractal` or `traditional` -> `{{placement_rules.clippings_dir}}` -> `{{placement_rules.default_new_note_parent}}`.
   If the chosen parent does not exist and would require a new directory, treat that as a structure change and follow `{{assistant_preferences.suggest_before_structure_changes}}`.
2. **Title**: Format `{{note_title}}` by resolving `{{naming_rules.timestamp_note_pattern}}` against the current timestamp in the active vault timezone.
   Do not infer the title from the capture text.
3. **Frontmatter**: If `{{frontmatter.enabled}}` is `true`, emit only the ordered subset of `{{frontmatter.common_fields}}` limited to `created` and `tags`, plus optional `event_date` when the caller provides grounded event timing.
   Emit `created` from the current timestamp when present.
   Emit `tags` only when the caller provides tags and `tags` exists in `{{frontmatter.common_fields}}`.
   Emit `event_date` only when the curator or caller provides it.
   Do not emit `{{frontmatter.people_fields}}`, `{{frontmatter.theme_fields}}`, or `{{frontmatter.location_fields}}` by default.
   If the caller explicitly provides person, theme, or location metadata, emit only the matching profile-defined fields with resolved values.
   Omit fields without a resolved value.
   Omit the entire frontmatter block if `{{frontmatter.enabled}}` is `false`.
4. **Automation posture**: Check `{{automation_posture}}` (from `.pa/settings.json`).
   At `observe` or `propose`, render the note as a proposal (do not write to disk).
   At `apply-low-risk` or `operate`, write directly only if the note qualifies as **low-risk** - defined as: creating a single new file, no deletion or rename, no modification of existing notes, no structure change that still requires confirmation under `{{assistant_preferences.suggest_before_structure_changes}}`, and `{{assistant_preferences.auto_create_low_risk_notes}}` is `true`.
5. **Light structure**: Keep the note minimal.
   Always render `{{body}}`, and render `Tasks`, `Decisions`, `Questions`, and `Related` only when those sections have content.
   Do not add empty headings.
6. **Fallback use**: Use this template as the safe default when the intake is low-confidence, mixed, or not yet classifiable into a more specific template.
   Preserve raw signal and avoid over-normalizing the capture.
   If `{{naming_rules.unresolved_link_policy}}` is `discouraged` or `disabled`, prefer plain text over speculative unresolved links in `Related`.

## Output Format

The agent builds the output by resolving the target parent using the placement order above.
The title is the current timestamp formatted with `{{naming_rules.timestamp_note_pattern}}`.
If `{{frontmatter.enabled}}` is `true`, frontmatter is built from the ordered subset of `{{frontmatter.common_fields}}` limited to `created` and `tags`, plus optional `event_date` and any caller-provided people, theme, or location fields that match the active profile.
Each section placeholder below resolves either to a complete section block or to an empty string.
When `{{related_section}}` contains note references, render them as `[[wikilinks]]` when `{{linking_style.prefer_wikilinks}}` is `true`, otherwise as Markdown links.

```markdown
---
{{created_line}}
{{tags_line}}
{{event_date_line}}
{{optional_frontmatter_lines}}
---

# {{note_title}}

{{body}}

{{tasks_section}}
{{decisions_section}}
{{questions_section}}
{{related_section}}
```

**Example** (if `created`, `tags`, and `event_date` resolve, and only `Tasks` and `Related` have content):

```markdown
---
created: 2026-03-14T09:30:00+09:00
tags: [inbox, launch]
event_date: 2026-03-13
---

# 2026-03-14 0930

Capture from a quick hallway conversation about the release checklist.

## Tasks

- Confirm who owns the release notes.
- Verify staging sign-off before 17:00.

## Related

- [[Launch Plan]]
```

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `note_title` | Current timestamp formatted with `{{naming_rules.timestamp_note_pattern}}` | Required - do not infer from the body |
| `proven_timestamp_parent` | Proven timestamp capture parent from vault inference or caller override | Not set - continue to daily-family resolution |
| `naming_rules.timestamp_note_pattern` | `vault-profile.json` -> `naming_rules.timestamp_note_pattern` | `"YYYY-MM-DD HHmm"` |
| `frontmatter.enabled` | `vault-profile.json` -> `frontmatter.enabled` | `true` |
| `frontmatter.common_fields` | `vault-profile.json` -> `frontmatter.common_fields` | No common fields emitted |
| `frontmatter.people_fields` | `vault-profile.json` -> `frontmatter.people_fields` | No person-specific fields emitted |
| `frontmatter.theme_fields` | `vault-profile.json` -> `frontmatter.theme_fields` | No theme-specific fields emitted |
| `frontmatter.location_fields` | `vault-profile.json` -> `frontmatter.location_fields` | No location-specific fields emitted |
| `created_line` | Current timestamp mapped to `created` when `created` exists in `{{frontmatter.common_fields}}` | Omit |
| `tags_line` | Caller-provided or triage-derived tags when `tags` exists in `{{frontmatter.common_fields}}` | Omit |
| `event_date_line` | Curator-provided grounded event date rendered as `event_date: {value}` when available | Omit |
| `optional_frontmatter_lines` | Explicit caller-provided people, theme, or location metadata for matching profile-defined fields | Omit |
| `body` | Caller-provided capture text or distilled quick summary | Required |
| `tasks_section` | Caller-provided or triage-derived action items | Empty string |
| `decisions_section` | Caller-provided or triage-derived decisions | Empty string |
| `questions_section` | Caller-provided or triage-derived open questions | Empty string |
| `related_section` | Caller-provided related notes, URLs, or references rendered with the active link style | Empty string |
| `placement_rules.daily_dir` | `vault-profile.json` -> `placement_rules.daily_dir` | No daily-family fallback available |
| `placement_rules.clippings_dir` | `vault-profile.json` -> `placement_rules.clippings_dir` | `{{placement_rules.default_new_note_parent}}` |
| `placement_rules.default_new_note_parent` | `vault-profile.json` -> `placement_rules.default_new_note_parent` | `"."` (vault root) |
| `journal_style.mode` | `vault-profile.json` -> `journal_style.mode` | `"none"` |
| `journal_style.timestamp_notes_enabled` | `vault-profile.json` -> `journal_style.timestamp_notes_enabled` | `false` |
| `linking_style.prefer_wikilinks` | `vault-profile.json` -> `linking_style.prefer_wikilinks` | `true` |
| `naming_rules.unresolved_link_policy` | `vault-profile.json` -> `naming_rules.unresolved_link_policy` | `"allowed"` |
| `automation_posture` | `.pa/settings.json` -> `automation_posture` | `"propose"` |
| `assistant_preferences.suggest_before_structure_changes` | `vault-profile.json` -> `assistant_preferences.suggest_before_structure_changes` | `true` |
| `assistant_preferences.auto_create_low_risk_notes` | `vault-profile.json` -> `assistant_preferences.auto_create_low_risk_notes` | `false` |

## Usage by Agents

Agents reference this template when they need to capture short-form intake without forcing a stronger classification.
The agent is responsible for:

- Having `curator` produce a triage result with body text, tags, confidence, optional temporal grounding, and any optional `Tasks`, `Decisions`, `Questions`, or `Related` content
- Having `/pa capture` render this template from that triage result and the active vault profile
- Resolving placement using the timestamp-parent -> daily-family -> clippings -> default-parent order
- Checking `{{automation_posture}}` before writing
- Keeping the final note light by omitting empty sections and preserving ambiguous raw signal
