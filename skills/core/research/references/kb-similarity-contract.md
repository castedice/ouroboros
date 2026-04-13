---
description: Semantic similarity contract for knowledge base lookup in research workflows.
---

# KB Similarity Contract

Purpose: provide one stable semantic similarity interface for active KB integration and future novelty checks.

## Input

- Input is a single query text string.
- Consumers may pass a topic, URL, path, or synthesized findings summary.

## Corpus

- Scan `docs/specs/knowledge/*.md`.
- Ignore `INDEX.md`.
- For each entry, comparison text is `title + first paragraph`.
- Tags come from frontmatter `tags`.

## Scoring

- Score range is `0.0` to `1.0`.
- Score is a weighted blend of normalized term overlap and tag-term overlap.
- Default weights are `term_overlap=0.7` and `tag_overlap=0.3`.
- No external API, embedding, or model call is allowed.

## Outcomes

- `duplicate`: score `> 0.8`.
- `related`: score `>= 0.3` and `<= 0.8`.
- `none`: score `< 0.3`.
- `contradiction`: manual flag only, set by entry frontmatter `contradiction: true`.
- `contradiction` overrides score-based outcome labels.

## Output

- Canonical output is a JSON array.
- Each item is `{path, title, score, outcome, tags}`.
- Results are sorted by descending `score`.
- The helper returns entries above the requested threshold plus any manually flagged contradictions.
- Default threshold is `0.3`.
- Default limit is top `5`.

## Consumer Expectations

- Active KB integration should load `related` entries as prior context.
- Active KB integration should warn when any `duplicate` entry is returned.
- Novelty check should reuse the same score and outcome semantics rather than redefining thresholds.
