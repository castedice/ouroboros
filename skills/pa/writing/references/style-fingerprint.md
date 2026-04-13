# Style Fingerprint — Dimension Definitions and Analysis Rules

> Purpose: Reference for `writing` skill — lookup table for style fingerprint dimensions, thresholds, and analysis methodology. This reference is standalone and can be consulted without the parent skill. For the end-to-end writing procedure, see `skills/pa/writing/SKILL.md`.

## Scope

This reference covers the 8 fingerprint dimensions used to analyze vault note exemplars, the agreement thresholds that determine whether a dimension enters the fingerprint, and the analysis methodology for extracting values from notes.

## Fingerprint Dimensions

| Dimension | What to Observe | Example Values | How to Measure |
|-----------|-----------------|----------------|----------------|
| Title shape | Capitalization and phrasing of note titles | concise-noun, sentence-case, kebab-case, question-form | Compare title formatting across 3+ notes in the target context |
| Heading depth | Deepest heading level used structurally | h1-only, h1+h2, deep (h1-h4) | Count heading levels in each exemplar; take the mode |
| Bullet/prose ratio | Proportion of content in lists vs. paragraphs | bullet-heavy (>70%), prose-heavy (>70%), mixed | Estimate list lines vs. paragraph lines across exemplars |
| Task syntax | Checkbox style and indentation pattern | `- [ ]` flat, nested with indentation, no tasks | Check if tasks exist; if so, note the format used |
| Link syntax | Internal link format and alias usage | wikilinks bare, wikilinks aliased, markdown links | Count link styles in each exemplar; take the dominant form |
| Callout usage | Presence and style of callout/admonition blocks | none, occasional, structural | Check for `> [!type]` patterns across exemplars |
| Sentence compression | Typical sentence length and density | terse (avg <12 words), standard (12-25), expanded (avg >25 words) | Sample 5-10 sentences per exemplar; estimate average length |
| Frontmatter density | Number and type of frontmatter fields | minimal (0-2 fields), moderate (3-5), rich (6+) | Count YAML fields in each exemplar's frontmatter block |

## Agreement Thresholds

| Condition | Rule |
|-----------|------|
| 2+ exemplars agree on a dimension value | Dimension enters the fingerprint — apply it to the draft |
| Exemplars disagree (no majority) | Dimension is unconstrained — use vault-profile default |
| Only 1 exemplar available | No dimension can be confirmed — all remain unconstrained |
| < 3 dimensions confirmed total | Mark fingerprint as sparse — lower confidence to `low` |

## Analysis Methodology

1. For each exemplar note, extract values for all 8 dimensions.
2. Create a tally: for each dimension, count how many exemplars share the same value.
3. A value is confirmed when its count reaches 2 or more.
4. When two values tie (e.g., 2 notes use h1-only, 2 use h1+h2), leave the dimension unconstrained.
5. Record confirmed dimensions with their values and agreement counts.
6. The fingerprint is the set of confirmed dimensions — it defines the style contract for the draft.

## Edge Cases

| Situation | Handling |
|-----------|----------|
| Exemplar has no frontmatter | Score `frontmatter_density` as `none` (0 fields) for that exemplar |
| Exemplar is very short (< 50 words) | Extract what dimensions are observable; skip dimensions that need more content |
| Exemplar uses mixed link syntax | Score the dominant syntax (> 60% of links) |
| Exemplar contains generated/template content | Exclude from fingerprint analysis — templates are not authored style |
