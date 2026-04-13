# Masking Rules — Person Data Protection and Name Substitution

> Purpose: Detailed masking reference for `trust-and-boundaries` — use it to decide when and how to mask person data, what sensitivity level applies, and how the propose-only rename policy works.

This reference is standalone and can be used without the parent skill.
For the end-to-end trust workflow, see `skills/pa/trust-and-boundaries/SKILL.md`.

## mask-map.json Schema

`mask-map.json` uses the version `2` schema defined in `skills/pa/personal-ontology/references/privacy-node-schema.md`.
This reference covers operational masking rules only.

## Masking Procedure

Follow these steps when a new person entity is encountered or registered.

### New Person Registration

1. **Check existing entries**: Query mask-map via `pa-mask.sh list` to verify the name is not already registered.
2. **Classify sensitivity**: Ask the user to assign a `trust_level` using the criteria in the Sensitivity Classification table below.
3. **Create mask entry**: Run `pa-mask.sh add "<name>" --aliases "<aliases>"` to generate the `mask_id` and seed the profile.
4. **Complete profile**: Fill in `relationship_type`, `context`, and `areas` in the generated profile at `.pa/people/profiles/{mask_id}.json`.
5. **Apply masking**: Use `pa-mask.sh mask` on any text containing the person's name before passing it to Claude.

### Ongoing Masking During Operations

1. **Before entity extraction**: Load mask-map and apply name substitution to vault note content.
2. **During output generation**: Use `mask_id` values in all assistant state such as `.pa/` files and ledger entries.
3. **Before user display**: Apply unmask to convert `mask_id` values back to real names in user-facing output.
4. **On profile staleness**: When `last_interaction` exceeds the `trust_level` threshold, flag the person for review.

## Masking Operations

| Operation | Input | Output | Tool |
|-----------|-------|--------|------|
| `mask` | Text with real names | Text with `mask_id` values | `pa-mask.sh mask` |
| `unmask` | Text with `mask_id` values | Text with real names | `pa-mask.sh unmask` |
| `mask-entity` | Text with entity names | Text with `mask_id(safe_name)` | `pa-mask.sh mask-entity` |
| `add` | Real name with optional aliases | New mask-map entry and empty profile | `pa-mask.sh add` |
| `list` | none | Current mask-map entries | `pa-mask.sh list` |

## 5-Layer Protection Order

Shadow vault sync and QMD MCP proxy apply these layers in order.
See `skills/pa/personal-ontology/references/privacy-node-schema.md` for detailed specifications.

| Layer | Operation | Handles |
|-------|-----------|---------|
| 1 | HTML comment strip | User-explicit private content |
| 2 | `private:true` stub | Full-note privacy |
| 3 | PII regex | Structural PII (phone, email, SSN, account) |
| 4 | Entity substitution | Identifiable organizations, places, schools, projects |
| 5 | Numeric generalization | Amounts, dates, ages |

## Masking Timing

| Phase | When to Mask | How |
|-------|--------------|-----|
| Entity extraction | Before passing vault content to Claude | Weaver reads mask-map and substitutes names in extracted text |
| Link suggestions | Before presenting entity names | Replace `mask_id` with real name only in user-facing output |
| Dossier generation | Before Claude processes person entities | All person references use `mask_id` |
| User output | After Claude produces output | Unmask for display to the user |
| **Write declassification** | Before vault write (draft, capture, compile, ingest, day) | `pa-write-safe.sh inspect` → Layer 4 reversible unmask via `declassify`. Layer 1/3/5 residuals → proposal-only. Code fences exempt |

## Sensitivity Levels

| Level | Definition | Handling |
|-------|------------|----------|
| `inner-circle` | Close family, partners, and dependents | Extra care, never suggest in proposals, and avoid bulk operations |
| `standard` | Friends, colleagues, and professional contacts | Names normally pass through, but other privacy layers still apply when needed |
| `restricted` | Public figures and non-sensitive contacts | Masking is optional and the user may keep real names |

Sensitivity maps to `trust_level` in the person profile.
The default `trust_level` is `standard`.

### Sensitivity Classification Criteria

| Level | Declarative Criteria | Behavioral Signals |
|-------|----------------------|--------------------|
| `inner-circle` | User explicitly identifies as family, partner, or dependent during interview | Appears in daily notes `3+` times per week and is referenced in personal areas |
| `standard` | User identifies as colleague, friend, or professional contact | Appears in project or area notes with regular but not daily interaction |
| `restricted` | User identifies as public figure, organization, or non-sensitive contact | Appears in reference notes with no personal context |

When signals conflict such as a colleague who is mentioned daily, use the higher sensitivity level.
When in doubt, default to `standard`.
The user can adjust the classification later.

## Propose-Only Vault Rename Policy

PA MUST NOT automatically rename vault wikilinks from `[[Kim]]` to `[[Person_A]]`.
This would break the user's vault structure, make notes less readable, and violate the trust-and-boundaries core principle.

Instead:

1. PA may propose a mapping such as "`[[Kim]]` could be tracked as `Person_A` in the people graph."
2. The vault wikilink stays as `[[Kim]]`.
3. The mask map handles the translation internally.
4. Only the data sent to Claude uses `mask_id`.

## Masking in Outputs

| Output Type | Masking Behavior |
|-------------|------------------|
| Link suggestions that face the user | Show real names by unmasking before display |
| Dossier files inside `.pa/` | Use `mask_id` values because they are assistant state |
| Entity records in `.pa/entities.json` | Use `mask_id` values |
| Ledger entries | Use `mask_id` values |
| Conversation responses to the user | Show real names by unmasking before display |
| Weaver internal processing | Use `mask_id` values |

## Leakage Prevention

| Vector | Risk | Mitigation |
|--------|------|------------|
| AskUserQuestion | Inner-circle real name appears in cleartext | Convert to `mask_id` immediately after receiving it when masked handling applies |
| `assistant-ledger.jsonl` | Inner-circle real name leaks into the audit trail | Always log masked people with `mask_id` |
| `entities.json` | Inner-circle real name becomes `canonical_name` | Use `mask_id` as `canonical_name` for masked people |
| Conversation context | Real name persists in context | Accept this as ephemeral and user-controlled |
| QMD search results | Real name appears in note content | Weaver masks before passing content to Claude |
| `.pa/mask-map.json` | The map file leaks | Use `.gitignore`, local file permissions, and no-sync guidance |

## Common Pitfalls

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Auto-renaming vault `[[Kim]]` to `[[Person_A]]` | Entity extraction | Propose-only policy - never auto-modify user notes |
| Forgetting to unmask in user-facing output | Output generation | Always unmask before displaying to the user |
| Masking partial name matches such as `Kimchi` when masking `Kim` | Name substitution | Use word-boundary matching in `pa-mask.sh` |
| Not updating mask-map when aliases change | Profile maintenance | `pa-mask.sh add` supports `--aliases` for updates |
| Unknown person in vault scan without a mask-map entry | Entity extraction | Propose new registration to the user and do not auto-create mask entries |

## Ambiguous Person Handling

When Weaver encounters a person name in vault notes that is not in the mask-map, use the following rules.

| Scenario | Behavior |
|----------|----------|
| Name appears in `2+` notes with consistent context | Propose registration: "`[[{name}]]`이 여러 노트에 등장합니다. People graph에 등록할까요?" |
| Name appears once only | Skip - insufficient evidence for person entity registration |
| Name matches an existing alias partially | Flag for user review: "`[[{name}]]`이 기존 `{mask_id}`의 alias와 유사합니다. 같은 사람인가요?" |
| Name is clearly a non-person entity such as a project or place | Skip - do not propose person registration for non-person entities |

Never auto-create `mask-map.json` entries from vault scanning.
All person registrations require user confirmation.

## Transmission Audit Ledger

Every data transmission to AI is recorded in `.pa/transmission-ledger.jsonl`. This ledger supports GDPR Art. 30 processing records, PIPA processing record obligations, and CCPA right-to-know.

### Schema

```json
{
  "ts": "2026-03-18T10:00:00+09:00",
  "action": "shadow-sync",
  "notes_processed": 13,
  "private_stubs": 1,
  "masking_layers": ["strip-private", "pii", "mask-entity", "generalize"],
  "entities_touched": ["ORG_A", "PLACE_A"],
  "pii_redacted": {"phone": 2, "email": 1},
  "mask_map_version": 2
}
```

Actions: `shadow-sync` (pa-shadow.sh), `qmd-query` (qmd-proxy.js), `forget` (pa-mask.sh forget).

The ledger is append-only. `forget` actions write a tombstone entry rather than deleting prior records, preserving the audit trail while documenting erasure.

### Audit Queries

- `jq 'select(.action == "shadow-sync")' .pa/transmission-ledger.jsonl` — all sync events
- `jq 'select(.entities_touched[] == "ORG_A")' .pa/transmission-ledger.jsonl` — all transmissions involving a specific entity
- `jq 'select(.action == "forget")' .pa/transmission-ledger.jsonl` — all erasure events

## Consent Management

Each person entity can have a `consent_status` field in their profile (`.pa/people/profiles/{mask_id}.json`):

| Status | Meaning | AI Behavior |
|--------|---------|-------------|
| `implicit` | Default — user recorded info, no explicit consent from subject | Normal masking and protection |
| `explicit` | Subject has consented to AI processing | Normal masking and protection |
| `denied` | Subject has denied AI processing | Entity completely excluded from shadow vault and QMD proxy results |
| `withdrawn` | Subject previously consented, then withdrew | Same as `denied` — complete exclusion |

When `consent_status` is `denied` or `withdrawn`:
- `pa-shadow.sh sync` strips ALL mentions of that entity from shadow vault
- `qmd-proxy.js` removes that entity's data from QMD results
- `pa-mask.sh forget <mask_id>` performs cascade erasure + tombstone

## See Also

| Component | Relationship |
|-----------|--------------|
| `skills/pa/trust-and-boundaries/SKILL.md` | Parent skill - overall trust workflow |
| `skills/pa/trust-and-boundaries/references/posture-matrix.md` | Sibling reference - posture permissions that govern masking actions |
| `skills/pa/personal-ontology/references/people-schema.md` | Person entity schema and privacy architecture |
| `skills/pa/personal-ontology/references/privacy-node-schema.md` | Privacy node schema and `5`-layer protection architecture |
| `scripts/pa-mask.sh` | CLI implementation of mask and unmask operations |
