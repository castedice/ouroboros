---
name: pa:specialist
description: "Use when you need to create, inspect, or manage domain specialists for your vault"
effort: medium
allowed-tools:
  - Read
  - Write
  - Agent
  - AskUserQuestion
argument-hint: "create <area> | list | remove <id>"
---

# Specialist — Domain Expert Management

Create, list, or manage domain specialists through persona interviews. Each specialist is a unique expert shaped by the user's stated perspective for a specific life area.

Action: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2 | Read (tool) | Load settings.json, personal-profile.json, specialists.json |
| 3 | AskUserQuestion (tool) | Persona interview (2-3 questions) |
| 4 | generator (agent) | Generate specialist agent definition from interview results |
| 5 | Write (tool) | Persist generated agent file and update registry |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/settings.json` | read | Vault path |
| `.pa/personal-profile.json` | read (optional) | core_areas for area validation, directions_by_area for context |
| `.pa/specialists.json` | read+write | Specialist registry |
| `agents/pa/specialists/{id}.md` | write | Generated specialist agent definition |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No argument | 1 | Show usage: `create <area>`, `list`, `remove <id>` |
| `create` without area | 1 | Ask: "어떤 영역의 전문가를 만들까요?" |
| `create` with area that already has an active specialist | 1 | Ask: "이미 '{area}' 전문가가 있어요. 새로 만들까요, 기존 것을 수정할까요?" |
| `list` | 2 | Show all registered specialists with status |
| `remove` without id | 1 | Abort: "Provide a specialist id to remove" |
| `remove` with unknown id | 2 | Abort: "Specialist '{id}' not found" |
| No `.pa/settings.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/specialists.json` | 2 | For `create`: initialize empty registry. For `list`/`remove`: abort with "No specialists registered" |

## Phase 1: Parse Input

Parse `$ARGUMENTS` as an action with optional parameter.

Accepted forms:
- `create <area>` — generate a new specialist for the given area
- `create` — ask for area interactively
- `list` — show registered specialists
- `remove <id>` — deactivate and remove a specialist

## Phase 2: Load State

1. Read `.pa/settings.json` for vault path.
2. Read `.pa/specialists.json` if it exists.
3. Read `.pa/personal-profile.json` if it exists — extract `core_areas` and `directions_by_area`.
4. For `list`: proceed to Phase 5 (Present). For `remove`: proceed to Phase 4b.

## Phase 3: Persona Interview (`create` only)

Run the specialist persona interview from `skills/pa/interviewing/references/question-patterns.md` (Specialist Persona Questions section).

### Interview Flow

Run the Specialist Persona Questions from `skills/pa/interviewing/references/question-patterns.md` using `AskUserQuestion` one question at a time. Use the area-specific example hints from that reference to adapt prompt wording. Respect skips.

Store interview answers as `$SPECIALIST_PERSONA`.

### Interview Recovery

| Failure | Action |
|---------|--------|
| User skips all questions | Generate a balanced/neutral specialist (style: "균형", no priority override). Note in confirmation that defaults were used |
| User aborts mid-interview | Discard partial answers. Do not write any files. Report: "전문가 생성을 취소했어요. 나중에 `/pa specialist create {area}`로 다시 할 수 있어요." |
| AskUserQuestion timeout | Treat as skip for that question. Continue with remaining questions |

## Phase 4a: Generate Specialist (`create` only)

Delegate specialist generation to the **generator** agent:
- **Input**: `$SPECIALIST_PERSONA` from Phase 3, exemplar files from `skills/pa/domain-specialization/examples/`, and the Agent Generation Contract from `skills/pa/domain-specialization/SKILL.md`
- **Instructions**: "Generate a specialist agent definition for area '{area}' incorporating the persona. Core Principles reflect the user's stated perspective. Domain Methodology includes 2-3 assessment methods. Calibration includes 1 Bad/Good pair. Structure matches exemplar patterns exactly. Return full agent file content plus `perspective_summary`."
- **Expected output**: Complete agent definition content + `perspective_summary` string

### Post-Generation Steps

1. Derive `{area_id}` from the area name: lowercase, kebab-case, ASCII-safe (e.g., "사이드 프로젝트" → "side-project", "운동" → "exercise").
2. Write generator output to `agents/pa/specialists/{area_id}.md`.
3. Update `.pa/specialists.json`: add entry with `status: "active"`, `source: "generated"`, area_refs including the user's area name.
4. Present a summary to the user: "'{area}' 전문가를 만들었어요. 관점: {perspective_summary}. 스타일: {style}."

### Generation Recovery

| Failure | Action |
|---------|--------|
| No exemplar files in `skills/pa/domain-specialization/examples/` | Generate using the Agent Generation Contract from SKILL.md without exemplar reference. Note lower structural confidence |
| Write to agent file fails | Retry once. If still fails, report error with the generated content in conversation so user can save manually |
| specialists.json write fails | Report error. The agent file was written but registry is inconsistent — instruct user to add the entry manually |
| Generated agent exceeds 300 lines | Trim Domain Methodology to 2 methods (drop the least relevant). Calibration to 1 pair only |

## Phase 4b: Remove Specialist (`remove` only)

1. Find the specialist entry by id in specialists.json.
2. Set `status: "inactive"`. Do not delete the agent file or registry entry.
3. Report: "'{id}' 전문가를 비활성화했어요. 다시 활성화하려면 specialists.json에서 status를 active로 변경하세요."

## Phase 5: Present (`list` only)

Show all registered specialists:

```markdown
## Registered Specialists

| ID | Area | Status | Perspective | Source |
|----|------|--------|-------------|--------|
| {id} | {area_refs[0]} | {status} | {first line of Core Principles} | {source} |
```

If no specialists are registered: "등록된 전문가가 없어요. `/pa specialist create <area>`로 만들 수 있어요."

## Next Actions

| Action | Condition | Suggestion |
|--------|-----------|------------|
| `create` completed | Always | "`/pa day`로 새 전문가의 조언을 확인해 보세요" |
| `create` completed, more core_areas without specialists | When unmatched areas exist | "`/pa specialist create {next_area}`로 다른 영역도 만들 수 있어요" |
| `list` shows all inactive | When no active specialists | "활성화하려면 specialists.json에서 status를 active로 변경하거나, `/pa specialist create`로 새로 만드세요" |
| `remove` completed | Always | "`/pa specialist list`로 현재 상태를 확인하세요" |

## Composability

| Context | Usage |
|---------|-------|
| `/pa init` | Init Phase 7 uses the same generation workflow for initial specialist setup |
| `/pa survey` | Survey Phase 7 offers generation for new areas |
| `/pa day`, `/pa agenda` | Phase 3.5 consults active specialists |
| `skills/pa/domain-specialization/SKILL.md` | Generation methodology and advice workflow |

## Rules

- **Interview before generation**: Never generate a specialist without the persona interview. The perspective shapes the expert.
- **Exemplar-guided**: Use existing specialists as structural patterns. Generate fresh domain content from interview answers.
- **No auto-activation**: Generated specialists start as `active` only after user confirms in Phase 4a.
- **Soft remove**: `remove` sets status to inactive, never deletes files. Recovery is always possible.
- **Persona application**: Apply persona render contract when presenting to the user.
