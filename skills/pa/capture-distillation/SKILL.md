---
name: capture-distillation
description: This skill provides capture distillation methodology. It should be activated when an agent needs to "classify raw input", "triage capture", "extract durable units from text", "transform transcript into note", "choose output routing for capture", "segment messy input", "normalize external source into vault note", "triage ingested content with provenance", or "detect duplicate content before ingest".
summary: Turns messy captures into conservative, provenance-preserving vault artifacts with safe classification, extraction, routing, and rendering.
version: 1
tags: [pa, capture, distillation, provenance, routing]
preamble_tier: 2
---

# Capture Distillation

## Core Rule

**"Preserve the user's meaning first, then add just enough structure to make it durable."**

Distillation exists to turn raw input into a vault-native artifact without upgrading ambiguity into false certainty.
Over-structuring makes the note look clean while silently changing what the user meant.
Under-structuring leaves the capture too messy to connect, review, or act on later.
Every result must preserve enough raw evidence to show what was explicit, what was inferred, and what is still unresolved.

## Gotchas

| Risk | Phase | Prevention |
|------|-------|------------|
| Segmenting after extraction and smearing unrelated topics together | Segmentation | Segment first and classify each unit independently |
| Forcing one tidy note type onto multi-intent input | Classification | Use `mixed` and lower confidence instead of forcing certainty |
| Converting vague intent into checkbox tasks | Extraction | Require explicit actor and explicit action |
| Dropping decision rationale because the note already names the choice | Extraction | Preserve the stated why whenever it exists |
| Appending to the wrong note because the title feels close enough | Routing | Demand clear target evidence or fall back to `proposal-only` or `timestamp-note` |
| Rewriting transcripts into polished prose with no evidence trail | Rendering | Keep a compact verbatim source section for long or transcript-like input |
| Filling metadata with guessed dates, owners, or facts | Rendering | Include only explicit or profile-supported fields |
| Treating uncertainty as clutter to remove | All | Preserve open loops, questions, and unresolved tensions |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "It is faster to extract first and segment later" | Extracting durable units before segment boundaries are set | Segment and classify each unit before extraction |
| "The user's vague intent is obviously a task" | Converting a partial intent into a checkbox without explicit actor and action | Keep it under `Open loops` or `Questions` until the action is explicit |
| "The title is close enough, so append it there" | Appending to an existing note from title similarity alone | Require clear target evidence or use `proposal-only` or `timestamp-note` |

## Workflow

### 1. Segmentation

Input: raw text, transcript, clip, or mixed material.
Output: ordered segments with provisional labels.
Split on speaker changes, topic shifts, quote boundaries, or abrupt intent changes, and prefer fewer segments when the boundaries are uncertain.

### 2. Three-Axis Classification

Input: segmented units.
Output: `input_form`, `capture_kind`, and `routing_target` candidates for each segment.
Classify structure, durable content type, and safest destination before you start extracting anything.

### 3. Durable Extraction

Input: classified segments.
Output: ideas, actions, decisions, references, journal observations, open loops, and questions.
Extract only units that can survive outside the original capture, and move partial or ambiguous material into `Open loops` or `Questions` instead of inventing missing facts.

### 4. Routing

Input: extracted units plus vault-profile placement rules and note-target evidence.
Output: the safest routing target.
Choose the destination that preserves reuse without overstating confidence about where the content belongs.

### 5. Rendering

Input: extracted units plus routing target.
Output: vault-native markdown or proposal payload.
Render sections only when they are actually present, keep frontmatter conservative, and prefer a short plain paragraph for very small captures.

### 6. Source Evidence Preservation

Input: rendered result plus original capture.
Output: compact evidence that keeps provenance visible.
For long input, retain a `Raw source` or `Source excerpt` section with verbatim fragments rather than rewritten summaries.

## Decision Rules

### Classification And Routing

| Axis | Purpose | Labels |
|------|---------|--------|
| `input_form` | Source shape | `snippet`, `bullet-dump`, `transcript`, `clip`, `source-digest`, `mixed` |
| `capture_kind` | Durable content pattern | `idea`, `action`, `decision`, `meeting`, `reference`, `journal`, `mixed` |
| `routing_target` | Safest destination | `timestamp-note`, `profiled-note`, `existing-note-append`, `ingest-digest`, `existing-note-proposal`, `proposal-only` |

| Routing confidence | Threshold | Target |
|--------------------|-----------|--------|
| High | `>= 0.8` with a clear placement match | `profiled-note` |
| Medium | `0.5-0.79` with topic clarity but placement uncertainty | `timestamp-note` |
| Low | `< 0.5`, mixed content, or no placement match | `timestamp-note` |
| Append candidate | Existing note match `>= 0.65` | `existing-note-append` or `proposal-only` |
| Duplicate detected | Strong lex or hash overlap | `existing-note-proposal` with net-new delta only |

### Extraction And Rendering Rules

Convert to a checkbox only when both actor and action are explicit.
Never invent dates, owners, or factual premises that do not appear in the source.
When `capture_kind = decision` and extraction confidence is at least `0.7`, extract `context`, `alternatives`, `chosen`, and `rationale`, and emit a `decision_entity_candidate`.
If alternatives are not explicit, set them to `["(not specified)"]`.
Captures under 50 words may stay as one paragraph, and captures over 500 words should always use headings.
For input over 200 words, preserve 50 to 150 words of verbatim evidence in a source section.

Validation checks: segment before extraction, classify every segment, route conservatively, preserve ambiguity, use append only with a clear target and boundary, and keep source markers such as speakers, timestamps, URLs, or import provenance.

## Reference Map

- `${CLAUDE_SKILL_DIR}/references/triage-taxonomy.md` — Three-axis labels, routing-target definitions, and classification disambiguation rules.
- `${CLAUDE_SKILL_DIR}/references/distillation-rules.md` — Durable extraction, rendering, and source-preservation rules with fabrication guards.

## See Also

- `agents/pa/curator.md` — Applies this methodology to captured material.
- `commands/pa/capture.md` — Uses distillation for user-originated captures.
- `commands/pa/ingest.md` — Uses distillation for imported or external-source material.
- `skills/pa/writing/SKILL.md` — Governs the vault-native writing style used during rendering.
- `skills/pa/trust-and-boundaries/SKILL.md` — Governs conservative handling of uncertainty and user intent.
