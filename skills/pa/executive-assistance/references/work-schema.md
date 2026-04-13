# Work Schema — Extracted Work Overlay for PA

> Purpose: Reference for `executive-assistance` skill — defines the append-only JSONL schema for `.pa/work.jsonl`.
> This reference is standalone.
> For prioritization and agenda rules, see `skills/pa/executive-assistance/SKILL.md`.

## Scope

This reference defines the schema, extraction rules, and integrity rules for the PA work overlay.
The file stores work items extracted from vault notes, including tasks, commitments, deadlines, waiting-fors, and habits.

## File Location

`{vault}/.pa/work.jsonl` — one JSON object per line, append-only during extraction.

## Schema

Each line is a JSON object with these fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique work item identifier |
| `kind` | string | yes | `deadline`, `todo`, `waiting-for`, `habit`, or `commitment` |
| `title` | string | yes | Concise description of the work item |
| `state` | string | yes | `open`, `done`, or `cancelled` |
| `due` | string (ISO date) or `null` | yes | Due date when explicit and normalizable, otherwise `null` |
| `wait_for` | string or `null` | yes | Entity this item depends on or is waiting on |
| `owner` | string or `null` | yes | Responsible entity when explicit in the source |
| `source_docs` | string[] | yes | Vault paths that provide provenance for the extraction |
| `confidence` | number | yes | Extraction confidence from `0.0` to `1.0` |
| `extracted_at` | string (ISO 8601) | yes | Timestamp when the extractor appended the record |

## Kind Definitions

| Kind | Use When |
|------|----------|
| `deadline` | The source states a deliverable or milestone with a due date |
| `todo` | The source states a concrete action or checkbox task |
| `waiting-for` | Progress depends on another person, team, or external response |
| `habit` | The source describes a recurring personal or operational routine |
| `commitment` | The source records a promise, obligation, or agreed follow-up without a clear checkbox form |

## Extraction Rules

Extract only work items that are explicit enough to survive outside the source note without inventing missing facts.
Always preserve `source_docs` so later review can trace every item back to its note of origin.

### Checkbox Tasks

- Extract Markdown checkboxes such as `- [ ]`, `* [ ]`, and `- [x]` as work items.
- Map unchecked boxes to `state: "open"` and checked boxes to `state: "done"`.
- Use `kind: "todo"` by default unless surrounding text clearly indicates a waiting-for, habit, deadline, or commitment.
- Use the checkbox text as the basis for `title`, trimmed into a concise action phrase.

### Deadline Mentions

- Extract `kind: "deadline"` when the note states a deliverable plus an explicit due signal such as `due 2026-03-18`, `by March 18`, or task metadata with a calendar date.
- Normalize `due` to `YYYY-MM-DD` only when the date is explicit or unambiguous from the note context.
- If the source uses vague timing such as `soon`, `next week`, or `before launch`, keep the work item but set `due` to `null`.
- Set `owner` only when the responsible person or entity is explicit in the source.

### Waiting-Fors

- Extract `kind: "waiting-for"` from phrases such as `waiting for`, `blocked on`, `pending`, `awaiting reply`, or `need approval from`.
- Set `wait_for` to the referenced entity when it is named or can be resolved from a canonical entity record.
- If the dependency is implied but unnamed, keep `wait_for` as `null` and lower `confidence`.
- Use `state: "done"` only when the source explicitly says the dependency was resolved.

### Commitments

- Extract `kind: "commitment"` when the source records an obligation, promise, or agreed next step such as `I will send`, `we committed to`, or `follow up with finance`.
- Prefer `commitment` over `todo` when the emphasis is the obligation or agreement rather than a plain task list entry.
- Leave `owner` as `null` when the source does not clearly identify responsibility.

### Habits

- Extract `kind: "habit"` for recurring actions such as daily, weekly, or routine practices.
- Habit items usually have `due: null` unless the source gives a specific next occurrence date.
- Keep the item `open` unless the source explicitly marks the recurrence as done or cancelled.

### State and Confidence

- Use `state: "cancelled"` only when the source explicitly marks the work item as cancelled, dropped, or no longer relevant.
- Assign higher `confidence` to direct checkboxes, explicit due dates, and named dependencies than to inferred commitments.
- When owner, dependency, or due date is missing, do not fabricate it.

## Integrity Rules

- **Append-only during extraction**: Each extraction pass appends new records and does not rewrite or delete prior lines in `work.jsonl`.
- **Provenance required**: Every entry must include at least one path in `source_docs`.
- **Source-first truth**: `work.jsonl` is an overlay for retrieval and planning, not a replacement for the vault note.
- **No fabrication**: Missing owners, due dates, and dependencies remain `null` rather than guessed.
- **One item per durable unit**: Split separate tasks, commitments, and waiting-fors into separate records instead of combining them into one broad row.
- **Extraction timestamp**: `extracted_at` records when the overlay entry was written, not when the underlying work was first created.

## Example Entries

{"id":"w-001","kind":"deadline","title":"Alpha MVP demo","state":"open","due":"2026-03-18","wait_for":null,"owner":"e-002","source_docs":["projects/alpha/timeline.md"],"confidence":0.95,"extracted_at":"2026-03-16T09:20:00+09:00"}
{"id":"w-002","kind":"todo","title":"Finalize API contracts","state":"open","due":null,"wait_for":null,"owner":null,"source_docs":["projects/alpha/design.md"],"confidence":0.82,"extracted_at":"2026-03-16T09:20:00+09:00"}
{"id":"w-003","kind":"waiting-for","title":"Approval for vendor contract","state":"open","due":"2026-03-20","wait_for":"e-014","owner":"e-002","source_docs":["operations/vendor-renewal.md","daily/2026-03-16.md"],"confidence":0.88,"extracted_at":"2026-03-16T09:20:00+09:00"}
{"id":"w-004","kind":"habit","title":"Weekly project review","state":"open","due":null,"wait_for":null,"owner":"e-001","source_docs":["systems/reviews.md"],"confidence":0.90,"extracted_at":"2026-03-16T09:20:00+09:00"}
{"id":"w-005","kind":"commitment","title":"Send budget update to finance","state":"done","due":"2026-03-16","wait_for":null,"owner":"e-002","source_docs":["daily/2026-03-16.md"],"confidence":0.86,"extracted_at":"2026-03-16T09:20:00+09:00"}
