# Vault Profile Schema — Phase 1 Contract and Field Guide

> Purpose: Machine-readable contract for `vault-profile.json` — map observed vault behavior into a stable adapter for PA without inventing structure the vault does not actually use.

This reference is standalone and can be read without the parent skill.
For the inference workflow, see `skills/pa/vault-modeling/SKILL.md`.

## Phase 1 Scope

Phase 1 captures structural conventions that downstream commands need immediately: archetype, placement, naming, journaling, linking, writing bias, assistant defaults, and QMD retrieval defaults. It does not encode full semantic ontology, personal priorities, schedule data, or per-field confidence inside the schema.

Confidence, disputes, and alternative interpretations belong in the cartographer report or `.pa/` analysis notes, not in the schema object itself.

## Init vs Survey Interpretation

The schema block below doubles as a fresh-vault scaffold and an existing-vault adapter.
For `/pa init`, the defaults may be accepted or adjusted during onboarding.
For `/pa survey`, change a field only when repeated evidence supports it, and never create new folders or stronger automation just to satisfy the schema.

## Full Schema

Two representations exist:
- `vault-profile.json` — machine-readable, consumed by PA agents
- `vault-profile.md` — human-readable mirror, presented to user for review

Both are stored in `{vault}/.pa/` and kept in sync. User edits to `vault-profile.md` are the authoritative source when conflicts arise.

```yaml
version: 1
vault_root: "."
archetype: "flat-kepano | nested-project | para-like | journal-first | hybrid | custom"
archetype_scores: {}  # top-3 archetype scores for transparency
archetype_confidence: 0.0  # 0.0-1.0
automation_posture: "observe | propose | apply-low-risk | operate"

navigation_style:
  primary: "quick-switcher | backlinks-first | search-first | folder-first | hybrid"
  uses_file_explorer: false

placement_rules:
  authored_root: "."
  references_dir: "References"
  clippings_dir: "Clippings"
  attachments_dir: "Attachments"
  daily_dir: "Daily"
  templates_dir: "Templates"
  categories_dir: "Categories"
  default_new_note_parent: "."
  allow_new_subfolders: false

naming_rules:
  note_title_style: "concise-title"
  daily_note_pattern: "YYYY-MM-DD"
  timestamp_note_pattern: "YYYY-MM-DD HHmm"
  unresolved_link_policy: "allowed | discouraged | disabled"

frontmatter:
  enabled: true
  common_fields: ["created", "start", "end", "published"]
  people_fields: ["author", "director", "artist", "cast"]
  theme_fields: ["genre", "type", "topic"]
  location_fields: ["neighborhood", "city", "coordinates"]
  rating_field: "rating"
  rating_scale: "1-7"

journal_style:
  mode: "fractal | traditional | none"
  daily_note_content: "links-only | mixed | full-text"
  compile_cadence: "rolling | every-few-days | monthly | annual | custom"
  timestamp_notes_enabled: true

linking_style:
  prefer_wikilinks: true
  link_density: "low | medium | high"
  create_unresolved_breadcrumbs: true
  moc_preference: "none | light | strong"
  alias_source: "frontmatter | inline | both"

writing_style:
  tone: "concise"
  prefers_short_notes: true
  evergreen_bias: "low | medium | high"

assistant_preferences:
  suggest_before_structure_changes: true
  auto_create_low_risk_notes: false
  allow_bulk_relinking: false
  allow_stub_creation: true
  citation_requirement: "strict | normal | relaxed"

qmd_defaults:
  use_mcp: true
  cli_fallback: true
  default_retrieval_k: 12
  max_context_docs: 6
```

## Population Rules

| Rule | Why It Exists |
|---|---|
| Keep the object shape stable across vaults. | downstream commands can rely on a fixed contract |
| Only deviate from default values when the vault shows repeated evidence. | avoids importing assistant preferences into user workflow |
| When a role folder is absent or ambiguous, use the safest existing parent rather than inventing a new hierarchy. | protects existing vault layout |
| Keep confidence and alternative hypotheses out of the schema. | Phase 1 schema is a control contract, not an audit record |
| When markdown and schema disagree later, reprofile or ask the user instead of rewriting notes to fit the profile. | markdown remains source of truth |

## Field Guide

### Top-Level Fields

| Field | Type | Default | Phase | Description |
|-------|------|---------|-------|-------------|
| `version` | integer | `1` | P1 | Schema version for forward compatibility |
| `vault_root` | string | `"."` | P1 | Vault root relative to profile location |
| `archetype` | string | — | P1 | Inferred vault archetype (see archetype-heuristics.md) |
| `archetype_scores` | object | — | P1 | Confidence scores for top-3 archetypes. Transparency field |
| `archetype_confidence` | float | — | P1 | Confidence of the assigned archetype label (0.0-1.0) |
| `automation_posture` | string | Varies | P1 | Current trust level (see trust-and-boundaries skill) |

`automation_posture` normally starts at `propose` for `/pa survey`. It may start at `apply-low-risk` for `/pa init` only after the user accepts the starter setup. Treat as a user or settings decision, not something inferred from folder shape alone.

### `navigation_style`

| Field | Meaning | Evidence | Conservative Fallback |
|---|---|---|---|
| `primary` | main discovery mode the vault appears to reward | folder depth, title style, link behavior, daily-note centrality | `hybrid` when two modes coexist |
| `uses_file_explorer` | whether folder browsing appears structurally important | stable folder roles, deep project trees, explicit folder naming discipline | `false` unless repeated folder-first behavior is visible |

### `placement_rules`

| Field | Meaning | Evidence | Conservative Behavior |
|---|---|---|---|
| `authored_root` | safest parent for generic authored notes | repeated placement of normal notes | use `"."` when no better root exists |
| `references_dir` | durable reference or source-note location | proven reference folder | point to an existing reference-like location or fall back to authored root |
| `clippings_dir` | raw imports, clippings, or inbox captures | repeated capture dump location | keep captures near their current proven home |
| `attachments_dir` | binary and media storage | file-type concentration | reuse an existing asset folder instead of inventing one |
| `daily_dir` | daily-note home | repeated daily-note placement | use authored root when no daily system exists |
| `templates_dir` | template storage | placeholder notes and reuse patterns | reuse only a proven template folder |
| `categories_dir` | taxonomy or category hub location | repeated category or hub folders | use authored root when categories are not an established convention |
| `default_new_note_parent` | default parent for generic note creation | precedent for new authored notes | keep equal to `authored_root` unless a stronger pattern exists |
| `allow_new_subfolders` | whether PA may create new subfolders autonomously | stable nested structure plus explicit trust preference | keep `false` by default |

The scaffold names in the schema block are safe starter defaults for `/pa init`. They are not a mandate to create missing folders during `/pa survey`.

### `naming_rules`

| Field | Meaning | Evidence | Conservative Fallback |
|---|---|---|---|
| `note_title_style` | dominant authored-title style | concise atomic titles, descriptive project titles, or other stable naming behavior | keep `concise-title` only when titles are consistently short and direct |
| `daily_note_pattern` | canonical daily-note title format | repeated date naming and placement | use the strongest proven pattern only |
| `timestamp_note_pattern` | canonical timestamp-capture format | minute-granularity note titles | keep conservative when timestamp notes are rare |
| `unresolved_link_policy` | how the vault treats unresolved links | presence and tolerance of unresolved links, template placeholders | prefer `discouraged` unless unresolved links are clearly part of the workflow |

### `frontmatter`

| Field | Meaning | Phase 1 Guidance |
|---|---|---|
| `enabled` | whether structured YAML frontmatter is a real convention | set `true` only when frontmatter appears repeatedly and parseably |
| `common_fields` | frequently reused general metadata fields | populate from fields present in at least 15% of sampled notes and at least 5 notes |
| `people_fields` | repeated person-related metadata | include only semantically stable person fields |
| `theme_fields` | repeated theme or classification metadata | keep short when multiple competing taxonomies exist |
| `location_fields` | repeated place-related metadata | use only fields with consistent geographic meaning |
| `rating_field` | dominant rating key | set only when one field clearly wins |
| `rating_scale` | dominant rating scale | infer only when the values are consistent enough to justify it |

### `journal_style`

| Field | Meaning | Evidence | Conservative Fallback |
|---|---|---|---|
| `mode` | journal operating mode | daily-note structure, timestamp captures, period compilation | `none` unless a journal habit clearly exists |
| `daily_note_content` | what usually lives inside daily notes | link hubs, mixed logs, or full narrative text | choose the dominant observed style |
| `compile_cadence` | whether short notes roll up into longer period notes | weekly, monthly, annual, rolling, or custom compilation notes | `custom` only when cadence is real but nonstandard |
| `timestamp_notes_enabled` | whether timestamp captures are an active pattern | repeated minute-granularity note titles | `false` when evidence is weak |

Use `fractal` when dailies mostly point outward to timestamp notes or period notes. Use `traditional` when dailies themselves contain the primary text.

### `linking_style`

| Field | Meaning | Evidence | Conservative Fallback |
|---|---|---|---|
| `prefer_wikilinks` | dominant internal-link syntax | note bodies and link formatting | follow whichever syntax clearly dominates |
| `link_density` | approximate internal-link intensity | median links per prose note | `medium` only when data is limited but not absent |
| `create_unresolved_breadcrumbs` | whether unresolved links appear to be a tolerated drafting tactic | repeated unresolved links or placeholder habits | `false` when unresolved links are rare |
| `moc_preference` | strength of map-of-content usage | recurring hub notes and organizational maps | `none` unless MOCs recur meaningfully |
| `alias_source` | where note aliases are typically expressed | frontmatter aliases, inline alias syntax, or both | choose the dominant proven source |

### `writing_style` [P2+]

| Field | Meaning | Phase 1 Guidance |
|---|---|---|
| `tone` | broad writing tone expectation | keep conservative and descriptive rather than literary |
| `prefers_short_notes` | whether shorter notes dominate the authored corpus | infer from recurring note length and capture style |
| `evergreen_bias` | how strongly notes appear optimized for durable reuse | estimate from title style, link reuse, and note abstraction |

These fields are soft defaults for future drafting. Do not over-interpret them from a sparse or mixed vault.

### `assistant_preferences`

| Field | Meaning | Phase 1 Guidance |
|---|---|---|
| `suggest_before_structure_changes` | whether PA should ask before reorganizing structure | keep `true` unless the user explicitly grants broader autonomy |
| `auto_create_low_risk_notes` | whether PA may create low-risk notes automatically | align with trust posture and explicit consent |
| `allow_bulk_relinking` | whether bulk relinking is ever preapproved | keep `false` in Phase 1 |
| `allow_stub_creation` | whether placeholder notes are acceptable | infer from unresolved-link habits and note-creation norms |
| `citation_requirement` | how strictly PA should cite source notes | default to `strict` for inherited vaults, relax only with user direction |

### `qmd_defaults`

| Field | Meaning | Phase 1 Guidance |
|---|---|---|
| `use_mcp` | whether MCP-backed QMD is the preferred path | keep aligned with environment capability |
| `cli_fallback` | whether CLI fallback is acceptable | keep `true` unless the environment forbids it |
| `default_retrieval_k` | baseline retrieval breadth | start at `12` |
| `max_context_docs` | maximum documents in one assembled context pack | start at `6` |

These are operational defaults, not structural facts about the vault.

## Phase 1 Scope Summary

Phase 1 (vault-modeling + init/survey) populates these sections fully:
- Root fields (version, vault_root, archetype, archetype_scores, archetype_confidence, automation_posture)
- navigation_style
- placement_rules
- naming_rules
- frontmatter
- journal_style (except compile_cadence)
- linking_style (prefer_wikilinks, link_density only)
- assistant_preferences (suggest_before_structure_changes, auto_create_low_risk_notes, citation_requirement)
- qmd_defaults

Fields marked **[P2+]** receive default values in Phase 1 and are refined when their respective phases activate.

## Out-of-Band Evidence

Keep the following outside the schema:
- per-field confidence scores
- rejected alternatives such as `journal-first` versus `hybrid`
- sampling notes and exclusions
- open questions for the user

A companion cartographer report should explain why the profile is safe to use and where it is still uncertain.

## Versioning

The `version` field enables forward-compatible schema evolution. When the schema changes:
1. Increment `version`
2. New fields get defaults (existing profiles remain valid)
3. Removed fields are ignored (no breaking change)
4. PA agents check `version` and handle missing fields with defaults
