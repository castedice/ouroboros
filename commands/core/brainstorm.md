---
description: Explore ideas through divergent and convergent thinking — generate freely, then evaluate rigorously
argument-hint: <topic-or-question> [--multi]
allowed-tools: Read, Glob, Grep, Task, Bash
---

# Brainstorm — Creative Exploration

Generate and evaluate ideas through structured divergent and convergent thinking before committing to a plan or implementation.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | brainstormer + Bash background (--multi) | Divergent idea generation + convergent evaluation + ranked recommendations (parallel with Codex + Gemini when --multi) |

## Execution Paths

| Flag | Phases | Behavior |
|------|--------|----------|
| (default) | 1, 2, 3, 5, 6 | Single-model brainstorm via Claude brainstormer agent |
| `--multi` | 1, 2, 3, 4, 5, 6 | Parallel Claude + Codex + Gemini brainstorm, cherry-pick merge, multi-model insights section added |

## Phase 1: Parse Input

Extract topic and options from $ARGUMENTS:

- **Topic**: Everything in $ARGUMENTS except flags. This is the brainstorming question or area to explore.
- **`--multi`**: Enable multi-model brainstorming in Phase 3 (Claude + Codex + Gemini parallel, cherry-pick merge)

If no argument provided:

- Output error: "Error: No topic specified. Usage: `/brainstorm <topic-or-question> [--multi]`"
- Abort

### CLI Availability Check (only when `--multi`)

Verify external model infrastructure:

1. Check `codex` and `gemini` CLI availability and versions via Bash: `which codex && codex --version; which gemini && gemini --version`
2. Check `${CLAUDE_PLUGIN_ROOT}/scripts/invoke-model.sh` exists
3. Ensure `.tmp/` directory exists (create if missing)

Store: `codex_available` (bool + version), `gemini_available` (bool + version).

Log availability:

- Both: "Multi-model: Claude + Codex v{ver} + Gemini v{ver}"
- Codex only: "Multi-model: Claude + Codex v{ver} (Gemini unavailable)"
- Gemini only: "Multi-model: Claude + Gemini v{ver} (Codex unavailable)"
- Neither: "No external CLIs found. Proceeding single-model." → disable `--multi` and continue

## Phase 2: Context Gathering

Collect relevant context to ground the brainstorming. The brainstormer agent needs concrete codebase and knowledge base context to produce actionable ideas, not abstract suggestions.

### 2.1: Codebase Context

Based on the topic, gather relevant files:

1. **Always read**: `dev/VISION.md` (philosophy), `dev/DECISIONS.md` (prior decisions relevant to topic)
2. **Topic-specific**: Glob for files matching keywords in the topic
   - If topic mentions a component/module: read its command, agent, and skill files
   - If topic mentions architecture: read `dev/VISION.md` and relevant `skills/core/` SKILL.md files
   - If topic mentions a workflow: read related `commands/core/` files
3. **Limit**: Read at most 10 context files to avoid overwhelming the agent

### 2.2: Knowledge Base

1. `Glob: docs/knowledge/*.md` — list available entries
2. Scan titles and tags for relevance to the topic
3. Read up to 3 relevant entries

### 2.3: Build Context Brief

Compile gathered context into a structured brief:

```text
## Topic
{the brainstorming topic/question}

## Codebase Context
{relevant file summaries — key facts, not full content}

## Knowledge Base
{relevant knowledge entry summaries}

## Known Constraints
{constraints from DECISIONS.md, VISION.md, or domain knowledge}
```

## Phase 3: Brainstorm

> Agent: **brainstormer** + Bash background (when `--multi`)

### Brainstormer Delegation

Launch the **brainstormer** agent via Task tool:

- **Input**: Context brief from Phase 2
- **Instructions**: "Perform Brainstorm Analysis. Read the provided context, select appropriate divergent techniques, generate 8-15 ideas, cluster into themes, apply convergent criteria, and produce a Brainstorm Analysis Report with top 3 ranked recommendations."
- **Expected output**: Brainstorm Analysis Report (ideas table, clusters, convergent assessment, top 3 with rationale)

### When `--multi` is active (parallel with Codex + Gemini):

1. **Build brainstormer relay prompt** following `skills/core/routing/references/invocation-protocol.md`:
   - **Section 1 — Role**: You are a creative thinking specialist. Generate diverse ideas through structured divergent thinking techniques, then evaluate and rank them through convergent analysis.
   - **Section 2 — Content**: Context brief from Phase 2 (verbatim)
   - **Section 3 — Methodology**: Follow the Brainstorm Analysis Procedure defined in `agents/core/brainstormer.md` (Steps 2-6: technique selection, divergent generation, clustering, convergent evaluation, top 3 selection). Reference `skills/core/brainstorming/references/divergent-techniques.md` for technique details and `skills/core/brainstorming/references/convergent-criteria.md` for evaluation framework.
   - **Section 4 — Response Format**: Schema BR from `skills/core/routing/references/relay-response-schemas.md`
   - Save to `.tmp/{SESSION_ID}_brainstorm_relay.txt`

2. **Fan-out** (parallel — up to 3 models):

   **Model selection** (from routing table):
   - Codex: `gpt-5.2` with `high` reasoning effort (general-purpose model, better than codex models for non-coding creative tasks)
   - Gemini: `gemini-3-pro-preview` (most intelligent Gemini, strong at architecture brainstorming and broad analysis)

   Launch all available models simultaneously:

   - **Background 1** (if codex_available): `Bash(invoke-model.sh codex gpt-5.2 .tmp/{SESSION_ID}_brainstorm_relay.txt .tmp/{SESSION_ID}_codex_brainstorm.json high, run_in_background=true)`
   - **Background 2** (if gemini_available): `Bash(invoke-model.sh gemini gemini-3-pro-preview .tmp/{SESSION_ID}_brainstorm_relay.txt .tmp/{SESSION_ID}_gemini_brainstorm.json, run_in_background=true)`
   - **Foreground**: Claude brainstormer agent (same delegation as above)

3. **Fan-in**: Collect background results after Claude completes. Handle exit codes per `evaluate.md` Phase 3 Step 3. Collect Codex and Gemini independently — one failure does not block the other

## Phase 4: Cherry-pick Merge (--multi only)

When Claude and external model brainstorm results are available, merge them:

1. **Union of ideas**: Combine all ideas from all models, removing near-duplicates (same concept, different wording). Tag each idea with its source model(s)
2. **Novel highlight**: Ideas that appear in only one model's output are marked as "unique perspective" with the source model noted — these are the highest-value additions from multi-model brainstorming
3. **Cross-model agreement**: Ideas independently generated by 2+ models are marked as "convergent" — higher confidence signals
4. **Re-rank**: Apply Feasibility × Impact criteria to the merged idea set using Claude's convergent assessment as the primary ranking, with external model assessments as supporting evidence
5. **Select top 3**: From the merged and re-ranked set

Graceful degradation:

- All external models failed: proceed with Claude-only results. Note: "Multi-model: external models unavailable, proceeding with single-model results."
- One model failed: merge available results (2-way instead of 3-way). Note which model was unavailable

## Phase 5: Present Results

Present the Brainstorm Analysis Report to the user:

```markdown
## Brainstorm Results: {topic}

{N} ideas generated across {M} techniques, clustered into {K} themes.

### Top 3 Recommendations

#### 1. {Idea name}
**Why**: {rationale}
**Weakness**: {honest weakness}
**Next**: `/{command} {args}` — {what this achieves}

#### 2. {Idea name}
**Why**: {rationale}
**Weakness**: {weakness}
**Next**: `/{command} {args}`

#### 3. {Idea name}
**Why**: {rationale}
**Weakness**: {weakness}
**Next**: `/{command} {args}`

### Full Analysis
{Link to or expansion of the complete Brainstorm Analysis Report: ideas table, clusters, convergent assessment}
```

If multi-model was active, add a section:

```markdown
### Multi-model Insights ({N}-way)
- **Convergent ideas**: {ideas generated by 2+ models independently — higher confidence}
- **Unique from Codex**: {ideas or perspectives that only Codex produced}
- **Unique from Gemini**: {ideas or perspectives that only Gemini produced}
- **Model count**: Claude + {available external models}
```

Omit "Unique from {model}" lines for models that were unavailable.

## Phase 6: Report

After presenting results, suggest next actions based on the brainstorming outcome:

```markdown
### Suggested Next Actions
- `/research {topic}` — investigate the selected idea further before committing
- `/generate {module/component}` — create a new component based on the selected idea
- `/evolve {component}` — improve an existing component using the selected idea
- `/brainstorm {refined-topic}` — explore a narrower aspect in more depth
- `/plan {feature}` — design the implementation if confidence is high
```

Tailor the suggestions to the specific top ideas — don't list generic commands. Each suggestion should reference a concrete idea from the brainstorm results.

## Rules

- This command produces no file artifacts — all output is conversational. To persist insights, suggest `/research` to formalize as a knowledge entry
- The brainstormer agent is read-only — command handles all context gathering (Phase 2) and network access
- User intuition is a legitimate data point — the brainstormer's ranking is a recommendation, not a decision
- Do not skip convergence — raw unranked ideas without structured evaluation are not useful output
- On `--multi` fan-out error, fall back gracefully: 3-way → 2-way → Claude-only (see Phase 4)
- **Settings requirement**: `--multi` requires `Bash(codex *)` and/or `Bash(gemini *)` in `settings.json` allow list
- **Temp file lifecycle**: all temp files go to `.tmp/{SESSION_ID}_*`. Clean up at command end: `bash scripts/session.sh cleanup {SESSION_ID}`
