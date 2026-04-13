---
name: specialist-registry
description: This reference defines the specialists.json schema, field semantics, area mapping rules, and status lifecycle. It should be consulted when an agent needs to "load specialist registry", "validate specialists.json", "map areas to specialists", "check specialist activation status", or "filter specialists by surface".
---

# Specialist Registry — `.pa/specialists.json`

> Purpose: Reference for `domain-specialization` — defines the complete schema for the specialist registry, including field semantics, validation rules, area mapping, and status lifecycle.
> This reference is standalone and can be consulted without the parent skill.
> For the specialist methodology, see `skills/pa/domain-specialization/SKILL.md`.

## Schema

```json
{
  "version": 1,
  "specialists": [
    {
      "id": "health",
      "agent": "agents/pa/specialists/health.md",
      "area_refs": ["health", "fitness", "exercise", "운동", "건강"],
      "goal_refs": [],
      "note_refs": [],
      "status": "active",
      "surfaces": ["day", "agenda"],
      "trigger_conditions": {
        "keywords": ["exercise", "workout", "run", "gym", "recovery", "운동", "헬스"],
        "work_kinds": ["habit", "todo", "deadline"],
        "timeline_windows": ["today", "week"]
      },
      "capabilities": ["assess_today", "risk_scan", "carry_forward", "habit_check"],
      "priority_hint": "normal",
      "custom_instructions": "",
      "registered": "2026-03-19",
      "source": "default",
      "suggestion_reason": "",
      "auto_state": {
        "last_evaluated": null,
        "last_declined_at": null,
        "last_matched_at": null
      }
    }
  ]
}
```

## Field Definitions

### Top-Level

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `version` | integer | yes | `1` | Schema version for forward compatibility |
| `specialists` | array | yes | `[]` | List of registered specialist entries |

### Specialist Entry

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | string | yes | — | Unique identifier. Lowercase, kebab-case. Must match the agent filename stem |
| `agent` | string | yes | — | Relative path to the agent definition file |
| `area_refs` | string[] | yes | — | Mapped `core_areas` keys and user-language aliases. Exact match used for filtering |
| `goal_refs` | string[] | no | `[]` | Linked goal entity canonical_names from entities.json. Auto-populated during survey |
| `note_refs` | string[] | no | `[]` | Key vault note paths relevant to this domain. User-provided |
| `status` | string | yes | `"active"` | Activation state: `active`, `inactive`, `suggested` |
| `surfaces` | string[] | yes | `["day", "agenda"]` | Commands that trigger this specialist. Valid: `day`, `agenda`, `review` |
| `trigger_conditions` | object | no | `{}` | Phase 14 auto-activation signals. Not used in Phase 13 MVP |
| `capabilities` | string[] | no | `[]` | Specialist capability tags. Informational in Phase 13, functional in Phase 14 |
| `priority_hint` | string | no | `"normal"` | Display ordering: `high`, `normal`, `low` |
| `custom_instructions` | string | no | `""` | User-provided guidance appended to the specialist's prompt |
| `registered` | string | yes | — | ISO date of registration |
| `source` | string | yes | `"generated"` | How registered: `generated`, `manual`, `auto`, `default` |
| `suggestion_reason` | string | no | `""` | Why this specialist was suggested. Set by dynamic activation coverage signal |
| `auto_state` | object | no | `null` | Dynamic activation state tracking. See Auto State Fields below |

### Trigger Conditions

| Field | Type | Description |
|-------|------|-------------|
| `keywords` | string[] | Terms in work items or notes that activate this specialist |
| `work_kinds` | string[] | Work item kinds (`habit`, `todo`, `deadline`, `commitment`, `waiting-for`) |
| `timeline_windows` | string[] | Time horizons (`today`, `week`, `month`) |

These fields support auto-activation and area matching for specialist invocation.

### Capabilities

| Value | Description |
|-------|-------------|
| `assess_today` | Evaluate today's area-specific state |
| `risk_scan` | Identify area-specific risks from gaps or overdue items |
| `carry_forward` | Suggest carry-forward items for evening closeout |
| `habit_check` | Evaluate habit streak consistency |

Capabilities control selective specialist invocation. Commands use capabilities to determine which specialists to call based on the current horizon. See the review command for capability-based horizon filtering.

### Auto State Fields

| Field | Type | Description |
|-------|------|-------------|
| `last_evaluated` | string (ISO datetime) or null | Last time the coverage signal was calculated for this specialist's area |
| `last_declined_at` | string (ISO datetime) or null | Last time the user declined activation. Suppresses re-suggestion for 30 days |
| `last_matched_at` | string (ISO datetime) or null | Last time a work item or timeline event matched this specialist's `area_refs` during a day/agenda/review call |

Updated by day, agenda, and review commands: if at least one work/timeline item matches the specialist's `area_refs`, set `last_matched_at` to the current timestamp. Only updated for `status: "active"` specialists.

See `skills/pa/domain-specialization/references/activation-signals.md` for the complete activation signal calculation and deactivation rules.

## Status Lifecycle

```
(init/survey generates via interview) → active
(user declines specialist for area)   → no entry created

active ↔ inactive     (user toggle or area removed)

(coverage signal proposes)         → suggested
suggested → active                  (user confirms + interview)
suggested → inactive                (user declines, 30-day suppression)
auto inactive → suggested           (re-evaluation after 30 days if signal persists)
```

## Area Mapping Rules

### During Init

1. Load `personal-profile.json` → `identity.core_areas`.
2. For each default specialist, check if any `area_refs` term appears in `core_areas`.
3. If match found: set `status: "active"`, add user's area term to `area_refs` if not already present.
4. If no match: set `status: "inactive"`.
5. Ask user to confirm: "운동 → health specialist로 매핑할까요?"
6. User may add custom aliases or reject the mapping.

### During Survey

1. Load existing `specialists.json` and `personal-profile.json`.
2. Detect changes in `core_areas` since last survey.
3. For new areas: propose specialist mapping.
4. For removed areas: propose `status: "inactive"` for affected specialists.
5. For changed area names: update `area_refs` aliases.

### Matching Logic

Work items and timeline events are matched to specialists by checking if any `area_refs` term appears in:
- The item's `tags` field (if present)
- The item's `title` or `description` (substring match)
- The item's `source_docs` path (folder name match)

This is a best-effort filter. Items that match no specialist are not assigned.

## Exemplar Specialists

Read-only structural references in `skills/pa/domain-specialization/examples/`. These are never activated directly — they demonstrate the expected agent definition pattern for the generation workflow.

| ID | Exemplar | Default `area_refs` | Default `surfaces` |
|----|----------|--------------------|--------------------|
| `health` | `examples/health.md` | `health`, `fitness`, `exercise` | `day`, `agenda` |
| `finance` | `examples/finance.md` | `finance`, `money`, `budget` | `day`, `agenda` |
| `learning` | `examples/learning.md` | `learning`, `study`, `skill` | `day`, `agenda` |

Runtime-generated specialists are written to `agents/pa/specialists/{area_id}.md` and registered in `.pa/specialists.json`. User-language aliases (e.g., "운동", "재정", "공부") are added during the init/survey mapping step.

## Quantified Constraints

| Rule | Threshold | Rationale |
|------|-----------|-----------|
| Maximum active specialists | 10 | Beyond 10, chief-of-staff Specialist Insights section becomes unwieldy. Phase 14 should auto-deactivate lowest-priority specialists when limit reached |
| Maximum `area_refs` per specialist | 8 | More than 8 aliases indicates the specialist's domain is too broad. Split into two specialists |
| Maximum `surfaces` per specialist | 3 | All valid values: `day`, `agenda`, `review`. Adding more surfaces in future versions requires schema update |
| `trigger_conditions.keywords` limit | 20 | Keyword list beyond 20 becomes a performance concern for matching. Use broader terms instead |
| Area matching item scan depth | 50 items per specialist | If work.jsonl has 200 items, only the 50 most recent per area are scanned for matches |

## Design Rationale

Why **exact match for `area_refs`** over fuzzy/semantic: exact match is deterministic, debuggable, and zero-cost. Fuzzy matching would require LLM calls per work item per specialist, adding cost proportional to work item count. The init/survey mapping step compensates by collecting user-language aliases once.

Why **`surfaces` field** instead of calling all specialists from all commands: not every specialist is relevant to every command. A health specialist adds value to morning day briefings but may be noise in a month-horizon review. `surfaces` gives user control over where specialist advice appears without modifying specialist logic.

Why **`source` field tracks provenance**: Phase 14 auto-activation needs to distinguish user-registered specialists (never auto-deactivate) from auto-suggested ones (may be auto-deactivated if area coverage drops). Without provenance, auto-cleanup would risk removing user choices.

Why **`priority_hint` defaults to "normal"**: most users start with 1-3 specialists of equal importance. Forcing priority assignment at registration time creates unnecessary friction. Users can adjust after seeing how specialist insights interact in practice.

## Cultural and Domain Assumptions

The 3 default specialists (health, finance, learning) encode assumptions about which life areas are universally relevant. These are not universal:
- Not everyone tracks exercise or has fitness goals.
- Not everyone manages personal finance actively.
- Not everyone is in a learning phase.

Mitigations:
- Default specialists that don't match any `core_areas` are set to `status: "inactive"` during init/survey mapping. They exist but don't activate.
- The init/survey mapping step asks the user to confirm each mapping, preventing unwanted specialist activation.
- `source: "default"` marks these as system-provided defaults, not user choices. Phase 14 auto-activation will respect user-registered specialists over defaults.
- Users can add specialists for any area (e.g., "parenting", "creative writing", "spiritual practice") — the schema is domain-agnostic.

When extending with new default specialists, do not assume the new domain is universally relevant. Follow the same inactive-until-mapped pattern.

## Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| `specialists.json` missing | No specialists called. Commands behave as before Phase 13 |
| `specialists.json` has zero active entries | No specialists called. Chief of staff omits Specialist Insights |
| Specialist agent file missing | Skip that specialist. Log warning in output |
| No area-matching work items | Skip that specialist. `no-data` status if called anyway |
| `entities.json` missing | `area_goals` passed as empty array. Specialist reports `no-data` or works from work items only |
| `personal-profile.json` missing | `personal_context` passed as empty string. Specialist works without direction context |

## Validation Rules

1. `version` must be `1`.
2. Each `id` must be unique within the `specialists` array.
3. `agent` path must be a valid relative path ending in `.md`.
4. `area_refs` must contain at least one string.
5. `status` must be one of: `active`, `inactive`, `suggested`.
6. `surfaces` must contain only valid values: `day`, `agenda`, `review`.
7. `priority_hint` must be one of: `high`, `normal`, `low`.
8. `source` must be one of: `generated`, `manual`, `auto`, `default`.
9. `registered` must be an ISO date string.
10. `auto_state`, when present, must contain `last_evaluated`, `last_declined_at`, and `last_matched_at` (each string or null).
11. `suggestion_reason` must be a string when present.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/domain-specialization/SKILL.md` | Parent skill — specialist methodology and advice workflow |
| `skills/pa/domain-specialization/examples/*.md` | Read-only exemplar specialists for generation reference |
| `agents/pa/specialists/*.md` | Runtime-generated specialist agent definitions referenced by `agent` field |
| `skills/pa/personal-profiling/references/profile-schema.md` | Source of `core_areas` for area mapping |
| `commands/pa/init.md` | Creates specialists.json during bootstrap |
| `skills/pa/domain-specialization/references/activation-signals.md` | Dynamic activation signal rules, thresholds, and auto_state schema |
| `commands/pa/survey.md` | Updates specialists.json area mappings and coverage signals on refresh |
