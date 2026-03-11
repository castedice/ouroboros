---
description: Research external sources — analyze plugins, fetch web content, or explore topics to build the knowledge base
argument-hint: <path|url|topic> [--shallow] [--single]
allowed-tools: Read, Glob, Grep, WebFetch, WebSearch, Write, Bash, Task
---

# Research — Knowledge Acquisition

Analyze external sources, extract patterns and insights, and store findings in the knowledge base.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 2 | sonnet collector (Task model: sonnet) | Source collection — Glob/Read (local), WebFetch (web), WebSearch+WebFetch (topic) |
| 3 | researcher (opus) + Bash background (--multi) | Analyze collected content, extract patterns, synthesize insights |

## Phase 1: Parse Input

Determine research mode from $ARGUMENTS:

| Pattern | Mode | Description |
|---------|------|-------------|
| Path exists (file or directory) | **A: Local Source** | Analyze a local plugin or codebase |
| Starts with `http://` or `https://` | **B: Web Source** | Fetch and analyze a remote source |
| Plain text (everything else) | **C: Topic Research** | Research a topic via web search |

Options:

- `--shallow`: Single-round collection without iterative convergence. Use for quick lookups or when deep research is unnecessary
- `--single`: Force single-model analysis in Phase 3 (skip external CLIs)

**Defaults** (DR-064): Deep research on by default for Mode B/C, multi-model auto-detected. See Branch Summary table below for all flag interactions.

If no argument provided:

- Output error: "Error: No target specified. Usage: `/research <path|url|topic>`"
- Abort

### Scope Definition (--deep only)

Before collection, define the research scope per `deep-research-procedure.md` § Goal Extraction:

1. **Generate research questions**: From the topic/URL, derive 3-5 specific research questions that capture what the user wants to learn. Questions must be concrete and assessable (not "What is X?" but "What are the key design trade-offs of X?")

2. **Define acceptance criteria**: For each question, define what "answered" means using the 4-level coverage framework:
   - **Strong**: 3+ independent sources with direct evidence, no unresolved contradictions
   - **Moderate**: 2 independent sources, or 1 high-credibility primary source
   - **Weak**: Single source, or only indirect evidence
   - **Unanswered**: No collected source addresses this question

3. **Present scope to user**: Display research questions and target coverage (all at "moderate" or above). User can adjust, add, or remove questions. Proceed after user confirmation.

## Branch Summary

All conditional branches that affect command behavior, consolidated for quick reference.

| Condition | State | Affected Phases | Behavior |
|-----------|-------|-----------------|----------|
| Source | Local path (Mode A) | 2: Mode A | Local collection via Glob/Read. Always standard pipeline (no deep) |
| Source | URL (Mode B) | 2: Mode B | Web fetch. Deep research on by default |
| Source | Plain text (Mode C) | 2: Mode C | Topic search. Deep research on by default |
| `--shallow` | true | 2, 3 | Single-round collection, no iterative convergence |
| `--shallow` | false (default, B/C) | 2, 3 | Deep research: iterative convergence with acceptance criteria |
| Deep + Mode A | — | Auto-downgrade | Standard pipeline. No additional sources for iteration |
| Deep + `--multi` | — | 3 | Round 1: Claude + Codex parallel. Round 2+: Claude only |
| `--single` | true | 3 | Claude researcher only (skip Codex) |
| `--single` | false (default) | 3 | Auto-detect: if codex CLI installed, parallel analysis |
| URL | Unreachable | 2 abort | Error + suggest local path or topic keyword |
| Topic | No results found | 2 abort | Error + suggest refining topic or direct URL |
| Deep scope | User adjusts questions | 1 | Adjust research scope before collection |
| Existing worktree | Found | 5: Session Recovery | User chooses Resume / Discard / create fresh |

## Phase 2: Gather Sources (Sonnet Collector)

> **2-tier architecture**: Phase 2 uses **sonnet** for I/O-heavy source collection (no judgment needed). Phase 3 uses **opus** researcher for deep analysis. This saves cost by routing mechanical collection to a cheaper model.

### Mode A: Local Source

Delegate to sonnet collector via `Task(model: "sonnet", subagent_type: "general-purpose")`:

- **Instructions**: "Read and collect content from the local path: {path}. If directory: Glob for key plugin files (`CLAUDE.md`, `plugin.json`, `README.md`), component files (`commands/**/*.md`, `agents/**/*.md`, `skills/**/*.md`, `templates/**/*.md`), and hooks (`hooks/hooks.json`). Read each discovered file. If single file: read it and check parent directory for related files. Return all collected content with file paths."
- **Expected output**: Collected content with file paths

If collector fails, fall back to direct Glob + Read in main context.

Log: "Found {N} files from local source. Proceeding with analysis."

### WebFetch Constraints (Mode B + C)

> Content passes through a Haiku summarization layer — raw source text is never returned. Pages over 100KB are truncated (tail content lost). Authenticated pages and JS-rendered SPAs return empty or partial content. If a URL yields thin results, try topic mode with alternative search terms.

### Mode B: Web Source

Delegate to sonnet collector via `Task(model: "sonnet", subagent_type: "general-purpose")`:

- **Instructions**: "Fetch content from URL: {url}. If the content appears to be a plugin repository or documentation, identify links to key files (CLAUDE.md, plugin.json, commands/, agents/) and WebFetch up to 5 additional linked pages. Return all fetched content."
- **Expected output**: Collected web content

If URL is unreachable:

- Inform user: "URL unreachable. Try a local path or topic keyword instead."
- Abort

Log: "Fetched {N} pages from web source. Proceeding with analysis."

### Mode C: Topic Research

Delegate to sonnet collector via `Task(model: "sonnet", subagent_type: "general-purpose")`:

- **Instructions**: "Search for topic: {topic}. WebSearch the keyword (include 'Claude Code plugin' or relevant context if applicable). Select top 3-5 most relevant results. WebFetch each selected result. Return all collected content with source URLs."
- **Expected output**: Collected content from web sources

If no results found:

- Inform user: "No relevant results found. Try refining the topic or use a direct URL."
- Abort

Log: "Collected content from {N} web sources. Proceeding with analysis."

### Auto Collection Expansion (--deep only)

When `--deep` is active, all collected content is merged into a single `collected_content` set with source URL dedup.

### Targeted Collection (--deep round 2+)

For iteration rounds after the initial broad collection, use focused queries derived from gap analysis:

1. Receive gap-derived queries from convergence assessment (max 3 per round)
2. Delegate to sonnet collector via `Task(model: "sonnet", subagent_type: "general-purpose")`:
   - **Instructions**: "Search and fetch content for these targeted queries: {queries}. Exclude these already-collected URLs: {collected_urls}. WebSearch each query, select top 2 results per query, WebFetch each. Return collected content with source URLs."
3. Merge new content into cumulative `collected_content`, update `collected_urls` set
4. If 0 new sources found: flag for convergence check (source saturation)

## Phase 3: Analysis (Opus Researcher)

> Agent: **researcher** (opus) + Bash background (when `--multi`)

Analysis runs the opus researcher agent for deep knowledge-base-integrated analysis — this is the synthesis tier that requires judgment, pattern extraction, and cross-referencing. When `--multi` is active, Codex researcher runs in parallel for a fresh perspective — cherry-pick mode combines the best insights from both. See `skills/core/routing/references/parallel-execution-pattern.md`.

**IMPORTANT**: The command passes all collected content (from sonnet collector in Phase 2) to the researcher agent. The researcher agent is read-only and does not access the network — all network access happens in Phase 2.

### Researcher Delegation (all modes)

Launch the Claude **researcher** agent via Task tool:

- **Input**: All collected source content + research mode + original target
- **Instructions**: "Perform Research Analysis. Scan the provided content, extract patterns and conventions, synthesize insights, cross-reference existing knowledge base. Produce a Research Analysis Report."
- **Instructions (--deep addition)**: Append to the above: "Assess coverage of each research question per `deep-research-procedure.md`. Append a Coverage Assessment section with per-question coverage level (strong/moderate/weak/unanswered), evidence summary, gap type (collection/knowledge/scope), and suggested follow-up queries for any question below 'moderate'."
- **Expected output**: Research Analysis Report (key findings, patterns, trade-offs, suggested tags) + Coverage Assessment (--deep only)

### When `--multi` is active (parallel with Codex):

1. **Build researcher relay prompt** using the Research Analyst template from `skills/core/routing/references/relay-prompt-templates.md`. Wrap collected source content in `<<<UNTRUSTED_CONTENT_START>>>` / `<<<UNTRUSTED_CONTENT_END>>>` markers before inserting as Section 2. Save to `.tmp/{SESSION_ID}_researcher_relay.txt`

2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.4 .tmp/{SESSION_ID}_researcher_relay.txt .tmp/{SESSION_ID}_codex_analysis.json high, run_in_background=true)`
   - **Foreground**: Claude researcher agent (same delegation as above)

3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3

4. **Cherry-pick merge**: Review both analysis reports and build a unified Research Analysis:
   - Union of all key findings and patterns from both models
   - Prefer findings with stronger evidence citations
   - Novel insights from Codex that Claude missed are highlighted as "External insight"
   - If Codex analysis failed or is partial, proceed with Claude-only analysis
   - Merged analysis feeds into Phase 4 (Draft Knowledge Entry) — the orchestrator uses the combined insights

### Iterative Deepening (--deep only)

After the initial analysis (round 1), enter the convergence loop per `deep-research-procedure.md`:

**State**: `round` (starts at 1), `cumulative_findings` (researcher output), `collected_urls` (dedup set), `coverage_scores` (per-question levels from Coverage Assessment)

**Loop** (repeat until converged):

1. **Convergence decision**: Evaluate the 5 stop conditions from `deep-research-procedure.md` § Convergence Logic against current `coverage_scores`:
   - All questions at "moderate" or above → stop: "Research goals met"
   - Zero collection gaps in Coverage Assessment → stop: "No further sources available"
   - Previous targeted collection returned 0 new sources → stop: "Source saturation reached"
   - `round` = 5 → stop: "Max iterations reached"
   - `coverage_scores` identical to previous round → stop: "No progress detected"
   - Otherwise → continue

2. **Targeted collection** (sonnet): Extract `suggested_query` values from collection-type gaps in the Coverage Assessment. Delegate to the Targeted Collection procedure in Phase 2. Update `collected_urls`.

3. **Re-synthesis** (opus researcher): Launch researcher with `cumulative_findings` + new sources only. Instructions per `deep-research-procedure.md` § Iterative Synthesis: "Integrate new sources into existing findings. Update coverage levels. Focus on what new sources add, contradict, or confirm." Update `cumulative_findings` and `coverage_scores`.

4. Increment `round`, loop to step 1.

**`--multi` interaction**: When `--deep --multi`, only round 1 uses parallel Claude + Codex analysis. Round 2+ uses Claude researcher only — iterative refinement benefits from consistency over diversity.

**Failure handling**: If targeted collection fails, skip to convergence re-evaluation with existing findings. If re-synthesis fails, use previous round's findings as final result and stop.

**Log**: After convergence, report: "Deep research converged after {round} rounds. Reason: {stop_reason}. Coverage: {N}/{total} questions at moderate or above."

## Phase 4: Draft Knowledge Entry

Build a knowledge entry from the researcher's report:

1. **Title**: Derive from the research focus (concise, descriptive)
2. **Frontmatter**:
   - `title`: the derived title
   - `tags`: use the researcher's suggested tags + add relevant existing tags from `docs/specs/knowledge/`
   - `source`: original target (path, URL, or topic keyword)
   - `created`: today's date (YYYY-MM-DD)
   - `status`: `active`
   - `related`: scan existing entries in `docs/specs/knowledge/` for 30%+ tag overlap. List matching filenames (e.g., `[llm-as-judge-evaluation.md, evaluation-scoring-design.md]`). Empty `[]` if no overlap found
3. **Body**: Structure from the Research Analysis Report
   - Overview — brief summary of what was researched and why
   - Key Patterns — conventions, techniques, design decisions
   - Practical Applications — how findings apply to ouroboros
   - Trade-offs — limitations and considerations
   - References — source URLs or citations

Use `templates/core/knowledge-entry.md` as the structural guide.

When `--deep` is active, add a "Research Process" section (see `templates/core/knowledge-entry.md` § Research Process) documenting: research questions asked, iterations completed, final coverage per question, and open questions remaining.

## Phase 5: Worktree Setup

### Session Recovery

Before creating a new worktree, check for existing research worktrees:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh status
```

If the JSON output contains entries with `"operation": "research"`:

1. Report to user: "Found existing research worktree: `{path}` (branch: `{branch}`, {commits_ahead} commits ahead, {dirty_files} dirty files)"
2. Present options:
   - **Resume**: Continue working in the existing worktree (skip worktree creation, use existing `$WORKTREE` path)
   - **Discard**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "{path}"` and proceed with fresh worktree
   - **Merge**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "{path}" "Research: resume merge"` and proceed with fresh worktree
3. Wait for user choice before proceeding

Also run prune to clean up stale worktrees silently:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh prune
```

### Create Worktree

Create an isolated worktree for writing the knowledge entry:

1. Derive slug from the research target (e.g., `compound-engineering`, `oh-my-claudecode`)
2. Create worktree:

   ```bash
   WORKTREE=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh create research {slug})
   ```

   The script handles branch conflicts by appending timestamps automatically.

## Phase 6: Store in Worktree

1. Generate filename: `docs/specs/knowledge/{slugified-title}.md`
   - Slugify: lowercase, replace spaces with hyphens, remove special characters
2. Check if file already exists in main branch:
   - If exists: append version suffix (e.g., `-v2`) — knowledge entries are append-only
3. Write the knowledge entry to the **worktree**: `$WORKTREE/docs/specs/knowledge/{filename}.md`
4. Stage and commit in worktree:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh commit "$WORKTREE" "Add knowledge entry: {title}"
   ```

## Phase 7: Review

Present the draft knowledge entry and diff for user review:

```markdown
## Research Draft: {title}

**Branch**: ouroboros/research/{slug}
**File**: docs/specs/knowledge/{filename}.md
**Tags**: {tags}
**Source**: {source}

### Key Findings
- {Finding 1}
- {Finding 2}
- {Finding 3}

### Draft Preview
{full entry content preview}

**Merge** this knowledge entry into main, or **Discard** the draft?
```

### On Merge

1. Merge and cleanup:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "$WORKTREE" "Add knowledge entry: {title}"
   ```

2. Regenerate knowledge index:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/knowledge-catalog.sh index
   ```

3. Confirm: "Knowledge entry merged to main at `docs/specs/knowledge/{filename}.md`"

### On Discard

1. Discard: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "$WORKTREE"`
2. Confirm: "Draft discarded. No changes made to main."

## Phase 8: Report

```markdown
## Research Complete: {title}

### Key Findings
- {Finding 1}
- {Finding 2}
- {Finding 3}

### Knowledge Base
- Stored: `docs/specs/knowledge/{filename}.md`
- Tags: {tags}
- Related entries: {list entries with overlapping tags, or "None yet"}

### Deep Research Summary (--deep only)
- Iterations: {round_count} (converged: {stop_reason})
- Sources: {initial_count} → {final_count} (+{new_sources} from targeted collection)
- Coverage: {covered_count}/{total_questions} questions at moderate or above
- Open questions: {list of questions still at weak/unanswered, or "None"}

### Suggested Next Actions
- `/research "{related_topic_from_findings}"` — deepen understanding of connected patterns
- `/absorb docs/specs/knowledge/{filename}.md` — integrate findings into existing module components
- `/generate {recommended_module}` — create a new module based on extracted patterns
- `/evaluate {most_relevant_component_path}` — assess components related to findings
```

## System Context

| Context | Usage |
|---------|-------|
| `/absorb` Phase 2 | Research is the collection engine — absorb delegates source analysis to /research |
| `/evolve` pre-analysis | Researcher agent analyzes evaluation results before planning improvements |
| `/swe spiral` knowledge turn | Research captures learnings from completed spiral turns |
| Standalone | Direct invocation for topic exploration or source analysis |

**Artifacts**: Produces `docs/specs/knowledge/{filename}.md` entries (written via worktree, merged after user review).

## Rules

- Knowledge entries are append-only — create a new version if an update is needed, never overwrite existing entries
- The command handles all network access (Phase 2); the researcher agent stays read-only with no network
- If a URL is unreachable, inform the user and suggest alternatives (local path or topic mode)
- All file writes happen in the worktree — never write directly to main branch
- User reviews the final draft (Phase 7) before merge — this is the only checkpoint
- One knowledge entry per research session — keep output focused
- All knowledge entries must be written in the language appropriate to the content (follow existing entry conventions)
- On any error during worktree operations, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh cleanup "$WORKTREE"` before aborting
