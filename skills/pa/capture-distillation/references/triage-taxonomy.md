# Triage Taxonomy — Three-Axis Classification for Capture Input

> Purpose: Reference for `capture-distillation` skill — lookup tables for the three classification axes used to triage raw capture input. This reference is standalone and can be consulted without the parent skill. For the end-to-end distillation procedure, see `skills/pa/capture-distillation/SKILL.md`.

## Scope

This reference covers the three classification axes (`input_form`, `capture_kind`, `routing_target`), their label definitions, signal detection rules, and disambiguation guidance.

## Three Axes

| Axis | Labels | Purpose |
|------|--------|---------|
| `input_form` | `snippet`, `bullet-dump`, `transcript`, `clip`, `source-digest`, `mixed` | Identifies the structural shape of the source |
| `capture_kind` | `idea`, `action`, `decision`, `meeting`, `reference`, `journal`, `mixed` | Identifies the durable content pattern to preserve |
| `routing_target` | `timestamp-note`, `profiled-note`, `existing-note-append`, `ingest-digest`, `existing-note-proposal`, `proposal-only` | Identifies the safest output destination |

## Input Form

| Form | Signal | Handling |
|------|--------|----------|
| `snippet` | 1-3 connected sentences or one short paragraph | Preserve wording closely and avoid heavy sectioning |
| `bullet-dump` | Multiple short bullets, fragments, or checklist-like lines | Normalize into grouped sections without forcing sentence form |
| `transcript` | Speaker turns, meeting notes, or conversational flow | Extract decisions and actions, then retain a compact raw-source section |
| `clip` | Imported quote, excerpt, or externally sourced text | Preserve attribution and separate source claims from user interpretation |
| `source-digest` | External content with clear provenance — fetched URL, imported file, pasted article excerpt, or speaker-labeled transcript with source attribution | Normalize into a source-packet (source_type, source_url, source_title, raw_content), then triage as a single ingest unit. Preserve provenance metadata throughout. Route to `ingest-digest` when source confidence is high |
| `mixed` | Multiple forms appear together with no single dominant structure | Segment conservatively and keep the final render visibly multi-part |

## Capture Kind

| Kind | Signal | Durable Focus |
|------|--------|---------------|
| `idea` | Concept, hypothesis, draft thought, or pattern | Preserve the insight and its framing, not just keywords |
| `action` | Requested follow-up, commitment, or next step | Extract only when actor and action are explicit |
| `decision` | Resolved choice, conclusion, or direction | Record the decision, scope, and stated rationale if present |
| `meeting` | Coordinated discussion with participants and outcomes | Preserve decisions, actions, open loops, and attendance context |
| `reference` | Fact source, quote, citation, or material to revisit | Preserve source metadata and key claims without over-summarizing |
| `journal` | Reflection, state snapshot, or lived observation | Preserve voice, chronology, and felt meaning |
| `mixed` | Two or more durable kinds are equally present | Split into labeled sections instead of forcing one dominant kind |

## Routing Target

| Target | Use When | Result |
|--------|----------|--------|
| `timestamp-note` | Placement confidence is low, the capture is mixed or transient, or the input needs a safe inbox landing zone | Create a time-scoped capture note that preserves extracted structure plus source evidence |
| `profiled-note` | One coherent topic dominates and vault-profile rules give a clear new-note placement and title pattern | Create a new durable note using vault-native conventions |
| `existing-note-append` | The target note is explicitly named or strongly evidenced and the append boundary is clear | Append a bounded section to the existing note |
| `proposal-only` | A likely destination exists but target identity, posture, or factual certainty is not strong enough for a write | Output a suggested placement or patch without applying it |
| `ingest-digest` | External source with clear provenance — URL fetch result, imported markdown, pasted article, or transcript with source attribution | Create a source-aware digest note using `templates/pa/ingest-digest.md` with provenance metadata, summary, claims, tasks, and related notes |
| `existing-note-proposal` | Duplicate detected — QMD lex title match ≥ 0.8 or content hash overlap with an existing vault note | Extract only the net-new delta from the ingest input and propose appending or merging with the existing note. Do not create a new note |

## Disambiguation Rules

- When a segment fits multiple labels equally well, prefer `mixed` and lower the routing confidence rather than forcing a neat classification.
- If placement confidence is low, fall back to `timestamp-note`.
- Use `proposal-only` instead of `existing-note-append` when the candidate target note is plausible but not provable.
- A short messy capture is better preserved in the wrong temporary place than rewritten into the wrong durable place.
