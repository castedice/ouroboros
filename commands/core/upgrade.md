---
name: core:upgrade
description: "Use when you need to pull upstream ouroboros changes into a customized local plugin and reconcile them safely"
argument-hint: [--check] [--source <path>] [--single]
allowed-tools: Read, Glob, Bash, Write, Edit, Task
---

# Upgrade — Ouroboros Self-Update

Upgrade the ouroboros plugin from upstream, preserving local customizations recorded in `docs/decisions/`.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 4 | reconciler + Bash background (--multi) | High-level change classification + resolution strategies (parallel with Codex when --multi) |
| 5 | reconciler + Bash background (--multi) | Per-conflict 3-way merge or overlap analysis (parallel with Codex when --multi) |
| 7 | evaluator + Bash background (--multi) | Before/after validation of merged conflict files (parallel with Codex when --multi) |

## Delegation Contracts

| Invocation | Input | Instructions | Expected Output |
|------------|-------|--------------|-----------------|
| Phase 4 reconciler | Diff manifest from Phase 2, customization map from Phase 3, relevant decision-entry contents, and `skills/core/routing/references/relay-prompt-templates.md` when `--multi` is active | Apply `agents/core/reconciler.md` Procedure 1 for upgrade reconciliation. Validate conflict classes, preserve intent from `docs/decisions/`, and mark any case that needs full 3-way merge. | Upgrade Reconciliation Report with `validated_classifications`, `resolution_strategy` per conflict, `detail_merge_required`, and `notes`. |
| Phase 5 reconciler for `CONFLICT-A` | Base, upstream, and local file contents plus related decision entries | Apply `agents/core/reconciler.md` merge analysis workflow. Preserve user intent, isolate upstream deltas, and produce merged content plus annotations. | Component Merge Spec with `path`, `merged_content`, `preserved_customizations`, `open_questions`, and `validation_risk`. |
| Phase 5 reconciler for `CONFLICT-B` | Upstream file, local overlapping file, and the decision entry that created the local file | Apply `agents/core/reconciler.md` overlap analysis plus `skills/core/brainstorming/references/divergent-techniques.md` for alternative synthesis. Return three bounded options only. | Overlap Resolution Spec with exactly three options: `keep_local`, `adopt_upstream`, and `merge_both`, each with trade-offs and a recommended choice. |
| Phase 7 evaluator | Before content, after content, component type, and `skills/core/evaluation/references/{type}-criteria.md` | Apply the comparative evaluation path from `commands/core/evaluate.md` Mode C. Check regressions, position-swap bias, and preserved quality. | Validation payload with before score, after score, verdict, regressed criteria, and a short rationale suitable for Phase 9 review. |


## Phase 1: Parse Input

Extract options from $ARGUMENTS:

| Option | Required | Description |
|--------|----------|-------------|
| `--check` | No | Dry-run mode — classify and analyze but do not apply changes. Exits after Phase 5 |
| `--source <path>` | No | Local upstream path instead of git remote. Must be a valid directory containing ouroboros structure |
| `--single` | No | Force single-model mode (skip external CLIs). By default, multi-model is auto-detected — if codex CLI is installed, Codex runs in parallel for reconciliation (Phase 4-5) and evaluation (Phase 7) |

If both `--check` and `--source` are provided, both apply (dry-run against local source).

If no arguments provided: default to git remote upgrade (no `--check`, no `--source`).

### Source Validation

If `--source <path>` provided:

1. Verify path exists and is a directory
2. Verify it contains ouroboros structure (check for `.claude-plugin/plugin.json` or `commands/core/`)
3. If invalid → Error: "Error: '{path}' is not a valid ouroboros directory. Expected `.claude-plugin/plugin.json` or `commands/core/`."
4. Abort

## Shared References & Payload Contracts

| Artifact | Path | Role |
|----------|------|------|
| Parallel execution pattern | `skills/core/routing/references/parallel-execution-pattern.md` | Fan-out, fan-in, and circuit-breaker rules for `--multi` |
| Relay prompt templates | `skills/core/routing/references/relay-prompt-templates.md` | Phase 4 and Phase 5 Codex prompt assembly |
| Completion status protocol | `skills/core/routing/references/completion-status-protocol.md` | Strip terminal status blocks before parsing reconciler or evaluator outputs |
| Consensus protocol | `skills/core/routing/references/consensus-protocol.md` | Verdict handling for Phase 7 multi-model validation |
| Divergent techniques | `skills/core/brainstorming/references/divergent-techniques.md` | Structured option generation for `CONFLICT-B` |
| Upgrade decision template | `templates/core/decision-upgrade.md` | Phase 8 decision-entry contract |

Machine-consumed payloads:
- Phase 4 writes `.tmp/{SESSION_ID}_upgrade_reconciliation.md`.
- Each Phase 5 `CONFLICT-A` merge writes `.tmp/{SESSION_ID}_merge_{slug}.md`.
- Each Phase 5 `CONFLICT-B` option set writes `.tmp/{SESSION_ID}_overlap_{slug}.md`.
- Phase 7 validation writes `.tmp/{SESSION_ID}_validate_{slug}.json`.

Status-handling rules:
- Strip trailing status blocks per `skills/core/routing/references/completion-status-protocol.md` before extracting classifications, merged content, or verdicts.
- Phases 4 and 5 use cherry-pick handling with Claude as the authoritative base and Codex as additive evidence only.
- Phase 7 uses the verdict rule from `skills/core/routing/references/consensus-protocol.md`. If Codex is missing, fall back to Claude-only validation without reclassifying the file set.


## Branch Summary

All conditional branches that affect command behavior, consolidated for quick reference.

| Condition | State | Affected Phases | Behavior |
|-----------|-------|-----------------|----------|
| Source | Git remote (default) | 2: Git mode | Fetch from configured remote |
| Source | `--source <path>` | 2: Local mode | Compare against local directory |
| `--check` | true | 6–10 skipped | Dry-run: classify and analyze only, exit after Phase 5 |
| `--check` | false (default) | All phases run | Full upgrade with worktree and merge |
| `--single` | true | 4, 5, 7 | Claude only for reconciliation and validation |
| `--single` | false (default) | 4, 5, 7 | Auto-detect: if codex CLI installed, parallel processing |
| Upstream version | Same as current | 2: early exit | "Already up to date." → Exit |
| Classification | No conflicts | 4, 5, 7 skipped | Fast path: skip reconciler and evaluator, proceed to Phase 6 |
| `--source <path>` | Invalid directory | 1 abort | Error: not a valid ouroboros directory |
| Git remote | Not configured | 2 abort | Error + suggest `--source <path>` alternative |
| CONFLICT-B files | Present | 5 | User selects per file: keep local / adopt upstream / merge both |
| REMOVAL-GUARDED | Present | 5 | User chooses keep or remove per file |
| Existing worktree | Found | 6a: Session Recovery | User chooses Resume / Discard / Merge |
| Validation verdict | `degraded` | 7, 9 | Flag for user review with details |

## Phase 2: Fetch Upstream

### Git Remote Mode (default)

1. Check if a git remote exists:

   Verify a git remote is configured. If not → Error: "No git remote configured. Use `--source <path>` or add a remote."

2. Fetch latest from remote and compare HEAD vs origin/main.
   - If same → Log: "Already up to date." → Exit
   - If different → Log: "Upstream has new changes."

3. Generate diff manifest via `git diff --name-status HEAD...origin/main`. Classify files as Added (A), Modified (M), or Deleted (D).

### Local Source Mode (`--source <path>`)

1. Verify `--source` path exists and is a directory
   - If not → Error: "Source path '{path}' does not exist or is not a directory."
   - Abort

2. Scan both local and source for plugin files:
   - Glob both directories for: `commands/**/*.md`, `agents/**/*.md`, `skills/**/*.md`, `templates/**/*.md`, `hooks/hooks.json`, `CLAUDE.md`, `scripts/**/*`

3. Build diff manifest by comparing file presence and content:
   - File in source but not local → Added
   - File in both but content differs → Modified
   - File in local but not source → (ignore — local-only files are not removals in source mode)

4. Use source path as version identifier: `--source {path}`

Log: "Diff manifest: {added} added, {modified} modified, {deleted} deleted."

## Phase 3: Change Classification

Cross-reference the diff manifest with `docs/decisions/` to classify each change.

### Step 1: Build Customization Map

1. `Glob: docs/decisions/*.md` — list all decision entries
2. Read each entry's frontmatter: type, date, component (or module + generated components)
3. Build map: `{component-path: [decision-entries]}`
   - Include entries of type: `evolve`, `generate`, `absorb`
   - For absorb entries, map each generated component path from the "Generated Components" table
   - For generate entries, map the generated component paths from the "Component Manifest"
   - For evolve entries, map the component path from frontmatter

### Step 2: Classify Each Change

For each file in the diff manifest:

| Condition | Classification |
|-----------|---------------|
| Modified + no decision entries | **AUTO-MERGE** |
| Modified + decision entries exist | **CONFLICT-A** |
| Added + similar local component exists (see similarity check below) | **CONFLICT-B** |
| Added + no similar local component | **ADDITION** |
| Deleted + no decision entries | **REMOVAL** |
| Deleted + decision entries exist | **REMOVAL-GUARDED** |

**Similarity pre-screen for `CONFLICT-B`**:
Use only a lightweight pre-screen in Phase 3.
If an added upstream file appears capability-adjacent to a local component, classify it provisionally as `CONFLICT-B`.
Phase 4 reconciler in `agents/core/reconciler.md` performs the authoritative overlap analysis and may confirm or downgrade that provisional class before any merge work starts.

### Step 3: Summary

Log classification summary:

```text
Change Classification:
- AUTO-MERGE: {n} files
- CONFLICT-A: {n} files
- CONFLICT-B: {n} files
- ADDITION: {n} files
- REMOVAL: {n} files
```

**Fast path**: If all changes are AUTO-MERGE, ADDITION, or REMOVAL (no conflicts) → skip Phase 4, 5, 7 and proceed directly to Phase 6.

## Phase 4: Reconciliation Analysis

> Agent: **reconciler** + Bash background (when `--multi`)

Reconciliation analysis runs Claude reconciler for deep intent-aware classification. When `--multi` is active, Codex reconciler runs in parallel for independent classification — cherry-pick mode combines the best resolution strategies from both. See `skills/core/routing/references/parallel-execution-pattern.md`.

### When `--multi` is active (parallel):

Run Codex reconciler in parallel per `skills/core/routing/references/parallel-execution-pattern.md`. Relay prompt: Phase 4 Reconciliation Analyst template from `skills/core/routing/references/relay-prompt-templates.md`. Merge strategy: cherry-pick (Claude primary, Codex supplements with additional conflict signals; Codex conflict escalates Claude's AUTO-MERGE to CONFLICT-A). Codex failure → Claude-only.

### When `--multi` is not active (single-model):

Launch the **reconciler** agent via Task tool (Procedure 1: Upgrade Reconciliation):

- **Input**: Diff manifest with classifications + customization map + decision entry contents (for CONFLICT-A/B files)
- **Instructions**: "Perform Upgrade Reconciliation (Procedure 1). Validate classifications, determine resolution strategies for each conflict. For CONFLICT-A: identify whether section-level auto-merge is possible or full 3-way analysis is needed. For CONFLICT-B: identify the overlapping capabilities. Output Upgrade Reconciliation Report."
- **Expected output**: Upgrade Reconciliation Report (validated classifications + resolution strategies)

Parse the report:

Before parsing the reconciler's report, strip the trailing completion status block from `skills/core/routing/references/completion-status-protocol.md` if present.

1. Confirm or adjust classifications based on reconciler's analysis
2. Extract resolution strategies for each conflict
3. Identify which CONFLICT-A files need detailed merge analysis vs section-level auto-merge

Log: "Reconciliation analysis complete. {N} conflicts need detailed merge, {M} can section-merge."

## Phase 5: Component Merge Analysis

> Agent: **reconciler** + Bash background (when `--multi`)

For each conflict requiring detailed analysis. When `--multi` is active, Claude and Codex reconcilers run in parallel — cherry-pick mode selects the best merge output. See `skills/core/routing/references/parallel-execution-pattern.md`.

### When `--multi` is active (parallel):

#### CONFLICT-A Files

For each CONFLICT-A file needing full 3-way merge:

For each CONFLICT-A file, run Codex reconciler in parallel per `skills/core/routing/references/parallel-execution-pattern.md`. Relay prompt: Phase 5 Merge Specialist template from `relay-prompt-templates.md`. Merge strategy: cherry-pick (Claude primary, incorporate Codex regression detection). Process sequentially (each merge depends on its inputs). Circuit breaker: 2 consecutive Codex failures → skip Codex for remaining.

#### CONFLICT-B Files

For each CONFLICT-B file, run Codex in parallel per the same pattern. Relay prompt: Phase 5 Overlap Analyst template. Cherry-pick Codex's unique trade-off insights.

### When `--multi` is not active (single-model):

#### CONFLICT-A Files

For each CONFLICT-A file needing full 3-way merge:

- **Input**: Base version + upstream version + local version + related decision entries
- **Instructions**: "Perform Component Merge Analysis for CONFLICT-A. 3-way comparison: base + upstream + local. Identify user intent from decision entries. Produce Component Merge Spec with merged content and intent preservation annotations."
- **Expected output**: Component Merge Spec (merged content + annotations)

#### CONFLICT-B Files

For each CONFLICT-B file, apply 1-2 techniques from [divergent-techniques.md](../../skills/core/brainstorming/references/divergent-techniques.md) (e.g., SCAMPER on the overlap, What-if on combining strengths) to ensure the 3 options explore creative hybrid resolutions beyond simple keep/adopt/merge defaults.

- **Input**: Upstream file + local file + decision entry that created the local file
- **Instructions**: "Perform Component Merge Analysis for CONFLICT-B. Side-by-side comparison. Produce Overlap Resolution Spec with 3 options (keep local / adopt upstream / merge both) and pros/cons."
- **Expected output**: Overlap Resolution Spec (3 options with trade-offs)

Before extracting merged content or option lists from any reconciler spec, strip the trailing completion status block from `skills/core/routing/references/completion-status-protocol.md` if present.

### CONFLICT-A Removal Variants

For each file deleted upstream but customized locally:

- Present to user: "Upstream removed `{path}`, but you customized it ({decision entry}). Keep or remove?"
- Record user choice

### `--check` Mode Exit Point

If `--check` flag is set:

Present the full analysis report:

```markdown
## Upgrade Check: {from} → {to}

### Classification Summary

| Classification | Count |
|---------------|-------|
| AUTO-MERGE | {n} |
| CONFLICT-A | {n} |
| CONFLICT-B | {n} |
| ADDITION | {n} |
| REMOVAL | {n} |

### Conflicts

{For each CONFLICT-A: file path + merge strategy summary}
{For each CONFLICT-B: file path + overlap summary + 3 options}

### Recommendation

{Overall assessment — complexity level, estimated effort}
```

Log: "Check complete. Run `/upgrade` without `--check` to apply." → Exit.

## Phase 6: Worktree Setup & Apply

### 6a: Session Recovery + Create Worktree

Before creating a new worktree, check for existing upgrade worktrees:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh status
```

If the JSON output contains entries with `"operation": "upgrade"`:

1. Report to user: "Found existing upgrade worktree: `{path}` (branch: `{branch}`, {commits_ahead} commits ahead, {dirty_files} dirty files)"
2. Present options:
   - **Resume**: Continue working in the existing worktree (skip worktree creation, use existing `$WORKTREE` path)
   - **Discard**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "{path}"` and proceed with fresh worktree
   - **Merge**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "{path}" "Upgrade: resume merge"` and proceed with fresh worktree
3. Wait for user choice before proceeding

Also run prune to clean up stale worktrees silently:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh prune
```

1. Derive version slug from upstream version (short hash or tag):
   - Git mode: `{short-hash}` (e.g., `a1b2c3d`)
   - Source mode: `local-{timestamp}`
2. Create worktree:

   ```bash
   WORKTREE=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh create upgrade {slug})
   ```

   The script handles branch conflicts by appending timestamps automatically.

### 6b: Apply Changes in Worktree

Apply changes in order of safety:

**1. ADDITION files** (safest — new files):

- Copy each added file from upstream into the worktree

**2. AUTO-MERGE files** (safe — no local customizations):

- Copy upstream version into the worktree, overwriting the existing file

**3. REMOVAL files** (safe — no local customizations):

- Delete the file from the worktree

**4. CONFLICT-A files** (reconciled):

- For section-level auto-merges: apply the reconciler's merged content
- For full 3-way merges: write the Component Merge Spec's merged content

**5. CONFLICT-B files** (user-chosen):

- Apply per user's choice from Phase 5 (or from `--check` review):
  - Keep local → no change needed
  - Adopt upstream → copy upstream version
  - Merge both → write the combined content

Log: "{N} files applied to worktree."

## Phase 7: Validation

> Agent: **evaluator** + Bash background (when `--multi`)

Validate merged CONFLICT-A files to ensure quality was preserved. When `--multi` is active, Claude and Codex evaluate in parallel for consensus validation. See `skills/core/routing/references/parallel-execution-pattern.md`.

### When `--multi` is active (parallel):

For each CONFLICT-A file, run before/after evaluation with Codex in parallel per `skills/core/routing/references/parallel-execution-pattern.md`. Relay prompt: Mode C comparative template. Consensus: majority rule on verdict. Circuit breaker: 2 consecutive failures → skip Codex for remaining.

### When `--multi` is not active (single-model):

For each CONFLICT-A file that underwent full 3-way merge:

1. Read the before version (current main) and after version (worktree)
2. Launch **evaluator** agent for before/after comparison (via Task tool):
   - Input: Before content + After content + component type
   - Instructions: "Evaluate both versions independently. Perform pairwise comparison with position swap. Check for regressions. Return verdict: improved/degraded/lateral."

### Interpret Result

For both modes, interpret the verdict:

| Verdict | Action |
|---------|--------|
| `improved` | Proceed |
| `lateral` | Proceed (acceptable — merge preserves quality) |
| `degraded` | Flag for user review with details |

If any file is degraded:

- Log: "Warning: `{path}` quality degraded after merge. Upstream change may conflict with your customization."
- Include in Phase 9 review for user decision

**Fast path**: If no CONFLICT-A files exist (all auto-merge/addition/removal), skip this phase.

Log: "Validation complete. {pass}/{total} passed."

## Phase 8: Record Decision

Create an upgrade decision entry in the worktree:
`$WORKTREE/docs/decisions/{date}-upgrade-{version-slug}.md`

Use template from `templates/core/decision-upgrade.md`.

Entry must include:

- type: upgrade
- date, from-version, to-version, upstream-source, intent
- Background (why the upgrade was performed)
- Version Info (from, to, upstream, method)
- Change Summary table (all files with classifications and actions)
- Conflict Resolutions (per conflict — upstream change, local customization, resolution, rationale)
- User Customizations Preserved table
- Verification results

Stage and commit in worktree:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh commit "$WORKTREE" "Upgrade ouroboros: {from-short} → {to-short}"
```

## Phase 9: Review

Present the upgrade results for user review:

```markdown
## Upgrade Draft: {from-version} → {to-version}

**Branch**: ouroboros/upgrade/{slug}
**Source**: {git remote | --source path}
**Method**: {git fetch | local source}

### Change Summary

| Classification | Count | Status |
|---------------|-------|--------|
| AUTO-MERGE | {n} | Applied |
| CONFLICT-A | {n} | Merged ({pass}/{total} validated) |
| CONFLICT-B | {n} | User-resolved |
| ADDITION | {n} | Applied |
| REMOVAL | {n} | Applied |

### Conflict Resolutions

{For each resolved conflict:}
- `{path}`: {resolution summary} (from {decision entry})

{If any degraded:}
### Quality Warnings

- `{path}`: Degraded after merge — {details}

### Diff

{git diff main...ouroboros/upgrade/{slug} output}

### Decision Entry

- `docs/decisions/{date}-upgrade-{version-slug}.md`

**Merge** into main, or **Discard** the draft?
```

### On Merge

1. Merge and cleanup:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "$WORKTREE" "Upgrade ouroboros: {from-short} → {to-short}"
   ```

2. Confirm: "Upgrade merged to main."

### On Discard

1. Discard: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "$WORKTREE"`
2. Confirm: "Draft discarded. No changes made to main."

## Phase 10: Report

### Standard Report

```markdown
## Upgrade Complete: {from-version} → {to-version}

**Source**: {git remote | --source path}
**Total changes**: {count}
**Conflicts resolved**: {count}
**User customizations preserved**: {preserved}/{total}

### Changes Applied

| # | File | Classification | Action |
|---|------|----------------|--------|
| 1 | `{path}` | {classification} | {action} |

### Decision Entry

- `docs/decisions/{date}-upgrade-{version-slug}.md`

### Next Actions

- `/evaluate {module} --multi --compare` — verify module quality against pre-upgrade baseline
- `/evolve {degraded_path} --focus {area}` — improve components flagged as degraded during merge validation
- Review {addition_count} new upstream additions for potential customization
- Decision entry: `docs/decisions/{date}-upgrade-{version-slug}.md`
```

### Already Up-to-Date Report

```markdown
## Upgrade: Already Up to Date

No upstream changes found. Ouroboros is at the latest version.

### Next Actions

- `/evaluate {module} --multi` — assess current module quality
- `/research` — explore new patterns and methodologies
```

## Rules

- **Upgrade = ouroboros self-update only** (DR-019) — external plugin updates use `/absorb` (re-absorb)
- `docs/decisions/` is the single source of truth for conflict detection — a file without decision entries is safe to overwrite
- All file operations happen in the worktree — never write directly to main branch
- User reviews the final result (Phase 9) before merge — this is the primary checkpoint
- CONFLICT-B is never auto-resolved — always present options to user
- `--check` mode exits after Phase 5 — no worktree created, no files modified
- Fast path: if no conflicts exist, skip reconciler and evaluator phases for faster upgrade
- On any error during worktree operations, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh cleanup "$WORKTREE"` before aborting
- If > 10 conflicts detected, suggest incremental upgrade: "Consider upgrading in smaller steps to reduce conflict resolution effort."
- Maximum scope: upgrade operates on plugin structure files only (commands/, agents/, skills/, templates/, hooks/, scripts/, CLAUDE.md). User project files are never touched
