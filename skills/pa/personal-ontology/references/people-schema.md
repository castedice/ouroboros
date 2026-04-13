---
name: people-schema
description: This reference provides the schema contract for person entities in the PA ontology. It should be consulted when an agent needs to "register a new person in the people graph", "look up a person's mask_id", "determine relationship type for a person", "validate person profile structure", "understand the 2-layer privacy model", or "check trust level for a person entity".
---

# People Schema - Person Entity Extension and 2-Layer Privacy Model

> Purpose: Detection and execution reference for `personal-ontology` - use it to define, register, and validate person entities while preserving the PA privacy boundary.
> This reference is standalone and can be consulted without the parent skill.
> For the main ontology workflow, see `skills/pa/personal-ontology/SKILL.md`.

## Scope

This reference covers person-specific privacy features such as profiles, trust levels, and consent.
For the generic privacy architecture that applies to all PII-bearing entity kinds including organizations and places, see `references/privacy-node-schema.md`.

This reference extends the existing vault ontology's `person` entity kind with a private detail layer.
For masked persons, the ontology shell stays in `.pa/entities.json` as a masked assistant-facing record.
The private detail layer stays in `.pa/people/profiles/{mask_id}.json` as a local-only record.
Together they define a two-layer privacy architecture for the people graph.

## 2-Layer Privacy Architecture

| Layer | Location | Contents | Claude Access |
|-------|----------|----------|---------------|
| Shell | `.pa/entities.json` | `mask_id`, `kind=person`, `relationship_type`, `area_refs`, `confidence`, `provenance` | Yes (masked) |
| Detail | `.pa/people/profiles/{mask_id}.json` | real name, aliases, detailed notes, interaction history, `trust_level` | No (local only) |

This `2`-layer model is a person-specific instance of the generic privacy node architecture defined in `references/privacy-node-schema.md`.
For masked persons, the shell layer uses `mask_id` such as `Person_A` as `canonical_name` in the entity record.
The detail layer stores the real name and sensitive information that must never be exposed to Claude.

## mask-map.json Schema

`mask-map.json` uses the version `2` schema defined in `references/privacy-node-schema.md`.
Person entries use `kind: "person"` with the `Person_` prefix for `inner-circle` persons, or no `mask_id` for standard trust.
Sequential person IDs remain intentionally meaningless for privacy.
`.pa/mask-map.json` is sensitive and should be added to `.pa/.gitignore`.
Weaver normalizes vault person mentions through `mask-map.json` lookup during entity extraction when a masked person entry exists.

## Person Profile Schema (Detail Layer)

The person profile lives at `.pa/people/profiles/{mask_id}.json`.

```json
{
  "mask_id": "Person_A",
  "relationship_type": "colleague",
  "trust_level": "standard",
  "consent_status": "implicit",
  "context": "같은 팀 백엔드 개발자",
  "first_registered": "2026-03-18",
  "last_interaction": "2026-03-18",
  "dates": [{"label": "birthday", "date": "03-28", "notify": true}],
  "notes": "...",
  "areas": ["career"]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `mask_id` | yes | Sequential mask ID matching the shell entity |
| `relationship_type` | yes | One of `colleague`, `family`, `friend`, `mentor`, `mentee`, `acquaintance`, `professional`, or `other` |
| `trust_level` | yes | One of `inner-circle`, `standard`, or `restricted` |
| `consent_status` | no | One of `implicit` (default), `explicit`, `denied`, or `withdrawn`. When `denied`/`withdrawn`, entity is excluded from all AI processing. See `trust-and-boundaries/references/masking-rules.md` Consent Management |
| `context` | yes | One-line description of how the user knows this person |
| `first_registered` | yes | ISO date when this person was first registered |
| `last_interaction` | no | ISO date of last known interaction |
| `dates` | no | Array of date entries: `[{label, date, notify}]`. Label: `birthday`, `anniversary`, or custom. Date: `MM-DD` (recurring annual) or `YYYY-MM-DD` (specific). Notify: boolean for day/heartbeat surfacing |
| `notes` | no | Free-text notes about this person |
| `areas` | no | Life areas this person is relevant to, referencing `identity.core_areas` |

## Person Entity Shell (Ontology Layer)

The person entity in `.pa/entities.json` uses `ontology_family: "vault"` because persons are detected from vault wikilinks.
When a person is masked, the shell also carries a small set of person-specific fields that are safe to expose in masked form.

```json
{
  "canonical_name": "Person_A",
  "kind": "person",
  "ontology_family": "vault",
  "mask_id": "Person_A",
  "safe_name": "가까운 동료",
  "name_hashes": ["3b7f92d1", "91f0c8aa", "72bd5e44"],
  "relationship_type": "colleague",
  "area_refs": ["career"],
  "confidence": 0.7,
  "provenance": "people-bootstrap-2026-03-18",
  "first_seen": "2026-03-18T09:00:00+09:00",
  "source_notes": ["meetings/2026-03-15.md"]
}
```

`relationship_type` is the only detail-layer field that crosses from the profile into the entity shell.
Real name, `trust_level`, and free-form notes stay in the detail layer.

## Registry-Seeded Persons

Persons may be registered directly through `.pa/people/` without requiring vault wikilinks.
This is an explicit exception to the standard two-signal rule for vault entities.
The interview engine's `people-bootstrap` mode handles the initial registration flow.
Vault reinforcement is optional because a confirmed registration is sufficient to create the entity.

## Ingress Rules

1. Interview bootstrap asks five questions through `interviewing/SKILL.md` bootstrap mode covering name, relationship, context, trust, and memo.
2. Vault wikilink detection lets Weaver detect `[[Name]]` patterns and check mask-map for an existing mapping.
3. Direct registration through `pa-mask.sh add "Name"` creates the mask-map entry and then seeds the profile manually or through interview flow.

## Cleartext Safety

When a real name is received through AskUserQuestion, handle it as follows.

1. If the person is `inner-circle`, convert the real name to `mask_id` immediately after receiving the answer.
2. Use only `mask_id` in all masked-person processing.
3. Never store inner-circle real names in logs, masked entity shells, or conversation cache.
4. Inner-circle real names may exist only in `.pa/mask-map.json` and `.pa/people/profiles/*.json`.

## Common Pitfalls

| Pitfall | Why It Breaks The Model | Prevention |
|---------|-------------------------|------------|
| Storing inner-circle real names in `entities.json` | Privacy breach because `entities.json` is shared with Claude | Always use `mask_id` as `canonical_name` for inner-circle persons |
| Auto-renaming vault wikilinks | Trust violation because it modifies user content without consent | Keep a propose-only policy for vault renames |
| Merging person entities across ontology families | A life entity like `friend` and a vault entity like `Kim` should not auto-merge | Keep `ontology_family` explicit |
| Creating a person profile without a mask-map entry | The profile becomes orphaned with no lookup path | Always create the mask-map entry first |
| Logging real names in `assistant-ledger.jsonl` | Privacy leak through the audit trail | Use `mask_id` in all ledger entries |

## Bias Mitigation

| Bias | Phase | Symptom | Countermeasure |
|------|-------|---------|----------------|
| Relationship-type anchoring | Registration | First-assigned relationship type persists even when the relationship evolves | Review `relationship_type` during catch-up interviews and flag persons with unchanged type after `6+` months of interaction |
| Trust-level middle-ground default | Registration | All persons default to `standard`, creating a flat trust landscape | Prompt for explicit trust classification during bootstrap and do not auto-assign `standard` without user confirmation |
| Recency bias in interaction tracking | Profile maintenance | Recently mentioned persons appear more important than long-term stable relationships | Weight interaction quality such as dedicated notes and project co-occurrence over mere mention frequency |

## Quantified Rules

Use numeric rules whenever person-entity confidence or profile freshness would otherwise be described qualitatively.
Round every stored confidence to the nearest `0.05`.
Cap reinforcement-adjusted confidence at `1.0`.

### Confidence Seeding for Person Entities

| Registration Path | Initial Confidence | Justification |
|-------------------|--------------------|---------------|
| Interview bootstrap (5 questions answered) | `0.60` | Direct user input but limited depth |
| Vault wikilink detection (2+ structural signals) | `0.50` | Standard vault entity evidence threshold |
| Direct registration (`pa-mask.sh add` only) | `0.35` | Minimal evidence - name and `mask_id` only |

### Vault Reinforcement Boosts

Apply vault reinforcement after seeding the base confidence.
Add `+0.15` for each reinforcing wikilink occurrence in a distinct note.
Add `+0.10` when a dedicated note is promoted to `canonical_note`.
Add `+0.05` for each additional distinct `source_note` beyond the first.
Do not raise confidence above `1.0`.

### Profile Staleness Thresholds

Treat a person profile as stale when `last_interaction` has not been updated within the threshold for that `trust_level`.
A stale flag triggers a review suggestion, not automatic removal.

| `trust_level` | Stale threshold (no `last_interaction` update) |
|---------------|-----------------------------------------------|
| `inner-circle` | `30` days |
| `standard` | `60` days |
| `restricted` | `90` days |

### Trust Level Behavioral Consequences

| `trust_level` | Dossier Detail | Proposal Inclusion | Bulk Operations |
|---------------|----------------|--------------------|-----------------|
| `inner-circle` | Relationship type and area only - no interaction notes | Never include in proposals without explicit user request | Excluded from bulk person operations |
| `standard` | Standard profile with names passing through unless another privacy rule applies | Include in proposals normally | Included in bulk operations with confirmation |
| `restricted` | Full profile - masking optional per user preference | Include freely | Included in bulk operations |

## Design Rationale

Why `2` layers instead of full encryption: full encryption through GPG or AES adds key-management complexity, lock-out risk, and extra CLI dependency.
The `2`-layer model achieves practical privacy through data separation, with `mask_id` values in shared state and real names in local-only files.
File permissions and `.gitignore` provide the access boundary.
Encryption can be added later without changing the masking architecture.

Why sequential IDs instead of UUIDs: UUIDs leak no semantic information, but they are hard to read in conversations, entity graphs, and relation outputs.
Sequential IDs such as `Person_A` and `Person_B` are human-scannable while still being semantically meaningless.
The tradeoff is that insertion order is technically inferable.
That privacy cost is small compared to the readability gain.

Why `relationship_type` crosses layers but `trust_level` does not: `relationship_type` is needed by Weaver for person-specific relation typing such as `colleague-of` and `family-of`, and it is a low-sensitivity categorical label.
`trust_level` drives behavioral consequences such as how much detail to show and whether to include a person in proposals.
That makes `trust_level` a sensitivity classification that belongs in the protected detail layer where it can govern handling rules without being exposed to Claude.

## Worked Examples

This example shows the `inner-circle` registration flow for a colleague named "Kim".

| Step | Output | Key fields |
|------|--------|------------|
| 1 | `.pa/mask-map.json` | `real_name: "Kim"`, aliases, `mask_id: "Person_A"`, `safe_name`, `kind: "person"` |
| 2 | `.pa/people/profiles/Person_A.json` | `relationship_type`, `trust_level`, `context`, `dates`, `notes`, `areas` |
| 3 | `.pa/entities.json` shell | masked `canonical_name`, `relationship_type`, `area_refs`, confidence, provenance |
| 4 | Assistant processing | convert the cleartext answer to `Person_A` immediately and use only `mask_id` in later masked processing |

The real name remains only in the mask map and person profile files.

## Validation Checklist

- [ ] Inner-circle person entities use `mask_id` as `canonical_name`, and standard person entities do not.
- [ ] A `mask-map.json` entry exists before any person profile is created.
- [ ] Inner-circle real names appear only in `.pa/mask-map.json` and `.pa/people/profiles/*.json`.
- [ ] `relationship_type` is the only detail-layer field that appears in the entity shell.
- [ ] `trust_level` stays in the detail layer and never appears in the entity shell.
- [ ] Each person entity has `ontology_family: "vault"` because it is detected from vault structure.
- [ ] Registry-seeded persons use provenance that clearly marks the bootstrap path.
- [ ] AskUserQuestion cleartext is converted to `mask_id` before masked-person processing.

## See Also

| Component | Relationship |
|-----------|--------------|
| `skills/pa/personal-ontology/SKILL.md` | Parent skill - overall ontology workflow |
| `skills/pa/personal-ontology/references/life-entities.md` | Sibling reference - life-entity schema |
| `skills/pa/personal-ontology/references/privacy-node-schema.md` | Generic privacy architecture for all PII-bearing entities |
| `skills/pa/personal-ontology/references/relation-taxonomy.md` | Person-specific relation types |
| `skills/pa/trust-and-boundaries/references/masking-rules.md` | Masking rules and sensitivity levels |
| `agents/pa/weaver.md` | Primary consumer - mask-map normalization during extraction |
| `scripts/pa-mask.sh` | CLI utility for mask and unmask operations |
