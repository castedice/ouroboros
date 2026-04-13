---
title: Profiled Note
description: Generic note template that adapts to vault-profile placement, frontmatter, and naming conventions
---

# Profiled Note Template

PA agents use this template when creating a new note that is not covered by a more specific template (daily, timestamp, dossier, etc.).
Every placeholder below is resolved from the user's `vault-profile.json` at render time.

## Rendering Rules

1. **Placement**: Save to `{{placement_rules.default_new_note_parent}}/{{note_title}}.md`. If `{{placement_rules.allow_new_subfolders}}` is `false`, never create intermediate directories.
2. **Structure changes**: If the resolved target path requires creating a directory that does not already exist or places the note outside `{{placement_rules.default_new_note_parent}}`, treat that as a structure change. When `{{assistant_preferences.suggest_before_structure_changes}}` is `true`, stop at a proposal and ask before writing. When `{{assistant_preferences.suggest_before_structure_changes}}` is `false`, proceed only if `{{placement_rules.allow_new_subfolders}}` is `true` and the active automation posture permits a direct write.
3. **Title**: Format according to `{{naming_rules.note_title_style}}`. Do not invent a style the vault does not use.
4. **Frontmatter**: If `{{frontmatter.enabled}}` is `true`, build the frontmatter from the ordered union of `{{frontmatter.common_fields}}`, `{{frontmatter.people_fields}}`, `{{frontmatter.theme_fields}}`, and `{{frontmatter.location_fields}}`. Emit duplicate field names only once at first occurrence. Omit fields without a resolved value. Omit the entire frontmatter block if `{{frontmatter.enabled}}` is `false`.
5. **Links**: Use `[[wikilinks]]` when `{{linking_style.prefer_wikilinks}}` is `true`, otherwise `[text](relative-path.md)`.
6. **Automation posture**: Check `{{automation_posture}}` (from `.pa/settings.json`). At `observe` or `propose`, render the note as a proposal (do not write to disk). At `apply-low-risk` or `operate`, write directly only if the note qualifies as **low-risk** — defined as: creating a single new file, no deletion or rename, no modification of existing notes, no structure change that still requires confirmation under `{{assistant_preferences.suggest_before_structure_changes}}`, and `{{assistant_preferences.auto_create_low_risk_notes}}` is `true`.
7. **Stub policy**: Only create a stub (empty body) if `{{assistant_preferences.allow_stub_creation}}` is `true`. Otherwise, require caller-provided body content.
8. **Unresolved links**: Follow `{{naming_rules.unresolved_link_policy}}` — if `discouraged` or `disabled`, avoid creating wikilinks to notes that do not exist.

## Output Format

The agent builds the output by iterating over the ordered union of the profile's `{{frontmatter.common_fields}}`, `{{frontmatter.people_fields}}`, `{{frontmatter.theme_fields}}`, and `{{frontmatter.location_fields}}` arrays.
Each entry is a field name (string).
Duplicate field names are emitted once at first occurrence.
The agent looks up the appropriate value for that field from the caller context (e.g., `created` → current date, `author` → caller-provided people metadata, `genre` → caller-provided theme metadata, `city` → caller-provided location metadata).
Fields without a value are omitted.

```markdown
---
{{profile_field_1}}: {{resolved_value_1}}
{{profile_field_2}}: {{resolved_value_2}}
---

# {{note_title}}

{{body}}
```

**Example** (if the combined frontmatter arrays resolve to `["created", "tags", "author", "genre", "city"]`):

```markdown
---
created: 2026-03-14
tags: [meeting, project-alpha]
author: Kim
genre: planning
city: Seoul
---

# Meeting Notes — Alpha Review

Discussion points from today's review.
```

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `note_title` | Caller-provided or inferred from context | Required — do not generate without a title |
| `naming_rules.note_title_style` | `vault-profile.json` → `naming_rules.note_title_style` | `"concise-title"` |
| `frontmatter.enabled` | `vault-profile.json` → `frontmatter.enabled` | `true` |
| `frontmatter.common_fields` | `vault-profile.json` → `frontmatter.common_fields` | No common fields emitted |
| `frontmatter.people_fields` | `vault-profile.json` → `frontmatter.people_fields` | No person-specific fields emitted |
| `frontmatter.theme_fields` | `vault-profile.json` → `frontmatter.theme_fields` | No theme-specific fields emitted |
| `frontmatter.location_fields` | `vault-profile.json` → `frontmatter.location_fields` | No location-specific fields emitted |
| `body` | Caller-provided content | Empty — the note is a stub if `{{assistant_preferences.allow_stub_creation}}` is `true`, otherwise required |
| `placement_rules.default_new_note_parent` | `vault-profile.json` → `placement_rules.default_new_note_parent` | `"."` (vault root) |
| `placement_rules.allow_new_subfolders` | `vault-profile.json` → `placement_rules.allow_new_subfolders` | `false` |
| `linking_style.prefer_wikilinks` | `vault-profile.json` → `linking_style.prefer_wikilinks` | `true` |
| `naming_rules.unresolved_link_policy` | `vault-profile.json` → `naming_rules.unresolved_link_policy` | `"allowed"` |
| `automation_posture` | `.pa/settings.json` → `automation_posture` | `"propose"` |
| `assistant_preferences.suggest_before_structure_changes` | `vault-profile.json` → `assistant_preferences.suggest_before_structure_changes` | `true` |
| `assistant_preferences.allow_stub_creation` | `vault-profile.json` → `assistant_preferences.allow_stub_creation` | `true` |
| `assistant_preferences.auto_create_low_risk_notes` | `vault-profile.json` → `assistant_preferences.auto_create_low_risk_notes` | `false` |

## Usage by Agents

Agents reference this template when they need to create a generic note.
The agent is responsible for:

- Resolving all placeholders from the active vault profile
- Combining `{{frontmatter.common_fields}}`, `{{frontmatter.people_fields}}`, `{{frontmatter.theme_fields}}`, and `{{frontmatter.location_fields}}` before frontmatter emission
- Checking `{{automation_posture}}` before writing
- Respecting `{{assistant_preferences.suggest_before_structure_changes}}` by switching to proposal mode before any new-folder or out-of-profile placement change
