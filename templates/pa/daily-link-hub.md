---
title: Daily Link Hub
description: Link-only daily note template for Fractal Journaling vaults that indexes today's timestamp captures and optional highlights
---

# Daily Link Hub Template

PA commands use this template when a Fractal Journaling vault treats the daily note as a lightweight index of same-day timestamp captures.
The daily note is a hub, not the primary place for full-text journaling.

## Rendering Rules

1. **Placement**: Save or update the note at `{{placement_rules.daily_dir}}/{{note_title}}.md`.
   If `{{placement_rules.daily_dir}}` is not set, does not exist, or would require creating a new directory, treat that as a structure change and follow `{{assistant_preferences.suggest_before_structure_changes}}`.
2. **Title**: Format `{{note_title}}` as the current local date in `YYYY-MM-DD`.
   Do not add subtitles, weekday suffixes, or descriptive text.
3. **Frontmatter**: If `{{frontmatter.enabled}}` is `true`, emit only the ordered subset of `{{frontmatter.common_fields}}` limited to `created` and `tags`.
   On create, emit `created` from the current timestamp when present.
   On update, preserve the existing `created` value when already present.
   Emit `tags` only when the caller provides tags and `tags` exists in `{{frontmatter.common_fields}}`.
   Omit fields without a resolved value.
   Omit the entire frontmatter block when `{{frontmatter.enabled}}` is `false` or no frontmatter fields resolve.
4. **Link collection**: Build `{{timestamp_links}}` by collecting timestamp notes whose titles resolve to the same local date as `{{note_title}}` under the active vault's timestamp-note family.
   Match titles using `{{naming_rules.timestamp_note_pattern}}`, sort the results ascending by timestamp, and render one link per line.
   When `{{linking_style.prefer_wikilinks}}` is `true`, render note links as `[[wikilinks]]`, otherwise render Markdown links.
   If no same-day timestamp notes exist, render `- No timestamp captures yet.`
5. **Highlights**: Render `{{highlights_section}}` only when the caller provides highlights or when an existing highlights block is being preserved during update.
   Keep highlights short and selective.
   Do not duplicate the full body text of timestamp notes inside this section.
6. **Fractal Journaling posture**: Use this template only when the vault's daily-note practice is link-first.
   Treat the daily note as an index of timestamp captures, not as a narrative daily log.
   Do not add long-form prose, meeting transcripts, or full capture bodies to the daily note.
7. **Automation posture**: Check `{{automation_posture}}` from `.pa/settings.json` before writing.
   At `observe` or `propose`, render the daily hub as a proposal and do not write to disk.
   At `apply-low-risk` or `operate`, write directly only when the action is low-risk: creating today's daily hub if missing, or updating only the managed `Links` section with same-day timestamp links, with no deletion, rename, structure change that still requires confirmation, or rewrite of existing prose, and `{{assistant_preferences.auto_create_low_risk_notes}}` is `true`.

## Output Format

The agent builds or refreshes the daily note at `{{placement_rules.daily_dir}}/{{note_title}}.md`.
The title is the current local date in `YYYY-MM-DD`.
If `{{frontmatter.enabled}}` is `true`, frontmatter is built from the ordered subset of `{{frontmatter.common_fields}}` limited to `created` and `tags`.
`{{timestamp_links}}` always resolves to a complete bullet list or to the fallback line `- No timestamp captures yet.`
`{{highlights_section}}` resolves either to a complete `Highlights` block or to an empty string.

    ---
    {{created_line}}
    {{tags_line}}
    ---

    # {{note_title}}

    ## Links

    {{timestamp_links}}

    {{highlights_section}}

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `note_title` | Current local date formatted as `YYYY-MM-DD` | Required |
| `frontmatter.enabled` | `vault-profile.json` -> `frontmatter.enabled` | `true` |
| `frontmatter.common_fields` | `vault-profile.json` -> `frontmatter.common_fields` | No common fields emitted |
| `created_line` | Existing `created` value on update, otherwise current timestamp when `created` exists in `{{frontmatter.common_fields}}` | Omit |
| `tags_line` | Caller-provided tags when `tags` exists in `{{frontmatter.common_fields}}` | Omit |
| `timestamp_links` | Same-day timestamp notes collected with `{{naming_rules.timestamp_note_pattern}}` and rendered with the active link style | `- No timestamp captures yet.` |
| `highlights_section` | Caller-provided highlights or preserved existing highlights block | Empty string |
| `placement_rules.daily_dir` | `vault-profile.json` -> `placement_rules.daily_dir` | Required for this template - otherwise stop at proposal mode |
| `naming_rules.timestamp_note_pattern` | `vault-profile.json` -> `naming_rules.timestamp_note_pattern` | `"YYYY-MM-DD HHmm"` |
| `linking_style.prefer_wikilinks` | `vault-profile.json` -> `linking_style.prefer_wikilinks` | `true` |
| `journal_style.mode` | `vault-profile.json` -> `journal_style.mode` | `"none"` |
| `journal_style.daily_note_content` | `vault-profile.json` -> `journal_style.daily_note_content` | Not set - do not assume link-only daily notes |
| `automation_posture` | `.pa/settings.json` -> `automation_posture` | `"propose"` |
| `assistant_preferences.suggest_before_structure_changes` | `vault-profile.json` -> `assistant_preferences.suggest_before_structure_changes` | `true` |
| `assistant_preferences.auto_create_low_risk_notes` | `vault-profile.json` -> `assistant_preferences.auto_create_low_risk_notes` | `false` |

## Usage by Commands

Commands reference this template when a Fractal Journaling vault uses daily notes as link hubs.
The calling command (`/pa day`) is responsible for:

- Resolving today's daily note path under `{{placement_rules.daily_dir}}`
- Creating the note when missing or updating the managed `Links` section when it already exists
- Collecting same-day timestamp notes with the active timestamp naming rule and rendering them in chronological order
- Preserving the link-only daily-note posture instead of turning the hub into a full-text journal
- Preserving or inserting `Highlights` only when content exists
- Checking `{{automation_posture}}` before writing
