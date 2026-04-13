---
name: proposition-logic
description: This skill provides formal logic proposition methodology. It should be activated when an agent needs to 'extract verifiable propositions from text', 'encode claims as ASP facts', 'run integrity checks on a proposition set', 'detect contradictions in knowledge', 'trace proposition dependencies', or 'validate proposition grounding against evidence'.
summary: Extracts and verifies knowledge propositions using Answer Set Programming for contradiction detection and dependency tracing.
version: 1
tags: [core, proposition-logic, asp, verification, knowledge]
preamble_tier: 3
---

# Proposition Logic

## Core Rule

Every proposition must have a source hash, confidence level, and derived/direct flag.
Cascade invalidation follows dependency edges, not semantic similarity.
ASP first, OWL only for ontology/taxonomy.

This skill is in research-spike phase.
Run `/rnd` to validate ASP/LOGIC-LM feasibility before production use.
Treat all generated encodings as hypotheses until a source-grounded check passes.

## Gotchas

| Gotcha | Prevention |
|--------|------------|
| Formalization hallucination | Keep `claim_text` as the source-facing truth and treat `asp_encoding` as a checkable projection, not a replacement |
| Open-world vs closed-world mismatch | Use ASP for closed-world integrity checks only after explicitly deciding what absence means |
| Solver dependency | Keep a `jq` fallback for schema, duplicate, and dependency checks when Clingo is unavailable |
| Source hash drift | Recompute `source_hash` whenever the source segment changes instead of trusting path stability |
| Semantic cascade | Invalidate derived propositions through `depends_on` edges only, not by similar wording |
| Overconfident derived claims | Mark derived propositions as `medium` or `low` unless the inference rule and all dependencies are validated |
| Ontology creep | Use OWL only for class/taxonomy relationships and keep contradiction detection in ASP |
| Mixed evidence granularity | Hash the segment used as evidence when a whole document contains unrelated claims |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The sentence obviously implies this fact" | Marking an inferred proposition as `direct` | Mark it `derived` and add explicit `depends_on` edges |
| "The solver passed, so the grounding is fine" | Treating ASP consistency as evidence validation | Re-check `source_ref`, `source_hash`, and confidence separately |
| "These two claims look related, so invalidate both" | Cascading by semantic similarity | Follow explicit dependency edges and add missing edges only with evidence |

## Workflow

1. Extract claims from source.
2. Encode each claim as ASP facts.
3. Run Clingo integrity checks when available.
4. Report contradictions and unsupported claims.
5. Update the dependency graph.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Direct vs derived | Use `direct` only when the claim is stated in the cited source segment |
| Source hash | Store `sha256:<hex>` for the exact source document or segment used as evidence |
| Confidence | Use `high` for directly grounded, unambiguous source claims; `medium` for source-backed paraphrase or simple derivation; `low` for tentative extraction or weak inference |
| Derivation depth | Limit derivation chains to at most 5 levels. Flag propositions beyond depth 5 as needing consolidation |
| Dependencies | Every `derived` proposition should depend on at least one proposition unless the inference source is external and separately cited |
| Minimum confidence | Do not add propositions with `low` confidence unless they are explicitly marked as hypotheses and depend on at least 1 `high` or `medium` proposition |
| Staleness | Flag propositions older than 90 days without re-verification as stale candidates for review |
| Invalidation | Mark the target invalidated, then cascade only to propositions whose `depends_on` includes an invalidated id |
| Contradictions | Prefer explicit `contradicts/2` rules or facts over natural-language similarity heuristics |
| Unsupported claims | Flag active derived propositions with missing, invalidated, or empty dependencies |
| Solver unavailable | Run fallback checks and report that contradiction detection is degraded |
| Ontology work | Use OWL only when the task is taxonomy or class membership, not proposition integrity |

## Reference Map

Load the schema reference before adding new proposition fields, changing the JSONL format, or editing ASP integrity rules.

| Need | Reference |
|------|-----------|
| Proposition record fields, ASP examples, dependency rules, and integrity constraint examples | `${CLAUDE_SKILL_DIR}/references/proposition-schema.md` |

## See Also

These components are the nearest research and verification neighbors.

| Component | Relationship |
|-----------|--------------|
| `commands/rnd.md` | Runs the required research spike before productionizing the proposition system |
| `skills/core/research/SKILL.md` | Provides source evaluation and synthesis discipline before proposition extraction |
| `skills/core/validation/SKILL.md` | Provides static validation patterns for schema and artifact checks |
| `scripts/proposition-kb.sh` | Minimal research-spike CLI for JSONL proposition storage, fallback checks, and optional Clingo integrity |

Extension points: future `${CLAUDE_SKILL_DIR}/learned.md` can capture formalization patterns and common ASP encoding mistakes discovered during `/rnd` studies. Graduation to production requires passing an `/rnd` study validating contradiction detection accuracy and cascade invalidation reliability.
