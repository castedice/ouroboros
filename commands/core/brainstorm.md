---
name: core:brainstorm
description: "Use when you need to generate, compare, and narrow ideas for a problem, decision, or design direction"
argument-hint: <topic-or-question> [--framework <name>] [--output [path]] [--single]
allowed-tools: Read, Glob, Write, Task, Bash
---

# Brainstorm — Creative Exploration

Generate and evaluate ideas through structured divergent and convergent thinking before committing to a plan or implementation.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | brainstormer + Bash background (--multi) | Divergent idea generation + convergent evaluation + ranked recommendations (parallel with Codex when --multi) |

## Shared References & Payload Contracts

| Artifact | Path | Role |
|----------|------|------|
| Relay assembly contract | `skills/core/external-models/references/relay-assembly.md` | Four-section relay construction for the Codex branch |
| Output template | `templates/core/brainstorm-output.md` | Persisted brainstorm file structure for Phase 7 |

Machine-consumed payloads:
- Claude brainstorm analysis is stored at `.tmp/{SESSION_ID}_brainstorm_claude.md`.
- Codex `--multi` output is stored at `.tmp/{SESSION_ID}_codex_brainstorm.json`.
- The merged multi-model result, when produced, is stored at `.tmp/{SESSION_ID}_brainstorm_merged.md`.
- When `--output` is active, the final saved file at `{output_path}` becomes the authoritative persisted payload for downstream commands.

Status-handling rules:
- Strip any trailing completion status block per `skills/core/routing/references/completion-status-protocol.md` before counting ideas, clusters, or ranked recommendations.
- When both conversational text and an on-disk payload exist, the on-disk payload is authoritative for Phase 4 merge work and Phase 7 save output.
- If the Codex payload is missing or malformed, keep the Claude payload authoritative and skip multi-model merge for missing fields only.

### Branch Summary

| Condition | State | Affected Phases | Behavior |
|-----------|-------|-----------------|----------|
| Topic | missing | 1 abort | Error with usage and stop |
| `--framework <name>` | valid | 2, 3 | Load `skills/core/brainstorming/references/process-frameworks.md` and force that framework |
| `--framework <name>` | invalid | 1, 2, 3 | Warn and fall back to brainstormer auto-selection |
| `--single` | true | 1, 3, 4 | Skip CLI auto-detect and run Claude-only |
| `--single` | false (default) + Codex available | 1, 3, 4 | Enable parallel Claude + Codex brainstorm and Phase 4 merge |
| `--single` | false (default) + Codex unavailable | 1, 3 | Continue single-model and omit Phase 4 |
| `--output [path]` | provided | 7 | Save results to the explicit path or the default brainstorm path |
| `--output` | absent | 7 skipped | Conversational output only |
| Scope confirmation | user adjusts scope | 2 | Revise topic, scope, or techniques before Phase 3 |
| Scope confirmation | user approves | 3 | Launch the brainstormer with the confirmed brief |

## Phase 1: Parse Input

Extract topic and options from $ARGUMENTS:

- **Topic**: Everything in $ARGUMENTS except flags. This is the brainstorming question or area to explore.
- **`--framework <name>`**: Use a specific process framework. Valid names: `double-diamond`, `design-thinking`, `cps`, `triz`, `triple-diamond`. If omitted, the brainstormer agent auto-selects based on topic analysis. Invalid names produce a warning and fall back to auto-selection.
- **`--output [path]`**: Save brainstorm results to a file. If path is provided, use it. If `--output` is present without a path, use default: `docs/brainstorms/{YYYY-MM-DD}-{topic-slug}.md` where topic-slug is the topic lowercased with spaces replaced by hyphens, truncated to 50 chars.
- **`--single`**: Force single-model mode (skip external CLIs)

By default, multi-model is auto-detected — if codex CLI is installed, it runs in parallel with Claude.

If no argument provided:

- Output error: "Error: No topic specified. Usage: `/brainstorm <topic-or-question>`"
- Abort

### CLI Availability Check (auto-detect)

Skip if `--single` is specified.

Verify external model infrastructure:

1. Check `codex` CLI availability and version via Bash: `which codex && codex --version`
2. Check `${CLAUDE_PLUGIN_ROOT}/scripts/codex-relay.sh` exists
3. Ensure `.tmp/` directory exists (create if missing)

Store: `codex_available` (bool + version).

Log availability:

- Codex available: "Multi-model: Claude + Codex v{ver}"
- Codex unavailable: "Single-model mode (no external CLIs found)"

## Phase 2: Context Gathering

Collect relevant context to ground the brainstorming. The brainstormer agent needs concrete codebase and knowledge base context to produce actionable ideas, not abstract suggestions.

### 2.0: Methodology References

Read brainstorming methodology files to include in the brainstormer's context:

1. **Always read**: `skills/core/brainstorming/references/divergent-techniques.md`, `skills/core/brainstorming/references/convergent-criteria.md`
2. **Always read**: `skills/core/brainstorming/references/framing-techniques.md`
3. **If `--framework` specified or topic is complex**: `skills/core/brainstorming/references/process-frameworks.md`
4. **If topic is high-stakes (strategic, architectural, irreversible)**: `skills/core/brainstorming/references/meta-reflection.md`

### 2.1: Codebase Context

Based on the topic, gather relevant files:

1. **Always read**: `dev/VISION.md` (philosophy), `dev/DECISIONS.md` (prior decisions relevant to topic)
2. **Topic-specific**: Glob for files matching keywords in the topic
   - If topic mentions a component/module: read its command, agent, and skill files
   - If topic mentions architecture: read `dev/VISION.md` and relevant `skills/core/` SKILL.md files
   - If topic mentions a workflow: read related `commands/core/` files
3. **Limit**: Read at most 10 context files to avoid overwhelming the agent

### 2.2: Knowledge Base

1. `Glob: docs/specs/knowledge/*.md` — list available entries
2. Scan titles and tags for relevance to the topic
3. Read up to 3 relevant entries

### 2.3: Build Context Brief

Compile gathered context into a structured brief:

```text
## Topic
{the brainstorming topic/question}

## Framework
{selected framework name, or "default" if none specified}

## Codebase Context
{relevant file summaries — key facts, not full content}

## Knowledge Base
{relevant knowledge entry summaries}

## Known Constraints
{constraints from DECISIONS.md, VISION.md, or domain knowledge}
```

### 2.4: Scope Confirmation

Present the interpreted scope to the user:

```text
Topic: {interpreted topic}. Scope: {narrow|medium|broad}. Techniques: {selected techniques}. Proceed, or adjust scope?
```

Wait for user confirmation before launching the brainstormer agent.

## Phase 3: Brainstorm

> Agent: **brainstormer** + Bash background (when `--multi`)

### Brainstormer Delegation

Launch the **brainstormer** agent via Task tool:

- **Input**: Context brief from Phase 2 + methodology reference files
- **Instructions**: "Perform Brainstorm Analysis. Read the provided context, select appropriate divergent techniques, generate 8-15 ideas, cluster into themes, apply convergent criteria, and produce a Brainstorm Analysis Report with top 3 ranked recommendations."
- **Framework hint** (if `--framework` specified): Append to instructions: "Use the {framework-name} process framework. Map its stages to the brainstorming workflow as described in process-frameworks.md."
- **Expected output**: Brainstorm Analysis Report written to `.tmp/{SESSION_ID}_brainstorm_claude.md`, with ideas table, clusters, convergent assessment, and top 3 ranked recommendations.

### When `--multi` is active (parallel with Codex):

1. **Build brainstormer relay prompt** following `skills/core/routing/references/invocation-protocol.md`:
   - **Section 1 — Role**: You are a creative thinking specialist. Generate diverse ideas through structured divergent thinking techniques, then evaluate and rank them through convergent analysis.
   - **Section 2 — Content**: Context brief from Phase 2 (verbatim)
   - **Section 3 — Methodology**: Follow the Brainstorm Analysis Procedure defined in `agents/core/brainstormer.md` (Steps 2-6: technique selection, divergent generation, clustering, convergent evaluation, top 3 selection). Reference `skills/core/brainstorming/references/divergent-techniques.md` for technique details and `skills/core/brainstorming/references/convergent-criteria.md` for evaluation framework.
   - **Section 4 — Response Format**: Schema BR from `skills/core/routing/references/relay-response-schemas.md`
   - Save to `.tmp/{SESSION_ID}_brainstorm_relay.txt`

2. **Fan-out** (parallel):

   **Model selection** (from routing table):
   - Codex: `gpt-5.2` with `high` reasoning effort (general-purpose model, better than codex models for non-coding creative tasks)

   Launch all available models simultaneously:

   - **Background** (if codex_available): `Bash(codex-relay.sh .tmp/{SESSION_ID}_brainstorm_relay.txt --output .tmp/{SESSION_ID}_codex_brainstorm.json --effort high, run_in_background=true)`
   - **Foreground**: Claude brainstormer agent (same delegation as above)

3. **Fan-in**: Collect background results after Claude completes. Handle exit codes per `evaluate.md` Phase 3 Step 3.

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

### Recovery

| Failure | Max Retries | Stagnation Detection | Stop Behavior |
|---------|-------------|----------------------|---------------|
| Brainstormer timeout or malformed report | 1 | The retry still omits ideas, clusters, or ranked recommendations | Stop retrying, report the partial failure, and ask the user whether to narrow the topic |
| Codex relay failure in `--multi` | 1 | The retry also fails, or the payload adds no unique or convergent ideas beyond Claude's result | Continue with Claude-only results and note the degraded multi-model path |
| Merge quality drift | 0 | The merged set cannot preserve Claude's top 3, or the external payload only restates Claude ideas | Keep Claude's ranking as authoritative and surface external ideas only as optional notes |
| Scope mismatch after confirmation | 1 clarification loop | The user rejects the revised scope twice | Stop before Phase 3 and ask for a rewritten topic or tighter scope |


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
- **Model count**: Claude + {available external models}
```

Omit "Unique from Codex" line if Codex was unavailable.

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

## Phase 7: Save Output (--output only)

When `--output` is active, write the brainstorm results to a file:

1. **Determine output path**:
   - If explicit path provided: use it
   - If `--output` without path: `docs/brainstorms/{YYYY-MM-DD}-{topic-slug}.md`
   - Create `docs/brainstorms/` directory if it doesn't exist

2. **Build output file** using `templates/core/brainstorm-output.md` as the structure, with added frontmatter:

```yaml
---
topic: "{the brainstorming topic}"
framework: "{framework used or 'default'}"
date: "{YYYY-MM-DD}"
tags: [{relevant tags from topic keywords}]
models: ["{models used, e.g. claude, codex}"]
---
```

3. **Write the file** with the full Brainstorm Analysis Report content (ideas table, clusters, convergent assessment, top 3, not-selected section)

4. **Report**: "Brainstorm results saved to `{output-path}`"
5. Treat `{output-path}` as the authoritative persisted payload for any later `/research`, `/generate`, or `/evolve` handoff.

## Rules

- Without `--output`, this command produces no file artifacts — all output is conversational. With `--output`, results are saved to a file (see Phase 7). To persist insights as a knowledge entry, suggest `/research`
- The brainstormer agent is read-only — command handles all context gathering (Phase 2) and network access
- User intuition is a legitimate data point — the brainstormer's ranking is a recommendation, not a decision
- Do not skip convergence — raw unranked ideas without structured evaluation are not useful output
- On `--multi` fan-out error, fall back gracefully: 3-way → 2-way → Claude-only (see Phase 4)
- **Settings requirement**: `--multi` requires `Bash(codex *)` in `settings.json` allow list
- **Temp file lifecycle**: all temp files go to `.tmp/{SESSION_ID}_*`. Clean up at command end: `bash scripts/session.sh cleanup {SESSION_ID}`
