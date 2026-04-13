---
name: privacy-node-schema
description: This reference provides the privacy schema contract for PII-bearing entities in the PA ontology. It should be consulted when an agent needs to "assign mask_id to a new entity", "determine safe_name for an organization or place", "look up entity privacy tier", "apply 5-layer protection to vault content", "check hash-index for disambiguation", or "understand which entity kinds require privacy treatment".
---

# Privacy Node Schema - Privacy Layer for PII-Bearing Entities

> Purpose: Detection and execution reference for `personal-ontology` - use it to define, assign, and validate the privacy layer for PII-bearing entity kinds.
> This reference is standalone and can be consulted without the parent skill.
> For the main extraction workflow, see `skills/pa/personal-ontology/SKILL.md`.

## Scope

This reference defines the privacy layer that extends the base entity schema.
It applies to entity kinds that carry personally identifiable information: `person` (inner-circle only), `organization`, `place`, `education`, and `project`.
It does NOT apply to `topic`, `concept`, `artifact`, `event`, or life-family entities (`area`, `goal`, `direction`, `value`, `habit`, `milestone`).

## Entity Privacy Fields

Add these optional fields to privacy-bearing entities on top of the base fields from `SKILL.md`.

| Field | Required | Description |
|-------|----------|-------------|
| `mask_id` | yes (privacy kinds) | Kind-prefixed unique ID. Format: `{KIND_PREFIX}_{LETTER}`. Examples: `ORG_A`, `PLACE_A`, `EDU_A`, `PROJ_A`, `Person_A` |
| `safe_name` | yes (when `mask_id` exists) | Human-readable generalized category shown to AI. Examples: "대기업 기술팀", "서울", "서울 소재 대학" |
| `name_hashes` | no | Array of SHA-256 first `8` hex chars. One hash per full `canonical_name` and each alias for homonym disambiguation |

## Kind-Specific Privacy Rules

| kind | mask prefix | safe_name example | when applied | standard person? |
|------|-------------|-------------------|--------------|------------------|
| person (inner-circle) | `Person_` | — | `trust_level = inner-circle` | No - names pass through |
| person (standard) | none | — | names pass through, not identifiable alone | Yes - no masking |
| organization | `ORG_` | "대기업 기술팀", "스타트업", "게임 기업" | always | n/a |
| place | `PLACE_` | "서울", "경기", "부산" | specific addresses only — see Place Masking Criteria below | n/a |
| education | `EDU_` | "서울 소재 대학 공학계열", "사립 고등학교" | always | n/a |
| project | `PROJ_` | "사내 AI 프로젝트", "오픈소스 도구" | external or identifiable projects only | n/a |
| topic | none | — | general concepts need no privacy | n/a |

### Place Masking Criteria

| Input | Action | Result | Rationale |
|-------|--------|--------|-----------|
| "테헤란로 123" | Mask | `PLACE_A(서울)` | Specific street address identifies location |
| "강남구 역삼동" | Mask | `PLACE_A(서울)` | District + neighborhood identifies location |
| "서울" | Pass through | "서울" | City-level is too broad to identify |
| "경기도" | Pass through | "경기도" | Province-level is too broad to identify |
| "스타벅스 역삼점" | Mask | `PLACE_B(서울 카페)` | Named venue identifies meeting location |

Rule: mask when the place can narrow a person's location to a neighborhood or specific venue. City/province level passes through.

### name_hashes Input Normalization

Before hashing, normalize the input: strip leading/trailing whitespace, collapse internal whitespace to a single space. Do not case-fold (Korean has no case). This ensures "삼성전자" and " 삼성전자 " produce the same hash.

## mask-map.json Schema (Version 2)

Location: `.pa/mask-map.json` - sensitive, local-only, recommend `.pa/.gitignore`.

```json
{
  "version": 2,
  "next_ids": {
    "person": 1,
    "org": 1,
    "place": 1,
    "edu": 1,
    "project": 1
  },
  "entries": [
    {
      "real_name": "삼성전자",
      "aliases": ["삼성", "Samsung"],
      "mask_id": "ORG_A",
      "safe_name": "대기업 기술팀",
      "kind": "org",
      "name_hashes": ["a1b2c3d4", "e5f6a7b8"],
      "created": "2026-03-18"
    }
  ]
}
```

Key rules:

- `next_ids` is per kind.
- When adding `ORG`, increment `next_ids.org` only.
- ID letter generation uses the same algorithm as `pa-mask.sh`: `1 -> A`, `2 -> B`, ..., `26 -> Z`, `27 -> AA`.
- `name_hashes` stores the SHA-256 first `8` hex chars of `real_name` and each alias.
- Version `1` backward compatibility: if `version` is `1` or missing, treat all entries as `kind: "person"` with `next_id` as `next_ids.person`.

## hash-index.json Schema

Location: `.pa/hash-index.json` - derived from `mask-map.json` and regenerable.

```json
{
  "a1b2c3d4": ["ORG_A"],
  "e5f6a7b8": ["ORG_A", "ORG_B"],
  "f1a2b3c4": ["Person_A"]
}
```

Lookup rules:

- `1` result -> unambiguous, use that `mask_id`.
- `2+` results -> ambiguous, use `area_refs` and note path context to disambiguate.
- `0` results -> unregistered entity, propose registration.

## Shadow Vault Location

The shadow vault is stored externally in `~/.cache/ouroboros/shadow/{vault-id}/` where `vault-id` is `{basename}-{sha256(realpath(vault))[:8]}`. This external location enables Read deny on the vault directory itself — the PreToolUse hook blocks `Read` calls on raw vault paths and redirects to the shadow. The `shadow_root` path is recorded in `.pa/settings.json`.

Resolution order for shadow directory:
1. `PA_SHADOW_ROOT` environment variable
2. `settings.json` `shadow_root` field
3. Fallback: `~/.cache/ouroboros/shadow/{vault-id}/`

## 5-Layer Protection Order

Applied by shadow vault sync and QMD MCP proxy in this exact order.

| Layer | Operation | Tool |
|-------|-----------|------|
| 1 | HTML comment strip (`<!-- ... -->`) | `pa-mask.sh --strip-private` |
| 2 | `private: true` frontmatter -> stub | `pa-shadow.sh` logic |
| 3 | PII regex (phone, email, SSN, account) -> tokens | `pa-mask.sh --pii` |
| 4 | Entity substitution: `canonical_name` -> `mask_id(safe_name)` | `pa-mask.sh mask-entity` |
| 5 | Numeric generalization: amount -> range, date -> month, age -> decade | `pa-mask.sh --generalize` |

## Progressive Learning Flow

```text
First /pa survey:
  Weaver reads raw vault (1-time exposure via Bash, bypassing Read hook)
  -> entity extraction + Privacy Assignment (mask_id + safe_name)
  -> entities.json + mask-map.json saved
  -> pa-shadow.sh sync creates shadow vault at ~/.cache/ouroboros/shadow/{vault-id}/
  -> deny-paths.json created in .pa/
  -> subsequent sessions: shadow vault reads only (Read hook enforces)

New note with unregistered entity:
  -> QMD indexes locally (OK)
  -> next PA command: 1-time exposure -> entity extraction -> mask_id + safe_name
  -> shadow vault updated (incremental sync)
```

## Worked Example

Register "삼성전자" as an organization.

1. `mask-map.json` entry:

```json
{
  "real_name": "삼성전자",
  "aliases": ["삼성", "Samsung"],
  "mask_id": "ORG_A",
  "safe_name": "대기업 기술팀",
  "kind": "org",
  "name_hashes": ["a1b2c3d4", "e5f6a7b8"],
  "created": "2026-03-18"
}
```

2. Entity shell in `entities.json`:

```json
{
  "canonical_name": "ORG_A",
  "kind": "organization",
  "ontology_family": "vault",
  "mask_id": "ORG_A",
  "safe_name": "대기업 기술팀",
  "name_hashes": ["a1b2c3d4", "e5f6a7b8"],
  "confidence": 0.7,
  "provenance": "survey-2026-03-18",
  "first_seen": "2026-03-18T09:00:00+09:00",
  "source_notes": ["work/meeting.md"]
}
```

3. Shadow vault transformation:

```text
Original: "김철수가 삼성전자 AI팀에서 연봉 5천만원 받는다"
Shadow:   "김철수가 ORG_A(대기업 기술팀) AI팀에서 연봉 중상위 받는다"
```

Note: "김철수" passes through because it is a standard person and not identifiable alone.
Note: "삼성전자" becomes `ORG_A(대기업 기술팀)`.
Note: "5천만원" becomes "중상위".
Note: Korean particles are adjusted automatically — "5천만원**을**" becomes "중상위**를**" (vowel ending → 를).
Each privacy-bearing kind keeps an independent `next_ids` counter, so `ORG_A` and `PLACE_A` can both exist without cross-kind leakage.

## Design Rationale

Why ontology-driven privacy: entities are already extracted during survey.
Adding `mask_id` and `safe_name` at extraction time means privacy registration is automatic instead of a separate workflow.
No separate PII registry is needed because the ontology is the registry.

Why `safe_name` exists alongside `mask_id`: `ORG_A` alone gives the AI no usable category context.
`ORG_A(대기업 기술팀)` preserves reasoning value without exposing the specific company.

Why kind-separated `next_ids` matter: `ORG_A`, `PLACE_A`, and `EDU_A` each start from `A` independently.
This prevents insertion order from leaking cross-kind information and keeps IDs readable.

Why the `5`-layer order matters: HTML comments are user-explicit privacy, then frontmatter-level note privacy, then structural PII, then ontology-level entity substitution, then contextual numeric generalization.
Each layer handles a different privacy class and later layers should not override earlier user intent.

## Common Pitfalls

| Pitfall | Why It Breaks The Model | Prevention |
|---------|-------------------------|------------|
| Masking standard person names | Names alone are not automatically identifiable and masking them harms UX | Only mask `inner-circle` persons, and let standard person names pass through |
| Applying `safe_name` to topics | Topics are general concepts such as "머신러닝" and do not need privacy treatment | Check `kind` before privacy assignment and apply privacy fields only to privacy-bearing kinds |
| Using `mask_id` without `safe_name` | The AI cannot reason about `ORG_A` without category context | Always pair `mask_id` with `safe_name` |
| Skipping hash generation | Homonym disambiguation fails for masked entities | Generate `name_hashes` for every `mask-map.json` entry |
| Applying layers out of order | HTML comments might contain entity names that get masked before stripping | Follow the `5`-layer order strictly |

## Validation Checklist

- [ ] Every privacy-bearing entity has `mask_id` and `safe_name`
- [ ] Standard person entities have NO `mask_id`
- [ ] Inner-circle person entities have `mask_id`
- [ ] `mask-map.json` uses version `2` schema with kind-separated `next_ids`
- [ ] `name_hashes` generated for every `mask-map.json` entry (`real_name` and each alias)
- [ ] `hash-index.json` is consistent with `mask-map.json` entries
- [ ] `5`-layer protection applied in the correct order
- [ ] Shadow vault contains only protected content and no raw PII-bearing entity names
- [ ] `topic`, `concept`, `event`, and `artifact` entities have no privacy fields

## See Also

| Component | Relationship |
|-----------|--------------|
| `skills/pa/personal-ontology/SKILL.md` | Parent skill - entity extraction workflow includes Privacy Assignment |
| `skills/pa/personal-ontology/references/people-schema.md` | Person-specific privacy fields such as profile schema, `trust_level`, and `consent_status` |
| `skills/pa/personal-ontology/references/entity-canonicalization.md` | `mask_id` overrides canonical form selection for privacy kinds |
| `skills/pa/personal-ontology/references/life-entities.md` | Life entities do not receive privacy treatment |
| `skills/pa/trust-and-boundaries/references/masking-rules.md` | Masking operations and `5`-layer protection details |
| `agents/pa/weaver.md` | Primary consumer - Privacy Assignment during entity extraction |
| `scripts/pa-mask.sh` | CLI implementation of masking operations |
| `scripts/pa-shadow.sh` | Shadow vault sync applying the `5`-layer protection order |
