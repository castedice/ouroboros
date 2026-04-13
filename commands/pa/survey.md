---
name: pa:survey
description: "Use when you need to onboard an existing Obsidian vault by scanning its structure and conventions"
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

# Survey — Existing Vault Onboarding

Scan an existing Obsidian vault, infer its structural conventions, build a vault profile, register QMD, and initialize the `.pa/` state directory.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 4 | cartographer (agent, sonnet) | Infer vault archetype, folder roles, naming conventions, and profile draft from scan packet |
| 7 | weaver (agent, sonnet) | Extract entities, relations, and atomic facts from vault notes using structural signals |
| 1, 5, 5.5 | AskUserQuestion (tool) | Gather missing vault path, present the vault profile, and run personal profile catch-up questions |
| 3, 7 | Glob, Read, Grep (tools) | Vault structure scanning, note sampling, and work/timeline extraction |
| 6 | Bash (tool) | QMD CLI registration and embedding |
| 7 | Write (tool) | Persist `.pa/` state files and extracted overlays |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass scan packet contents, refresh baselines, and inline sampled note excerpts on every call.
Use named return payloads rather than prose-only summaries.
The command owns user checkpoints, `.pa/` state writes, and QMD registration side effects.
Internal calls use `Agent(subagent_type: "ouroboros:pa:cartographer")` and `Agent(subagent_type: "ouroboros:pa:weaver")`.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:pa:cartographer` | 4 | `scan_data`, `survey_mode`, `capability_tier`, posture seed, and caller diagnostics | `vault_profile_draft`, `human_summary`, `open_questions`, and `boundary_notes` |
| `ouroboros:pa:weaver` | 7 | `notes`, confirmed `vault_profile`, existing ontology state when refreshing, optional `personal_profile`, and optional privacy data | `entities`, `relations`, `entity_revision_rows`, `memories`, `memory_links`, `memory_heads`, and `limitations[]` |

## State Contract

| File | Reference | Purpose |
|------|-----------|---------|
| `.pa/vault-profile.json` | `skills/pa/vault-modeling/references/profile-schema.md` | Machine-readable vault adapter |
| `.pa/vault-profile.md` | `templates/pa/vault-profile.md` | Human-readable mirror for inspection and edits |
| `.pa/personal-profile.json` | `skills/pa/personal-profiling/references/profile-schema.md` | Existing personal profile baseline plus approved catch-up updates |
| `.pa/mask-map.json` | `skills/pa/personal-ontology/references/privacy-node-schema.md` | Real name to mask_id mappings for privacy-bearing entities — read if present |
| `.pa/people/profiles/*.json` | `skills/pa/personal-ontology/references/people-schema.md` | Person profiles — read if present |
| `.pa/work.jsonl` | `skills/pa/executive-assistance/references/work-schema.md` | Extracted work overlay: tasks, deadlines, waiting-fors, habits, and commitments |
| `.pa/timeline.jsonl` | `skills/pa/executive-assistance/references/timeline-schema.md` | Extracted timeline overlay: events, milestones, recurring anchors, and dated notes |
| `.pa/entities.json` | `skills/pa/personal-ontology/SKILL.md` | Extracted vault and life entities with `ontology_family`, canonical sources, kinds, and provenance |
| `.pa/relations.json` | `skills/pa/personal-ontology/SKILL.md` | Discovered relations with types, evidence, and confidence |
| `.pa/entity-revisions.jsonl` | `skills/pa/personal-ontology/references/entity-revision-schema.md` | Append-only identity history for merges, splits, and other entity-level changes |
| `.pa/memories.jsonl` | `skills/pa/personal-ontology/references/memory-schema.md` | Append-only atomic fact log grounded in source notes |
| `.pa/memory-links.jsonl` | `skills/pa/personal-ontology/references/memory-schema.md` | Fact-to-fact edges for support, contradiction, supersession, and derivation |
| `.pa/memory-heads.json` | `skills/pa/personal-ontology/references/memory-schema.md` | Active fact materialized view keyed by `claim_key` |
| `{shadow_root}/` | `skills/pa/personal-ontology/references/privacy-node-schema.md` | Masked copies of vault notes in external cache (`~/.cache/ouroboros/shadow/{vault-id}/`) |
| `.pa/deny-paths.json` | `skills/pa/trust-and-boundaries/references/read-boundaries.md` | Authored-path Read deny configuration for PreToolUse hook |
| `.pa/transmission-ledger.jsonl` | `skills/pa/personal-ontology/references/privacy-node-schema.md` | Audit trail of data transmitted to AI |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No vault path | 1 | Ask the user for a project-relative or absolute vault path |
| Path does not exist or is unreadable | 1 | Abort with a correction request |
| Path has no markdown notes | 1 | Stop and recommend `/pa init <vault-path>` |
| No `.obsidian/` in path | 1 | Warn: not an Obsidian vault. Proceed with caution |
| `.pa/` exists | 1 | Ask the user to choose `refresh` or `full re-survey`, then apply the Survey Mode Contract |
| QMD not found | 2 | Fail with a QMD install and enablement guide |
| QMD is reachable only via CLI, or registration/indexing later degrades | 2, 6, 8 | Apply the QMD Registration Contract and record the degraded state |
| Obsidian CLI not found | 2 | Warn and continue without enhanced runtime metadata |
| `ob` not found | 2 | Warn and continue without sync capability |
| Vault < 30 notes | 3 | Inspect all notes (no sampling) |
| Sample read failures | 3 | Record in diagnostics, continue with available notes |
| Scan coverage is partial | 3 | Continue with diagnostics and a lower confidence ceiling |
| Cartographer times out or errors | 4 | Retry once with a condensed packet |
| Cartographer returns low confidence | 5 | Present open questions before confirmation |
| User requests focused edits | 5 | Patch the draft or rerun the cartographer once with the answers |
| User rejects profile | 5 | Loop: adjust corrections, re-present changed fields |
| User aborts | 5 | Cancel onboarding, no state written |
| Personal-profile state requires bootstrap, skip, or targeted catch-up | 5.5 | Apply the Personal Profile Catch-Up Contract |
| Work extraction finds no items | 7 | Write an empty `.pa/work.jsonl`, continue gracefully, and report zero extracted work items |
| Timeline extraction finds no events | 7 | Write an empty `.pa/timeline.jsonl`, continue gracefully, and report zero extracted timeline items |
| No readable personal profile is available by entity extraction time | 7 | Skip life-entity extraction and continue with vault entities only |
| `.pa/mask-map.json` exists | 7 | Pass mask-map to weaver for privacy-bearing entity normalization |
| No mask-map or people data | 7 | Skip privacy-bearing entity normalization — continue with standard entity extraction |
| A state file write fails | 7 | Retry that file once and report any residual gap |

## Capability Tier Matrix

| Detected Tools | Tier | Survey Behavior |
|----------------|------|-----------------|
| QMD + `ob` + Obsidian CLI | `enhanced` | Full onboarding plus optional runtime metadata |
| QMD + `ob` | `full` | Full onboarding with sync capability |
| QMD only | `standard` | Full onboarding without sync or runtime metadata |
| Filesystem only | `fallback` | Unsupported for `/pa survey`, so abort after detection |

## Detection Outputs

Store `qmd_mode` (`mcp`/`cli`/`missing`), `capability_tier`, `obsidian_cli`, `sync_available`, and `default_posture` (`propose` per `skills/pa/trust-and-boundaries/references/posture-matrix.md`). These fields feed the Capability Tier Matrix and downstream phases.

## Scan Packet Contract

Build a scan packet matching the Input Contract in `agents/pa/cartographer.md`. Required parts: `caller_context`, `folder_tree`, `folder_stats`, `sample_manifest`, `sampled_notes`, `frontmatter_stats`, `linking_stats`, `caller_diagnostics`. Optional: `runtime_metadata` (Obsidian CLI extras).

## Survey Mode Contract

This is the authoritative mode-selection table for `refresh` versus `full re-survey`.
Phases 1, 4, 5, 6, and 7 reference this table instead of restating the split inline.

| Mode | Trigger | Phase Behavior |
|------|---------|----------------|
| `full re-survey` | `.pa/` is absent, or the user selects `full re-survey` when `.pa/` already exists | Treat the new scan as authoritative, run the normal confirmation cycle, and regenerate derived state after approval |
| `refresh` | `.pa/` already exists and the user selects `refresh` | Read the existing `vault-profile.json` as the cartographer baseline, present only changed fields in Phase 5, skip QMD re-registration when `qmd_status: "registered"`, and merge regenerated overlays while preserving user-owned settings fields in Phase 7 |

## Personal Profile Catch-Up Contract

This table is the authoritative gate for missing, recent, and stale personal-profile states.

| Profile State | Behavior |
|---------------|----------|
| `.pa/personal-profile.json` is missing | Offer the bootstrap interview via `skills/pa/interviewing/SKILL.md` in `bootstrap` mode, ask 5 bootstrap questions from `skills/pa/interviewing/references/question-patterns.md`, or let the user skip with "프로필 인터뷰를 건너뛰시겠어요? 나중에 다시 할 수 있어요.". Store the bootstrap seed as `$PERSONAL_PROFILE` with confidence `0.4` only if the user participates |
| `last_interview < 30 days` | Skip Phase 5.5 and keep the stored profile unchanged |
| Existing profile has no material gaps after gap detection | Skip Phase 5.5 and keep the stored profile unchanged |
| Existing profile has missing, stale, or contradictory gaps | Run `skills/pa/interviewing/SKILL.md` in `catch-up` mode, apply `skills/pa/personal-profiling/SKILL.md` gap detection against Phase 3 evidence, the confirmed vault profile, and optional memory observations, ask 2-3 narrow gap-based questions, and optionally add one insight-driven follow-up per `skills/pa/domain-specialization/references/insight-accumulation.md` |

## Recovery And Degradation Contracts

Use `skills/pa/context-assembly/references/qmd-gate.md` for the hard-vs-degraded semantics and the contract below for the concrete Phase 6 route selection.

### QMD Registration Contract

| Route | Trigger | Behavior | Recorded State |
|-------|---------|----------|----------------|
| Reuse existing registration | `survey_mode = "refresh"` and `$VAULT/.pa/settings.json` already shows `qmd_status: "registered"` | Skip new registration and keep the existing collection identity | Preserve `qmd_status: "registered"` and the current `qmd_mode` |
| MCP preferred | `qmd_mode = "mcp"` and the MCP path succeeds | Create or reuse the collection through MCP, then run the embed or update path there | Record `qmd_mode: "mcp"` and `qmd_status: "registered"` |
| CLI fallback | MCP is unavailable or failed, but the CLI path works | Create or reuse the collection through CLI and run the CLI embed or update path | Record `qmd_mode: "cli"` and `qmd_status: "registered"` unless embedding degrades |
| Embedding degraded | Collection registration succeeded but embedding or indexing failed | Continue to Phase 7 without retrying registration loops in this invocation | Record `qmd_status: "pending"` and the exact degraded warning |
| Registration unavailable | No MCP or CLI route succeeds | Continue to Phase 7 without a registered collection | Record `qmd_status: "pending"` and the exact failure reason |

## Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| Existing `.pa/` state | 1, 4, 5, 6, 7 | Resolve `refresh` versus `full re-survey` through the Survey Mode Contract |
| Vault has 30 or fewer notes | 3 | Inspect all notes instead of sampling |
| Legacy schema is detected | 3, 7, 8 | Continue in additive read-compatible mode and surface the migrate suggestion |
| Personal-profile state | 5.5 | Resolve bootstrap, skip, or targeted catch-up through the Personal Profile Catch-Up Contract |
| Learned overlay generator yields no new proposed diff | 5.6 | Skip that overlay without opening another approval loop |
| Learned overlay generator yields a proposed diff | 5.6 | Run the shared one-question approval loop and log the accept or reject outcome |
| QMD route or degradation | 6, 8 | Resolve registration, CLI fallback, or pending state through the QMD Registration Contract |
| Specialist registry already exists | 7 | Refresh it through `activation-signals.md` instead of recalculating the signal inline |
| No specialist registry exists but confirmed `core_areas` do | 7 | Offer initial specialist creation after bootstrap |
| Shadow sync or read-deny generation fails | 7, 8 | Keep the survey successful, mark the surface degraded, and report it |
| Only `vault-profile.md` rendering fails | 7, 8 | Keep JSON state files and report the mirror as missing |

## Phase 1: Parse Input

Extract vault path from `$ARGUMENTS`.

**Vault path resolution**: The argument must be an explicit path. Do not infer from current working directory — cwd auto-inference is forbidden because the plugin's cwd is the plugin root, not the user's vault.

Validate input per the Decision Matrix.
If no path is provided, ask the user.
If the path does not exist or has no markdown notes, abort with the appropriate guidance.
If `.pa/` exists, ask the user to choose `refresh` or `full re-survey`, store `survey_mode`, and use the Survey Mode Contract as the authoritative branch table.
If `.pa/` does not exist, treat the run as `survey_mode = "full re-survey"`.

Store the resolved absolute vault path as `$VAULT`.

## Phase 2: Tool Detection

Check availability of QMD (required), QMD MCP, ob CLI, and Obsidian CLI.
Store detection outputs and determine capability tier from the Capability Tier Matrix.
Handle each detection result per the Decision Matrix, `skills/pa/context-assembly/references/qmd-gate.md`, and the QMD Registration Contract.
If QMD is missing, abort.
If optional tools are missing, warn and continue.
If tier resolves to `fallback`, abort with guidance.

## Phase 3: Vault Scan

Build a comprehensive scan packet for the cartographer agent. This phase is data collection only — no inference or classification. Apply the intake and sampling rules from `skills/pa/vault-modeling/SKILL.md`.

**Note on Read deny**: This phase is the one-time raw vault exposure. Use `Bash` (e.g., `cat`, `head`) for raw note sampling instead of the `Read` tool when `deny-paths.json` is already configured. The Read guard hook will block `Read` tool calls on denied paths. For fresh surveys (no `deny-paths.json` yet), `Read` tool works normally.

### Step 1: Folder Tree

Glob the vault folder structure following scan depth from `skills/pa/vault-modeling/SKILL.md` (Step 1). Record the complete folder tree. Exclude `.obsidian/`, `.trash/`, `.git/`, `.pa/` from all subsequent analysis. Keep excluded paths in diagnostics when they explain missing coverage.

### Step 2: File Counts

Count markdown files per folder. Build a table of `folder -> markdown_count`.

### Step 3: Note Sampling

Follow the sampling strategy from `skills/pa/vault-modeling/SKILL.md` (Step 1). Record each sampled note's frontmatter, link count, basename, body excerpt, and relative path.

### Step 4: Frontmatter Statistics

Collect frontmatter statistics across sampled notes per `skills/pa/vault-modeling/SKILL.md` (Step 4). Identify candidate `common_fields`, `people_fields`, `theme_fields`, `rating_field`.

### Step 5: Linking Statistics

Collect linking statistics across sampled notes per `skills/pa/vault-modeling/SKILL.md` (Step 5). Identify dominant link syntax, hub-note candidates, and link density.

### Step 6: Obsidian CLI Enrichment (if `obsidian_cli = true`)

Use for cross-validation of file counts and supplemental evidence. Never let runtime metadata override the filesystem scan when they disagree.

### Packet Assembly

Bundle all collected data into the scan packet per the Scan Packet Contract table above. Assemble the packet exactly once and pass diagnostics forward rather than rescanning blindly.

### Step 7: Schema Version Check

After the scan packet is assembled, read `.pa/settings.json` if it exists and inspect `schema_version`.
If `schema_version` is missing or lower than `2.4.0`, surface a legacy-schema warning and suggest running `scripts/pa-migrate.sh apply 2.4.0`.
Continue the survey in additive read-compatible mode even when the migration has not been applied yet.

### Step 8: Temporal Backfill Advisory

Apply the survey backfill advisory procedure from `skills/pa/content-pipeline/references/temporal-grounding.md`.
Carry forward only the advisory count and the conservative `document_date` backfill suggestion.
Do not modify notes, derive `event_date`, or imply that the survey itself performs the backfill.

## Phase 4: Cartographer Delegation

> Agent: **cartographer**

Delegate vault profile inference to the cartographer agent.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | scan packet, survey mode, capability tier, posture seed, caller diagnostics. See the Survey Mode Contract for mode-specific baseline inputs |
| Instructions | Apply the vault-modeling workflow (`skills/pa/vault-modeling/SKILL.md`). Use `skills/pa/vault-modeling/references/archetype-heuristics.md` for archetype scoring and false-positive checks. Use `skills/pa/vault-modeling/references/profile-schema.md` to keep the draft within Phase 1 scope. Honor `skills/pa/trust-and-boundaries/SKILL.md` and keep `automation_posture` tied to the caller seed instead of inferring from structure. Use `hybrid` or `custom` instead of a forced named archetype when evidence is weak |
| Expected Output | Header, vault-profile.json draft, human summary table, open questions, boundary notes |

### Recovery

| Failure | Action |
|---------|--------|
| Timeout or tool error | Retry once with a condensed packet that preserves folder stats, sample manifest, and the strongest note evidence |
| Partial report | Reuse the recovered draft, turn missing sections into open questions, continue to confirmation |
| Contradictory signals | Keep confidence at medium or low and make the contradiction explicit in the preview |

## Phase 5: User Confirmation

Present the cartographer's output to the user. This is the mandatory checkpoint per the "Confirmation before expensive work" rule.

### Presentation Format

Render the preview with the headings and field order from `templates/pa/vault-profile.md`. Include archetype detection with top-3 scores, a structure summary table with confidence and evidence per area, and the cartographer's open questions for low-confidence fields.

### Confirmation Branches

| User Choice | Behavior |
|-------------|----------|
| Accept draft | Freeze the confirmed profile and continue |
| Edit a few fields | Patch the draft and continue without a rescan |
| Edit structural assumptions | Rerun the cartographer once with the answers as higher-priority evidence |
| Restart scan | Return to Phase 3 with the clarified scope |
| Decline all options | Abort without QMD registration or file writes |

### Recovery

Use one bounded correction loop for survey confirmation and one bounded retry per write-like surface.

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Profile preview correction | 1 field-patch cycle + 1 cartographer rerun after structural clarification | The rerun preserves the same unresolved structural disagreement or repeats the same open questions | Stop looping, summarize the unresolved differences, and ask the user to accept the current draft, return to starter selection, or abort |
| Restart scan | 1 restart after clarified scope | The rescanned packet still produces the same contradiction set | Stop rescanning in this invocation and require explicit user escalation to continue |
| File writes or derived overlay generation | 1 retry per file or generator | The retry fails for the same target or yields the same incomplete artifact | Report the target as degraded and continue with the surviving survey state only |

If `survey_mode = "refresh"`, apply the Phase 5 behavior from the Survey Mode Contract.

## Phase 5.5: Personal Profile Catch-Up (Conditional)

Resolve this phase through the Personal Profile Catch-Up Contract.
When the contract selects `catch-up`, apply `skills/pa/interviewing/SKILL.md` in `catch-up` mode and use `skills/pa/personal-profiling/SKILL.md` gap-detection rules before asking anything new.
Compare the current personal profile against Phase 3 vault activity evidence, the confirmed vault profile, and optional memory observations from `.pa/memory/observations.jsonl` to prioritize only missing, stale, or contradictory fields.
Use `AskUserQuestion` one prompt at a time and choose the narrowest prompts from `skills/pa/interviewing/references/question-patterns.md`.
For the optional specialist follow-up, apply the survey integration, pattern priority, context-only carry-forward, proposal logging, and confidence-adjustment rules from `skills/pa/domain-specialization/references/insight-accumulation.md`.
Draft the smallest bootstrap seed or approved patch that matches `skills/pa/personal-profiling/references/profile-schema.md` and round stored confidence per the schema guidance.
Store the resulting draft as `$PERSONAL_PROFILE` only when the contract produced one.
If this phase is skipped or produces no approved change, leave `.pa/personal-profile.json` untouched.
Never create a new personal profile from scan evidence alone in `/pa survey`.

## Phase 5.6: Learned Overlay Proposals (Conditional)

Use one shared approval loop for learned overlays instead of restating the same accept or reject flow twice.

### Learned Overlay Approval Contract

| Overlay | Generator | Skip Condition | Preview Prompt | Accept Action | Reject Action | Proposal Kind |
|---------|-----------|----------------|----------------|---------------|---------------|---------------|
| `preferences-learned.json` | `scripts/pa-feedback-analysis.sh preferences` | `.pa/assistant-ledger.jsonl` missing or fewer than 30 feedback entries | "PA가 학습한 패턴: {recommendation}. 근거: {evidence summary}. 적용할까요?" | Set the matching rule to `status: "approved"` and record `approved_at` | Set the matching rule to `status: "reverted"` and record `reverted_at` | `learned-preference` |
| `context-profiles.json` | `scripts/pa-feedback-analysis.sh context --generate` | Fewer than 20 command runs with context telemetry | "PA가 명령별 컨텍스트 예산을 조정했어요: {changed_profile_summary}. 적용할까요?" | Set the changed profile to `status: "approved"` and record `approved_at` | Set the changed profile to `status: "reverted"` and record `reverted_at` | `context-profile-refresh` |

1. Iterate the rows of the Learned Overlay Approval Contract in order.
2. Run the row's generator.
3. If the generator yields no new `status: "proposed"` entry or no diff from the approved baseline, skip that row.
4. Present exactly one approval question using the row's `Preview Prompt`.
5. Apply the row's accept or reject action and log the result to `.pa/proposals.jsonl` using the row's `Proposal Kind`.
6. Never open a second correction loop for the same overlay in the same survey run.

## Phase 6: QMD Registration

Create or reuse a stable QMD collection identity for the vault by executing the first matching route from the QMD Registration Contract in the Recovery And Degradation Contracts section.
Store the resulting QMD state for Phase 7 and the final report.

## Phase 7: State Initialization

Apply the write order, refresh merge rules, specialist registry refresh, content-pipeline detection, shadow bootstrap, and read-deny bootstrap from `skills/pa/vault-modeling/references/survey-bootstrap-contract.md`.
If `survey_mode = "refresh"`, apply the Phase 7 behavior from the Survey Mode Contract.
Regenerate `work.jsonl` and `timeline.jsonl` from the full vault, not just the Phase 3 sample set, using the extraction rules from `skills/pa/executive-assistance/references/work-schema.md` and `skills/pa/executive-assistance/references/timeline-schema.md`.
Delegate full-vault ontology extraction to the weaver per the contract below, then persist the returned `ontology_pack` in the state files named by the bootstrap contract.
If the vault has fewer than 5 authored notes, allow sparse extraction by skipping pairwise relation discovery when the weaver marks it too thin for meaningful connections, but still persist entities and atomic facts.
Retry a failed file write once before reporting it as degraded.
If only the human-readable mirror render fails, keep the JSON files and report the mirror as missing.

### Weaver Delegation Contract

> Agent: **weaver**

| Contract Part | Content |
|---------------|---------|
| Input | full-vault scan data or refresh manifest, confirmed `vault-profile.json`, current `settings.json`, existing `entities.json`, `relations.json`, `entity-revisions.jsonl`, `memories.jsonl`, `memory-links.jsonl`, and `memory-heads.json` when refresh state exists, optional `personal_profile`, optional `mask_map`, and any pre-registered person shells from `.pa/people/profiles/` |
| Instructions | Apply `skills/pa/personal-ontology/SKILL.md` workflows for entity extraction, relation discovery, revision diffing, atomic fact extraction, memory-link assembly, and privacy-bearing entity normalization. Use `skills/pa/personal-ontology/references/entity-canonicalization.md`, `entity-revision-schema.md`, `relation-taxonomy.md`, `memory-schema.md`, and `contradiction-resolution.md`. Return append-ready assistant-state artifacts only. Do not write files |
| Expected Output | `ontology_pack` containing materialized `entities`, `relations`, append-ready `entity_revision_rows`, `memories`, `memory_links`, rebuilt `memory_heads`, extraction counts, and any limitation or privacy-normalization notes |

## Phase 8: Report

### Soul Migration Check

Apply the legacy-persona migration and fallback contract from `skills/pa/persona-response/references/soul-fallback.md`.
If `.pa/persona.json` exists without `.pa/soul.md`, offer the migration prompt "기존 persona.json을 발견했어요. soul.md로 마이그레이션하면 성격과 원칙도 설정할 수 있어요. 변환할까요?" and follow the reference's transformation rules before the final render pass.

### Persona Application

Before presenting the report to the user, load render state through `skills/pa/persona-response/references/soul-fallback.md` and apply the persona render contract from `skills/pa/persona-response/references/render-contract.md`:
- Use the sentence style from `render_hints.sentence_style`
- Apply warmth level from `warmth`
- Apply directness level from `directness`
- Respect emoji setting from `render_hints.emoji`
- Do not alter substance: facts, rankings, evidence, confidence, citations, and action recommendations stay unchanged

Present the final result.
Include archetype with confidence, notes scanned, capability tier, QMD mode, posture, state file write status, ontology or memory extraction status, QMD registration status, and any warnings.
If the Phase 3 temporal backfill advisory found notes that could benefit from temporal backfill, include that count and remind the user that only `document_date` backfill is automated by `scripts/pa-migrate.sh apply 2.4.0`.

### Next Actions

Tailor next actions to the survey outcome:

| Condition | Suggested Action |
|-----------|-----------------|
| QMD registered successfully | `/pa ask "What are my most connected notes?"` — test semantic retrieval |
| QMD status is pending or degraded | Run `qmd collection add {vault}` and `qmd embed` to complete registration |
| Profile has low-confidence fields | Edit `{vault}/.pa/vault-profile.md` to refine uncertain fields, then re-run `/pa survey {vault}` to refresh |
| Always | `/pa brief {topic}` — generate a contextual briefing from vault content |

## Composability

| Context | Usage |
|---------|-------|
| `/pa init` | Survey's sibling — init creates fresh vaults, survey onboards existing ones. Both produce the same `.pa/` state structure |
| `/pa ask`, `/pa brief` | Primary consumers of vault profile and QMD registration |
| `/pa steward` | Reads settings.json for posture and capability tier |

A healthy QMD result makes `/pa ask` immediately useful. A degraded QMD result still leaves a valid vault profile, but retrieval-heavy commands should surface the degraded state first.

## Rules

- **Confirmation before expensive work**: No QMD indexing or `.pa/` file writes before user confirms the profile in Phase 5
- **cwd auto-inference forbidden**: The vault path must come from `$ARGUMENTS` or user input, never from the current working directory
- **Cartographer is read-only**: The cartographer agent analyzes the scan packet but never accesses the vault directly
- **Posture starts at `propose`**: Existing vaults get conservative posture per `skills/pa/trust-and-boundaries/SKILL.md`
- **Profile is user-editable**: After creation, the user may edit `vault-profile.md` directly — PA detects changes on next invocation
- **Report degraded states explicitly**: Never pretend onboarding is fully healthy when QMD or mirror-render failed
