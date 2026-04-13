---
name: pa:link
description: "Use when you need to discover or repair meaningful relationships around a note, entity, or topic"
effort: low
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
  - Write
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__status
argument-hint: "<note-path or topic>"
---

# Link — Relationship Discovery

Discover connections for a note or topic. Suggests new links, resolves broken wikilinks, and generates relationship maps when density warrants it.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 3 | weaver (agent, sonnet) | Graph reasoning — entity extraction, relation discovery, fact-aware link suggestions, and conservative fact extraction |
| 2 | Read (tool) | Load vault-profile.json, settings.json, derivation-state.json, existing entity/relation data |
| 5 | Write (tool) | Update .pa/derivation-state.json and persist entity, relation, and memory data to .pa/ |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/vault-profile.json` | read | Linking style, density, MOC preference |
| `.pa/settings.json` | read | Collection name, vault path, posture |
| `.pa/preferences-learned.json` | read (optional) | Approved learned preferences for `link` suggestion volume |
| `.pa/derivation-state.json` | read+write | Dirty-path tracking |
| `.pa/entities.json` | read+write | Existing entity data |
| `.pa/relations.json` | read+write | Existing relation data |
| `.pa/entity-revisions.jsonl` | read+write | Append-only entity identity history for merge and split events |
| `.pa/memories.jsonl` | read+write | Atomic fact log discovered during link analysis |
| `.pa/memory-links.jsonl` | read+write | Fact-to-fact evidence edges |
| `.pa/memory-heads.json` | read+write | Active fact heads used for fact-first lookup |
| `.pa/mask-map.json` | read | Person name resolution for display |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No target argument | 1 | Ask the user what note or topic they want to explore |
| No `.pa/settings.json` | 1 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/vault-profile.json` | 1 | Abort: "Run `/pa survey` or `/pa init` first" |
| Target is a file path that exists | 1 | Use as note-based analysis target |
| Target is a file path that does not exist | 1 | Search for matching notes by name, fall back to topic-based analysis |
| Target is a topic string (no path separators) | 1 | Topic-based analysis — search vault for related notes |
| QMD unavailable | 2 | Warn and proceed with structural analysis only (no semantic reinforcement) |
| No existing entity/relation data | 2 | First-time extraction — run lightweight extraction on target neighborhood |
| `.pa/memory-heads.json` exists | 3 | Pass active facts to weaver so relationship discovery can compare against known entity facts |
| Weaver returns merge, split, or identity-level entity changes | 5 | Append entity revision entries with change type and evidence |
| Dirty paths exist in target neighborhood | 3 | Refresh dirty paths before analysis |
| Weaver returns zero suggestions | 4 | Report: "No new connections found. The target appears isolated or fully linked" |
| Weaver discovers 5+ relations | 4 | Include relationship map in output |
| Weaver returns new facts or fact links | 5 | Append them to the memory logs and rebuild `memory-heads.json` |
| `create_unresolved_breadcrumbs=false` | 3 | Do not suggest creating new notes to resolve broken links |
| User requests apply | 5 | Apply bounded, reversible link additions with posture check |

### Output Contracts

| Output Mode | Trigger | Required Shape |
|-------------|---------|----------------|
| `suggestions` | Weaver returned link suggestions but no map-level output is required | Render the `Phase 4` output template with `Suggestions`, `Unresolved Links`, and `Summary` |
| `relationship-map` | Weaver discovered 5+ relations or the user explicitly requested map-style output | Render `templates/pa/relationship-map.md` as the map body, preceded by `## Link Analysis: [[{target}]]` and followed only by unresolved-link fixes or next actions when present |
| `apply-preview` | The user asked to apply but posture or scope still requires confirmation | Show exact target paths, edit types, and the confirmation question before any write |
| `apply-result` | Suggested edits or bounded state updates were applied | Show applied paths, skipped paths, and the updated state summary |
| `no-connections` | Weaver returned zero suggestions and zero unresolved fixes | Short no-connection report with target, reason, and next actions |
| `analysis-error` | Analysis still fails after bounded recovery | Short failure report naming the degraded mode used or the exact failed surface |

### Recovery

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Weaver analysis | 1 full attempt + 1 structural-only retry when QMD or semantic reinforcement failed | The retry returns the same failure class or no additional evidence chains | Stop retrying and use the degraded structural-only or error output contract |
| Apply confirmation | 1 confirmation round for proposal-only or multi-note changes | The user leaves the same proposal unresolved or the clarified edit set does not change | Stop prompting, keep the proposal unresolved, and end the run without writes |
| No-connection outcome | 0 retries once the no-connection result is established | A second pass would use the same target, same state, and same evidence | Keep the `no-connections` report and recommend a narrower follow-up instead of looping |


## Phase 1: Parse Input

Extract the target from `$ARGUMENTS`.

The argument can be a vault-relative file path, an absolute file path, or a plain topic string. Resolve per the Decision Matrix. If no argument is provided, ask: "어떤 노트나 주제의 연결 관계를 찾아볼까요?"

## Phase 2: Load State

1. Read `.pa/settings.json` — extract vault path, collection name, automation posture.
2. Read `.pa/vault-profile.json` — extract `linking_style` (link_density, moc_preference, create_unresolved_breadcrumbs), `naming_rules`.
3. Read `.pa/preferences-learned.json` (optional). If a `frequency` rule for `link` is approved, cap suggestion count to the recommended value (e.g., top-3 instead of default top-5). If file missing, use default suggestion count.
4. Read `.pa/derivation-state.json` — check for `dirty_paths` entries in the target's neighborhood.
5. Read `.pa/entities.json` and `.pa/relations.json` if they exist — load existing ontology data.
6. Read `.pa/entity-revisions.jsonl` if it exists — load prior identity history for append-safe revision updates.
7. Read `.pa/memory-heads.json` if it exists — load active facts for the target neighborhood.
8. Read `.pa/memories.jsonl` and `.pa/memory-links.jsonl` if they exist — load prior fact history for append-safe updates.
9. Read `.pa/mask-map.json` if it exists — load for entity name resolution (all privacy-bearing kinds).
10. **Shadow vault check**: Read `shadow_root` from `.pa/settings.json`. If `shadow_root` exists, prefer reading target notes from `{shadow_root}/{path}` instead of the raw vault path. This ensures Claude only sees privacy-protected content. If `shadow_root` is not set, fall back to checking `.pa/shadow/` for backward compatibility.
11. Check QMD availability via `mcp__qmd__status`. If unavailable, warn and continue with structural analysis only.

If required state files are missing, abort per the Decision Matrix.

## Phase 3: Weaver Delegation

> Agent: **weaver**

Delegate graph analysis to the weaver agent.

### Pre-delegation: Target Note Reading

If the target is a file path, read the target note's content. Extract:
- All wikilinks (resolved and unresolved)
- Frontmatter fields
- Note title
- Tags

Pass this data to the weaver along with the state files.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | target note content (or topic string), analysis type (`link-suggestions` or `relationship-map`), vault-profile.json contents, settings.json contents, existing entities/relations, existing entity revisions, existing memories, memory heads, dirty paths, `mask_map` (if available) |
| Instructions | Apply `skills/pa/personal-ontology/SKILL.md` workflow. Use `references/entity-canonicalization.md` for alias resolution. Use `references/entity-revision-schema.md` for merge and split history. Use `references/relation-taxonomy.md` for relation classification. Use `references/contradiction-resolution.md` when new facts conflict with active memory heads. Check `memory-heads.json` for existing facts about the entities involved before deciding whether a claim is new, reinforcing, or conflicting. Respect `link_density` for suggestion count. Respect `create_unresolved_breadcrumbs` for unresolved link suggestions. Generate relationship map only when 5+ relations discovered or explicitly requested. Return append-ready memory records for any clear new facts found during link discovery, and return append-ready entity revision rows when link-driven canonicalization causes merge, split, or other identity-level changes |
| Expected Output | Link suggestions report with evidence chains, optional relationship map, entity/relation data updates, optional entity revision entries, and any memory-layer updates |

### Recovery

| Failure | Action |
|---------|--------|
| Weaver timeout | Report error and suggest retrying with a simpler target |
| Weaver returns error (QMD failure) | Fall back to structural-only analysis |
| Zero suggestions | Report that no new connections were found |

## Phase 4: Present Results

Present the weaver's output to the user.

### Read-Only Presentation

Default behavior — show discovered connections without modifying the vault.

1. **Link suggestions**: Show each suggestion with evidence, confidence, and the proposed action.
2. **Unresolved link fixes**: Show broken wikilinks with suggested corrections.
3. **Relationship map**: Include when the weaver discovers 5+ relations or the user requested `--map`.

### Person Entity Display

When presenting link suggestions involving person entities:
1. **User-facing output**: Unmask person entities — show real names instead of mask_ids for readability
2. **State persistence**: Keep mask_ids in `.pa/entities.json` and `.pa/relations.json`
3. **Relationship type display**: Show person-specific relation types (`colleague-of`, `family-of`, etc.) when applicable

Use `pa-mask.sh unmask` logic (or mask-map lookup) to resolve mask_ids to real names in the presentation layer only.

### Output Template

```markdown
## Link Analysis: [[{target}]]

### Suggestions ({n} connections)

#### 1. [[{entity}]] — {relation_type} (confidence: {high|medium|low})
- **Evidence**: {structural signal description}
- **Action**: {suggest link | resolve unresolved | already linked}

...

### Unresolved Links ({n} found)

| Unresolved | Best Match | Confidence |
|------------|------------|------------|
| `[[{broken}]]` | [[{match}]] | {confidence} |

### Summary
- **Entities**: {count} | **Relations**: {count} | **Density**: {sparse|moderate|dense}

---
더 자세한 답변이 필요하면 말씀하세요.
```

For relationship maps (5+ relations or `--map`), use `templates/pa/relationship-map.md`.

### link_density Enforcement

| `link_density` | Display Limit |
|-----------------|---------------|
| `low` | Show top 1-2 suggestions |
| `medium` | Show top 3-5 suggestions |
| `high` | Show all suggestions |

Always show unresolved link fixes regardless of density setting — these are corrections, not new suggestions.

## Phase 5: Apply (On Request)

Link application happens only when the user explicitly asks to apply the suggestions. Default is read-only.

### Posture Check

Before applying, check automation posture from `.pa/settings.json`:

| Posture | Behavior |
|---------|----------|
| `observe` | Refuse — "Current posture is observe. Switch to `apply-low-risk` to enable link edits" |
| `propose` | Show exact edits, ask for confirmation before each |
| `apply-low-risk` | Apply single-note link additions automatically. Confirm before multi-note changes |
| `operate` | Apply all suggested link additions. Confirm before deletions |

### Apply Rules

1. **Single-note edits**: Adding wikilinks to the target note is a low-risk write. Apply under `apply-low-risk` or higher.
2. **Unresolved link fixes**: Correcting a wikilink target in the originating note is a low-risk write.
3. **New note creation**: Creating a note to resolve a wikilink is a high-risk write. Requires `operate` posture or explicit confirmation.
4. **`create_unresolved_breadcrumbs=false`**: Never create new notes to resolve broken links when this setting is `false`.

### State Updates

After analysis (regardless of apply):
1. Update `.pa/derivation-state.json` — mark refreshed dirty paths, record the link analysis timestamp.
2. Update `.pa/entities.json` — persist newly discovered entities.
3. Update `.pa/relations.json` — persist newly discovered relations.
4. Update `.pa/entity-revisions.jsonl` — append revision rows with `change_type`, `change_summary`, and source-note evidence when merge, split, status, canonical-note, or other identity-level changes happened during link discovery.
Do not append revision rows for pure evidence refresh.
5. Update `.pa/memories.jsonl` — append newly discovered facts from the analyzed note or neighborhood.
6. Update `.pa/memory-links.jsonl` — append supporting, contradicting, superseding, or explicit `derives` links returned by the weaver.
7. Update `.pa/memory-heads.json` — rebuild the active fact materialized view from the latest memory state.

## Phase 6: Feedback Recording

If link suggestions were presented to the user (not a read-only relationship map), record user feedback per the Feedback Recording Contract in `skills/pa/trust-and-boundaries/references/ledger-schema.md`.

For link suggestions, the feedback applies to the suggestion set as a whole.
If the user applied some and rejected others, record `modified` with `feedback_tags` indicating which aspects were accepted.

Skip this phase in unattended mode.

## Phase 7: Next Actions

| Condition | Suggested Action |
|-----------|-----------------|
| Suggestions presented | "이 연결들을 적용하려면 말씀하세요" (if posture allows) |
| Relationship map shown | "`/pa focus '{entity}'` — 이 주제에 대한 종합 분석을 해볼까요?" |
| Unresolved links found | "미해결 링크를 수정하려면 말씀하세요" |
| Sparse graph | "Vault 내 연결이 적습니다. 관련 노트를 더 작성하면 연결이 풍부해집니다" |
| Dense graph | "`/pa brief '{topic}'` — 관련 컨텐츠 브리핑이 필요하면 말씀하세요" |

## Composability

| Context | Usage |
|---------|-------|
| `/pa focus` | Focus composes link + brief + optional draft around a goal |
| `/pa brief` | Brief provides content dossier, link provides structural analysis — complementary |
| `/pa survey` | Survey builds the baseline ontology that link refines |
| `/pa draft` | After draft writes a note, link discovers its connections |
| `/pa` router | Router fast path provides narrow link suggestions, deep path delegates here |

## Rules

- **Read-only by default**: Link never modifies the vault unless the user explicitly requests apply
- **Structural-first**: Every suggestion has structural evidence. Semantic similarity reinforces but never creates connections
- **Vault-profile faithful**: Respect `link_density`, `moc_preference`, and `create_unresolved_breadcrumbs`
- **Bounded apply**: Single-note, reversible link additions only. No bulk operations without confirmation
- **Dirty-path aware**: Check and refresh stale areas before analysis
