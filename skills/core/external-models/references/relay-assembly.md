# Relay Assembly

This reference defines how to assemble neutral external-model relay prompts without duplicating routing logic.

## Core Shape

Build relays in four sections named Role, Content, Methodology or Criteria, and Response Format.
Join sections with exactly two newlines between them.
Write the final prompt to a deterministic `.tmp/` path before any external branch starts.
Use descriptive suffixes such as `_relay.txt`, `_researcher_relay.txt`, `_security_relay.txt`, or `_review_relay.txt`.

## Section 1 — Role

Keep Role fixed, generic, and independent.
State the task clearly without hinting at the preferred conclusion.
Include the no-prior-context warning when the external model should rely only on the provided relay.
For imported or web content, add the untrusted-content warning here as well.

## Section 2 — Content

Insert gathered task content verbatim.
Do not summarize, paraphrase, annotate, or pre-score the content block.
Use structural separators such as `=== BASE ===` or `=== LOCAL ===` when the template expects multiple artifacts in one section.
Wrap external or user-provided source material in `<<<UNTRUSTED_CONTENT_START>>>` and `<<<UNTRUSTED_CONTENT_END>>>` markers when the consumer analyzes potentially instruction-bearing content.

## Section 3 — Methodology Or Criteria

Insert raw criteria text when the consumer expects independent scoring against a rubric.
Insert a narrow procedure when the consumer expects structured analysis, reconciliation, research synthesis, or generation.
Keep this section deterministic and reference-backed rather than conversational.
When the methodology already lives in a reference file, reuse it rather than rewriting a near-duplicate inline.

## Section 4 — Response Format

Use strict JSON-only response contracts for parse-heavy consumers.
List every required field, including empty arrays that the caller still expects.
Avoid markdown fences, prose wrappers, or completion metadata in this section.
If a consumer needs free-text output instead of JSON, do not use the JSON relay path at all.

## Current Template Sources

Use `skills/core/evaluation/references/evaluator-relay-prompts.md` for evaluation relays.
Use `skills/core/routing/references/relay-prompt-templates.md` for research and upgrade reconciliation relays.
Use `skills/core/absorption/references/researcher-relay-prompt.md` and `gap-analysis-relay-prompt.md` for absorb-specific research and gap work.
Use `skills/core/evolution/references/researcher-relay-prompt.md` for evolve analysis relays.
Use `skills/swe/methodology/references/swe-relay-prompts.md` for SWE review and quality relays.

## Inline Consumer Rules

`commands/core/generate.md` still assembles generator relays inline, so it should follow the same four-section contract even without a dedicated template file.
`commands/core/brainstorm.md` also assembles a relay recipe inline and should keep its Role and Response Format sections templated while preserving raw content and methodology references.
If a command currently mixes template-backed and inline assembly, normalize behavior around these four sections before inventing a new transport pattern.

## Assembly Checks

Verify that every content-bearing section was sourced from an existing artifact or reference file rather than from Claude paraphrase.
Verify that the response schema matches the caller's parser expectations.
Verify that the prompt file exists on disk before launching any background branch.
