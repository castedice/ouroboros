---
name: pa:init
description: "Use when you need to set up a new Obsidian vault for PA"
effort: high
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
  - Agent
  - AskUserQuestion
argument-hint: <vault-path>
---

# Init — Fresh Vault Bootstrap

Create a new Obsidian vault from scratch with user-guided scaffolding, starter templates, QMD registration, and `.pa/` state initialization.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 4 | cartographer (agent, sonnet) | Assemble vault-profile.json draft from selected starter profile and interview answers |
| 3, 3b, 3d, 4, 9 | AskUserQuestion (tool) | Vault interview, personal profile bootstrap, persona interview, profile selection, sync opt-in |
| 3c | AskUserQuestion, Bash (tools) | People bootstrap interview, pa-mask.sh for registration |
| 5 | Write (tool) | Create folder structure and starter templates |
| 6 | Bash (tool) | QMD CLI registration and embedding |
| 7, 8 | Write (tool) | Persist `.pa/` state files and welcome note |

## State Contract

| File | Reference | Purpose |
|------|-----------|---------|
| `.pa/vault-profile.json` | `skills/pa/vault-modeling/references/profile-schema.md` | Machine-readable vault adapter |
| `.pa/vault-profile.md` | `templates/pa/vault-profile.md` | Human-readable mirror for inspection and edits |
| `.pa/personal-profile.json` | `skills/pa/personal-profiling/references/profile-schema.md` | Seeded personal profile for direction-aware support |
| `.pa/mask-map.json` | `skills/pa/personal-ontology/references/people-schema.md` | Real name to mask_id mappings (sensitive) |
| `.pa/people/profiles/*.json` | `skills/pa/personal-ontology/references/people-schema.md` | Individual person profiles (sensitive) |
| `.pa/soul.md` | `skills/pa/persona-response/references/persona-schema.md`, `templates/pa/soul.md` | PA soul layer — render settings (frontmatter) + reasoning personality (body) |
| `.pa/specialists.json` | `skills/pa/domain-specialization/references/specialist-registry.md` | Domain specialist registry and area mappings |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No vault path | 1 | Ask the user for a destination path |
| Path does not exist | 1 | Ask whether PA should create the vault directory |
| Parent directory does not exist | 1 | Error + abort |
| Path exists and already has authored markdown | 1 | Recommend `/pa survey <vault-path>` instead |
| Path exists but empty | 1 | Proceed — valid fresh start |
| `.pa/` exists | 1 | Offer `reuse existing state` versus `reinitialize` |
| QMD not found | 2 | Fail with a QMD install and enablement guide |
| QMD MCP missing but CLI works | 2 | Continue in CLI mode and record degraded QMD mode |
| Obsidian CLI not found | 2 | Warn and continue without enhanced runtime metadata |
| `ob` not found | 2 or 9 | Warn and skip sync setup |
| Purpose = Work or Mixed | 3 | Ask optional question about project structure preference |
| Journaling = Yes | 3 | Ask optional question about date format preference |
| User skips personal interview | 3b | Create a minimal personal profile draft with `confidence.overall = 0.0` and continue |
| User skips people registration | 3c | Continue without people data — no `.pa/people/` created |
| User registers people | 3c | Create mask-map.json, people profiles, and entity shells |
| User skips soul interview | 3d | Store default soul and continue |
| User chooses a starter profile with custom edits | 4 | Patch the seeded draft before any scaffold writes |
| User rejects the seeded profile | 4 | Revise or rerun the cartographer once |
| Custom profile selected | 4 | Pass user description to cartographer for custom layout |
| Scaffold target already exists | 5 | Ask overwrite, keep, or skip per conflicting path |
| QMD indexing fails | 6 | Warn and continue to state initialization |
| MCP path failed but CLI path works | 6 | Downgrade to CLI mode and continue |
| `Getting Started.md` already exists | 8 | Ask whether to overwrite, rename, or skip |
| Sync offer declined | 9 | Skip sync setup without failing bootstrap |
| Sync step fails | 9 | Warn, keep bootstrap complete, report failure |

## Capability Tier Matrix

| Detected Tools | Tier | Init Behavior |
|----------------|------|---------------|
| QMD + `ob` + Obsidian CLI | `enhanced` | Full bootstrap plus optional runtime metadata |
| QMD + `ob` | `full` | Full bootstrap with optional sync setup |
| QMD only | `standard` | Full bootstrap without sync or runtime metadata |
| Filesystem only | `fallback` | Unsupported for `/pa init`, so abort after detection |

## Starter Profiles

| Starter | Archetype | Best For | Scaffold | Nav | Subfolders | Journal |
|---------|-----------|----------|----------|-----|------------|---------|
| `kepano-flat` | `flat-kepano` | Shallow evergreen, link-heavy | `Daily/`, `Templates/`, `Attachments/`, `References/`, `Clippings/`, `Categories/` | `quick-switcher` | `false` | per interview |
| `nested-project` | `nested-project` | Project-heavy, deep folders | `projects/`, `areas/`, `resources/`, `templates/`, `attachments/` | `folder-first` | `true` | per interview |
| `para-like` | `para-like` | Responsibility buckets | `Projects/`, `Areas/`, `Resources/`, `Archive/`, `Templates/`, `Attachments/` | `hybrid` | `false` | per interview |
| `journal-first` | `journal-first` | Daily-note driven capture | `Daily/`, `Periodic/`, `References/`, `Templates/`, `Attachments/` | `quick-switcher` | `false` | `traditional` |
| `custom` | `custom` | User-described layout | per interview | per interview | per interview | per interview |

## Interview Questions

| Question | Purpose | Example Options |
|----------|---------|-----------------|
| Primary purpose | Recommend a starter profile and note defaults | `personal`, `work`, `learning`, `mixed` |
| Domains of interest | Scope the vault's content coverage | free-text: "software engineering, book notes, travel" |
| Journaling habit | Seed `journal_style` and daily-note defaults | `none`, `daily notes`, `timestamp captures`, `both` |
| Folder bias (optional, if mixed signals) | Resolve starter preference | `keep it shallow`, `group by projects`, `use PARA buckets`, `let PA recommend` |
| Date format (optional, if journaling) | Seed daily note pattern | `YYYY-MM-DD`, `YYYY/MM/YYYY-MM-DD`, custom |

Keep the interview to 3-5 questions. Skip optional questions when earlier answers make them unnecessary.

## Phase 1: Parse Input

Extract vault path from `$ARGUMENTS`. Do not infer from current working directory.

Validate input per the Decision Matrix. If no path provided, ask the user. If the path already contains an existing vault, redirect to `/pa survey`. If the parent directory does not exist, abort. If `.pa/` exists, offer reuse vs reinitialize.

Store the resolved absolute path as `$VAULT`. Do not create folders, notes, or `.pa/` files in this phase. Treat this phase as classification, not execution.

## Phase 2: Tool Detection

Same detection procedure as `/pa survey`. Check QMD (required), QMD MCP, ob CLI, and Obsidian CLI availability. Handle each result per the Decision Matrix. Determine capability tier from the Capability Tier Matrix. Seed `default_posture` as `apply-low-risk` per `skills/pa/trust-and-boundaries/SKILL.md`.

## Phase 3: User Interview

Ask 3-5 concise questions from the Interview Questions table. Capture answers as structured bootstrap inputs.

### Recommendation Hints

| Interview Signal | Recommended Starter |
|------------------|---------------------|
| Shallow notes plus reference-heavy workflow | `kepano-flat` |
| Project-heavy work with folder discipline | `nested-project` |
| Explicit bucket language (projects, areas, resources, archive) | `para-like` |
| Strong daily or timestamp habit | `journal-first` |
| Mixed signals | Present the top two and ask the user to choose |

Store all interview answers as `$INTERVIEW`. Do not write any files in this phase.

## Phase 3b: Personal Profile Interview

Run a personal profile bootstrap interview after the vault structure interview.
Apply `skills/pa/interviewing/SKILL.md` in `bootstrap` mode and ask the five bootstrap questions from `skills/pa/interviewing/references/question-patterns.md` one at a time with `AskUserQuestion`.
Use the `Role`, `Areas`, `Direction`, `Values`, and `Focus` slots from that reference as the default sequence.
Offer this skip option before the first question and whenever the user wants to opt out: "프로필 인터뷰를 건너뛰시겠어요? 나중에 `/pa survey`에서 할 수 있어요."
Synthesize confirmed answers into a seeded personal profile draft that matches `skills/pa/personal-profiling/references/profile-schema.md`.
Set `confidence.overall`, `confidence.identity`, `confidence.direction`, and `confidence.focus` to `0.4` for answered bootstrap profiles.
If the user skips, initialize the minimal valid object from the schema with all confidence fields at `0.0` and continue without asking more profile questions.
Store the resulting draft as `$PERSONAL_PROFILE`.
Do not write `.pa/personal-profile.json` in this phase.

## Phase 3c: Initial People Registration (Optional)

After the personal profile interview, offer to register key people.
This phase is entirely optional and can be skipped.

Ask: "삶에서 중요한 사람들을 등록하시겠어요? 나중에 언제든 추가할 수 있어요."

If the user agrees:
1. Ask how many people to register (suggest 3-5 to start)
2. For each person, run the people bootstrap questions from `skills/pa/interviewing/references/question-patterns.md` (People Bootstrap Questions section)
3. After receiving the real name (Question 1), immediately convert to mask_id using `scripts/pa-mask.sh add`
4. Use only mask_id for all subsequent questions and processing
5. Create `.pa/people/profiles/{mask_id}.json` for each registered person
6. Create person entity shells in the entity list for Phase 7

If the user skips, continue to Phase 4 without creating any people data.
Store registered people as `$PEOPLE_REGISTRY` for Phase 7.

### Entity Privacy Registration

Beyond people, the init process can optionally register known organizations, places, and other entities for privacy protection.
During the first `/pa survey` after init, the Weaver automatically assigns `mask_id` + `safe_name` to detected entities.
Users can also pre-register entities:

```bash
scripts/pa-mask.sh add "삼성전자" --kind org --safe-name "대기업 기술팀" --aliases "삼성,Samsung"
```

Pre-registered entities will be recognized and protected from the first survey onward.

### Cleartext Safety

Real names received via AskUserQuestion must be:
1. Converted to mask_id immediately after Question 1
2. Never stored in conversation logs or `.pa/` state beyond mask-map.json and profiles
3. Used only for the mask-map entry creation

## Phase 3d: Soul Interview (Optional)

After the people registration phase, offer to configure PA's soul layer (conversational persona + reasoning personality).
This phase is optional. If skipped, PA uses the default soul (professional-friendly, haeyo, no emoji, default principles/personality).

Ask: "PA의 성격과 말투를 설정할까요? 기본은 해요체예요."

If the user agrees, ask the soul questions from `skills/pa/interviewing/references/question-patterns.md` (Persona Questions (Soul Layer) section) one at a time with `AskUserQuestion`:

1. Speech style: "제가 어떤 말투로 도와드리면 편할까요? (해요체/합니다체/반말)"
2. Response style: "답변 스타일은 어떤 게 좋으세요? (부드럽게/균형/직설적으로)"
3. Emoji (optional): "이모지를 사용할까요? (안 쓸래요/조금/적당히)"
4. Relationship (optional): "PA와의 관계를 어떻게 느끼고 싶어요? (전문적인 비서/오래된 동료/친한 친구)"
5. Principles (optional): "PA가 어떤 원칙으로 도와드리면 좋을까요? 예: '사실 우선', '도전적으로', '안전하게'"

Questions 4-5 can be skipped: "이 질문은 건너뛰셔도 돼요. 기본 설정을 사용합니다."

Map answers to soul.md using the Interview-to-Schema Mapping (frontmatter) and Interview-to-Soul Mapping (body sections) from the question-patterns reference. Fill unmapped frontmatter fields with defaults from `skills/pa/persona-response/references/persona-schema.md`. Fill skipped body sections with defaults from `templates/pa/soul.md`.

Set `source: "interview"`, `version: 2`, `created` and `updated` to today's date.

Store the resulting soul draft as `$SOUL`. Write `.pa/soul.md` in Phase 7 alongside other state files. Do not create `.pa/persona.json` — soul.md replaces it.

If the user skips entirely, store the default soul from `templates/pa/soul.md` with `source: "default"` as `$SOUL`.

## Phase 4: Profile Selection

Present the four starter profiles from the Starter Profiles table. Recommend one based on the interview answers. Ask the user to choose a starter or customize one.

### Cartographer Delegation

> Agent: **cartographer**

After profile selection, delegate to cartographer for profile assembly.

| Contract Part | Content |
|---------------|---------|
| Input | Selected profile name, interview answers (`$INTERVIEW`), capability tier, customizations. For custom profiles, include the user's described layout |
| Instructions | Apply `skills/pa/vault-modeling/SKILL.md` in fresh-vault mode. Use `skills/pa/vault-modeling/references/profile-schema.md` for Phase 1 fields. Treat defaults as seeded choices, not observed facts. Set confidence ceiling to 0.45 per fresh-vault intake condition. Set `automation_posture` to `apply-low-risk`. Honor `skills/pa/trust-and-boundaries/SKILL.md` |
| Expected Output | Seeded vault-profile.json draft, scaffold plan, open questions, boundary notes |

Present the seeded draft using headings from `templates/pa/vault-profile.md`. Ask the user to accept or edit placement, journaling, frontmatter, linking, and posture settings.

### Confirmation Branches

| User Choice | Behavior |
|-------------|----------|
| Accept starter draft | Freeze the confirmed profile and continue |
| Edit a few fields | Patch the draft and continue |
| Change structural assumptions | Rerun the cartographer once with clarified answers |
| Reject the starter entirely | Return to starter selection without writing anything |
| Downgrade posture | Keep the rest of the draft and lower `automation_posture` before writes |

### Recovery

Use one bounded correction loop for the seeded profile and one bounded retry per write-like surface.

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Starter-draft correction | 1 field-patch cycle + 1 cartographer rerun after structural clarification | The rerun preserves the same unresolved structural disagreement or repeats the same open questions | Stop looping, summarize the unresolved differences, and send the user back to starter selection or abort before writes |
| Scaffold or state-file write | 1 retry per path | The retry fails for the same path or does not change the target state | Report the path as degraded and continue with the surviving bootstrap state only |
| QMD or sync setup | 1 attempt only | The same backend failure persists | Stop retrying, record the degraded status, and keep bootstrap complete without looping inside init |


See Rules: "No writes before confirmation".

## Phase 5: Scaffold Creation

Create the vault directory structure and starter templates based on the confirmed profile. Prefer the smallest viable scaffold that matches the chosen starter.

### Scaffold Contract

| Target | Source or Rule | Behavior |
|--------|----------------|----------|
| Vault root | confirmed path | Create only if missing and approved in Phase 1 |
| Starter folders | confirmed scaffold plan | Create only the chosen paths |
| Templates directory | confirmed `placement_rules.templates_dir` | Create only if present in the plan |
| `Profiled Note.md` | `templates/pa/profiled-note.md` | Write a starter generic note template |
| Daily directory | confirmed `placement_rules.daily_dir` | Create the folder only, with no extra template set |

Handle existing targets per the Decision Matrix (scaffold target already exists). Do not move, normalize, or rewrite existing markdown notes during bootstrap.

## Phase 6: QMD Registration

Create or reuse a stable QMD collection identity for the vault. Prefer MCP when `qmd_mode = "mcp"`, CLI fallback otherwise. Handle outcomes per the Decision Matrix. Store the resulting QMD status for Phase 7 and the final report.

## Phase 7: State Initialization

Create `.pa/` if it does not already exist.
Write the state files from the State Contract table in the listed order.
Write `schema_version: "2.4.0"` into `.pa/settings.json` when initializing a new PA setup.

After writing `vault-profile.json`, render the human-readable mirror `vault-profile.md` by reading `templates/pa/vault-profile.md` and replacing all `{{placeholder}}` tokens with values from the JSON. Apply the Render / Parse Contract rules from the template.
Write `.pa/personal-profile.json` from `$PERSONAL_PROFILE` without adding fields that were not directly confirmed in Phase 3b.
Write `.pa/soul.md` from `$SOUL`.
If `$PERSONAL_PROFILE` has `core_areas`, offer to create specialists for each area. For each area the user wants a specialist for, run the specialist persona interview from `skills/pa/interviewing/references/question-patterns.md` (Specialist Persona Questions) and generate a specialist agent at `agents/pa/specialists/{area_id}.md` following `skills/pa/domain-specialization/SKILL.md` (Specialist Generation). Use exemplars in `skills/pa/domain-specialization/examples/` as structural references. Register each generated specialist in `.pa/specialists.json` with `status: "active"` and `source: "generated"`. If the user declines specialists entirely, write an empty specialists.json (`{"version": 1, "specialists": []}`).

If `$PEOPLE_REGISTRY` contains registered people:
- Write `.pa/mask-map.json` with all registered entries
- Create `.pa/people/profiles/` directory
- Write individual `{mask_id}.json` profile files
- Add person entity shells to the entity list for later extraction

Key differences from survey: archetype confidence is low (seeded defaults, not observed evidence), all placement rules match folders actually created in Phase 5. If the user chose `reuse existing state`, preserve confirmed user-owned preference fields. Retry a failed file write once before reporting it as degraded.

## Phase 8: Welcome Note

Create a `Getting Started.md` note after scaffold and `.pa/` state are in place. Place it in the vault root or `placement_rules.default_new_note_parent`. Use confirmed naming rules and link style from the profile.

### Welcome Note Minimum Contents

| Section | Purpose |
|---------|---------|
| What PA set up | Summarize folders, template, and `.pa/` state |
| Where to write | Point to the confirmed default note parent and daily directory |
| Trust posture | Explain `apply-low-risk` in one short paragraph |
| First commands | Give `/pa ask` and `/pa brief` examples tied to the new vault |

If `Getting Started.md` already exists, ask whether to overwrite, rename, or skip. Keep the note short and operational — do not let it become a methodology manifesto.

## Phase 9: Sync Setup (Optional)

Skip this phase entirely if `ob_available = false`.

When `ob` CLI is available, ask the user whether PA should run `ob sync-create-remote` and `ob sync-setup`. Do not execute without explicit confirmation. Handle all sync outcomes per the Decision Matrix.

## Phase 10: Report

Present the final result using the following template:

```markdown
## PA Init Complete

### Vault Identity
- **Path**: {$VAULT}
- **Starter Profile**: {starter_label}
- **Archetype**: {archetype} (confidence: {confidence})
- **Purpose**: {purpose}

### Capability Summary
- **Tier**: {capability_tier}
- **QMD Mode**: {qmd_mode}
- **Posture**: {automation_posture}

### Scaffold Status
| Path | Status |
|------|--------|
| {folder_1} | created / skipped / existed |
| {folder_2} | created / skipped / existed |
| ... | ... |

### State Files
| File | Status |
|------|--------|
| `.pa/vault-profile.json` | written / failed |
| `.pa/vault-profile.md` | written / failed |
| `.pa/settings.json` | written / failed |
| `.pa/personal-profile.json` | written / failed |
| `.pa/soul.md` | written / skipped |
| `.pa/specialists.json` | written |
| `.pa/mask-map.json` | written / skipped |
| `.pa/people/profiles/` | {count} profiles / skipped |
| `.pa/derivation-state.json` | written / failed |

### QMD Registration
- **Status**: {qmd_status}
- **Collection**: {collection_name}

### Sync
- **Status**: {sync_status}

### Warnings
{warnings_or_none}

### Next Actions
- Open `{$VAULT}` in Obsidian and start creating notes
- `/pa ask "What's in my vault?"` — test PA after adding a few notes
- `/pa brief {domains[0]}` — try a domain briefing once you have content
- `/pa survey {$VAULT}` — re-survey after the vault has 30+ notes
```

## Composability

| Context | Usage |
|---------|-------|
| `/pa survey` | Init's sibling — survey onboards existing vaults, init creates fresh ones. Both produce the same `.pa/` state structure |
| `/pa ask`, `/pa brief` | Primary consumers of vault profile and QMD registration |
| `/pa steward` | Reads settings.json for posture and capability tier |

A healthy QMD result makes `/pa ask` immediately useful. If the vault stops being fresh because the user bulk-imports notes, switch to `/pa survey` for re-onboarding.

## Rules

- **No writes before confirmation**: No scaffold folders, `.pa/` files, or QMD registration before user confirms the profile in Phase 4
- **Interview is concise**: 3-5 questions maximum. Avoid over-scaffolding
- **Starter profiles are defaults, not constraints**: The user can change anything in vault-profile.md after creation
- **`apply-low-risk` default posture**: Fresh vaults get higher trust because there's no existing content to damage
- **cwd auto-inference forbidden**: Vault path must come from `$ARGUMENTS` or user input
- **Name collision avoidance**: Uses `name: pa:init` in frontmatter to avoid collision with built-in `/init` command
- **Report degraded states explicitly**: Never pretend bootstrap is fully healthy when QMD, mirror-render, or sync failed
