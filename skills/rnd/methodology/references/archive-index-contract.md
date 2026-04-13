# Archive Index Contract

This reference defines the shared archive index used for cross-study prior-work recall in the RnD workflow.
The archive index is a search surface, not a replacement for study artifacts, source reading, or probe evidence.

## Purpose

The archive index gives new studies a stable way to discover related completed studies before they commit budget to duplicate work.
The contract is intentionally shaped to remain compatible with `scripts/kb-similarity.sh`, which reads `.studies[]` entries and consumes `.path`, `.title`, `.tags`, and `.summary`.

## Top-Level Schema

The archive file lives at `.rnd/archive-index.json`.
The canonical schema version is `rnd-archive-index.v1`.

```json
{
  "schema_version": "rnd-archive-index.v1",
  "rebuilt_at": "2026-04-08T12:21:26Z",
  "studies": [
    {
      "study_id": "rnd-20260408-164202",
      "slug": "example-study-slug",
      "question": "What question did this study answer?",
      "title": "Human-readable study title",
      "path": "docs/research/2026/example-study-slug/report.md",
      "study_path": "docs/research/2026/example-study-slug",
      "tags": ["example", "terms"],
      "summary": "Composite search text assembled from the study artifacts.",
      "claims": ["claim-01", "claim-02"],
      "verdict": "release",
      "review_scores": {
        "C1": 2,
        "C2": 2,
        "C3": 2,
        "C4": 2,
        "C5": 2
      },
      "source_count": 20,
      "probe_count": 9,
      "completed_at": "2026-04-08T09:10:51Z",
      "year": "2026",
      "mode": "literature-only"
    }
  ]
}
```

## Entry Fields

Every entry in `.studies[]` represents one completed archive study.
The fields below define both the producer obligations and the consumer assumptions.

| Field | Required | Source of truth | Notes |
|------|----------|-----------------|-------|
| `study_id` | yes | `state.json.session_id`, else `brief.md` Study ID, else slug | Stable archive key used for append-or-replace updates |
| `slug` | yes | `state.json.slug`, else archive directory name | Human-readable study handle |
| `question` | yes | First non-empty line after `## Question` in `brief.md`, else `state.json.question`, else report metadata | Canonical problem statement for similarity search |
| `title` | yes | First `#` heading in `report.md`, else `question` | Consumer-facing label for search results |
| `path` | yes | `report.md` relative path | Required by `kb-similarity.sh` |
| `study_path` | yes | Archive directory relative path | Directory anchor for follow-up reads |
| `tags` | yes | Derived from `question` | Required by `kb-similarity.sh` |
| `summary` | yes | Composite artifact text | Required by `kb-similarity.sh` |
| `claims` | yes | Claim IDs from the `## Claims & Evidence Table` in `report.md` | Used for quick trace inspection |
| `verdict` | yes | First non-empty line after `## Release Verdict` in `review.md` | Review outcome such as `release` or `rework` |
| `review_scores` | yes | `C1` through `C5` rows in `review.md` | Integer score object keyed by criterion id |
| `source_count` | nullable | `state.json.final_summary.total_sources` | Null when no session state exists |
| `probe_count` | nullable | `state.json.final_summary.total_probes` | Null when no session state exists |
| `completed_at` | nullable | `state.json.completed_at` | Null when no session state exists |
| `year` | yes | `state.json.year`, else archive path segment | Used for sorting and archive inspection |
| `mode` | yes | `state.json.mode`, else first non-empty line after `## Mode` in `brief.md` | Preserves study mode boundary |

`path`, `title`, `tags`, and `summary` are the compatibility minimum for `scripts/kb-similarity.sh`.
The remaining fields are RnD-specific metadata layered on top of that compatibility surface.

## Tag Derivation

`tags` are derived from the study question rather than copied from report prose.
The producer lowercases the question, tokenizes on non-alphanumeric boundaries, drops short tokens and common stop words, deduplicates the result, and emits a stable array.
The goal is not semantic perfection.
The goal is a compact tag surface that improves term overlap for similarity search without changing the scoring contract in `kb-similarity.sh`.

## Summary Composition

`summary` is a composite string assembled from multiple artifact sections so similarity search has richer term coverage than a title alone.
The producer composes `summary` in this order:

1. The study question.
2. The first paragraph after `## Executive Summary` in `report.md`.
3. The claim statements from the `## Claims & Evidence Table` in `report.md`, using claim text only and not the rest of the table cells.
4. The `## Open Gaps` section from `prior-work-map.md` when present.
5. The `## Next Questions` section from `report.md`.

The composite text is normalized into plain search text by stripping markdown formatting, collapsing whitespace, and preserving the substantive words.
This summary is context for retrieval only.
It does not change the underlying evidentiary status of the study.

## Lifecycle Rules

Only completed studies are indexed.
When a matching `state.json` exists, the producer must require `run_status == "completed"` before indexing the study.
When no matching `state.json` exists, the producer may index the study from archive artifacts alone to support pre-v3.3.0 archives.

`build` performs a full rebuild of `.rnd/archive-index.json` from the archive directories under `docs/research/`.
`build` is idempotent.
If a rebuild would produce the same `.studies[]` payload, the file content and `rebuilt_at` must remain unchanged.

`update <session-id>` performs append-or-replace on one completed study.
If the `study_id` already exists, the entry is replaced in place.
If the `study_id` does not exist, the entry is appended.
`update` refreshes `rebuilt_at` because it is an explicit targeted write.

`search <query>` is a thin wrapper over `scripts/kb-similarity.sh` with corpus path `.rnd/archive-index.json`, threshold `0.3`, limit `5`, and JSON output.
Missing archive index means skip with an empty JSON array rather than a hard failure.

`status` reports the current study count, last rebuild time, and indexed slugs.
Missing archive index means report an empty status rather than a hard failure.

## Consumer Expectations

Phase 3 novelty check should query the archive index before probe planning and interpret scores using the existing similarity contract.
The score semantics remain unchanged from `kb-similarity.sh`.
`duplicate` means score `> 0.8`.
`related` means score `>= 0.3`.
`none` means score `< 0.3`.

Phase 5 prior-work reuse may load `related` and `duplicate` studies as contextual prior work for hypothesis shaping, gap discovery, contradiction checks, or study framing.
Consumers should use `study_path` to open the full artifact set after a search hit, not just the indexed summary.
Consumers should preserve the current study's scope, mode, and budget contract even when strong archive overlap exists.

## Reuse Discipline

Archive hits are context, not evidence.
A new study may borrow vocabulary, open questions, contradictions, or candidate probe directions from prior studies.
A new study may not treat archived claims as if they were freshly earned evidence in the current run.
Every material claim in the new study must still be backed by its own evidence chain through current sources, current probes, or explicit revalidation of archived artifacts.

Archive reuse should reduce duplicate search effort, not bypass methodological rigor.
When archived work appears directly reusable, the current study should cite that reuse explicitly in its own prior-work or limitations discussion.

## Backward Compatibility

Missing `.rnd/archive-index.json` means the consumer skips archive similarity and proceeds without failure.
An empty `.rnd/archive-index.json` means the consumer skips archive similarity and proceeds without failure.
Pre-v3.3.0 archives without `state.json` remain indexable from artifacts alone, but state-backed fields such as `source_count`, `probe_count`, and `completed_at` may be null.
The contract does not require retroactive migration of older studies before the index becomes useful.
