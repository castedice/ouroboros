---
description: Research external sources — analyze plugins, fetch web content, or explore topics to build the knowledge base
argument-hint: <path|url|topic> [--multi]
allowed-tools: Read, Glob, Grep, WebFetch, WebSearch, Write, Bash, Task
---

# Research — Knowledge Acquisition

Analyze external sources, extract patterns and insights, and store findings in the knowledge base.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | researcher + Bash background (--multi) | Analyze collected content, extract patterns, synthesize insights (parallel with Codex when --multi) |

## Phase 1: Parse Input

Determine research mode from $ARGUMENTS:

| Pattern | Mode | Description |
|---------|------|-------------|
| Path exists (file or directory) | **A: Local Source** | Analyze a local plugin or codebase |
| Starts with `http://` or `https://` | **B: Web Source** | Fetch and analyze a remote source |
| Plain text (everything else) | **C: Topic Research** | Research a topic via web search |

Options:

- `--multi`: Enable multi-model analysis in Phase 3 (Claude + Codex parallel researcher, cherry-pick merge)

If no argument provided:

- Output error: "Error: No target specified. Usage: `/research <path|url|topic>`"
- Abort

## Phase 2: Gather Sources

### Mode A: Local Source

1. Verify path exists
2. If directory:
   - Glob for key plugin files: `CLAUDE.md`, `plugin.json`, `README.md`
   - Glob for component files: `commands/**/*.md`, `agents/**/*.md`, `skills/**/*.md`, `templates/**/*.md`
   - Glob for hooks: `hooks/hooks.json`
   - Read each discovered file
3. If single file:
   - Read the file
   - Check parent directory for related files if it appears to be part of a plugin
4. Log: "Found {N} files from local source. Proceeding with analysis."

### Mode B: Web Source

1. WebFetch the provided URL
2. If the content appears to be a plugin repository or documentation:
   - Identify links to key files (CLAUDE.md, plugin.json, commands/, agents/)
   - WebFetch up to 5 additional linked pages
3. If URL is unreachable:
   - Inform user: "URL unreachable. Try a local path or topic keyword instead."
   - Abort
4. Log: "Fetched {N} pages from web source. Proceeding with analysis."

### Mode C: Topic Research

1. WebSearch the topic keyword (include "Claude Code plugin" or relevant context if applicable)
2. Review search results — select top 3-5 most relevant
3. WebFetch each selected result
4. If no results found:
   - Inform user: "No relevant results found. Try refining the topic or use a direct URL."
   - Abort
5. Log: "Collected content from {N} web sources. Proceeding with analysis."

## Phase 3: Analysis

> Agent: **researcher** + Bash background (when `--multi`)

Analysis runs Claude researcher for deep knowledge-base-integrated analysis. When `--multi` is active, Codex researcher runs in parallel for a fresh perspective — cherry-pick mode combines the best insights from both. See `skills/core/routing/references/parallel-execution-pattern.md`.

**IMPORTANT**: The command passes all collected content to the researcher agent. The researcher agent is read-only and does not access the network — all network access happens in Phase 2.

### Researcher Delegation (all modes)

Launch the Claude **researcher** agent via Task tool:

- **Input**: All collected source content + research mode + original target
- **Instructions**: "Perform Research Analysis. Scan the provided content, extract patterns and conventions, synthesize insights, cross-reference existing knowledge base. Produce a Research Analysis Report."
- **Expected output**: Research Analysis Report (key findings, patterns, trade-offs, suggested tags)

### When `--multi` is active (parallel with Codex):

1. **Build researcher relay prompt** following `skills/core/routing/references/invocation-protocol.md`:
   - **Section 1 — Role**: Independent research analyst analyzing provided source content
   - **Section 2 — Content**: All collected source content from Phase 2 (verbatim)
   - **Section 3 — Methodology**: Scan → Extract patterns → Synthesize → Suggest tags
   - **Section 4 — Response Format**: Schema R from `skills/core/routing/references/relay-response-schemas.md`
   - Save to `.tmp/{SESSION_ID}_researcher_relay.txt`

2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_researcher_relay.txt .tmp/{SESSION_ID}_codex_analysis.json high, run_in_background=true)`
   - **Foreground**: Claude researcher agent (same delegation as above)

3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3

4. **Cherry-pick merge**: Review both analysis reports and build a unified Research Analysis:
   - Union of all key findings and patterns from both models
   - Prefer findings with stronger evidence citations
   - Novel insights from Codex that Claude missed are highlighted as "External insight"
   - If Codex analysis failed or is partial, proceed with Claude-only analysis
   - Merged analysis feeds into Phase 4 (Draft Knowledge Entry) — the orchestrator uses the combined insights

## Phase 4: Draft Knowledge Entry

Build a knowledge entry from the researcher's report:

1. **Title**: Derive from the research focus (concise, descriptive)
2. **Frontmatter**:
   - `title`: the derived title
   - `tags`: use the researcher's suggested tags + add relevant existing tags from `docs/knowledge/`
   - `source`: original target (path, URL, or topic keyword)
   - `created`: today's date (YYYY-MM-DD)
   - `status`: `active`
   - `related`: scan existing entries in `docs/knowledge/` for 30%+ tag overlap. List matching filenames (e.g., `[llm-as-judge-evaluation.md, evaluation-scoring-design.md]`). Empty `[]` if no overlap found
3. **Body**: Structure from the Research Analysis Report
   - Overview — brief summary of what was researched and why
   - Key Patterns — conventions, techniques, design decisions
   - Practical Applications — how findings apply to ouroboros
   - Trade-offs — limitations and considerations
   - References — source URLs or citations

Use `templates/core/knowledge-entry.md` as the structural guide.

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

1. Generate filename: `docs/knowledge/{slugified-title}.md`
   - Slugify: lowercase, replace spaces with hyphens, remove special characters
2. Check if file already exists in main branch:
   - If exists: append version suffix (e.g., `-v2`) — knowledge entries are append-only
3. Write the knowledge entry to the **worktree**: `$WORKTREE/docs/knowledge/{filename}.md`
4. Stage and commit in worktree:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh commit "$WORKTREE" "Add knowledge entry: {title}"
   ```

## Phase 7: Review

Present the draft knowledge entry and diff for user review:

```markdown
## Research Draft: {title}

**Branch**: ouroboros/research/{slug}
**File**: docs/knowledge/{filename}.md
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

2. Confirm: "Knowledge entry merged to main at `docs/knowledge/{filename}.md`"

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
- Stored: `docs/knowledge/{filename}.md`
- Tags: {tags}
- Related entries: {list entries with overlapping tags, or "None yet"}

### Suggested Next Actions
- `/research {related topic}` — deepen understanding
- `/generate {module}` — create a module based on findings
- `/absorb {source}` — integrate external patterns into existing components
- `/evolve {component}` — improve a component using new insights
```

## Rules

- Knowledge entries are append-only — create a new version if an update is needed, never overwrite existing entries
- The command handles all network access (Phase 2); the researcher agent stays read-only with no network
- If a URL is unreachable, inform the user and suggest alternatives (local path or topic mode)
- All file writes happen in the worktree — never write directly to main branch
- User reviews the final draft (Phase 7) before merge — this is the only checkpoint
- One knowledge entry per research session — keep output focused
- All knowledge entries must be written in the language appropriate to the content (follow existing entry conventions)
- On any error during worktree operations, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh cleanup "$WORKTREE"` before aborting
