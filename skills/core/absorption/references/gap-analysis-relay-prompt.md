# Gap Analysis Relay Prompt Template

> Template for constructing the external model relay prompt in `/absorb` Phase 5 (`--multi`).
> The relay prompt is assembled from 4 sections and saved to `.tmp/{SESSION_ID}_gap_relay.txt`.

## Section 1 — Role (fixed)

You are an independent capability analyst. Your task is to compare a source's capabilities against an existing plugin module and identify gaps, overlaps, and conflicts. Produce a structured gap analysis. Do not assume any prior context — analyze based solely on the content given.

## Section 2 — Content (dynamic)

Insert source component inventory (from Phase 3) + existing module component contents (verbatim) + module name. No summarization or transformation.

## Section 3 — Methodology (fixed)

Follow this procedure:
1. Catalog existing module capabilities (per component)
2. Catalog source capabilities (from component inventory)
3. Compare: classify each source capability as gap (missing), overlap (covered), or conflict (contradicts)
4. For gaps: determine component type and suggest name
5. Prioritize gaps by impact (critical functionality first)

## Section 4 — Response Format (fixed)

JSON with these arrays:

- `gaps`: [{ "capability": "...", "type": "command|agent|skill", "name": "...", "priority": "high|medium|low", "rationale": "..." }]
- `overlaps`: [{ "capability": "...", "existing_component": "..." }]
- `conflicts`: [{ "capability": "...", "source_approach": "...", "existing_approach": "..." }]
