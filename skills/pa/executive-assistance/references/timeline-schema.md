# Timeline Schema — Temporal Overlay for Executive Assistance

> Purpose: Reference for `executive-assistance` skill — defines the JSONL schema for `{vault}/.pa/timeline.jsonl`.
> This reference is standalone.
> For prioritization and agenda behavior, see `skills/pa/executive-assistance/SKILL.md`.

## Scope

This reference defines the schema, extraction rules, and integrity rules for the PA timeline overlay.
The timeline records temporal items extracted from the vault, including dated notes, milestones, recurring anchors, and explicit event references.

## File Location

`{vault}/.pa/timeline.jsonl` — one JSON object per line.

## Schema

Each line is a JSON object with these fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Stable identifier for the timeline item |
| `kind` | string | yes | `event`, `milestone`, `recurring`, or `note-date` |
| `title` | string | yes | Human-readable label for the item |
| `date` | string (ISO date) | yes | Primary event date in `YYYY-MM-DD` form. For `note-date`, this is the note's anchored day |
| `end_date` | string (ISO date) | no | Event end date for multi-day spans |
| `document_date` | string (ISO date) | no | Artifact date for the supporting note when it differs from the event date |
| `recurrence` | string or null | yes | `daily`, `weekly`, `monthly`, `annual`, or `null` |
| `source_docs` | string[] | yes | Vault note paths that support the extraction |
| `confidence` | number | yes | Extraction confidence from `0.0` to `1.0` |
| `extracted_at` | string (ISO 8601) | yes | Timestamp when the item was last extracted |

## Kind Semantics

| Kind | Meaning |
|------|---------|
| `event` | A dated occurrence such as a meeting, trip, appointment, or scheduled activity |
| `milestone` | A deadline, target date, launch, review, or delivery checkpoint |
| `recurring` | A repeating anchor such as weekly review, monthly close, or annual renewal |
| `note-date` | A note whose filename or frontmatter establishes a meaningful date anchor even when no discrete event is stated |

## Temporal Semantics

`date` and `end_date` represent when the underlying real-world event happened.
`document_date` represents when the supporting artifact note was created, published, or captured.
For `note-date` items, `date` and `document_date` may legitimately match.
For `event`, `milestone`, and `recurring` items, keep `date` / `end_date` as event-time fields and store note-time separately in `document_date` when known.

## Extraction Rules

Timeline items are extracted conservatively.
Prefer missing a weak candidate over inventing a false commitment.

### 1. Frontmatter Dates

Create timeline items from frontmatter when a note contains date-bearing fields such as `date`, `start`, `end`, `due`, `deadline`, `scheduled`, `published`, or other proven vault date fields.

Use these rules:
- Emit `milestone` when the field or nearby title implies a target, deadline, launch, release, submission, or review.
- Emit `event` when the field or nearby title implies a meeting, appointment, visit, trip, or scheduled occurrence.
- Emit `note-date` when the note is primarily date-stamped rather than event-like.
- Set `end_date` only when the note explicitly defines a span.
- Preserve the note's own artifact date as `document_date` when a reliable create, publish, or capture date is known and it differs from the extracted event date.
- Set `recurrence` only when the note explicitly expresses a repeating cadence.

### 2. Date-Named Files

Create `note-date` items from files whose note title or path matches a proven vault date pattern.

Examples include:
- Daily notes such as `2026-03-16.md`.
- Timestamp notes whose title begins with a calendar date.
- Journal or period notes whose filename clearly anchors them to a day, month, or year.

Use the normalized calendar date as `date`.
Set `document_date` to the same normalized value for `note-date` items unless a stronger artifact-date signal disagrees.
Do not invent recurrence from date-shaped filenames alone.

### 3. Explicit Date Mentions in Note Body

Scan note bodies for explicit date mentions in headings, bullets, task lines, or prose.
Extract only when the date can be normalized confidently.

Use these rules:
- Emit `milestone` when date mentions appear with cues such as `due`, `deadline`, `ship`, `launch`, `submit`, `target`, or `review`.
- Emit `event` when date mentions appear with cues such as `meeting`, `call`, `appointment`, `travel`, `visit`, or `session`.
- Emit `recurring` when a title or clause pairs a repeatable anchor with a cadence such as `every week`, `monthly`, `annual`, or `each Friday`.
- If a note mentions multiple dates for the same item, use the earliest start-like date as `date` and the explicit finishing date as `end_date`.
- If a relative date such as `next Friday` appears, resolve it only when the source note has a trustworthy anchor date from frontmatter, filename, or `document_date`.
- Preserve the source note's artifact date as `document_date` when it is known independently of the event date.
- Skip ambiguous or weakly supported date mentions instead of creating low-integrity items.

## Integrity Rules

- **Derived index**: `timeline.jsonl` is a materialized overlay derived from vault notes, not user-authored source of truth.
- **Source-backed only**: Every item must include at least one supporting path in `source_docs`.
- **Stable identity**: Re-extracting the same logical item should preserve the same `id` whenever `kind`, normalized `title`, `date`, and primary source remain the same.
- **Deduplicate by fact**: When multiple notes describe the same logical item, merge them into one entry and accumulate `source_docs`.
- **No invented precision**: If the exact date cannot be normalized confidently, do not emit an item.
- **No date-role collapse**: Do not overwrite an event date with an artifact date or vice versa.
- **Bounded recurrence**: Use `recurrence` only for explicit repeating anchors, not for habits inferred from repeated past notes.
- **Null means one-time**: One-off items must use `recurrence: null`.
- **Date-only contract**: `date` and `end_date` store calendar dates only, never times of day.
- **Optional artifact time**: `document_date` is optional, but when present it must follow the same ISO date contract as `date`.
- **Regenerate from source**: Corrections should come from source note edits and re-extraction, not manual editing of `timeline.jsonl`.
- **Refresh timestamp**: `extracted_at` must reflect the extraction run that last confirmed or updated the item.

## Example Entries

{"id":"t-001","kind":"milestone","title":"Alpha MVP demo","date":"2026-03-18","end_date":null,"document_date":"2026-03-16","recurrence":null,"source_docs":["projects/alpha/timeline.md","daily/2026-03-16.md"],"confidence":0.95,"extracted_at":"2026-03-16T09:20:00+09:00"}

{"id":"t-002","kind":"event","title":"Tokyo client visit","date":"2026-04-02","end_date":"2026-04-03","document_date":"2026-03-16","recurrence":null,"source_docs":["work/travel.md"],"confidence":0.84,"extracted_at":"2026-03-16T09:20:00+09:00"}

{"id":"t-003","kind":"recurring","title":"Weekly review","date":"2026-03-20","end_date":null,"document_date":"2026-03-14","recurrence":"weekly","source_docs":["systems/reviews.md","daily/2026-03-14.md"],"confidence":0.9,"extracted_at":"2026-03-16T09:20:00+09:00"}

{"id":"t-004","kind":"note-date","title":"2026-03-16","date":"2026-03-16","end_date":null,"document_date":"2026-03-16","recurrence":null,"source_docs":["Daily/2026-03-16.md"],"confidence":0.99,"extracted_at":"2026-03-16T09:20:00+09:00"}
