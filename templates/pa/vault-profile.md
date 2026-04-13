---
title: Vault Profile
description: Human-readable rendering of vault-profile.json for user inspection and editing
---

# Vault Profile

> This document is rendered from `.pa/vault-profile.json`. If you edit this file directly, PA will detect changes on next invocation and update the JSON to match — **this markdown file wins on conflict**.

**Schema Version**: `{{version}}`
**Vault Root**: `{{vault_root}}`
**Generated**: {{generated_date}} *(ISO 8601 timestamp, set by the rendering command)*

---

## Render / Parse Contract

This markdown file is the authoritative editable mirror of `.pa/vault-profile.json`.
PA parses values from the visible tables and lines exactly as written in this document.
`archetype_scores.rank1.*`, `archetype_scores.rank2.*`, and `archetype_scores.rank3.*` are derived display slots, not persistent JSON keys.
For rendering, PA sorts `archetype_scores` by numeric score descending, breaks ties by archetype name ascending, and renders only the first three entries.
Scores outside the rendered top three are not round-tripped here, so edit `.pa/vault-profile.json` directly if you need to preserve more than three entries.
For parsing, PA rebuilds `archetype_scores` from the non-empty rows in the Top-3 table, converts `Score` cells to numbers, ignores fully blank rows, and treats partially blank rows as invalid until corrected.
For array fields (`Common fields`, `People fields`, `Theme fields`, `Location fields`), PA renders JSON arrays as comma-separated lists in source order and parses them back by splitting on commas, trimming whitespace, dropping empty items, and preserving the remaining order.
A blank array line parses as `[]`.
For typed scalar fields, keep explicit values such as `true`, `false`, integers, floats, and enum strings; blank scalar values are invalid input and should be filled before the next sync.

---

## Archetype

**Detected**: {{archetype}}
**Confidence**: {{archetype_confidence}}

Top-3 scores *(derived from `archetype_scores` using the contract above)*:

| Archetype | Score |
|-----------|-------|
| {{archetype_scores.rank1.name}} | {{archetype_scores.rank1.score}} |
| {{archetype_scores.rank2.name}} | {{archetype_scores.rank2.score}} |
| {{archetype_scores.rank3.name}} | {{archetype_scores.rank3.score}} |

**Automation Posture**: {{automation_posture}}

> Posture governs what PA may do without asking. `observe` = read-only analysis. `propose` = suggest changes, never apply. `apply-low-risk` = apply reversible, low-risk edits automatically. `operate` = full autonomy within trust boundaries.

---

## Navigation Style

| Setting | Value |
|---------|-------|
| Primary navigation | {{navigation_style.primary}} |
| Uses file explorer | {{navigation_style.uses_file_explorer}} |

---

## Placement Rules

Where PA puts new files, based on observed vault conventions.

| Role | Path |
|------|------|
| Authored notes root | `{{placement_rules.authored_root}}` |
| References | `{{placement_rules.references_dir}}` |
| Clippings / inbox | `{{placement_rules.clippings_dir}}` |
| Attachments | `{{placement_rules.attachments_dir}}` |
| Daily notes | `{{placement_rules.daily_dir}}` |
| Templates | `{{placement_rules.templates_dir}}` |
| Categories / hubs | `{{placement_rules.categories_dir}}` |
| Default new note parent | `{{placement_rules.default_new_note_parent}}` |
| Allow new subfolders | {{placement_rules.allow_new_subfolders}} |

---

## Naming Rules

| Setting | Value |
|---------|-------|
| Note title style | {{naming_rules.note_title_style}} |
| Daily note pattern | `{{naming_rules.daily_note_pattern}}` |
| Timestamp note pattern | `{{naming_rules.timestamp_note_pattern}}` |
| Unresolved link policy | {{naming_rules.unresolved_link_policy}} |

---

## Frontmatter

| Setting | Value |
|---------|-------|
| Enabled | {{frontmatter.enabled}} |
| Rating field | `{{frontmatter.rating_field}}` |
| Rating scale | {{frontmatter.rating_scale}} |

**Common fields**: {{frontmatter.common_fields}} *(JSON array → comma-separated list)*

**People fields**: {{frontmatter.people_fields}} *(JSON array → comma-separated list)*

**Theme fields**: {{frontmatter.theme_fields}} *(JSON array → comma-separated list)*

**Location fields**: {{frontmatter.location_fields}} *(JSON array → comma-separated list)*

---

## Journal Style

| Setting | Value |
|---------|-------|
| Mode | {{journal_style.mode}} |
| Daily note content | {{journal_style.daily_note_content}} |
| Compile cadence | {{journal_style.compile_cadence}} |
| Timestamp notes enabled | {{journal_style.timestamp_notes_enabled}} |

> `fractal` = dailies mostly link outward to timestamp/period notes. `traditional` = dailies contain the primary text. `none` = no journal habit detected.

---

## Linking Style

| Setting | Value |
|---------|-------|
| Prefer wikilinks | {{linking_style.prefer_wikilinks}} |
| Link density | {{linking_style.link_density}} |
| Create unresolved breadcrumbs | {{linking_style.create_unresolved_breadcrumbs}} |
| MOC preference | {{linking_style.moc_preference}} |
| Alias source | {{linking_style.alias_source}} |

---

## Writing Style

| Setting | Value |
|---------|-------|
| Tone | {{writing_style.tone}} |
| Prefers short notes | {{writing_style.prefers_short_notes}} |
| Evergreen bias | {{writing_style.evergreen_bias}} |

---

## Assistant Preferences

These control PA's behavior boundaries, independent of automation posture.

| Setting | Value | Effect |
|---------|-------|--------|
| Suggest before structure changes | {{assistant_preferences.suggest_before_structure_changes}} | PA asks before reorganizing folders or moving notes |
| Auto-create low-risk notes | {{assistant_preferences.auto_create_low_risk_notes}} | PA may create stub notes and captures without asking |
| Allow bulk relinking | {{assistant_preferences.allow_bulk_relinking}} | PA may update links across multiple notes at once |
| Allow stub creation | {{assistant_preferences.allow_stub_creation}} | PA may create placeholder notes for unresolved links |
| Citation requirement | {{assistant_preferences.citation_requirement}} | How strictly PA must cite source notes in generated content |

---

## QMD Defaults

Retrieval settings for context assembly via QMD.

| Setting | Value |
|---------|-------|
| Use MCP | {{qmd_defaults.use_mcp}} |
| CLI fallback | {{qmd_defaults.cli_fallback}} |
| Default retrieval k | {{qmd_defaults.default_retrieval_k}} |
| Max context docs | {{qmd_defaults.max_context_docs}} |

---

## Verification Checklist

Use this checklist when reviewing the rendered profile.

- [ ] The archetype matches the vault's actual shape
- [ ] The placement directories match current folder reality
- [ ] The naming rules match existing note titles
- [ ] The frontmatter fields reflect repeated real usage
- [ ] The journal settings match daily and timestamp behavior
- [ ] The linking defaults match the vault's linking habits
- [ ] The assistant preferences match the intended trust posture
- [ ] The QMD defaults look safe for current tooling

---

*To change any setting, edit this file directly. PA will detect the changes on next invocation and update `vault-profile.json` to match.*
