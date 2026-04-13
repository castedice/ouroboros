# Posture Matrix — Permission Matrix and Example Scenarios

> Purpose: Detailed action matrix for `trust-and-boundaries` — use it to decide what PA may do at each posture, when confirmation is mandatory, and how to interpret bounded maintenance.

This reference is standalone and can be used without the parent skill.
For the end-to-end trust workflow, see `skills/pa/trust-and-boundaries/SKILL.md`.

## Reading the Matrix

Use the matrix after classifying the target surface and exact operation. Interpret the statuses as follows.

| Status | Meaning |
|---|---|
| **Allow** | may proceed without extra confirmation if provenance, confidence, and reversibility checks also pass |
| **Confirm** | may proceed only after explicit user confirmation of this exact action |
| **Forbid** | do not perform at this posture even if the user originally asked for a broad outcome; either downgrade to proposal or request a posture change |

If an action spans multiple rows, use the strictest status. If the target is user-visible markdown, trust rules are stricter than `.pa/` state updates even when the mechanical edit is small.

## Artifact Boundary Reminder

| Surface | Examples | Authority Rule |
|---|---|---|
| `.pa-state` | ledger, proposals, dossiers inside `.pa/`, derivation caches | assistant-owned and regenerable |
| `derived-markdown` | human-readable profile mirrors, accepted PA-generated notes in the visible vault | user-visible, so treat as markdown truth after creation |
| `source-markdown` | user notes, dailies, MOCs, captures, projects, templates | always source of truth |

Once a note exists outside `.pa/`, it is user markdown regardless of who created it.

## Entry Path Defaults

| Entry Path | Typical Starting Posture | Reason |
|---|---|---|
| `/pa init` | `apply-low-risk` after the user accepts the scaffold | the scope is explicit and the edits are expected |
| `/pa survey` | `propose` | the vault already exists and structure must be confirmed before mutation |
| missing or unreadable settings | `observe` | fail closed rather than granting accidental autonomy |

## Permission Matrix

| Action | Observe | Propose | Apply-Low-Risk | Operate | Example Scenario |
|---|---|---|---|---|---|
| Run QMD queries, vault scans, and structural analysis | Allow | Allow | Allow | Allow | surveying the vault before onboarding |
| Write reports, dossiers, or cached analysis inside `.pa/` | Allow | Allow | Allow | Allow | refreshing `.pa/dossiers/project-alpha.md` |
| Store pending proposals in `.pa/proposals.jsonl` | Allow | Allow | Allow | Allow | saving a draft patch for later review |
| Produce exact patch text without applying it | Allow | Allow | Allow | Allow | showing a diff for a daily note |
| Create a new note from a known template in a proven location | Forbid | Confirm | Allow | Allow | creating today's daily brief |
| Append a source block or citation section to an existing note | Forbid | Confirm | Allow | Allow | adding `Sources` to a briefing note |
| Add links to an existing daily hub without changing prior prose | Forbid | Confirm | Allow | Allow | linking a capture note from today's daily note |
| Refresh a single MOC or relationship map within one named scope | Forbid | Confirm | Confirm | Allow | updating one project map note |
| Normalize one capture note title or frontmatter without deleting content | Forbid | Confirm | Confirm | Allow | standardizing one imported capture note |
| Scoped relinking within one named scope | Forbid | Confirm | Confirm | Allow | relinking aliases across one project dossier |
| Create a small batch of new notes from templates | Forbid | Confirm | Confirm | Allow | generating weekly review and follow-up report together |
| Bulk property backfill across many notes | Forbid | Confirm | Confirm | Confirm | adding `topic:` to fifty notes |
| Rename a note | Forbid | Confirm | Confirm | Confirm | changing `Idea.md` to `Project Alpha Idea.md` |
| Move a note between folders | Forbid | Confirm | Confirm | Confirm | moving a project note into `Projects/Alpha/` |
| Mass relinking across multiple scopes | Forbid | Confirm | Confirm | Confirm | replacing a canonical entity name across the vault |
| Folder migration or structural reorganization | Forbid | Confirm | Confirm | Confirm | introducing a new `References/` hierarchy |
| Delete notes or remove substantive content | Forbid | Forbid | Forbid | Confirm | deleting duplicates or trimming old sections |

Interpretation notes:
- `observe` and `propose` may still create or update `.pa/` files because those are assistant state, not user notes.
- `apply-low-risk` is for small, bounded, reversible edits with clear precedent.
- `operate` expands into maintenance work, not destructive freedom.
- Delete, rename, move, migration, and mass change classes always require confirmation regardless of posture.

## Bounded Maintenance Thresholds

Use these defaults to separate `operate` from hidden bulk work. Lower the threshold when evidence is weak or the notes are especially valuable.

| Category | Default Boundary | Escalate When |
|---|---|---|
| scoped relinking | at most 20 link edits across at most 10 notes within one named scope | either limit is exceeded or the links cross multiple scopes |
| small batch note creation | at most 3 notes from known templates in proven folders | a new folder must be created or the batch is larger |
| MOC refresh | one MOC or map note with no deletion of user prose | multiple MOCs or note merges are involved |
| ingestion normalization | one imported note family with no content replacement over 30% | normalization becomes rewriting or spans multiple folders |
| low-risk markdown edits | at most 5 notes and at most 30 added lines total | file count, line count, or semantic impact exceeds the bound |

## Example Scenarios

### Observe

| Situation | Expected Handling |
|---|---|
| Build an inferred `vault-profile.json` draft in `.pa/` | Allow |
| Refresh a QMD-backed dossier in `.pa/` | Allow |
| Fix links inside a visible daily note | Confirm or downgrade to proposal |
| User runs `/pa brief` on a project | Allow — brief generates a report (read) |

### Propose

| Situation | Expected Handling |
|---|---|
| Produce an exact diff for a project note | Allow |
| Recommend a folder for a new note and store it in `.pa/proposals.jsonl` | Allow |
| Apply the diff directly to the project note | Confirm |
| PA wants to update vault-profile.json | Allow — `.pa/` state, not user content |

### Apply-Low-Risk

| Situation | Expected Handling |
|---|---|
| Create a daily brief from a known template | Allow |
| Append a source section to a visible note with direct provenance | Allow |
| Add 3 wikilinks to today's daily note | Allow — low-risk, bounded, reversible |
| Rename a note or touch 8 visible notes at once | Confirm |
| Delete an orphan note | Forbid — destructive, not available at this posture |

### Operate

| Situation | Expected Handling |
|---|---|
| Refresh one project MOC with clearly sourced links | Allow |
| Relink 12 notes to updated canonical name | Allow — high-risk but within operate scope |
| Compile a bounded set of timestamp captures into one monthly note | Allow |
| Move notes across folders, delete content, or migrate structure | Confirm |
| Rewrite a note's content entirely | Confirm — destructive rewrite always needs confirmation |

## Escalation Triggers

Ask the user before proceeding when any of the following is true.

- Provenance is missing, indirect, or contradictory.
- Confidence is `low` or disputed.
- The action touches more than 5 visible markdown notes.
- Scoped relinking would exceed 20 link changes or 10 notes.
- The change renames, moves, deletes, or migrates notes or folders.
- The edit would replace more than 30% of an existing note.
- The action changes placement rules, default parents, or folder conventions.
- `.pa/` state disagrees with markdown and the difference matters to the edit.

## Posture Transition Rules

| From → To | Allowed | Mechanism |
|-----------|---------|-----------|
| Any → lower | Always | User can restrict PA at any time |
| Any → higher | User-initiated only | PA never self-promotes posture |

**Critical rule**: PA NEVER suggests posture elevation. The user decides when to trust PA more. PA may note its current posture if the user requests an action that requires a higher posture ("This action requires apply-low-risk posture; current posture is observe").

## Unattended Operate (Autopilot)

When PA runs unattended via `scripts/pa-autopilot.sh` (cron, headless Claude), `operate` posture applies with additional constraints:

| Action Category | Attended Operate | Unattended Operate |
|-----------------|:----------------:|:------------------:|
| `.pa/` state refresh | Allow | Allow |
| Bounded low-risk markdown (daily hub, managed blocks) | Allow | Allow |
| Confirmation-required actions | Confirm, then allow | Emit report-only recommendation, skip action |
| Delete, archive, rename, move | Confirm, then allow | Report-only — never execute |
| Folder creation or restructuring | Confirm, then allow | Report-only — never execute |

**Key rule**: Unattended operate never asks follow-up questions. Checkpoints that would normally block for user input become report items in the gardening report.

**Posture gate**: If `.pa/settings.json` has `automation_posture` other than `operate`, the autopilot daemon runs infrastructure only (QMD, shadow, hash-index) and skips all Claude gardening.

## Always Forbidden

These actions are forbidden at every posture until the user resolves them explicitly.

| Forbidden Action | Reason |
|---|---|
| Editing user markdown with no direct provenance | unverifiable authority |
| Silently upgrading posture because an action seems small | permission boundary breach |
| Treating `.pa/` overlays as more authoritative than markdown notes | source-of-truth violation |
| Splitting one bulk rewrite into many hidden micro-edits to avoid confirmation | trust circumvention |
| Deleting or rewriting notes based only on inferred duplicates | irreversible loss from weak evidence |

## Interpretation Rule

The matrix is a permission ceiling, not a command to act. An action that is technically Allow should still be skipped or downgraded when it is unnecessary, weakly evidenced, or poorly reversible.
