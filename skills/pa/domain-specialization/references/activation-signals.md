---
name: activation-signals
description: This reference defines the area coverage signal calculation, activation/deactivation thresholds, suggested specialist flow, and auto_state schema. It should be consulted when an agent needs to "calculate area coverage", "determine specialist activation", "evaluate auto-suggestion eligibility", "check deactivation thresholds", or "manage suggested specialist lifecycle".
---

# Activation Signals — Dynamic Specialist Activation

> Purpose: Reference for `domain-specialization` — defines how PA automatically detects areas that need specialists and manages the suggested → active → inactive lifecycle.
> This reference is standalone and can be consulted without the parent skill.
> For the specialist methodology, see `skills/pa/domain-specialization/SKILL.md`.

## Area Coverage Signal

The coverage signal determines whether an area has enough activity to warrant a specialist. It uses a dual-anchor approach to avoid suggesting specialists for areas the user hasn't committed to.

### Dual Anchor Conditions

| Anchor | Source | Condition |
|--------|--------|-----------|
| **Profile anchor** | `personal-profile.json` → `identity.core_areas` | The area appears in `core_areas` |
| **Ontology anchor** | `entities.json` | At least one active goal or habit entity has `area_refs` matching this area |
| **Operational anchor** | `work.jsonl` | 3 or more work items match the area (by tag, title, description, or source path) |

### Activation Decision

| Profile Anchor | Ontology Anchor | Operational Anchor | Result |
|:-:|:-:|:-:|--------|
| Yes | Yes | — | Suggest specialist |
| Yes | — | Yes | Suggest specialist |
| Yes | — | — | No suggestion (profile alone is insufficient) |
| — | Yes | Yes | No suggestion — enrichment candidate only |
| — | — | Yes | No suggestion |

Profile anchor is always required. Without it, operational signals alone cannot trigger a suggestion — the user must have declared the area in their profile.

### Signal Calculation Timing

Coverage signals are calculated during:
1. `/pa survey` — Phase 7 Specialist Registry Update
2. `/pa steward` — Phase A Survey Refresh (inherited from survey)

Not calculated during `/pa day`, `/pa agenda`, `/pa review` — these commands consume specialists but do not create or suggest them.

## Suggested Specialist Flow

### Creation

When the coverage signal triggers for an area without an existing specialist:

1. Create a stub entry in `specialists.json` with `status: "suggested"`, `agent: null`, `source: "auto"`.
2. Set `suggestion_reason` to describe why (e.g., "core_area 'health' has 2 active goals and 5 work items").
3. Initialize `auto_state` with `last_evaluated: {now}`, `last_declined_at: null`, `last_matched_at: null`.

### User Interaction — Survey

At the end of survey Phase 7, after registry updates:

1. Check for `status: "suggested"` entries.
2. Present each: "{area} 영역에 전문가를 추가할까요?"
3. User response branches:

| Choice | Action |
|--------|--------|
| Create now | Run persona interview → generate agent → `status: "active"`, `source: "generated"` |
| Keep suggested | Keep stub. Re-evaluate on next survey |
| Decline | Set `status: "inactive"`, `auto_state.last_declined_at: {now}`. Suppress re-suggestion for 30 days |

### User Interaction — Day/Agenda

Phase 3.4 surfaces suggested specialists as optional notifications:

1. Check `specialists.json` for `status: "suggested"` entries.
2. If found, briefly notify: "{area} 영역에 전문가를 추가할 수 있어요. 추가할까요?"
3. User may accept (triggers persona interview inline) or dismiss (keeps suggested).
4. Day/agenda does not set `inactive` — only survey and explicit `/pa specialist remove` manage registry-level deactivation.

## Deactivation Rules

### Hard Deactivation

Automatic `status: "inactive"` for `source: "auto"` specialists only:

| Condition | Action |
|-----------|--------|
| Area removed from `core_areas` AND no active goal/habit for that area | Set `status: "inactive"` |
| `status: "suggested"` for 30+ days AND coverage signal weakens (< 3 work items, no goals) | Set `status: "inactive"` |

### Soft Deactivation (Proposal Only)

For `source: "generated"`, `source: "manual"`, or `source: "default"` specialists:

| Condition | Action |
|-----------|--------|
| `last_matched_at` is 90+ days ago or null | Survey/review proposes: "이 전문가를 일시 중지할까요?" |
| Area removed from `core_areas` | Survey proposes: "이 영역이 프로필에서 제거되었어요. 전문가를 비활성화할까요?" |

User-registered specialists are never auto-deactivated. The system only proposes.

### Deactivation Immunity

| `source` | Auto Hard Deactivation | Soft Deactivation Proposal |
|----------|:----------------------:|:--------------------------:|
| `auto` | Yes | Yes |
| `generated` | — | Yes |
| `manual` | — | Yes |
| `default` | — | Yes |

## auto_state Schema

Added to each specialist entry in `specialists.json`:

```json
{
  "auto_state": {
    "last_evaluated": "2026-03-20T09:00:00+09:00",
    "last_declined_at": null,
    "last_matched_at": "2026-03-19T18:00:00+09:00"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `last_evaluated` | string (ISO datetime) or null | Last time the coverage signal was calculated for this specialist's area |
| `last_declined_at` | string (ISO datetime) or null | Last time the user declined activation. Suppresses re-suggestion for 30 days |
| `last_matched_at` | string (ISO datetime) or null | Last time a work item or timeline event matched this specialist's `area_refs` during a day/agenda/review call |

### last_matched_at Update Rules

Updated by day, agenda, and review commands when they filter work/timeline items against `area_refs`:
- If at least one item matches → set `last_matched_at` to the current timestamp.
- If no items match → leave `last_matched_at` unchanged.
- Only updated for `status: "active"` specialists (suggested and inactive are not matched against).

## Graceful Degradation

| Missing State | Behavior |
|---------------|----------|
| `personal-profile.json` missing | Profile anchor unavailable. No coverage signals calculated. Skip all activation logic |
| `entities.json` missing | Ontology anchor unavailable. Use operational anchor only (requires profile anchor + 3 work items) |
| `work.jsonl` missing | Operational anchor unavailable. Use ontology anchor only (requires profile anchor + active goal/habit) |
| Both `entities.json` and `work.jsonl` missing | No anchors beyond profile. Skip all activation logic |
| `specialists.json` missing | No registry to update. Skip activation logic |

## Design Rationale

Why **dual-anchor over single signal**: A single operational signal (3 work items) would suggest specialists for areas the user tracks operationally but hasn't committed to as a life area. Requiring the profile anchor ensures the user has declared intent. The ontology or operational anchor then confirms activity.

Why **30-day decline suppression**: Prevents nagging. If the user explicitly declined, the system respects that for a month before re-evaluating. If coverage signals strengthen significantly, the next survey will re-suggest after 30 days.

Why **90-day inactivity for soft deactivation**: Aligns with the quarter horizon. If a specialist hasn't matched any items in a full quarter, it's likely no longer relevant. But since user-registered specialists may have seasonal patterns, this is proposal-only.

Why **day/agenda notification but not deactivation**: Day and agenda are consumption-oriented commands. They should alert the user to available improvements but not make registry-level changes. Survey is the registry management command.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/domain-specialization/SKILL.md` | Parent skill — specialist methodology and dynamic activation workflow |
| `skills/pa/domain-specialization/references/specialist-registry.md` | Registry schema including `auto_state` fields |
| `commands/pa/survey.md` | Coverage signal calculation and suggested specialist creation |
| `commands/pa/day.md` | Phase 3.4 suggested specialist notification |
| `commands/pa/agenda.md` | Phase 3.4 suggested specialist notification |
| `commands/pa/steward.md` | Specialist activation check via survey refresh |
| `skills/pa/personal-profiling/references/profile-schema.md` | `core_areas` source for profile anchor |
