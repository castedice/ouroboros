---
description: Absorb external sources into the modular monolith — orchestrate Research + Evaluate + Generate/Evolve to transform external patterns into internal modules or components
argument-hint: <path|url|topic> [--into <module>] [--reference <module>] [--single]
allowed-tools: Read, Glob, Grep, WebFetch, WebSearch, Write, Bash, Task
---

# Absorb — External Source Integration

Bring external sources (plugins, codebases, web resources, topics) into the ouroboros modular monolith by orchestrating Research, Evaluate, and Generate/Evolve as a unified pipeline.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Mode | Role |
|-------|-------|------|------|
| 3 | researcher + Bash background (--multi) | A+B | Analyze collected source content, extract patterns and conventions (parallel with Codex when --multi) |
| 5 | evaluator + Bash background (--multi) | B | Gap analysis — compare source capabilities vs existing module (parallel with Codex when --multi) |
| 6 | generator | A | Module spec generation from research findings (Procedure 1) |
| 6 | generator | B | Component spec generation to fill identified gaps (Procedure 3) |
| 8 | evaluator, generator + Bash background (--multi) | A+B | Quality gate — validate + retry (parallel evaluator with Codex when --multi). See [procedure reference](../../skills/core/validation/references/quality-gate-procedure.md) |

## Phase 1: Parse Input

Determine absorption mode from $ARGUMENTS (DR-017):

| Input pattern | Condition | Mode | Action |
|---------------|-----------|------|--------|
| `<source>` | No `--into` flag | **Mode A**: New Module | Research source → Generate new module from findings |
| `<source> --into <module>` | Target module exists | **Mode B**: Integrate | Research source → Gap analysis → Generate components to fill gaps |

Extract arguments from $ARGUMENTS:

| Argument | Required | Description |
|----------|----------|-------------|
| `source` | Yes | Path (file or directory), URL (`http://` or `https://`), or topic keyword |
| `--into` | No | Target module name for Mode B integration (must exist) |
| `--reference` | No | Reference module for pattern matching (default: `core`) |
| `--single` | No | Force single-model mode (skip external CLIs). By default, multi-model is auto-detected — if codex CLI is installed, Codex runs in parallel for research (Phase 3), gap analysis (Phase 5), and evaluation (Phase 8) |

### Source Type Detection

Determine source type using the same logic as `/research`:

| Pattern | Source Type |
|---------|------------|
| Path exists (file or directory) | **Local Source** |
| Starts with `http://` or `https://` | **Web Source** |
| Plain text (everything else) | **Topic** |

### Mode Detection

1. **Check `--into` flag**:
   - Present → candidate Mode B
   - Absent → candidate Mode A

2. **Validate mode**:

   **Mode A candidate** (no `--into`):
   - No additional validation needed — Mode A generates a new module; the module name is derived later from research findings
   - **Mode A confirmed**

   **Mode B candidate** (`--into <module>`):
   - Scan `commands/{module}/`, `agents/{module}/`, `skills/{module}/`, `templates/{module}/`
   - If module exists → **Mode B confirmed**
   - If module doesn't exist → Error: "Module '{module}' doesn't exist. Use `/absorb <source>` without `--into` to create a new module, or `/generate {module} \"desc\"` to create the module first."
   - Abort

3. **Source validation**:
   - If no source provided → Error: "Error: No source specified. Usage: `/absorb <path|url|topic> [--into <module>] [--reference <module>]`"
   - Abort

Log parsed input: source, source type, mode, reference module. Proceed automatically.

## Phase 2: Gather Sources

Collect raw content from the external source. This phase handles all network access — subsequent agents are read-only.

### Local Source

1. Verify path exists
2. If directory:
   - Glob for plugin structure: `CLAUDE.md`, `AGENTS.md`, `plugin.json`, `README.md`
   - Glob for components: `commands/**/*.md`, `agents/**/*.md`, `skills/**/*.md`, `templates/**/*.md`
   - Glob for hooks: `hooks/hooks.json`
   - Read each discovered file
3. If single file:
   - Read the file
   - Check parent directory for related files if it appears to be part of a plugin
4. Log: "Found {N} files from local source."

### WebFetch Constraints (Web Source + Topic)

> Content passes through a Haiku summarization layer — raw source text is never returned. Pages over 100KB are truncated (tail content lost). Authenticated pages and JS-rendered SPAs return empty or partial content. If a URL yields thin results, try topic mode with alternative search terms.

### Web Source

1. WebFetch the provided URL
2. If the content appears to be a repository or documentation:
   - Identify links to key files and prioritize by information density:
     1. **Structural definition**: `plugin.json`, `CLAUDE.md`, `AGENTS.md` (plugin architecture)
     2. **Component files**: `commands/`, `agents/`, `skills/` directory listings or files (functional content)
     3. **Documentation**: `README.md`, docs pages (context and rationale)
     4. **Configuration**: `hooks/`, `settings.json`, `templates/` (supporting structure)
   - WebFetch up to 5 additional linked pages, selecting from the highest available priority tier first
3. If URL is unreachable:
   - Error: "URL unreachable. Try a local path or topic keyword instead."
   - Abort
4. Log: "Fetched {N} pages from web source."

### Topic

1. WebSearch the topic keyword (include "Claude Code plugin" or relevant domain context)
2. Review search results — select top 3-5 most relevant
3. WebFetch each selected result
4. If no results found:
   - Error: "No relevant results found. Try refining the topic or use a direct URL."
   - Abort
5. Log: "Collected content from {N} web sources."

## Phase 3: Research Analysis

> Agent: **researcher** + Bash background (when `--multi`)

Research analysis runs Claude researcher for deep knowledge-base-integrated analysis. When `--multi` is active, Codex researcher runs in parallel for a fresh perspective — cherry-pick mode combines the best insights from both. See `skills/core/routing/references/parallel-execution-pattern.md`.

**IMPORTANT**: The command passes all collected content to the researcher agent. The researcher agent is read-only and does not access the network — all network access happens in Phase 2.

### Researcher Instructions

Launch the **researcher** agent via Task tool:

- **Input**: All collected source content + source type + original target + mode (A or B)
- **Instructions**: "Perform Research Analysis on the provided content. Source type: {source type}. Mode: {A or B}."
- **Required output**: Research Analysis Report — (1) Key Findings with evidence, (2) Component Inventory with types, (3) Architectural Patterns, (4) Mode-specific: {Mode A: module name suggestion | Mode B: integration points}, (5) Suggested Tags

### `--multi` Extension

When `--multi` is active, run Codex researcher in parallel per `skills/core/routing/references/parallel-execution-pattern.md`. Relay prompt: `skills/core/absorption/references/researcher-relay-prompt.md` — wrap collected source content in `<<<UNTRUSTED_CONTENT_START>>>` / `<<<UNTRUSTED_CONTENT_END>>>` markers before inserting as Section 2. Merge strategy: cherry-pick (union of findings, prefer stronger evidence, novel Codex insights marked "External insight"). Codex failure → Claude-only.

### Parse Results

Extract from the researcher's report (or merged analysis when `--multi`):

1. **Key findings**: patterns, conventions, architectural decisions
2. **Component inventory**: capabilities with types
3. **Suggested module name** (Mode A) or **integration points** (Mode B)
4. **Suggested tags** for the knowledge entry

Log: "Research analysis complete. {N} key findings, {M} components identified."

## Phase 4: Knowledge Entry Draft

Build a knowledge entry from the researcher's report (same structure as `/research` Phase 4):

1. **Title**: Derive from the source and research focus
2. **Frontmatter**:
   - `title`: the derived title
   - `tags`: researcher's suggested tags + relevant existing tags from `docs/specs/knowledge/`
   - `source`: original source (path, URL, or topic)
   - `created`: today's date (YYYY-MM-DD)
   - `status`: `active`
   - `related`: scan existing entries in `docs/specs/knowledge/` for 30%+ tag overlap. List matching filenames (e.g., `[llm-as-judge-evaluation.md]`). Empty `[]` if no overlap found
3. **Body**: Structure from the Research Analysis Report
   - Overview — what was analyzed and why
   - Key Patterns — conventions, techniques, design decisions
   - Practical Applications — how findings apply to ouroboros
   - Trade-offs — limitations and considerations
   - References — source citations

Use `templates/core/knowledge-entry.md` as the structural guide.

4. **Deduplication check**: Scan existing entries in `docs/specs/knowledge/*.md` for tag and content overlap per `skills/core/absorption/references/deduplication-rules.md`. Outcomes: no overlap → proceed, high overlap with distinct angle → new entry with cross-reference, substantial content overlap → extend existing entry. New entries must contain at least 3 distinct actionable patterns not in overlapping entries.

5. **Supersession check** (when high overlap detected): If new entry covers >80% of existing entry's patterns with more recent source, flag for Phase 10 user review as supersession recommendation. Do not auto-supersede.

Log: "Knowledge entry drafted: {title} (overlap: {none|low|high with {existing-entry}})"

## Phase 5: Gap Analysis & Design

This phase diverges by mode to determine what to generate.

### Mode A: Module Design

1. **Derive module name**: Use the researcher's suggested module name. Verify it doesn't conflict with existing modules:
   - Scan `commands/{name}/`, `agents/{name}/`, `skills/{name}/`, `templates/{name}/`
   - If any exist → Error: "Module '{name}' already exists. Use `/absorb <source> --into {name}` to integrate, or `/evolve {name}` to improve."
   - Abort

2. **Design module spec**: From the component inventory and research findings, determine:
   - Module name and domain description
   - Capabilities list (mapped from source's feature set)
   - Component inventory (commands, agents, skills, templates needed)
   - Which core agents to reuse vs which module-specific agents to create

3. **Reference structure**: Read the reference module (default: `core/`):
   - `Glob: commands/{reference}/*.md` — read 1-2 representative commands
   - `Glob: agents/{reference}/*.md` — read 1-2 representative agents
   - `Glob: skills/{reference}/**/*.md` — read 1-2 representative skills

4. **Evaluation criteria**: Read all applicable criteria:
   - `skills/core/evaluation/references/command-criteria.md`
   - `skills/core/evaluation/references/agent-criteria.md`
   - `skills/core/evaluation/references/skill-criteria.md`

5. **Scaffold template**: Read `templates/core/module-scaffold.md`

6. **Design checkpoint** (Mode A only):
   Before presenting, apply 1-2 techniques from [divergent-techniques.md](../../skills/core/brainstorming/references/divergent-techniques.md) (e.g., SCAMPER on module scope, What-if on component boundaries) to generate 2-3 alternative designs. Present the recommended design with brief alternatives.

   Present the module design summary for user confirmation:

   ```markdown
   Module Design: {name}
   Domain: {description}
   Components planned: {N} commands, {M} agents, {K} skills, {J} templates

   Component list:

   - commands/{name}/{cmd1}.md — {description}
   - agents/{name}/{agent1}.md — {description}
   - ...

   Proceed with generation, or adjust the design?
   ```

   - On approval → proceed to Phase 6
   - On adjustment → revise module name/scope per user feedback and re-log

Log: "Module '{name}' designed: {N} commands, {M} agents, {K} skills planned."

### Mode B: Integration Gap Analysis

> Agent: **evaluator** + Bash background (when `--multi`)

Gap analysis runs Claude evaluator for deep capability comparison. When `--multi` is active, Codex runs in parallel for independent analysis — synthesis mode combines both perspectives. See `skills/core/routing/references/parallel-execution-pattern.md`.

1. **Scan existing module**: Read all components of the target module:
   - `Glob: commands/{module}/*.md`, `agents/{module}/*.md`, `skills/{module}/**/*.md`, `templates/{module}/*.md`
   - Read each file to understand current capabilities

2. **Gap analysis**: Launch **evaluator** agent via Task tool:
   - **Input**: Source component inventory (from Phase 3) + existing module component contents + module name
   - **Instructions**: "Perform gap analysis. Compare source capabilities vs existing module. Classify each as gap (missing), overlap (covered), or conflict (contradicts). Return Gap Analysis Report with prioritized gaps."
   - **Expected output**: Gap Analysis Report (gaps, overlaps, conflicts)

#### `--multi` Extension

When `--multi` is active, run Codex gap analyst in parallel per `skills/core/routing/references/parallel-execution-pattern.md`. Relay prompt: `skills/core/absorption/references/gap-analysis-relay-prompt.md`. Merge strategy: synthesis (union of gaps, deduplicate by capability, conflicts from either model included). Codex failure → Claude-only.

#### Process Results

3. **Filter actionable gaps**: Select gaps fillable with new components. For each gap, determine component type and name. Conflicts → log for review phase. No gaps → Log "No gaps identified." → Skip to Phase 7 (knowledge entry only)

4. **High-overlap checkpoint**: If overlap count > gap count AND gap count <= 2, present summary and offer: proceed with generation or record knowledge entry only. Otherwise → proceed automatically

5. **Reference components**: For each component type to generate, identify 1-2 existing same-type components (prefer same module, then `core/`). Read evaluation criteria: `skills/core/evaluation/references/{type}-criteria.md`

Log: "Gap analysis complete. {N} gaps to fill, {M} overlaps, {K} conflicts."

## Phase 6: Generation

> Agent: **generator**

### Mode A: Module Generation

Launch the **generator** agent via Task tool:

- **Input**: All context from Phase 3-5:
  - Module spec: name, domain description, capabilities (from Phase 5 design)
  - Research findings and knowledge entry draft (from Phase 3-4)
  - Reference module patterns (from Phase 5 reference structure)
  - Evaluation criteria (from Phase 5)
  - Scaffold template
- **Instructions**: "Perform Module Generation (Procedure 1). The source material comes from an external absorption — transform external patterns into ouroboros module conventions. Analyze reference patterns, design module architecture, generate all component file contents. Output a complete Module Spec with manifest, rationale, and file contents."
- **Expected output**: Module Spec (component manifest + rationale + all file contents)

Parse the Module Spec:

1. Extract the component manifest (list of files to create)
2. Extract each file's content
3. Extract the Module README content

### Mode B: Component Generation (per gap)

For each gap identified in Phase 5, launch the **generator** agent via Task tool:

- **Input**: All context from Phase 3-5:
  - Component spec: module name, component name, description, type (from Phase 5 gaps)
  - Existing module components (all files — for pattern extraction)
  - Same-type reference components (from Phase 5)
  - Research findings relevant to this gap (from Phase 3)
  - Evaluation criteria for the target component type
- **Instructions**: "Perform Component Generation (Procedure 3). This component fills a gap identified during external source absorption. Analyze existing module patterns, generate a single component that integrates seamlessly. Output a Component Spec with path, rationale, and file content."
- **Expected output**: Component Spec (path + rationale + file content)

Parse each Component Spec:

1. Extract the file path
2. Extract the file content

Collect all generated components into a unified manifest.

Log: "Generation complete. {N} components generated."

### Integration Plan (Mode A + B)

After generation, analyze which existing components should be evolved to integrate the new additions:

1. **Scan for consumers**: For each generated component, search existing same-module components for phases or sections where the new component should be referenced. Cross-reference by component type (skills → commands that apply them, agents → commands that delegate to them, etc.)

2. **Produce integration list**:

   | New Component | Existing Component | Integration Point | Suggested `/evolve` Focus |
   |---------------|-------------------|-------------------|---------------------------|
   | `{new path}` | `{existing path}` | {where the new component should be referenced} | {which phase/section to evolve} |

3. **Embed in Phase 11 output**: Replace generic "Next Actions" with specific evolve targets from this list.

Log: "Integration plan: {N} existing components identified for follow-up evolution."

## Phase 7: Worktree Setup & Write

### 7a: Session Recovery + Create Worktree

Before creating a new worktree, check for existing absorb worktrees:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh status
```

If the JSON output contains entries with `"operation": "absorb"`:

1. Report to user: "Found existing absorb worktree: `{path}` (branch: `{branch}`, {commits_ahead} commits ahead, {dirty_files} dirty files)"
2. Present options:
   - **Resume**: Continue working in the existing worktree (skip worktree creation, use existing `$WORKTREE` path)
   - **Discard**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "{path}"` and proceed with fresh worktree
   - **Merge**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "{path}" "Absorb: resume merge"` and proceed with fresh worktree
3. Wait for user choice before proceeding

Also run prune to clean up stale worktrees silently:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh prune
```

1. Derive slug from the source and mode:
   - Mode A: `{module-name}` (e.g., `code-review`)
   - Mode B: `into-{module}` (e.g., `into-dev`)
2. Create worktree:

   ```bash
   WORKTREE=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh create absorb {slug})
   ```

   The script handles branch conflicts (prior aborted absorption) by appending timestamps automatically.

### 7b: Write Knowledge Entry

Write the knowledge entry (from Phase 4) to the worktree:

1. Generate filename: `docs/specs/knowledge/{slugified-title}.md`
2. Check if file already exists in main branch:
   - If exists → append version suffix (e.g., `-v2`)
3. Write: `.worktrees/absorb-{slug}/docs/specs/knowledge/{filename}.md`

### 7c: Write Generated Components

**Mode A — Full Module:**

1. Create module directories in the worktree:

   ```bash
   mkdir -p .worktrees/absorb-{slug}/commands/{module-name}
   mkdir -p .worktrees/absorb-{slug}/agents/{module-name}
   ```

   (Only directories that will contain files)

2. Write each component file:
   - `.worktrees/absorb-{slug}/{component-path}`

3. Write the Module README:
   - `.worktrees/absorb-{slug}/commands/{module-name}/README.md`

**Mode B — Gap-Filling Components:**

1. For each generated component, ensure the directory exists:

   ```bash
   mkdir -p .worktrees/absorb-{slug}/{type-directory}/{module}
   ```

2. Write each component file:
   - `.worktrees/absorb-{slug}/{component-path}`

**If no gaps (Mode B skip):** Only the knowledge entry is written. No generated components.

Log: "{N} files written to worktree ({M} components + 1 knowledge entry)."

## Phase 8: Quality Validation

> Agent: **evaluator**, **generator** (on retry) + Bash background (when `--multi`)

Apply the [Quality Gate Procedure](../../skills/core/validation/references/quality-gate-procedure.md) to validate generated components (commands, agents, skills — templates excluded). When `--multi` is active, Claude and Codex evaluate in parallel per `skills/core/routing/references/parallel-execution-pattern.md`.

**If no generated components (Mode B, no gaps):** Skip to Phase 9.

For each component, run Mode A static evaluation. Quality gate threshold: Level >= 2. On failure, retry with Claude generator (max 1 retry).

### `--multi` Extension

When `--multi` is active, run Codex evaluator in parallel per `skills/core/routing/references/parallel-execution-pattern.md`. Relay prompt: `skills/core/evaluation/references/evaluator-relay-prompts.md`. Consensus: per-criterion majority rule per `skills/core/routing/references/consensus-protocol.md`. Circuit breaker: 2 consecutive Codex failures → skip for remaining.

Log quality validation results and proceed to Phase 9.

## Phase 9: Record Decision

Create an absorb decision entry in the worktree:

- `.worktrees/absorb-{slug}/docs/decisions/{date}-absorb-{module-name}.md` (Mode A)
- `.worktrees/absorb-{slug}/docs/decisions/{date}-absorb-into-{module}.md` (Mode B)

Entry must include:

- type: absorb
- date, module, source, mode (new-module | integrate), intent
- evaluation-summary (pass/fail counts and scores)
- Background (why this source was absorbed)
- Research Findings (key patterns and insights from Phase 3)
- Decisions (module name, gap selections, what was adapted vs faithfully copied)
- Conflicts (Mode B only — capabilities that conflicted with existing module)
- Generated Components table (all files with types and scores)
- Knowledge Entry (path to stored entry)
- Verification results

Stage and commit in worktree (`{source-display}` is a shortened version of the source — filename, domain, or topic keyword):

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh commit "$WORKTREE" "Absorb {mode}: {source-display} → {module-name}"
```

## Phase 10: Review

Present the absorption results for user review:

```markdown
## Absorption Draft: {source-display} → {module-name}

**Branch**: ouroboros/absorb/{slug}
**Mode**: {New Module | Integrate into {module}}
**Source**: {source}
**Source Type**: {Local | Web | Topic}

### Research Summary

- {Key finding 1}
- {Key finding 2}
- {Key finding 3}

### Knowledge Entry

- `docs/specs/knowledge/{filename}.md` ({tags})

### Generated Components

| # | Path | Type | Score |
|---|------|------|-------|
| 1 | `{component-path}` | {type} | {score}/5 |
| ... | ... | ... | ... |

**Quality**: {pass-count}/{total} passed (>= 3/5)

{If Mode B conflicts exist:}

### Conflicts (require attention)

| Capability | Source | Existing | Resolution |
|------------|--------|----------|------------|
| {capability} | {source component} | {existing component} | {skipped — user decision needed} |

### Diff

{git diff main...ouroboros/absorb/{slug} output}

### Decision Entry

- `docs/decisions/{date}-absorb-{...}.md`

**Merge** into main, or **Discard** the draft?
```

### On Merge

1. Merge and cleanup:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "$WORKTREE" "Absorb {mode}: {source-display} → {module-name}"
   ```

2. Confirm: "Absorption merged to main. Module '{module-name}' is now part of the monolith."

### On Discard

1. Discard: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "$WORKTREE"`
2. Confirm: "Draft discarded. No changes made to main."

## Phase 11: Report

```markdown
## Absorption Complete: {source-display} → {module-name}

**Mode**: {New Module | Integrate into {module}}
**Source**: {source}
**Components**: {count} file(s) generated + 1 knowledge entry
**Quality**: {pass-count}/{total} passed (>= 3/5)

### Knowledge Entry

- `docs/specs/knowledge/{filename}.md`
- Tags: {tags}
- Related entries: {list entries with overlapping tags, or "None"}

### Generated Files

| Path | Type | Score |
|------|------|-------|
| `docs/specs/knowledge/{filename}.md` | knowledge | — |
| `{component-path}` | {type} | {score}/5 |
| ... | ... | ... |

### Integration Plan

{If integration targets identified in Phase 6:}

| New Component | Existing Component | Suggested `/evolve` Focus |
|---------------|-------------------|---------------------------|
| `{new path}` | `{existing path}` | {focus area} |

{If no integration targets:}

- No existing components require immediate evolution.

### Next Actions

{For each integration target:}

- Run `/evolve {existing-component-path} --focus {focus}` to integrate {new-component-name}
{Always:}
- Run `/evaluate {module-name}` to assess the absorbed module
- Run `/absorb <source> --into {module-name}` to integrate additional sources
- Decision entry: `docs/decisions/{date}-absorb-{...}.md`
```

## Rules

- **Absorb = external involved** (DR-017) — if no external source, use `/generate` (new) or `/evolve` (improve existing)
- **Mode A**: Never absorb into an existing module without `--into` — use Mode B explicitly
- **Mode B**: If no gaps are found, only the knowledge entry is stored — no unnecessary component generation
- All file operations happen in the worktree — never write directly to main branch
- User reviews the final result (Phase 10) before merge — primary checkpoint. Conditional checkpoints in Phase 5 (Mode A design, Mode B high-overlap) are optional gates that prevent wasted generation
- Absorb always produces a knowledge entry, even if no components are generated — research is never wasted
- The command handles all network access (Phase 2); agents (researcher, evaluator, generator) are read-only with no network
- Quality gate is 3/5, not 5/5 — absorb creates a "starting point" that `/evolve` improves
- Maximum 1 retry round per component on quality gate failure
- On any error during worktree operations, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh cleanup "$WORKTREE"` before aborting
- If the source is a previously absorbed plugin (check `docs/decisions/` for matching source), log a warning: "This source was previously absorbed on {date}. The new absorption will create additional components, not replace existing ones."
- Namespace collision: before generating, verify that no generated component name collides with existing components across all modules
