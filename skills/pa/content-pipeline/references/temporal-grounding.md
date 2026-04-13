# Temporal Grounding

> Purpose: Reference for `content-pipeline` and PA ingest triage — define how packets separate artifact time from real-world event time.

## Dual Timestamp Model

`document_date` is when the source artifact itself was created, published, or captured.
Typical sources are file mtime, page publish date, video publish date, or `fetch_date` when no better artifact date exists.
`event_date_start` and `event_date_end` describe when the source says the underlying real-world event happened.
Use the same date for both fields when the event is a single day.
Use bounded ranges when the source refers to a week, month, quarter, or year.
`event_date_precision` records the granularity of the event date as `day`, `week`, `month`, `quarter`, `year`, or `unknown`.
`temporal_confidence` records how confident the extraction is on a `0.0` to `1.0` scale.

## Core Rules

Prefer explicit artifact dates for `document_date`.
Prefer explicit event dates for `event_date_start` and `event_date_end`.
Back-calculate relative event references against `document_date`, not the current clock.
If a relative expression appears but `document_date` is unavailable, keep the phrase as a temporal hint and omit event-date fields.
If the source has no temporal signal at all, omit the event-date fields instead of guessing.
Readers must treat missing temporal fields as valid and ungrounded, not malformed.

## Confidence Rules

Explicit calendar dates or unambiguous timestamps should usually score `0.9` or higher.
Relative references grounded by a credible `document_date` should usually score between `0.5` and `0.8`.
Weak contextual guesses that are not anchored by explicit or relative phrasing should stay below `0.5` or be omitted entirely.
If multiple temporal interpretations remain plausible, lower confidence instead of forcing precision.

## Precision Rules

Use `day` when the source names a specific day or a single relative day such as `yesterday`.
Use `week` when the source says `last week`, `this week`, `next week`, or an equivalent week-sized period.
Use `month` when the source refers to a named month or phrases like `last month`.
Use `quarter` when the source refers to `Q1`, `this quarter`, `next quarter`, or equivalent fiscal phrasing.
Use `year` when only the year is recoverable.
Use `unknown` only when the source clearly points to an event time but the granularity cannot be narrowed safely.

## Supported Relative Expressions

Korean examples include `어제`, `그제`, `지난 주`, `지난 달`, `지난 해`, `이번 주`, `다음 주`, `N일 전`, and `N주 전`.
English examples include `yesterday`, `the day before yesterday`, `last week`, `last month`, `last year`, `this week`, `next week`, `N days ago`, and `N weeks ago`.

## Examples

| Source text | `document_date` | `event_date_start` | `event_date_end` | `event_date_precision` | `temporal_confidence` | Why |
|-------------|-----------------|--------------------|------------------|------------------------|-----------------------|-----|
| `Meeting on 2026-03-14 approved the rollout.` | `2026-03-21` | `2026-03-14` | `2026-03-14` | `day` | `0.95` | Explicit event date in text. |
| `지난 주 미팅에서 결정한 내용 정리.` with note created on `2026-03-21` | `2026-03-21` | `2026-03-09` | `2026-03-15` | `week` | `0.7` | Relative week back-calculated from the artifact date. |
| `어제 고객 통화에서 가격을 확정했다.` with capture on `2026-03-21` | `2026-03-21` | `2026-03-20` | `2026-03-20` | `day` | `0.75` | Relative single-day reference anchored by capture date. |
| `The roadmap review happened last month.` in a memo dated `2026-03-12` | `2026-03-12` | `2026-02-01` | `2026-02-28` | `month` | `0.65` | Relative month resolved to a bounded range. |
| `Interesting ideas for our launch.` | `2026-03-21` | omitted | omitted | omitted | omitted | No temporal signal in the content. |

## Practical Notes

For YouTube, `publish_date` usually maps cleanly to `document_date`, but the described event dates may still be absent.
For local files, file mtime is an acceptable `document_date` fallback when no better author or publish date exists.
For fetched web content with no visible publish date, use `fetch_date` as `document_date` and keep confidence conservative.

## Survey Backfill Advisory

During `/pa survey`, use this reference to estimate a count of scanned notes that have reliable artifact-date anchors but no grounded event-date fields yet.
Eligible anchors include frontmatter dates, publish dates, date-shaped filenames, and other scan-level signals that are strong enough to support conservative `document_date` backfill later.
Report only the count-level advisory and point to `scripts/pa-migrate.sh apply 2.4.0` as the future `document_date` backfill path.
Keep the advisory informational only.
Do not modify notes during survey, do not derive `event_date`, and do not imply that survey performs the backfill itself.
