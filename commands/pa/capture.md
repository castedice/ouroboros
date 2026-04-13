---
name: pa:capture
description: "Use when you need to turn raw thoughts, scraps, or transcripts into structured vault material"
effort: medium
allowed-tools:
  - Read
  - Write
  - Agent
  - Bash
  - mcp__qmd__status
argument-hint: <raw text>
---

# Capture — Raw Input Intake

Capture raw text — a quick thought, bullet dump, transcript excerpt, or pasted scrap — into a single structured vault note shaped by the curator's triage and the vault profile's conventions.

Input: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2 | Read (tool) | Load settings.json, vault-profile.json, and capture state |
| 3 | curator (agent, sonnet) | Triage raw input, extract durable units, and recommend routing |
| 4 | librarian (agent, sonnet, optional) | Check semantic overlap or canonical notes only when `lookup_mode = qmd` |
| 6 | scribe (agent, opus, optional) | Render a vault-native note when final routing remains `profiled-note` |
| 7 | Write (tool) | Create the note file and append the capture ledger entry |
| 8 | Write (tool) | Append an approved decision entity to `.pa/entities.json` and append the decision ledger entry |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass raw input, vault profile state, and duplicate-assessment artifacts explicitly on every call.
Use named return payloads rather than prose-only summaries.
The command owns note writes, duplicate routing, declassification, and ledger or state updates.
Internal calls use `Agent(subagent_type: "ouroboros:pa:curator")`, `Agent(subagent_type: "ouroboros:pa:librarian")`, and `Agent(subagent_type: "ouroboros:pa:scribe")` when `profiled-note` rendering is needed.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:pa:curator` | 3 | `raw_text`, `vault_profile`, `settings`, permission seed, optional entity and session state, and optional temporal hints | `triage_report`, `note_type`, `route`, `extracted_items`, `resolved_entities[]`, and `unresolved_entities[]` |
| `ouroboros:pa:librarian` | 4 | title seed, extracted entities, `vault_profile`, `settings`, and `lookup_mode` | `duplicate_status`, `canonical_candidates[]`, `duplicate_evidence`, and optional `net_new_delta` |
| `ouroboros:pa:scribe` | 6 | `triage_report`, `vault_profile`, `permission_envelope`, and same-folder exemplars when available | `write_plan`, `rendered_content`, `confidence`, and `reversal_hint` |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/settings.json` | read | Automation posture, capability tier, QMD collection name, vault path |
| `.pa/vault-profile.json` | read | Placement rules, naming rules, frontmatter defaults, linking style, assistant preferences |
| `.pa/entities.json` | read/write | Coreference authority for the curator and decision entity append target when a decision capture is accepted |
| `.pa/sessions/{id}.json` | read+write | Ephemeral session entity state with `recent_entities` and pending `unresolved_entities` |
| `{vault note path}` | write | Destination note created by capture |
| `.pa/assistant-ledger.jsonl` | append | Audit trail for every capture action including proposals and no-note outcomes |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No input text | 1 | Ask the user what they want to capture |
| No `.pa/settings.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/vault-profile.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| Transcript too long (> 5000 words) | 1 | Warn about distillation risk and continue with the full text |
| QMD unavailable or librarian lookup fails | 2 or 4 | Downgrade to `lookup_mode: filesystem-only` per the Lookup Coverage Matrix |
| Curator returns `confidence: none` | 3 | End with no note per the Routing Policy |
| Curator returns low confidence or a malformed report | 3 | Downgrade to `timestamp-note` per the Routing Policy |
| Duplicate signal is `likely` or `path-collision` | 4 or 5 | Route to `existing-note-proposal` per the Routing Policy |
| Posture or render confidence blocks application | 6 | Present proposal only per the Application Policy |
| Curator timeout | 3 | Report error and do not create any note |

## Shared Policies

### Execution State

| Field | Values | Meaning |
|-------|--------|---------|
| `lookup_mode` | `qmd`, `filesystem-only`, `skipped` | How duplicate assessment is being handled for this capture |
| `duplicate_status` | `pending`, `none`, `possible`, `likely`, `path-collision`, `unverified-no-qmd`, `skipped:not-needed` | Normalized duplicate outcome carried across phases |
| `effective_routing` | `timestamp-note`, `profiled-note`, `existing-note-proposal`, `no-new-note` | Final routing after curator confidence and duplicate handling are applied |
| `application_outcome` | `apply`, `proposal-only`, `no-note` | Final write decision after posture and render checks |
| `blocking_reason` | free text | Exact reason a proposal-only or no-note path was chosen |

### Lookup Coverage Matrix

| `lookup_mode` | Trigger | Duplicate Coverage | Required Behavior |
|---------------|---------|--------------------|-------------------|
| `qmd` | QMD collection is configured and `mcp__qmd__status` is healthy | Semantic duplicate and canonical-note assessment via librarian | Use librarian output to set `duplicate_status` to `none`, `possible`, or `likely` |
| `filesystem-only` | QMD is unavailable, QMD lookup fails, or librarian times out | No semantic duplicate detection | Skip librarian entirely, carry `duplicate_status: unverified-no-qmd`, and later apply only the exact `target_path` collision guard in Phase 5 |
| `skipped` | Capture already downgraded to `timestamp-note`, ended as `no-new-note`, or curator lacks a stable title seed and entities | No duplicate assessment needed | Set `duplicate_status: skipped:not-needed` and continue |

### Routing Policy

| Signal | `effective_routing` | Behavior |
|--------|---------------------|----------|
| `confidence: none` | `no-new-note` | Report empty extraction and create no note |
| `confidence: low` or malformed curator report | `timestamp-note` | Preserve raw signal in a simple capture and skip profiled-note routing |
| Curator returned `routing_target: no-new-note` | `no-new-note` | Report the curator's reasoning and suggest `/pa ask` or `/pa draft` |
| `duplicate_status: likely` | `existing-note-proposal` | Warn about the likely duplicate and present a proposal instead of creating a new note |
| `duplicate_status: path-collision` | `existing-note-proposal` | Warn that the resolved target path already exists and do not overwrite it |
| Curator returned `routing_target: existing-note-proposal` | `existing-note-proposal` | Present an existing-note proposal without creating a new note |
| Curator returned `routing_target: profiled-note` | `profiled-note` | Continue to lookup and possible scribe rendering |
| Any other successful case | `timestamp-note` | Continue with the minimal single-note capture |

### Application Policy

| Condition | `application_outcome` | Behavior |
|-----------|------------------------|----------|
| `effective_routing = no-new-note` | `no-note` | Do not render or write a note |
| `effective_routing = existing-note-proposal` | `proposal-only` | Never write and present the proposal or collision warning only |
| Posture is `observe` | `proposal-only` | Never write |
| Posture is `propose` | `proposal-only` | Never write |
| Posture is `apply-low-risk` and `action_class = low-risk write` and `auto_create_low_risk_notes = true` and render confidence is not `low` | `apply` | Write one new note only |
| Posture is `operate` and render confidence is not `low` | `apply` | Write one new note only |
| Any other case | `proposal-only` | Present the exact proposal and state the blocking reason |

### Degradation Policy

| Failure | State Change | Effect |
|---------|--------------|--------|
| Curator returns malformed report | Treat as `confidence: low` | Re-apply the Routing Policy and fall back to `timestamp-note` |
| QMD lookup fails | Set `lookup_mode: filesystem-only` and `duplicate_status: unverified-no-qmd` | Skip semantic duplicate detection and continue with the degraded path |
| Librarian timeout | Set `lookup_mode: filesystem-only` and `duplicate_status: unverified-no-qmd` | Skip semantic duplicate detection and continue with the degraded path |
| Scribe timeout | Change `effective_routing` to `timestamp-note` | Render a timestamp-note instead of a profiled-note |
| Scribe confidence is `low` | Keep current routing, set `blocking_reason`, and re-apply the Application Policy | Present proposal only regardless of posture |

### Output Contracts

Use the matching contract in Phase 9 so applied, proposal-only, collision, and no-note outcomes stay reconstructable.

| Output Mode | Trigger | Required Shape |
|-------------|---------|----------------|
| `applied-note` | `application_outcome = apply` | Shared `Result Format` block plus the exact final note content, the written `target_path`, the final `duplicate_status`, and the reversal hint recorded in the ledger |
| `proposal-only` | `application_outcome = proposal-only` and the flow is not a collision path | Shared `Result Format` block plus the exact proposed note body, the proposed `target_path`, the blocking reason, and the current posture or duplicate state that blocked application |
| `collision-proposal` | `effective_routing = existing-note-proposal` because `duplicate_status = likely|path-collision` or the curator explicitly proposed reuse of an existing note | Shared `Result Format` block plus a `Duplicate Evidence` block containing the existing or canonical path, the duplicate reason, candidate notes when available, and any exact proposal body or merge guidance that would have been written |
| `no-note` | `application_outcome = no-note` | Shared `Result Format` block plus a `No-Note Basis` block containing the curator routing, confidence, empty-extraction or policy reason, and the exact reason a new note was not justified |
| `capture-failure` | Curator timeout or an unrecoverable failure before a stable note outcome exists | Short failure report with the failed phase, input preview, current routing state if known, and one concrete retry suggestion |

### Recovery

Apply one bounded recovery loop per delegated or write-like surface.

| Surface | Max Retries | Stagnation Signal | Stop Behavior |
|---------|-------------|-------------------|---------------|
| Curator triage | 0 automatic retries after the first failed or malformed pass | The same raw input would be retried without new state, or the curator still returns no durable units after degradation | Stop the capture flow, use `capture-failure` or `no-note`, and do not continue to lookup or render |
| Librarian duplicate assessment | 1 fallback from `qmd` to `filesystem-only`, with no second semantic retry | QMD remains unavailable, or another lookup would reuse the same title seed and entities without stronger duplicate evidence | Stop duplicate retries, carry the degraded `duplicate_status`, and continue through the degraded routing path |
| Scribe render | 1 reroute from `profiled-note` to `timestamp-note` or narrower proposal-only scope | The fallback still returns low confidence, the same missing fields, or the same blocked routing | Stop rerendering, keep the degraded routing, and use the matching output contract |
| Declassification gate | 1 inspect pass + 1 declassify pass only | Irreversible residuals or the same unknown masks remain after the declassify pass | Stop before `Write`, force `proposal-only`, and present the blocked proposal contract |
| Note write or state append | 1 retry per target file | The same target fails twice or the retry leaves the same missing file state | Stop further writes for that target, keep the conversation result as proposal-only or degraded apply, and report the failed target explicitly |

## Phase 1: Parse Input

Extract the raw text from `$ARGUMENTS`.

The input is free-form text — it can be a single sentence, bullet list, meeting notes, transcript excerpt, pasted article clip, or any other raw material.

Do not restrict format or length at parse time.

If the input exceeds 5000 words, warn the user: "This is a long capture. The curator will distill the most durable content, and longer inputs may lose peripheral details."

Proceed with the full text.

If the raw text contains explicit dates or relative temporal references such as `yesterday`, `last week`, `어제`, `지난 주`, or `N주 전`, record those phrases as `temporal_hints`.
When `temporal_hints` are present, carry the current local capture date into Phase 3 as a `document_date` anchor for event-date extraction.

If no input is provided, ask the user: "What would you like to capture?"

## Phase 2: Load State

1. Read `.pa/settings.json` and extract `automation_posture`, capability tier, vault path, QMD collection name, and `shadow_root`.
2. Read `.pa/vault-profile.json` and extract placement rules, naming rules, frontmatter defaults, linking style, and assistant preferences.
3. Read `.pa/entities.json` when present and treat it as the curator's lightweight coreference authority.
4. Derive `session_id` from the active command session when available.
If no stable session identifier is exposed, use a deterministic local fallback for the current PA session.
5. Read `.pa/sessions/{session_id}.json` when present and extract `recent_entities` plus pending `unresolved_entities`.
If the file is missing, initialize an in-memory session object with empty arrays.
6. Determine `lookup_mode`.
7. If a QMD collection is configured and `mcp__qmd__status` is healthy, set `lookup_mode: qmd` and `duplicate_status: pending`.
8. Otherwise, set `lookup_mode: filesystem-only` and `duplicate_status: unverified-no-qmd`.
9. When checking for existing notes (duplicate detection, path collision), prefer reading from `{shadow_root}/{relative_path}` when shadow is available.
Fall back to `.pa/shadow/` for backward compatibility, then raw vault path if no shadow exists.
10. Do not infer posture from the conversation.
11. The configured posture is authoritative.

If any required state file is missing, abort per the Decision Matrix.

## Phase 3: Curator Delegation

> Agent: **curator**

Delegate triage to the curator agent.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | `raw_text` (the full capture input), `vault_profile` (vault-profile.json contents), `settings` (settings.json contents), optional `entities_registry` from `.pa/entities.json`, optional `session_state` from `.pa/sessions/{session_id}.json`, a permission envelope seed containing posture and allowed surfaces from Phase 2, and optional `temporal_hints` plus `document_date` when temporal references were detected in Phase 1 |
| Instructions | Apply `skills/pa/capture-distillation/SKILL.md` workflow. Classify input form, capture kind, and routing target. Extract durable units (title seed, summary, tasks, decisions, questions, entities). When `temporal_hints` are present, extract grounded event-date fields and return temporal hints without guessing. When entity mentions are present and `entities_registry` is available, run the lightweight coreference pass from `skills/pa/personal-ontology/references/coreference-rules.md` and return both `resolved_entities` and `unresolved_entities`. Return a structured triage report per the curator's output format |
| Expected Output | Triage report with input analysis, extracted durable units, temporal grounding when supported, resolved and unresolved entities, routing recommendation, lookup eligibility, and confidence assessment |

After curator returns, normalize its output through the Routing Policy and set `effective_routing`.
Carry any grounded temporal output forward even when routing later degrades to `timestamp-note`.

If `effective_routing = no-new-note`, stop the capture flow after Phase 9 presentation.

If curator times out, abort per the Decision Matrix.

If curator returns a malformed report, apply the Degradation Policy.

## Phase 4: Duplicate Assessment

> Agent: **librarian** (conditional)

Run duplicate assessment only when `effective_routing = profiled-note` or `effective_routing = existing-note-proposal`, and the curator returned a stable title seed with meaningful entities.

If `lookup_mode = skipped`, do nothing.

If `lookup_mode = filesystem-only`, skip librarian entirely.

In that degraded path, semantic duplicate detection is unavailable.

The only duplicate safeguard is the exact `target_path` collision guard in Phase 5.

### Librarian Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | Curator's extracted entities and title seed, `brief_type: capture`, vault-profile.json contents, and settings.json contents |
| Instructions | Query QMD with the title seed and high-signal entities. Check for duplicate or canonical notes. Return duplicate assessment and canonical candidates. Do not assemble a full context pack |
| Expected Output | Lookup assessment with duplicate risk (`none`, `possible`, `likely`) and canonical candidates with paths and scores |

If librarian returns successfully, map the result into `duplicate_status` and re-apply the Routing Policy.

If `duplicate_status = possible`, continue with capture and report the overlap in Phase 9.

If QMD query fails or librarian times out, apply the Degradation Policy.

## Phase 5: Permission Envelope

Before any rendering or writing, resolve the candidate note path and build the permission envelope.

1. Resolve `target_path` from the vault profile's placement and naming rules using the current `effective_routing` and the curator's extracted units.
2. If `lookup_mode = filesystem-only`, check whether `target_path` already exists.
3. If that exact path already exists, set `duplicate_status: path-collision`, set `blocking_reason`, and re-apply the Routing Policy.
4. If no path collision exists in `filesystem-only` mode, keep `duplicate_status: unverified-no-qmd`.
5. Classify the action as `new-note-creation` when `effective_routing` is `timestamp-note` or `profiled-note`.
6. Treat `existing-note-proposal` as proposal-only and never as an authorized write.
7. Mark the action as `low-risk write` when it creates one new note, requires no rename, move, or deletion, stays within the vault profile's placement rules, and does not create a new folder unless `allow_new_subfolders` is `true`.
8. Mark the action as `high-risk write` when it requires a new folder not in the profile or the flow has already downgraded to `existing-note-proposal`.
9. Compare the classified action against the active posture from `.pa/settings.json`.
10. If posture, provenance, or scope is weak, set `blocking_reason` and carry the downgraded posture forward.

### Permission Envelope Fields

| Field | Meaning |
|-------|---------|
| `mode` | `timestamp-capture`, `profiled-capture`, or `existing-note-proposal` |
| `target_path` | Resolved note path from vault-profile placement rules |
| `posture` | Active posture after any required downgrade |
| `action_class` | `low-risk write` or `high-risk write` |
| `lookup_mode` | `qmd`, `filesystem-only`, or `skipped` |
| `duplicate_status` | Normalized duplicate outcome from the Shared Policies |
| `scope_limits` | `max_files=1`, no rename, no move, no delete |

## Phase 6: Render and Posture Gate

Apply rendering and the Application Policy before any vault mutation.

1. If `effective_routing = no-new-note`, set `application_outcome: no-note` and skip rendering.
2. If `effective_routing = timestamp-note`, render directly using `templates/pa/timestamp-note.md` with the curator's extracted units and vault-profile rules.
3. If `effective_routing = profiled-note`, delegate to scribe to produce the exact note content, even when the final outcome may still be proposal-only.
4. If `effective_routing = existing-note-proposal`, prepare a proposal body or collision message only.
5. Apply the Application Policy after render confidence and posture are known.
6. If the gate blocks direct application, present the exact proposal and state the blocking reason.

### Optional Scribe Delegation

> Agent: **scribe**

Run only when `effective_routing = profiled-note`.

| Contract Part | Content |
|---------------|---------|
| Input | `write_request` containing the curator's title seed and summary, curator's extracted durable units, vault-profile.json contents, permission envelope, and same-folder exemplars (2-3 notes from the target folder when available) |
| Instructions | Apply `skills/pa/writing/SKILL.md` workflow. Use `templates/pa/profiled-note.md` as the structural guide. Match vault voice from exemplars. Return a `write_plan` with rendered content, confidence, and reversal hint. Do not write files |
| Expected Output | `write_plan` with rendered content ready for `Write`, confidence assessment, fingerprint report, and reversal hint |

Handle scribe timeout or low confidence per the Degradation Policy.

## Phase 7: Apply

### Declassification Gate

Before any Write tool call, run write-safe declassification on the rendered content:

1. Run `scripts/pa-write-safe.sh inspect` on the rendered markdown.
2. If `write_safe: true`, run `scripts/pa-write-safe.sh declassify` and use the declassified text as the final content.
3. If `write_safe: false`, force `application_outcome = proposal-only` with `blocking_reason: "Irreversible mask residuals detected"`.
4. If no mask-map exists, skip declassification and proceed as-is.

### Write

1. If `application_outcome = apply` and `effective_routing = timestamp-note`, use `Write` to create the note at `target_path` with the declassified content.
2. If `application_outcome = apply` and `effective_routing = profiled-note`, use the declassified content and `Write` to create the note at the approved path.
3. If `application_outcome = proposal-only`, skip note creation and keep the rendered content or proposal body for presentation.
4. If `application_outcome = no-note`, skip note creation entirely.
5. Append a JSONL record to `.pa/assistant-ledger.jsonl` for every outcome, including proposals, no-note, and declassification-blocked results. Include `declassification` metadata.
6. Record at least: timestamp, command `capture`, nominal posture, effective posture, action, target path, `effective_routing`, `lookup_mode`, `duplicate_status`, confidence, input preview (first 80 chars), blocking reason, and reversal hint (`delete {path}` for applied new notes).
7. After a successful Write, append a dirty_path entry to `.pa/derivation-state.json`: `{path, event: "capture", content_hash, queued_at, shadow_status: "pending", ontology_status: "pending"}`.
8. After capture completes, rewrite `.pa/sessions/{session_id}.json` with the merged session entity state.
9. Add curator `resolved_entities` to `recent_entities` in most-recent-first order, dedupe by `entity_id` or `canonical_name`, and cap the list at `25`.
10. Carry forward `unresolved_entities` with `status: "pending_review"` so later curator, weaver, steward, and heartbeat passes can reuse or surface them.

Never create more than one note per capture invocation.

Never overwrite an existing note during capture.

## Phase 8: Decision Entity Proposal

### Decision Entity Proposal

If the curator's triage report includes a `decision_entity_candidate`:

1. Build a decision entity from the candidate fields plus today's date as `decision_date` plus default `review_date` (`decision_date + 180 days`).
2. If posture is `apply-low-risk` or higher, propose appending the decision entity to `.pa/entities.json`.
3. Present the proposal: `의사결정을 기록할까요? '{chosen}' — {rationale_summary}. 6개월 후 리뷰 예정.`
4. If accepted, append to `.pa/entities.json`.
If rejected, skip.
5. Record in `.pa/assistant-ledger.jsonl` with `action: "decision_entity_created"` or `action: "decision_entity_declined"`.

## Phase 9: Present

Show the result clearly and keep the action traceable.
Use the matching Output Contract first, then fill the shared `Result Format` shell below.

### Result Format

```
{Captured|Proposed|No note created}: {target_path|n/a}
Routing: {effective_routing}
Confidence: {curator confidence}

{final note content or proposal content or no-note reasoning}

---
**Posture:** {effective posture}
**Gate:** {application_outcome} — {authorized|blocking_reason}
**Curator routing:** {routing_target} ({input_form} + {capture_kind})
**Lookup mode:** {lookup_mode}
**Duplicate status:** {duplicate_status}
```

### Next Actions

After the result, suggest one relevant next step when natural.

| Condition | Suggestion |
|-----------|------------|
| Timestamp-note created from a rich topic | "This captured the raw material. Use `/pa draft {title_seed}` to expand it into a full note" |
| Proposal only because posture blocked application | "Want me to apply this note? You can also adjust posture in `.pa/settings.json`" |
| Existing-note-proposal | "Review the existing note at `{path}` and decide whether to merge manually" |
| Capture had entities with vault connections | "Try `/pa ask \"{entity}\"` to explore what your vault already knows" |
| No note created because extraction was empty | "If this is a question rather than a capture, try `/pa ask \"{input_preview}\"`" |

## Phase 10: Feedback Recording

If the Phase 7 note outcome or the Phase 8 decision-entity proposal was `proposal-only`, record user feedback per the Feedback Recording Contract in `skills/pa/trust-and-boundaries/references/ledger-schema.md`.

Skip this phase in unattended mode.

## Composability

| Context | Usage |
|---------|-------|
| `/pa draft` | Capture turns raw material into structured inputs, and draft turns intentional inputs into polished notes |
| `/pa ask` | When capture input is really a question, redirect to ask for retrieval-grounded answers |
| `/pa survey` | Survey produces the vault profile and QMD registration that capture depends on |
| `/pa brief` | Brief can precede capture when the user wants context before deciding what to note |

## Rules

- **Single-output bias**: Every capture produces at most one note
- **Posture-first**: Always check posture and the permission envelope before any vault mutation
- **Honest duplicate coverage**: When `lookup_mode = filesystem-only`, do not imply semantic duplicate detection. Only guard against exact `target_path` collisions and report `duplicate_status` explicitly
- **No fabricated metadata**: Never invent dates, owners, claims, note titles, or source attributions not present in the raw input
- **Timestamp-note fallback**: When routing is uncertain, curator confidence is low, or scribe times out, default to `timestamp-note`
- **Ledger every action**: Append to `.pa/assistant-ledger.jsonl` after every invocation, including writes, proposals, and no-note outcomes
