---
description: Absorb external sources into the modular monolith — orchestrate Research + Evaluate + Generate/Evolve to transform external patterns into internal modules or components
argument-hint: <path|url|topic> [--into <module>] [--reference <module>] [--multi]
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
| `--multi` | No | Enable multi-model analysis in Phase 3 (Claude + Codex parallel researcher, cherry-pick), Phase 5 (Claude + Codex parallel gap analysis, synthesis), and Phase 8 (Claude + Codex parallel evaluator, consensus) |

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

### When `--multi` is active (parallel):

1. **Build researcher relay prompt**: Construct from collected source content + analysis instructions. Save to `.tmp/{SESSION_ID}_researcher_relay.txt`

   **Section 1 — Role** (fixed template):

   ```text
   You are an independent research analyst. Your task is to analyze the provided source content and extract architectural patterns, design decisions, conventions, and a component inventory for absorption into a plugin system. Produce a structured research analysis. Do not assume any prior context — analyze based solely on the content given.
   ```

   **Section 2 — Content**: All collected source content from Phase 2 (verbatim) + source type + mode (A or B).

   **Section 3 — Methodology**:

   ```text
   Follow this procedure:
   1. Scan all provided content. Identify scope: plugin structure, file types, key files
   2. Extract patterns: naming conventions, structure, design decisions, techniques, trade-offs
   3. Build component inventory: capabilities with types (command/agent/skill/template candidates)
   4. Mode-specific: {Mode A: suggest module name with rationale | Mode B: map integration points to existing module structure}
   5. Suggest 3-7 tags for categorization
   ```

   **Section 4 — Response Format**: JSON with `key_findings`, `component_inventory`, `architectural_patterns`, `mode_specific` (module name or integration points), `suggested_tags` arrays.

2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_researcher_relay.txt .tmp/{SESSION_ID}_codex_analysis.json high, run_in_background=true)`
   - **Foreground**: Launch Claude **researcher** agent (via Task tool) with all collected content

3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3

4. **Cherry-pick merge**: Review both analysis reports and build a unified Research Analysis:
   - Union of all key findings and component inventory items from both models
   - Prefer findings with stronger evidence citations
   - Novel insights from Codex that Claude missed are highlighted as "External insight"
   - If Codex analysis failed or is partial, proceed with Claude-only analysis
   - Merged analysis feeds into Phase 4 (Knowledge Entry) and Phase 5 (Gap Analysis)

### When `--multi` is not active (single-model):

Launch the **researcher** agent via Task tool:

- **Input**: All collected source content + source type + original target + mode (A or B)
- **Instructions**:
  - "Perform Research Analysis on the provided content."
  - "Source type: {source type}. Mode: {A or B}."
  - "Required output sections: (1) Key Findings — top 3-5 patterns with evidence, (2) Component Inventory — capabilities with types (command/agent/skill candidates), (3) Architectural Patterns — structural decisions worth preserving, (4) Mode-specific: {Mode A: suggested module name with rationale | Mode B: integration points mapped to existing module structure}, (5) Suggested Tags — for knowledge entry."
- **Expected output**: Research Analysis Report (structured per above sections)

Parse the researcher's report to extract:

1. **Key findings**: patterns, conventions, architectural decisions
2. **Component inventory**: what capabilities/components the source offers
3. **Suggested module name** (Mode A) or **integration points** (Mode B)
4. **Suggested tags** for the knowledge entry

Log: "Research analysis complete. {N} key findings, {M} components identified."

## Phase 4: Knowledge Entry Draft

Build a knowledge entry from the researcher's report (same structure as `/research` Phase 4):

1. **Title**: Derive from the source and research focus
2. **Frontmatter**:
   - `title`: the derived title
   - `tags`: researcher's suggested tags + relevant existing tags from `docs/knowledge/`
   - `source`: original source (path, URL, or topic)
   - `created`: today's date (YYYY-MM-DD)
   - `status`: `active`
   - `related`: scan existing entries in `docs/knowledge/` for 30%+ tag overlap. List matching filenames (e.g., `[llm-as-judge-evaluation.md]`). Empty `[]` if no overlap found
3. **Body**: Structure from the Research Analysis Report
   - Overview — what was analyzed and why
   - Key Patterns — conventions, techniques, design decisions
   - Practical Applications — how findings apply to ouroboros
   - Trade-offs — limitations and considerations
   - References — source citations

Use `templates/core/knowledge-entry.md` as the structural guide.

4. **Deduplication check**:
   - Glob `docs/knowledge/*.md` and read frontmatter (title + tags) of each entry
   - Compare tags: if >= 50% tag overlap with any existing entry, flag as "high overlap"
   - For high-overlap entries, read the body and compare key patterns
   - If substantial content overlap → merge approach: extend the existing entry rather than creating a new one
   - If distinct angle on shared topic → proceed with new entry, note the related entry in References
   - **Minimum depth**: knowledge entry body must contain at least 3 distinct actionable patterns not already present in overlapping entries

5. **Supersession check** (when high overlap detected):
   - If the new entry substantially replaces an existing entry's content (>80% pattern coverage + more recent source), flag for supersession in Phase 10 review:
     - "Suggest: mark `{existing-entry}` as `status: superseded` with `superseded_by: {new-entry}` — the new entry covers its content with updated findings."
   - Do not auto-supersede — present as a recommendation for user decision during Phase 10 review

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

Gap analysis runs Claude evaluator for deep capability comparison. When `--multi` is active, Codex runs in parallel for independent analysis — synthesis mode combines both perspectives into a comprehensive gap report. See `skills/core/routing/references/parallel-execution-pattern.md`.

1. **Scan existing module**: Read all components of the target module:
   - `Glob: commands/{module}/*.md`
   - `Glob: agents/{module}/*.md`
   - `Glob: skills/{module}/**/*.md`
   - `Glob: templates/{module}/*.md`
   - Read each file to understand current capabilities

#### When `--multi` is active (parallel):

1. **Build gap analysis relay prompt**: Construct from source component inventory + existing module contents + gap analysis instructions. Save to `.tmp/{SESSION_ID}_gap_relay.txt`

   **Section 1 — Role** (fixed template):

   ```text
   You are an independent capability analyst. Your task is to compare a source's capabilities against an existing plugin module and identify gaps, overlaps, and conflicts. Produce a structured gap analysis. Do not assume any prior context — analyze based solely on the content given.
   ```

   **Section 2 — Content**: Source component inventory (from Phase 3) + existing module component contents (verbatim) + module name.

   **Section 3 — Methodology**:

   ```text
   Follow this procedure:
   1. Catalog existing module capabilities (per component)
   2. Catalog source capabilities (from component inventory)
   3. Compare: classify each source capability as gap (missing), overlap (covered), or conflict (contradicts)
   4. For gaps: determine component type and suggest name
   5. Prioritize gaps by impact (critical functionality first)
   ```

   **Section 4 — Response Format**: JSON with `gaps` (array of {capability, type, name, priority, rationale}), `overlaps` (array of {capability, existing_component}), `conflicts` (array of {capability, source_approach, existing_approach}).

2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_gap_relay.txt .tmp/{SESSION_ID}_codex_gap.json high, run_in_background=true)`
   - **Foreground**: Launch Claude **evaluator** agent (via Task tool) for gap analysis

3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3

4. **Synthesis merge**: Combine both gap analyses into a unified report:
   - Union of all gaps from both models (deduplicate by capability name)
   - If both models identify the same gap, merge their rationale and use the higher priority
   - Gaps identified by only one model are included but marked with source ("Claude-only" or "Codex-only")
   - Conflicts identified by either model are included (conservative — false positive conflicts are safer than missed ones)
   - If Codex analysis failed, proceed with Claude-only analysis

#### When `--multi` is not active (single-model):

2. **Gap analysis**: Launch **evaluator** agent via Task tool:
   - **Input**: Source component inventory (from Phase 3) + existing module component contents + module name
   - **Instructions**: "Perform gap analysis. Compare the source's capabilities against the existing module. Identify: (1) capabilities present in source but missing from module (gaps to fill), (2) capabilities that overlap (no action needed), (3) capabilities that conflict (require user decision). Return a Gap Analysis Report with prioritized gaps."
   - **Expected output**: Gap Analysis Report (gaps, overlaps, conflicts)

3. **Filter actionable gaps**: From the gap analysis:
   - Select gaps that can be filled with new components (commands, agents, skills, templates)
   - For each gap, determine component type and name
   - If conflicts found → log them for the review phase
   - If no gaps found → Log "No gaps identified. Source capabilities already covered by module." → Skip to Phase 7 (record knowledge entry only)

4. **High-overlap checkpoint** (Mode B only):
   - If overlap count > gap count AND gap count <= 2:
     - Present to user:

       ```markdown
       Gap Analysis Summary:

       - Overlaps: {M} capabilities already covered
       - Gaps: {N} remaining ({list brief descriptions})
       - Conflicts: {K}

       The source is largely reflected in the existing module.
       Proceed with component generation for {N} gaps, or record knowledge entry only?
       ```

     - On "knowledge only" → Skip to Phase 7 (record knowledge entry only)
     - On "proceed" → continue to Phase 6
   - Otherwise → proceed to Phase 6 automatically

5. **Reference components**: For each component type to generate:
   - Identify 1-2 existing components of the same type (prefer same module, then `core/`)
   - Read evaluation criteria: `skills/core/evaluation/references/{type}-criteria.md`

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

1. **Scan for consumers**: For each generated component:
   - If **skill**: search `commands/{module}/*.md` for phases where this knowledge applies (e.g., a validation skill → commands with evaluation phases)
   - If **agent**: search `commands/{module}/*.md` for phases that delegate to related domains
   - If **command**: search `skills/{module}/` and `agents/{module}/` for overlapping capabilities
   - If **template**: identify commands that produce the same document type

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

1. Generate filename: `docs/knowledge/{slugified-title}.md`
2. Check if file already exists in main branch:
   - If exists → append version suffix (e.g., `-v2`)
3. Write: `.worktrees/absorb-{slug}/docs/knowledge/{filename}.md`

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

Apply the [Quality Gate Procedure](../../skills/core/validation/references/quality-gate-procedure.md) to validate generated components. When `--multi` is active, Claude and Codex evaluate in parallel for consensus scoring. See `skills/core/routing/references/parallel-execution-pattern.md`.

**If no generated components (Mode B, no gaps):** Skip to Phase 9.

### When `--multi` is active (parallel):

For each generated command, agent, and skill (templates excluded):

1. **Build relay prompt**: Construct Mode A static evaluation prompt from component content + criteria reference. Save to `.tmp/{SESSION_ID}_relay.txt`
2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_relay.txt .tmp/{SESSION_ID}_codex_eval.json xhigh, run_in_background=true)`
   - **Foreground**: Launch Claude **evaluator** agent (via Task tool) for static evaluation
3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3
4. **Consensus**: Apply per-criterion majority rule (same as `evaluate.md` Phase 5.5). Consensus score determines pass/fail

Process components sequentially with circuit breaker (2 consecutive Codex failures → skip Codex for remaining components).

Quality gate threshold remains Level >= 2 (same as single-model). On failure, retry uses Claude generator only.

### When `--multi` is not active (single-model):

Evaluate each generated command, agent, and skill (templates excluded).

Apply the Quality Gate Procedure as defined.

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

- `docs/knowledge/{filename}.md` ({tags})

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

- `docs/knowledge/{filename}.md`
- Tags: {tags}
- Related entries: {list entries with overlapping tags, or "None"}

### Generated Files

| Path | Type | Score |
|------|------|-------|
| `docs/knowledge/{filename}.md` | knowledge | — |
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
