---
name: pa:focus
description: "Use when you need a goal-centered working context with the relevant entities, relationships, and next actions"
effort: medium
allowed-tools:
  - Read
  - Glob
  - Agent
  - Write
  - AskUserQuestion
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__multi_get
  - mcp__qmd__status
argument-hint: "<goal or topic>"
---

# Focus — Goal-Centered Working Context

Build a comprehensive working context around a goal or topic. Composes entity analysis (weaver), content retrieval (librarian), and relationship mapping into a project dossier with actionable next steps.

Goal: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 3 | librarian (agent, sonnet) | Assemble context pack from vault via QMD retrieval |
| 4 | weaver (agent, sonnet) | Graph reasoning — entity analysis, relation discovery, connection mapping |
| 2, 5 | Read (tool) | Load state files, read dossier template |
| 6 | Write (tool) | Persist dossier to .pa/dossiers/, update derivation-state.json |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/vault-profile.json` | read | Retrieval defaults, linking style, link_density, moc_preference |
| `.pa/settings.json` | read | Collection name, vault path, automation posture |
| `.pa/derivation-state.json` | read+write | Dirty-path tracking, focus analysis timestamp |
| `.pa/entities.json` | read+write | Existing entity data |
| `.pa/relations.json` | read+write | Existing relation data |
| `.pa/memory-heads.json` | read | Active facts for the dossier's "what we know" section and source-note seeding |
| `.pa/dossiers/{subject}.json` | write | Persisted dossier output |
| `.pa/mask-map.json` | read | Person name resolution for dossier display |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No goal argument | 1 | Ask the user what goal or topic they want to focus on |
| No `.pa/settings.json` | 1 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/vault-profile.json` | 1 | Abort: "Run `/pa survey` or `/pa init` first" |
| QMD unavailable | 2 | Warn: semantic retrieval unavailable. Proceed with structural analysis only |
| `.pa/memory-heads.json` missing or empty | 2 | Continue with graph + QMD retrieval only |
| Librarian returns zero results | 4 | Proceed with weaver analysis only — dossier will lack content excerpts |
| Weaver returns zero relations | 5 | Report sparse graph — dossier focuses on retrieved content |
| Both librarian and weaver return empty | 5 | Report: "No vault content or connections found for this goal" |
| Existing dossier found for subject | 2 | Offer: refresh (rebuild) or view existing dossier |
| Dirty paths exist | 3 | Refresh dirty paths before analysis |

### Recovery

Use one bounded recovery loop per delegated or optional surface in this command.

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Graph bootstrap or preliminary weaver query | 1 attempt only | No seed entity or no candidate notes are resolved | Stop graph enrichment and continue with QMD-only retrieval |
| Librarian retrieval | 1 full attempt + 1 narrowed retry using graph seeds only or the simplest topic query | The retry yields the same failure, the same low-confidence result, or no new citations | Stop retrying and continue with weaver-only dossier or the no-content contract |
| Dossier weaver analysis | 1 full attempt + 1 retry using the existing `graph_context` only | The retry yields the same failure class or no new relations or open items | Stop retrying and render from librarian content only |


## Phase 1: Parse Input

Extract the goal or topic from `$ARGUMENTS`.

The goal is a free-text string describing what the user wants to focus on. It can be:
- A project name: "Project Alpha"
- A topic: "meta-prompts design patterns"
- A goal statement: "메타프롬프트 설계 패턴 정리"
- An entity name: "Kim"

If no argument is provided, ask: "어떤 목표나 주제에 집중하시겠어요?"

## Phase 2: Load State

Check vault maturity per `skills/pa/trust-and-boundaries/references/vault-maturity.md`.
If below `intermediate`, present guidance and suggest `/pa brief`.
Continue regardless.
Guidance is advisory.

1. Read `.pa/settings.json` — extract vault path, collection name, automation posture.
2. Read `.pa/vault-profile.json` — extract qmd_defaults, linking_style, link_density.
3. Read `.pa/derivation-state.json` — check for dirty paths.
4. Read `.pa/entities.json` and `.pa/relations.json` if they exist.
5. Read `.pa/memory-heads.json` if it exists — load active facts for the goal's central entity or topic. If missing or empty, continue without memory facts.
6. Read `.pa/mask-map.json` if it exists — load for entity name resolution (all privacy-bearing kinds).
7. **Shadow vault check**: Read `shadow_root` from `.pa/settings.json`. If `shadow_root` exists, prefer reading target notes from `{shadow_root}/{path}` instead of the raw vault path. If `shadow_root` is not set, fall back to checking `.pa/shadow/` for backward compatibility.
8. Check for existing dossier in `.pa/dossiers/` matching the subject and apply the `Existing dossier` row from the Subject Resolution Contract.
9. Verify QMD availability via `mcp__qmd__status`.
10. Read `.pa/soul.md` — load soul layer (frontmatter for render settings, body for soul context). If missing, read `.pa/persona.json` as fallback (render only). If both missing, use defaults from `skills/pa/persona-response/references/persona-schema.md`.

If required state files are missing, abort per the Decision Matrix.
If an existing dossier is found, ask once: "기존 '{subject}' dossier가 있습니다. 새로 만들까요, 기존 것을 볼까요?"

## Subject Resolution Contract

Resolve subject-centered memory and graph context once, then reuse it across the librarian and weaver phases.

| Concern | Rule |
|---------|------|
| Existing dossier | Ask once whether to view or rebuild. If the user chooses `view existing`, present the stored dossier and stop before new delegation |
| Memory facts | Use the goal string and any resolved seed entity to identify the central entity for `memory-heads.json` lookup before broader retrieval |
| Graph bootstrap | When `.pa/entities.json` and `.pa/relations.json` exist, run one preliminary weaver `graph-query` with `query_type: "subgraph"` and reuse the resulting `graph_context` in both Phase 3 and Phase 4 |
| Missing ontology files or unresolved seed | Skip graph bootstrap and continue with topic-level memory lookup plus QMD-only retrieval |
| Reuse rule | Never rebuild `graph_context` in the same invocation when Phase 3 already produced a usable one. Only carry it forward or note that it was unavailable |

## Phase 3: Librarian Delegation

> Agent: **librarian**

Delegate content retrieval to the librarian agent.
Resolve and carry forward `memory_context` plus reusable `graph_context` through the Subject Resolution Contract before delegation.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | goal string, brief type (`focus`), vault-profile.json contents, settings.json contents, `memory-heads.json` contents (if present), graph_context (if available) |
| Instructions | Apply `skills/pa/context-assembly/SKILL.md` workflow. Query memory heads for the central entity or topic before QMD planning. Use broader retrieval with hyde for comprehensive topic coverage. Return a structured context pack |
| Expected Output | Context pack with query analysis, matching memory facts, retrieved documents with excerpts, coverage assessment, citation index |

### Recovery

| Failure | Action |
|---------|--------|
| Weaver graph query fails | Warn and proceed with QMD-only retrieval |
| Librarian timeout | Warn and proceed with weaver analysis only |
| Librarian returns error (QMD failure) | Warn and proceed with structural analysis only |
| Zero results | Proceed — dossier will note "no content retrieved" |

## Phase 4: Weaver Delegation

> Agent: **weaver**

Delegate graph analysis to the weaver agent. Run after the librarian so the weaver can incorporate retrieved content as additional context.
Reuse the `graph_context` resolved through the Subject Resolution Contract.
Run Workflow G with `query_type: "subgraph"` only when that contract left `graph_context` unavailable and the ontology files are present.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | goal string, analysis type (`dossier`), vault-profile.json contents, settings.json contents, existing entities/relations, dirty paths, librarian context pack (if available), graph_context (if available), `mask_map` (if available) |
| Instructions | Apply `skills/pa/personal-ontology/SKILL.md` workflow. Run Workflow G before Workflow C with `query_type: "subgraph"` when graph context is missing or stale. Identify the central entity from the goal. Discover entity neighborhood. Extract timeline markers. Identify open items. Use `references/entity-canonicalization.md` for identity resolution. Use `references/relation-taxonomy.md` for relation classification |
| Expected Output | Project dossier data: central entity profile, related entities with relations, timeline, open items, graph density metrics |

### Recovery

| Failure | Action |
|---------|--------|
| Weaver timeout | Render dossier from librarian content only |
| Weaver returns error | Render dossier from librarian content only, note structural analysis unavailable |
| Zero relations | Include in dossier with note about sparse graph |

## Phase 5: Render Dossier

Read `templates/pa/project-dossier.md` for the output structure.
Render the dossier by applying the template's `Rendering Rules`, `Field Resolution`, `Section Omission Rules`, `Person Entity Presentation Rules`, and `Dossier Storage` contract.
Use the resolved `subject`, `memory_context`, librarian context pack, weaver dossier data, and `mask_map` as render inputs.
Treat the lower of librarian content confidence and weaver entity confidence as the overall dossier confidence.
If either source is missing, omit the affected sections per the template instead of inventing filler.

## Phase 6: Persist and Present

### Persist Dossier

Write the rendered dossier to `.pa/dossiers/{subject_slug}.json` per `templates/pa/project-dossier.md` (Dossier Storage section). The slug is derived from the goal string following the template's rules.

### Update State

1. Update `.pa/derivation-state.json` — record focus analysis timestamp, mark refreshed dirty paths.
2. Update `.pa/entities.json` — persist newly discovered entities.
3. Update `.pa/relations.json` — persist newly discovered relations.

### Persona Application

Before presenting results to the user, apply the persona render contract from `skills/pa/persona-response/references/render-contract.md`:
- Use the sentence style from `render_hints.sentence_style`
- Apply warmth level from `warmth`
- Apply directness level from `directness`
- Respect emoji setting from `render_hints.emoji`
- Do not alter substance: facts, rankings, evidence, confidence, citations, and action recommendations stay unchanged

### Present

Output the rendered dossier in conversation using `templates/pa/project-dossier.md` format.

## Phase 7: Next Actions

| Condition | Suggested Action |
|-----------|-----------------|
| Dossier has high confidence | "`/pa link '{entity}'` — 특정 연결을 더 탐색해 볼까요?" |
| Dossier has low confidence | "Vault에 이 주제 관련 노트를 더 추가하면 분석이 풍부해집니다" |
| Open items found | "미해결 항목이 있습니다. 처리할 것을 선택해 주세요" |
| Timeline has upcoming events | "다가오는 일정이 있습니다. `/pa agenda`로 우선순위를 확인하세요" |
| Dense graph | "`/pa draft '{subtopic}'` — 관련 하위 주제를 정리해 볼까요?" |

## Composability

| Context | Usage |
|---------|-------|
| `/pa link` | Link provides targeted relationship discovery. Focus uses link as a component for comprehensive analysis |
| `/pa brief` | Brief provides content dossier. Focus incorporates brief-style content alongside graph analysis |
| `/pa ask` | Ask is conversational Q&A. Focus is comprehensive working context — complementary |
| `/pa draft` | Focus identifies what to write. Draft produces the note |
| `/pa agenda` | Focus surfaces open items and timeline. Agenda provides priority ordering |
| `/pa survey` | Survey builds baseline ontology. Focus refines it around a specific goal |

## Rules

- **Dual-source synthesis**: Combine graph analysis (weaver) with the librarian's memory facts and QMD note retrieval for comprehensive coverage
- **Dossier persistence**: Always write to `.pa/dossiers/` — dossiers are reusable assistant state
- **Read-only analysis**: Focus never modifies vault notes. It discovers and reports
- **Graceful degradation**: If one agent fails, render dossier from the other agent's output alone
- **Vault-profile faithful**: Respect link_density, moc_preference, and linking_style in all output
