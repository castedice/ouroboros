---
description: Upgrade ouroboros from upstream — fetch changes, reconcile with local customizations, validate, and apply
argument-hint: [--check] [--source <path>] [--multi]
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Task
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

## Phase 1: Parse Input

Extract options from $ARGUMENTS:

| Option | Required | Description |
|--------|----------|-------------|
| `--check` | No | Dry-run mode — classify and analyze but do not apply changes. Exits after Phase 5 |
| `--source <path>` | No | Local upstream path instead of git remote. Must be a valid directory containing ouroboros structure |
| `--multi` | No | Enable multi-model reconciliation in Phase 4-5 (Claude + Codex parallel reconciler, cherry-pick merge) and Phase 7 (Claude + Codex parallel evaluator, consensus) |

If both `--check` and `--source` are provided, both apply (dry-run against local source).

If no arguments provided: default to git remote upgrade (no `--check`, no `--source`).

### Source Validation

If `--source <path>` provided:

1. Verify path exists and is a directory
2. Verify it contains ouroboros structure (check for `.claude-plugin/plugin.json` or `commands/core/`)
3. If invalid → Error: "Error: '{path}' is not a valid ouroboros directory. Expected `.claude-plugin/plugin.json` or `commands/core/`."
4. Abort

## Phase 2: Fetch Upstream

### Git Remote Mode (default)

1. Check if a git remote exists:

   ```bash
   git remote -v
   ```

   - If no remote configured → Error: "No git remote configured. Use `--source <path>` to upgrade from a local directory, or add a remote with `git remote add origin <url>`."
   - Abort

2. Fetch latest from remote:

   ```bash
   git fetch origin
   ```

3. Compare versions:
   - Current: `git rev-parse HEAD`
   - Upstream: `git rev-parse origin/main`
   - If same → Log: "Already up to date (${VERSION})." → Exit
   - If different → Log: "Upstream has new changes. Current: ${CURRENT_SHORT}, Upstream: ${UPSTREAM_SHORT}."

4. Generate diff manifest:

   ```bash
   git diff --name-status HEAD...origin/main
   ```

   Parse into a structured manifest:
   - `A` → Added files
   - `M` → Modified files
   - `D` → Deleted files

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

**Similarity check for CONFLICT-B**:
For each added upstream file, check if a local component covers the same capability:

- Compare file names across all module directories
- Compare frontmatter descriptions (if readable)
- Compare command argument patterns or agent procedure names
- If >= 2 similarity signals match → CONFLICT-B

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

1. **Build reconciler relay prompt**: Construct from diff manifest + customization map + decision entries + classification instructions. Save to `.tmp/{SESSION_ID}_reconciler_relay.txt`

   **Section 1 — Role** (fixed template):

   ```text
   You are an independent version reconciliation analyst. Your task is to analyze upstream changes against local customizations and classify each change with a resolution strategy. Do not assume any prior context — analyze based solely on the diff manifest, decision entries, and customization map given.
   ```

   **Section 2 — Content**: Diff manifest with classifications + customization map + decision entry contents (verbatim).

   **Section 3 — Methodology**:

   ```text
   Follow this procedure:
   1. Parse the diff manifest and customization map
   2. For each file, validate the classification (AUTO-MERGE / CONFLICT-A / CONFLICT-B / ADDITION / REMOVAL / REMOVAL-GUARDED)
   3. For CONFLICT-A: determine if section-level auto-merge is possible or full 3-way analysis is needed
   4. For CONFLICT-B: identify overlapping capabilities and recommend options
   5. Produce resolution strategy for each conflict
   ```

   **Section 4 — Response Format**: JSON with `classifications`, `conflict_strategies`, `section_merges`, `full_merges` arrays.

2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_reconciler_relay.txt .tmp/{SESSION_ID}_codex_recon.json high, run_in_background=true)`
   - **Foreground**: Launch Claude **reconciler** agent (via Task tool) with Procedure 1 inputs

3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3

4. **Cherry-pick merge**: Review both reconciliation reports and build unified classification:
   - Use Claude's classifications as primary (Claude has full decision entry context)
   - Cherry-pick from Codex: additional conflict signals, alternative resolution strategies, missed overlaps
   - If Codex identifies a conflict that Claude classified as AUTO-MERGE, escalate to CONFLICT-A (conservative)
   - If Codex analysis failed or is partial, proceed with Claude-only analysis

### When `--multi` is not active (single-model):

Launch the **reconciler** agent via Task tool (Procedure 1: Upgrade Reconciliation):

- **Input**: Diff manifest with classifications + customization map + decision entry contents (for CONFLICT-A/B files)
- **Instructions**: "Perform Upgrade Reconciliation (Procedure 1). Validate classifications, determine resolution strategies for each conflict. For CONFLICT-A: identify whether section-level auto-merge is possible or full 3-way analysis is needed. For CONFLICT-B: identify the overlapping capabilities. Output Upgrade Reconciliation Report."
- **Expected output**: Upgrade Reconciliation Report (validated classifications + resolution strategies)

Parse the report:

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

1. **Build merge relay prompt**: Construct from base + upstream + local versions + decision entries + merge instructions. Save to `.tmp/{SESSION_ID}_merge_relay.txt`

   **Section 1 — Role** (fixed template):

   ```text
   You are an independent version reconciliation specialist. Your task is to perform a 3-way merge of a plugin component, preserving user customization intent as recorded in decision entries. Do not assume any prior context — analyze based solely on the versions and decision entries given.
   ```

   **Section 2 — Content**: Base version + upstream version + local version + related decision entries (all verbatim).

   **Section 3 — Methodology**:

   ```text
   Follow this procedure:
   1. Identify user intent from decision entries (what was changed and why)
   2. Analyze each section: classify as unchanged / upstream-only / local-only / both-modified
   3. For both-modified sections: merge preserving user intent while incorporating upstream improvements
   4. Produce complete merged file content with origin annotations
   ```

   **Section 4 — Response Format**: JSON with `file_path`, `section_analysis`, `merged_content`, `intent_preservation`, `regressions`, `recommendations`.

2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_merge_relay.txt .tmp/{SESSION_ID}_codex_merge.json high, run_in_background=true)`
   - **Foreground**: Launch Claude **reconciler** agent (via Task tool) with Procedure 2 inputs

3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3

4. **Cherry-pick merge**: Review both merge outputs:
   - Use Claude's merged content as primary (Claude has full context including knowledge base)
   - Cherry-pick from Codex: better section ordering, clearer intent annotations, additional regression detection
   - If Codex detected regressions that Claude missed, incorporate them
   - If Codex merge failed, proceed with Claude-only merge

Process CONFLICT-A files sequentially (each merge depends on its specific inputs). Circuit breaker: 2 consecutive Codex failures → skip Codex for remaining files.

#### CONFLICT-B Files

For each CONFLICT-B file:

1. **Build overlap relay prompt**: Construct from upstream + local files + decision entry + comparison instructions. Save to `.tmp/{SESSION_ID}_overlap_relay.txt`

   Use same 4-section structure with CONFLICT-B-specific methodology (side-by-side comparison, 3 options, pros/cons).

2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_overlap_relay.txt .tmp/{SESSION_ID}_codex_overlap.json high, run_in_background=true)`
   - **Foreground**: Launch Claude **reconciler** agent (via Task tool) for CONFLICT-B analysis

3. **Fan-in + Cherry-pick**: Same pattern — Claude primary, cherry-pick Codex's unique trade-off insights.

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

For each CONFLICT-A file that underwent full 3-way merge:

1. **Read files**: Before version (current main) and after version (worktree)
2. **Build relay prompt**: Construct Mode C comparative prompt from before + after content + criteria reference. Save to `.tmp/{SESSION_ID}_relay.txt`
3. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_relay.txt .tmp/{SESSION_ID}_codex_eval.json xhigh, run_in_background=true)`
   - **Foreground**: Launch Claude **evaluator** agent for before/after comparison (via Task tool)
4. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3
5. **Consensus verdict**: Apply majority rule on improved/degraded/lateral across models

Process files sequentially with circuit breaker (2 consecutive Codex failures → skip Codex for remaining files).

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
`.worktrees/upgrade-{slug}/docs/decisions/{date}-upgrade-{version-slug}.md`

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

- Run `/evaluate core` to verify module quality after upgrade
- Run `/evolve <path>` on any degraded components
- Review new additions from upstream for potential customization
- Decision entry: `docs/decisions/{date}-upgrade-{version-slug}.md`
```

### Already Up-to-Date Report

```markdown
## Upgrade: Already Up to Date

No upstream changes found. Ouroboros is at the latest version.

### Next Actions

- Run `/evaluate core` to assess current module quality
- Run `/research` to explore new patterns and methodologies
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
