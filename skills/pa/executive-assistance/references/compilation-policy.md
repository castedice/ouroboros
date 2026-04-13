---
name: compilation-policy
description: This reference provides compilation window selection and source eligibility rules for period synthesis. It should be consulted when an agent needs to "determine the compile window from cadence", "check if notes are eligible for compilation", "decide when compilation is a no-op", "read the compile cursor from derivation-state", "map compile_cadence to date boundaries", or "process day-handoff compile candidates".
---

# Compilation Policy — Cadence, Eligibility, and Period Boundaries

> Purpose: Reference for `executive-assistance` skill — defines when and how `/pa compile` should aggregate captures into period summaries.
> This reference is standalone and can be consulted without the parent skill.
> For the prioritization workflow, see `skills/pa/executive-assistance/SKILL.md`.

## Scope

This reference defines policy for choosing a compilation window, selecting eligible source notes, and deciding when `/pa compile` should produce a clean no-op.
It complements `references/work-schema.md` and `references/timeline-schema.md`, which define the structured overlays used after extraction and planning.
Those sibling references answer "what work and temporal records look like," while this reference answers "which raw or semi-processed notes should enter period synthesis, and when."
Use the sibling references when a compilation needs to align carry-forward items with `work.jsonl` or dated anchors with `timeline.jsonl`, but use this reference for note-family eligibility and window boundaries.
It does not cover review loops (Phase 7), evergreen note promotion (handled by `/pa draft`), or daily close-out (handled by `/pa day`).

## Cadence-to-Window Mapping

The `journal_style.compile_cadence` field in vault-profile determines the default compilation window.
The user may override with an explicit `--from` / `--to` range.

| `compile_cadence` | Default Window | Start Boundary | End Boundary |
|-------------------|----------------|----------------|--------------|
| `rolling` | Since last compile cursor | `derivation-state.json` -> `last_compile.timestamp` | Now |
| `every-few-days` | Last 3 days | 3 days before today | End of yesterday |
| `monthly` | Previous calendar month | 1st of previous month | Last day of previous month |
| `annual` | Previous calendar year | Jan 1 of previous year | Dec 31 of previous year |
| `custom` | Since last compile cursor | `derivation-state.json` -> `last_compile.timestamp` | Now |

When `last_compile.timestamp` is null (first run), use the earliest note creation date in the vault as the start boundary.

### Explicit Range Override

When the user provides `--from YYYY-MM-DD` or `--to YYYY-MM-DD`, these values override the cadence-derived defaults.
The cadence field is a hint, not a mandate.

## Source Eligibility

Not every note qualifies for compilation.
Eligible sources are notes created or modified within the compilation window that match one of the following families.

### Source Families

| Family | Match Criteria | Priority |
|--------|----------------|----------|
| **Timestamp notes** | Notes matching `naming_rules.timestamp_note_pattern` in the window | 1 — primary compilation material |
| **Capture notes** | Notes in `placement_rules.clippings_dir` or routed via `/pa capture` | 2 — inbox content to be synthesized |
| **Ingest digests** | Notes matching `ingest-digest` routing from `/pa ingest` | 3 — external content to include |
| **Day handoff candidates** | Structured compile-candidate blocks from `/pa day --mode evening` | 4 — pre-triaged material |

Priority indicates synthesis preference, not hard inclusion order.
Lower-priority families remain eligible, but higher-priority families should dominate when the same material appears through multiple routes or when the compiler must trim redundant evidence.

### Exclusion Rules

| Exclude | Reason |
|---------|--------|
| Existing compilation notes | Avoid compiling compilations (recursive synthesis) |
| Profiled notes (non-capture) | Already durable — no need to compile |
| `.pa/` state files | Assistant state, not user content |
| Notes in `_system/templates` | Template scaffolding |

## No-Op Conditions

Compilation should produce no output and report a clean no-op when any of the following holds.

| Condition | Report Message |
|-----------|---------------|
| Fewer than 3 eligible sources in the window | "Too few captures to compile ({n} found, minimum 3). Try a wider range or wait for more captures." |
| All eligible sources already appear in a prior compilation note | "All captures in this window have already been compiled." |
| No `compile_cadence` set and no explicit range provided | "Compilation cadence not configured. Use `--from` / `--to` or set `journal_style.compile_cadence` in vault-profile." |

## Compile Cursor

After a successful compilation, update `.pa/derivation-state.json` with a minimal cursor.

```json
{
  "last_compile": {
    "timestamp": "2026-03-17T18:00:00+09:00",
    "window_start": "2026-03-14",
    "window_end": "2026-03-16",
    "sources_compiled": 5,
    "output_path": "notes/2026-03-14--2026-03-16-compilation.md"
  }
}
```

The cursor prevents recompilation of the same window and provides the start boundary for `rolling` / `custom` cadence.

## Day Handoff Integration

`/pa day --mode evening` produces a compile-candidate block that `/pa compile` can consume as pre-triaged input.
The handoff format:

```markdown
### Compile Candidates

| Source | Theme | Carry-Forward |
|--------|-------|---------------|
| `notes/2026-03-17-1430-meeting-notes.md` | project sync | 2 open actions |
| `notes/2026-03-17-0900-idea.md` | design pattern | none |

**Themes**: project sync, design patterns
**Carry-forward items**: 2 open actions from meeting notes
```

When this block is present in the current day's note or conversation, `/pa compile` uses it to pre-filter and theme-sort the eligible sources.
The handoff is optional.
Compile works without it.

## Output Expectations

The compilation result must include per `templates/pa/period-compilation.md`:

1. **Window metadata**: period start, end, source count
2. **Themes**: grouped durable units by topic
3. **Key decisions**: decisions extracted from captures in the window
4. **Carry-forward items**: unresolved actions and open loops
5. **Evergreen candidates**: topics that recurred 3+ times, signaling potential promotion to a durable note via `/pa draft`

The compile command renders the output.
This reference defines only the policy that drives source selection and window boundaries.

## Design Rationale

Why 3-source minimum for compilation: compiling 1-2 captures produces a summary shorter than the originals, adding overhead without value.
Three is the empirical minimum where thematic grouping and cross-capture synthesis become meaningful.
Below this threshold, the captures are better served by direct reading.

Why cadence is a hint, not a mandate: vault habits evolve and do not always match the profiled cadence.
A user who normally compiles monthly may want a weekly compilation before a review.
Explicit range overrides ensure the tool adapts to the user's current need rather than enforcing a stale cadence setting.

Why compile cursor instead of per-note "compiled" flag: a per-note flag would require modifying every compiled source note's frontmatter, which is a high-risk write across N notes.
A single cursor in `derivation-state.json` is one assistant-state write that tracks the same information.
This follows the PA principle of minimal vault mutation.

Why source family priorities favor timestamp notes and direct captures first: compilation is a second-pass synthesis over the freshest user-authored evidence.
Timestamp notes and direct captures preserve wording, uncertainty, and local context best.
Ingest digests are already one step removed from the original source, so they stay eligible but secondary.
Day handoff candidates are last because they are triage hints, not a replacement for the full eligible set.

Why exclusion rules are strict: compilation should summarize raw period evidence once, not repeatedly summarize prior assistant outputs, durable notes, or system scaffolding.
Excluding compilation notes, profiled notes, assistant state, and templates prevents recursive synthesis, double-counting, and theme distortion.

## Common Pitfalls

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Compiling an empty or near-empty window | Source Collection | Check source count against minimum threshold (3+) before proceeding |
| Recompiling the same period | Window Selection | Always check `last_compile` cursor before starting. Skip when the window is fully covered |
| Including profiled notes in compilation | Source Eligibility | Profiled notes are already durable — filter them out during source collection |
| Ignoring day-handoff candidates | Source Collection | Check conversation context and today's daily note for compile-candidate blocks |
| Using cadence as a mandate instead of a hint | Window Selection | Cadence is a default — explicit `--from`/`--to` always overrides |
| Compiling compilation notes recursively | Source Eligibility | Exclude notes with `compiled_from` frontmatter from source families |

## Bias Mitigation

| Bias | Phase | Symptom | Countermeasure |
|------|-------|---------|----------------|
| Recency bias | Theme Extraction | Over-weighting the most recent captures in the summary | Weight all sources equally within the window regardless of creation date |
| Completion bias | Carry-Forward | Marking open loops as "resolved" to make the summary cleaner | Carry-forward items must trace to explicit resolution evidence, not inference |
| Quantity bias | Source Collection | Including low-value sources to inflate the compilation | Apply eligibility rules strictly — source families only, no padding |

## Validation Checklist

- [ ] Compilation window boundaries are explicit (start date, end date)
- [ ] `compile_cadence` used as default, explicit range overrides when provided
- [ ] `last_compile` cursor checked before proceeding
- [ ] Source count meets minimum threshold (3+) or no-op reported
- [ ] Excluded: existing compilation notes, profiled notes, `.pa/` files, templates
- [ ] Day-handoff candidates checked when available
- [ ] Compile cursor updated after successful compilation
- [ ] No sources from outside the compilation window included

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/executive-assistance/SKILL.md` | Parent skill — prioritization and temporal analysis |
| `skills/pa/executive-assistance/references/work-schema.md` | Sibling reference — schema for carry-forward work items surfaced after compilation |
| `skills/pa/executive-assistance/references/timeline-schema.md` | Sibling reference — schema for dated anchors that contextualize compilation output |
| `commands/pa/compile.md` | Primary consumer — applies this policy for source selection |
| `commands/pa/day.md` | Produces compile-candidate handoff in evening mode |
| `templates/pa/period-compilation.md` | Output template for compilation results |
| `commands/pa/draft.md` | Receives evergreen promotion candidates from compilation |