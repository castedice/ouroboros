---
name: core:research
description: "Use when you need to study external sources, plugins, or topics and capture findings in the knowledge base"
argument-hint: <path|url|topic> [--shallow] [--single]
allowed-tools: Read, Glob, WebFetch, WebSearch, Write, Bash, Skill, Task
---

# Research — Knowledge Acquisition

Analyze external sources, extract patterns and insights, and store findings in the knowledge base.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 2 | sonnet collector (Task model: sonnet) | Source collection — Glob/Read (local), WebFetch (web), WebSearch+WebFetch (topic) |
| 3 | researcher (opus) + Bash background (--multi) | Analyze collected content, extract patterns, synthesize insights |
| 5 | draft-writer (sonnet, isolated worktree) | Write knowledge entry to isolated worktree, commit |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass source artifact paths, collected source URLs, and inline collected content on every collector or researcher call.
Use named return payloads rather than prose-only summaries.
The command owns network access, cumulative state, and final knowledge-entry assembly.
Collector and researcher remain read-only.
Phase 5 draft-writer is the documented core-module exception to the default file-ownership rule and should return explicit draft metadata only.
Internal agent calls use `Agent(subagent_type: "ouroboros:core:{agent}")` when a core agent exists, and the sonnet collector still follows the same explicit-input contract.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `sonnet collector` | 2 and targeted collection | Original target, mode, artifact paths, inline prior content when reused, excluded URLs, and deep-research or KB reference paths when present | `sources[]`, `source_count`, `collected_content`, `collected_urls[]`, `perspectives[]`, `gaps[]`, and `unresolved_questions[]` |
| `ouroboros:core:researcher` | 3 and iterative re-synthesis | Original target, mode, artifact paths, inline collected content, prior KB context, cumulative findings, and deep-research reference paths | `analysis_report`, `key_findings[]`, `patterns[]`, `tradeoffs[]`, `suggested_tags[]`, `coverage_assessment[]`, `follow_up_queries[]`, and `unresolved_questions[]` |
| `ouroboros:core:draft-writer` | 5 | Finalized knowledge entry content, target path, commit message, and worktree context | `worktree`, `branch`, `files[]`, `commit_message`, and `unresolved_questions[]` |

| Artifact | Path | Role |
|----------|------|------|
| Deep research procedure | `skills/core/research/references/deep-research-procedure.md` | Scope definition, convergence rules, and iterative synthesis |
| Source evaluation | `skills/core/research/references/source-evaluation.md` | Independence checks before raising deep-research coverage levels |
| Relay prompt templates | `skills/core/routing/references/relay-prompt-templates.md` | Round 1 Codex researcher relay assembly |
| Parallel execution pattern | `skills/core/routing/references/parallel-execution-pattern.md` | Fan-out, fan-in, and round-1 multi-model behavior |
| Completion status protocol | `skills/core/routing/references/completion-status-protocol.md` | Strip terminal status blocks before parsing collector or researcher outputs |
| KB similarity contract | `skills/core/research/references/kb-similarity-contract.md` | Duplicate, related, and contradiction handling |
| Knowledge entry template | `templates/core/knowledge-entry.md` | Draft structure for Phase 4 |
| PA bridge contract | `skills/pa/content-pipeline/references/bridge-contracts.md` | Optional post-merge PA ingest handoff |

Machine-consumed payloads:
- Phase 2 collector rounds write `.tmp/{SESSION_ID}_collector_round{n}.md`.
- Phase 3 Claude analysis writes `.tmp/{SESSION_ID}_research_round{n}_claude.md`.
- Phase 3 Codex round 1 analysis writes `.tmp/{SESSION_ID}_codex_analysis.json`.
- Phase 3.5 novelty results write `.tmp/{SESSION_ID}_novelty.json`.
- Phase 4 draft knowledge entry writes `.tmp/{SESSION_ID}_knowledge_entry.md` before the worktree write.

Status-handling rules:
- Strip trailing status blocks per `skills/core/routing/references/completion-status-protocol.md` before counting sources, deduplicating URLs, or parsing sections.
- Round 1 `--multi` uses cherry-pick merge with Claude as the authoritative base and Codex as additive evidence only.
- Round 2+ use Claude-only updates to the same cumulative state and do not reopen consensus on prior rounds.


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

Before collection, run the Goal Extraction procedure from `skills/core/research/references/deep-research-procedure.md`.
Derive 3-5 concrete research questions, define target coverage using that reference's coverage framework and independence rules, and present the scoped question set to the user for confirmation or adjustment before collection starts.

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

If a collector response includes the terminal completion status block from `skills/core/routing/references/completion-status-protocol.md`, strip it before counting files, deduplicating URLs, or passing collected content to Phase 3.

### Active KB Integration

Before mode-specific collection, run `bash scripts/kb-similarity.sh "$ARGUMENTS" --threshold 0.3 --top 5 --format json`.
Interpret the returned matches using `skills/core/research/references/kb-similarity-contract.md` instead of hard-coding duplicate or related thresholds here.
If the contract classifies a match as a close duplicate, warn the user that closely matching knowledge already exists and suggest updating the existing entry instead of drafting a new one.
If the contract classifies matches as related, read those KB entries and load them as prior context for the Phase 3 researcher agent.
Log a `KB Context Loaded` note with each loaded entry's `path`, `title`, and `score` so the Phase 3 analyst can see what prior knowledge was injected.

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

- **Role split**: Run the collection as three explicit perspectives within the same delegation: `skeptic`, `practitioner`, and `theorist`
- **Instructions**: "Search for topic: {topic}. WebSearch the keyword (include 'Claude Code plugin' or relevant context if applicable). Collect 1-2 sources per role perspective. `skeptic`: find contradictions, weak evidence, and missing context. `practitioner`: find practical application guidance and real-world constraints. `theorist`: find underlying principles and broader framework connections. WebFetch each selected result. Return all collected content with source URLs and a perspective label for each source."
- **Expected output**: Collected content from web sources with perspective labels

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
   - **Background**: `Bash(codex-relay.sh .tmp/{SESSION_ID}_researcher_relay.txt --output .tmp/{SESSION_ID}_codex_analysis.json --effort high, run_in_background=true)`
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

1. **Convergence decision**: Evaluate the stop conditions from `skills/core/research/references/deep-research-procedure.md` § Convergence Logic against current `coverage_scores`, the latest gap types, and source-saturation signals.
Use the reference's bounded cap, no-progress rule, and source-independence checks instead of redefining them here.

2. **Targeted collection** (sonnet): Extract `suggested_query` values from collection-type gaps in the Coverage Assessment. Delegate to the Targeted Collection procedure in Phase 2. Update `collected_urls`.

3. **Re-synthesis** (opus researcher): Launch researcher with `cumulative_findings` + new sources only. Instructions per `deep-research-procedure.md` § Iterative Synthesis: "Integrate new sources into existing findings. Update coverage levels. Focus on what new sources add, contradict, or confirm." Update `cumulative_findings` and `coverage_scores`.

4. Increment `round`, loop to step 1.

**`--multi` interaction**: When `--deep --multi`, only round 1 uses parallel Claude + Codex analysis. Round 2+ uses Claude researcher only — iterative refinement benefits from consistency over diversity.

**Failure handling**: If targeted collection fails, skip to convergence re-evaluation with existing findings. If re-synthesis fails, use previous round's findings as final result and stop.

**Log**: After convergence, report: "Deep research converged after {round} rounds. Reason: {stop_reason}. Coverage: {N}/{total} questions at moderate or above."

## Phase 3.5: Novelty Assessment

Extract a concise key findings summary from the final Research Analysis Report and run `bash scripts/kb-similarity.sh "{key_findings_summary}" --threshold 0.3 --top 5 --format json`.
Apply the match interpretation and carry-forward rules from `skills/core/research/references/kb-similarity-contract.md` rather than restating thresholds inline.
Use that contract to decide whether to suggest updating an existing entry, flag a contradiction for user review, or carry related matches into Phase 4 metadata.
If no results are returned, confirm that the findings appear novel and proceed normally.
Log a `Novelty Assessment` note with each retained match's `path`, `title`, `score`, and `outcome`.

## Phase 4: Draft Knowledge Entry

Build a knowledge entry from the researcher's report and Phase 3.5 novelty result:

1. **Title**: Derive from the research focus (concise, descriptive)
2. **Frontmatter**:
   - `title`: the derived title
   - `tags`: use the researcher's suggested tags + add relevant existing tags from `docs/specs/knowledge/`
   - `source`: original target (path, URL, or topic keyword)
   - `created`: today's date (YYYY-MM-DD)
   - `status`: `active`
   - `related`: include Phase 3.5 `related` matches plus any additional 30%+ tag-overlap matches from `docs/specs/knowledge/`, deduplicated. List matching filenames (e.g., `[llm-as-judge-evaluation.md, evaluation-scoring-design.md]`). Empty `[]` if no overlap found
3. **Body**: Structure from the Research Analysis Report
   - Overview — brief summary of what was researched and why
   - Key Patterns — conventions, techniques, design decisions
   - Related Entries — overlapping KB entries from Phase 3.5 and how this entry differs, extends, or contradicts them
   - Practical Applications — how findings apply to ouroboros
   - Trade-offs — limitations and considerations
   - References — source URLs or citations

Use `templates/core/knowledge-entry.md` as the structural guide.

When `--deep` is active, add a "Research Process" section (see `templates/core/knowledge-entry.md` § Research Process) documenting: research questions asked, iterations completed, final coverage per question, and open questions remaining.

### Phase 4.5: Action Checkpoint

If the draft's "Practical Applications" section suggests a pattern that should be applied to ouroboros, present a structured checkpoint instead of auto-jumping.
Format: `{target: "/absorb" | "/evolve", rationale: "...", likely_components: ["..."], command_draft: "..."}`.
User decides whether to continue with research only or run the drafted follow-up command manually.

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

### Write via Draft Writer

Delegate file writing to the draft-writer agent running in an isolated worktree:

1. Prepare: the knowledge entry content (from Phase 4) and target path `docs/specs/knowledge/{filename}.md`
2. Spawn the draft-writer agent:

   ```
   Agent(subagent_type: "ouroboros:core:draft-writer")
   ```

   Prompt payload:
   - File: `docs/specs/knowledge/{filename}.md` with the knowledge entry content
   - Commit message: `Add knowledge entry: {title}`

3. Parse the `DRAFT_RESULT` block from the agent's response to extract `worktree`, `branch`, and `files`

If the draft-writer agent fails, abort and report the error to the user.

## Phase 6: Store in Worktree

Writing is handled by the draft-writer agent in Phase 5.
Use the returned `worktree`, `branch`, and `files` values as the committed draft state for review.

## Phase 7: Review

Present the draft knowledge entry and diff for user review:

```markdown
## Research Draft: {title}

**Branch**: {branch}
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
   git merge --squash {branch} && git commit -m "Add knowledge entry: {title}" && git worktree remove {worktree} && git branch -D {branch}
   ```

2. Regenerate knowledge index:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/knowledge-catalog.sh index
   ```

3. Confirm: "Knowledge entry merged to main at `docs/specs/knowledge/{filename}.md`"

### PA Vault Bridge (Optional)

After merge completes, check if PA module is available for cross-module knowledge capture.

1. Check if `.pa/settings.json` exists via `Glob(".pa/settings.json")`.
2. If PA module is not detected, skip silently.
3. If PA module is detected, present the bridge proposal per `skills/pa/content-pipeline/references/bridge-contracts.md` (Route 2: Core → PA).
4. If user confirms, build the structured summary from the merged knowledge entry and invoke `Skill("ouroboros:pa:ingest")` with the summary text.
5. If user declines, skip silently.

### On Discard

1. Discard: `git worktree remove --force {worktree} && git branch -D {branch}`
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
- On any error during worktree operations, run `git worktree remove --force {worktree} && git branch -D {branch}` before aborting
