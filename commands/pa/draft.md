---
name: pa:draft
description: "Use when you need to create or revise a vault note in the vault's established voice and structure"
effort: medium
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Agent
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__multi_get
  - mcp__qmd__status
argument-hint: "<topic|--revise path/to/note.md>"
---

# Draft — Intentional Note Creation and Revision

Create a new note or revise one existing note in the voice, structure, and placement rules your vault already uses.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2 | Read (tool) | Load settings, vault profile, retrieval overrides, target note, and local exemplars |
| 3 | librarian (agent, sonnet) | Optionally assemble a context pack when the draft needs vault grounding beyond the target note |
| 5 | scribe (agent, opus) | Produce a `write_plan` in vault-native voice from exemplars, context, and the permission envelope |
| 7 | Write/Edit (tools) | Create the note, apply the patch, and append the assistant ledger entry |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass target note paths, exemplar contents, and inline context on every call.
Use named return payloads rather than prose-only summaries.
The command owns note writes, declassification, and ledger updates.
Internal calls use `Agent(subagent_type: "ouroboros:pa:librarian")` and `Agent(subagent_type: "ouroboros:pa:scribe")`.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:pa:librarian` | 3 | `topic_or_revision_goal`, target note contents when revising, `vault_profile`, `settings`, and retrieval overrides | `context_pack`, `citations`, `coverage_assessment`, and `query_analysis` |
| `ouroboros:pa:scribe` | 5 | `topic`, `vault_profile`, `exemplars`, `permission_envelope`, optional `context_pack`, and target note contents | `write_plan`, `rendered_content`, `confidence`, `style_sources`, and `ledger_metadata` |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/vault-profile.json` | read | Placement rules, naming defaults, frontmatter defaults, linking style, and assistant preferences |
| `.pa/settings.json` | read | Collection name, capability tier, and active automation posture |
| `.pa/context-profiles.json` | read (optional) | Approved context budget for `draft` optional state loading |
| `.pa/preferences-learned.json` | read (optional) | Approved learned preferences for `draft` output shaping |
| `.pa/retrieval-profiles.json` | read (optional) | `draft` retrieval overrides for librarian grounding |
| `{vault note path}` | read/write | Target note for revision or destination note for creation |
| `.pa/assistant-ledger.jsonl` | append | Audit trail for proposals and applied note mutations |

## Unified Decision Table

| Branch | Trigger | Path Basis | Direct Tool | Outcome |
|--------|---------|------------|-------------|---------|
| Missing target | No target argument | n/a | n/a | Ask the user what they want to draft or which note they want to revise |
| Invalid revise input | `--revise` has no note path | n/a | n/a | Abort: "Provide a note path after `--revise`" |
| Missing setup | `.pa/settings.json` or `.pa/vault-profile.json` is missing | n/a | n/a | Abort: "Run `/pa survey` or `/pa init` first" |
| Missing revision target | Revision target path does not exist | target path | n/a | Abort: "Target note not found: {path}" |
| Shared fallback trigger | Posture is unreadable, grounding is required but unavailable, librarian confidence is low, scribe confidence is low, the permission envelope downgrades posture, or scope exceeds bounds | proposed or existing target path | n/a | Follow the Shared Fallback Policy |
| Creation under `observe` or `propose` | Mode is `creation` and effective posture is `observe` or `propose` | `vault-profile.json` placement rules | n/a | Present the exact proposed note only |
| Creation under `apply-low-risk` | Mode is `creation`, effective posture is `apply-low-risk`, `action_class=low-risk write`, and the path stays within existing allowed structure | approved new note path | `Write` | Create one note and append a ledger entry |
| Creation under `operate` | Mode is `creation`, effective posture is `operate`, and the path stays within bounded single-note scope that is already allowed or explicitly permitted by the profile | approved new note path | `Write` | Create one note and append a ledger entry |
| Creation blocked at write time | Creation would require a new folder, placement-rule change, or cross-note spillover not already allowed by the profile | proposed new note path | n/a | Present the proposal and the blocking reason |
| Revision under `observe` or `propose` | Mode is `revision` and effective posture is `observe` or `propose` | existing target path | n/a | Present the exact bounded patch only |
| Revision under `apply-low-risk` | Mode is `revision`, effective posture is `apply-low-risk`, `action_class=low-risk write`, and the revision stays within the bounded threshold | existing target path | `Edit` | Apply the bounded in-place patch and append a ledger entry |
| Revision under `operate` | Mode is `revision`, effective posture is `operate`, and the revision remains a bounded non-destructive single-note edit | existing target path | `Edit` | Apply the in-place patch and append a ledger entry |
| Revision blocked at write time | Revision implies destructive rewrite, rename, move, delete, folder migration, or cross-note spillover | existing target path | n/a | Present the proposal and require confirmation before any broader write |

## Shared Fallback Policy

When any branch routes to fallback, do all of the following.

1. Present the exact proposed note or exact bounded patch only, and do not mutate the vault.
2. Preserve librarian citations for every factual addition whenever a context pack exists.
3. Keep the request scoped to one visible note, with no rename, move, delete, folder migration, or multi-note spillover.
4. For revisions, use an exact in-place patch and never replace or reformat the full note, except for a strictly append-only change already authorized by the selected decision-table row.
5. Append a proposal record to `.pa/assistant-ledger.jsonl`.

### Recovery

Use a single bounded recovery loop for each delegated phase.

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Librarian grounding | 1 attempt + 1 narrowed retry using the smallest viable query | The retry returns no new citations, the same low-confidence result, or the same QMD failure | Stop retrying and route through the Shared Fallback Policy |
| Scribe planning | 1 full attempt + 1 narrower retry with tighter scope or proposal-only render | The retry still exceeds the permission envelope, misses required fields, or returns the same low-confidence result | Stop retrying and route through the Shared Fallback Policy |
| Declassification gate | 1 inspect pass + 1 declassify pass only | Irreversible residuals remain after the declassify pass | Block the write, present the blocked output contract, and do not attempt another write in this invocation |


## Phase 1: Parse Input

Extract the target from `$ARGUMENTS`.

If the first token is `--revise`, parse the remainder as a vault-relative markdown path and enter revision mode.
Otherwise, treat the full string as a creation topic and enter creation mode.

Creation mode drafts one new note.
Revision mode revises one existing note only.
Rename, move, delete, and multi-note edits are out of scope for this command.

Resolve missing or malformed input through the Unified Decision Table.

## Phase 2: Load State

1. Read `.pa/settings.json` and extract `automation_posture`, capability tier, and QMD collection name.
2. Read `.pa/vault-profile.json` and extract placement rules, naming rules, frontmatter defaults, linking style, and assistant preferences.
3. Read `.pa/context-profiles.json` (optional). If present, load the approved `draft` profile and use it to decide whether to skip optional state such as `retrieval-profiles.json`. If the file is missing or has no approved `draft` profile, follow the defaults from `skills/pa/context-assembly/references/loading-strategy.md`.
4. Read `.pa/retrieval-profiles.json` and look for `draft` overrides. If the file does not exist or the approved context profile excludes it, fall back to `vault-profile.json` -> `qmd_defaults`.
5. Read `.pa/preferences-learned.json` (optional). If present, load approved rules where `scope.command` matches `draft`. Apply rule effects during Phase 5 (scribe delegation) or Phase 7 (write decision). If file missing, continue without preference adjustments.
6. Do not infer posture from the conversation. The configured posture is authoritative.

If any required state file is missing, abort through the Unified Decision Table.

## Phase 3: Context Gathering

Gather only the context needed for one deliberate note operation.

1. Read `shadow_root` from `.pa/settings.json`. If `shadow_root` is set, prefer reading vault notes from `{shadow_root}/{relative_path}` instead of the raw vault path. Fall back to `.pa/shadow/` for backward compatibility. When Read deny is active, raw vault note reads will be blocked by the PreToolUse hook.
2. In revision mode, read the target note in full (via shadow path if available). Note: `--revise` with Read deny active limits revision to `proposal-only` because line-level matching against the shadow copy may diverge from the original.
3. Resolve the working folder from the target note's folder in revision mode, or from `vault-profile.json` placement rules in creation mode.
4. Sample `2-5` local exemplar notes from the same folder when available (via shadow paths if available).
5. Prefer authored notes over templates, and exclude the target note itself from the exemplar set when possible.
6. If no same-folder exemplars exist, continue with vault-profile defaults and the target note only.
7. Use the librarian only when the draft needs topic grounding, factual support, or cross-note synthesis beyond the target note and local exemplars.
8. When librarian grounding is needed, verify QMD availability via `mcp__qmd__status` before delegation.

### Optional Librarian Use

> Agent: **librarian**

Delegate vault grounding to the librarian only when local context is insufficient.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | topic string or revision goal, target note contents (if revising), vault-profile.json contents, settings.json contents, retrieval-profile overrides (if present) |
| Instructions | Apply `skills/pa/context-assembly/SKILL.md` workflow. Retrieve only the minimum context needed to ground the draft. Return a structured context pack with citations |
| Expected Output | Context pack with query analysis, retrieved excerpts, coverage assessment, and citation index |

### Recovery

| Failure | Action |
|---------|--------|
| QMD unavailable or librarian confidence is low when grounding is required | Route through the Shared Fallback Policy |
| Librarian returns zero results | Continue with exemplars only and avoid unsupported factual expansion |

## Phase 4: Permission Envelope

Before any writing, classify the change and build a permission envelope for the scribe.

1. Classify the action as `new-note-creation` or `single-note-revision`.
2. Treat the visible target note as `source-markdown`, even if PA created it previously.
3. Mark the action as `low-risk write` only when it touches one note, avoids rename, move, and delete, stays within bounded thresholds, and has direct provenance.
4. Mark the action as higher-risk when it creates a new folder, changes note placement rules, replaces more than `30%` of an existing note, or rewrites meaning rather than phrasing.
5. Compare the classified action to the active posture from `.pa/settings.json`.
6. If posture, provenance, or scope is weak, set the effective posture and fallback behavior that the Unified Decision Table will use.

### Permission Envelope Fields

| Field | Meaning |
|-------|---------|
| `mode` | `creation` or `revision` |
| `target_path` | existing note path or proposed new note path |
| `posture` | effective posture after any required downgrade |
| `action_class` | `low-risk write` or `high-risk write` |
| `scope_limits` | `max_files=1`, no rename, no move, no delete, no full-note reformat |
| `citation_policy` | preserve librarian citations when a context pack exists |
| `voice_sources` | same-folder exemplars plus vault-profile defaults |
| `fallback_policy` | use the Shared Fallback Policy when direct application is not allowed |

## Phase 5: Scribe Delegation

> Agent: **scribe**

Delegate note planning and drafting to the scribe agent.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | `write_request` containing topic or revision target, target note contents, same-folder exemplars, optional context pack, vault-profile.json contents, settings.json contents, and permission envelope |
| Instructions | Write in vault-native voice from exemplars first. Respect vault-profile placement, naming, frontmatter, and linking rules. Use librarian citations for factual claims. Return a bounded `write_plan` only and do not write files. For revisions, preserve the note's intent and edit in place |
| Expected Output | `write_plan` with target path, note title, proposed content or exact bounded patch, citations used, confidence, scope estimate, and ledger metadata |

The `write_plan` must explicitly state whether the command would use `Write` or `Edit` if the Unified Decision Table authorizes application.
For revision mode, prefer an exact bounded patch over full-file replacement.

### Recovery

| Failure | Action |
|---------|--------|
| Scribe timeout | Report error and do not mutate the vault |
| `write_plan` exceeds the permission envelope or confidence is `low` | Route through the Shared Fallback Policy |

## Phase 6: Resolve Outcome

Apply the permission envelope and select the outcome from the Unified Decision Table.

1. Combine parsed mode, target path basis, structure risk, grounding status, permission envelope, and scribe confidence.
2. Choose the first matching row from the Unified Decision Table from top to bottom.
3. If the selected row routes to the Shared Fallback Policy, present the proposal and state the exact blocking reason.
4. If the selected row authorizes `Write` or `Edit`, carry that exact tool choice into Phase 7.

## Phase 7: Apply

### Declassification Gate

Before any Write or Edit tool call, run write-safe declassification on the scribe's rendered content:

1. Run `scripts/pa-write-safe.sh inspect` on the rendered markdown.
2. If `write_safe: true`, run `scripts/pa-write-safe.sh declassify` and use the declassified text as the final content.
3. If `write_safe: false`, route through the Shared Fallback Policy with `blocking_reason: "Irreversible mask residuals detected: {irreversible_tokens + unknown_masks}"`. Do not write.
4. If no mask-map exists (no privacy layer active), skip declassification and write the rendered content as-is.

### Write

1. If the selected row authorizes `Write` and declassification passed, use `Write` to create the note at the approved path with the declassified content.
2. If the selected row authorizes `Edit` and declassification passed, use `Edit` to apply the bounded patch with the declassified content.
3. Otherwise, do not mutate the note and keep the scribe output as a proposal.
4. Append a JSONL record to `.pa/assistant-ledger.jsonl` for every outcome, including proposal-only and declassification-blocked paths. Include `declassification: {applied: true|false|skipped, residuals: [...]}`, `state_files_loaded`, `state_files_used`, and `estimated_context_chars` in the record per the Context Telemetry section in `skills/pa/trust-and-boundaries/references/ledger-schema.md`.
5. Record at least: timestamp, command `draft`, posture, action, target path, citations, confidence, reversibility class, and reversal data when a write was applied.
6. After a successful Write or Edit, append a dirty_path entry to `.pa/derivation-state.json`: `{path, event: "draft:create"|"draft:revise", content_hash, queued_at, shadow_status: "pending", ontology_status: "pending"}`.

### Output Contracts

| Output Mode | Trigger | Required Shape |
|-------------|---------|----------------|
| `created` | `Write` succeeded | `Created: {target_path}`, full rendered note, `Grounding`, `Posture`, `Gate`, and any reversal data |
| `revised` | `Edit` succeeded | `Revised: {target_path}`, exact bounded patch or rendered delta, `Grounding`, `Posture`, `Gate`, and any reversal data |
| `proposed` | Shared Fallback Policy or posture block selected | `Proposed: {target_path_or_topic}`, full proposed note or exact bounded patch, `Grounding`, `Posture`, `Gate`, and explicit blocking reason |
| `blocked` | Declassification, scope, or structure guard blocked application after planning | `Blocked: {target_path_or_topic}`, proposal body or patch, exact `blocking_reason`, and the smallest change needed for a future apply path |
| `error` | Librarian or scribe failed after the bounded recovery budget | `Error: {phase}`, target or topic, exact failure reason, and one retry or narrowing suggestion |

Use the matching output mode in Phase 8 so every materially distinct outcome is reconstructable.


## Phase 8: Present

Show the result clearly and keep the action traceable.

### Result Format

{Created|Revised|Proposed}: {target_path_or_topic}

{final note content or exact bounded patch}

---
**Grounding:** {librarian citations used | local exemplars only}
**Posture:** {effective posture}

### Next Actions

After the result, suggest one relevant next step when natural.

| Condition | Suggestion |
|-----------|------------|
| Proposal only | "Want me to narrow this to a smaller revision or show the exact patch again?" |
| Topic is broad or under-grounded | "I can prepare a brief first - `/pa brief {topic}`" |
| Revision exposed a factual gap | "I can gather supporting context first - `/pa ask \"{question}\"`" |
| Raw material needs distillation before writing | "Use `/pa capture ...` first, then return to `/pa draft`" |

## Phase 9: Feedback Recording

If the Phase 7 outcome was `proposed` (not `completed` or `blocked`), record user feedback per the Feedback Recording Contract in `skills/pa/trust-and-boundaries/references/ledger-schema.md`.

Skip this phase in unattended mode.

## Composability

| Context | Usage |
|---------|-------|
| `/pa capture` | Capture turns raw material into structured inputs, and draft turns intentional inputs into durable notes |
| `/pa ask` | Ask provides citation-grounded vault context that draft can use for factual grounding |
| `/pa brief` | Brief produces a structured context pack that can precede a more deliberate draft |
| `/pa survey` | Survey produces the vault profile, posture, and QMD registration that draft depends on |

## Rules

- **Decision-table first**: Resolve the outcome from the Unified Decision Table before any markdown mutation
- **Shared fallback**: When confidence, scope, posture, or grounding is weak, use the Shared Fallback Policy instead of improvising a broader write
- **Voice from exemplars**: Match same-folder exemplars and vault-profile conventions before any generic writing prior
- **Single-note discipline**: Never expand a single-note request into rename, move, delete, folder migration, or multi-note work
- **Ledger every action**: Record proposals and applied writes in `.pa/assistant-ledger.jsonl`
EXTRACTION_FAILED
