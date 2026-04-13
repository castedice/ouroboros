# Cross-Module Bridge Contracts

> Purpose: Reference for `content-pipeline` skill — defines routing rules for cross-module integration between PA, SWE, and Core modules.
> All bridges use explicit user-confirmed proposals.

## Core Principle

**"Modules share context through explicit proposals, never automatic hooks."**

Cross-module bridges present proposals after significant workflow phases.
The user decides what enters their vault.
No module silently writes to another module's data store.

## PA Module Detection

Before proposing a bridge action, check if PA is active:

```
Glob(".pa/settings.json")
```

If absent, skip the bridge proposal silently.
Do not suggest PA installation from SWE/Core commands.

## Bridge Routes

| # | Direction | Trigger | Proposal | Acceptance |
|---|-----------|---------|----------|------------|
| 1 | SWE → PA | `/swe spiral` archive complete (Phase 10.7) | Propose vault ingest of technology decision summary | User confirms → `Skill("ouroboros:pa:ingest")` |
| 2 | Core → PA | `/research` On Merge — PA Vault Bridge | Propose vault ingest of research findings | User confirms → `Skill("ouroboros:pa:ingest")` |
| 3 | PA → SWE | `/pa brief` target matches project | Read `docs/specs/project/` for Living Project Model context | Read-only, automatic enrichment |

## Route 1: SWE → PA (Spiral Decision Note)

### Trigger

Phase 10.7 of `/swe spiral`, after archive and project model update.
Only when `.pa/settings.json` exists.

### Proposal

```
이 spiral의 기술 결정을 vault에 기록할까요?

**요약:**
- Task: {task description}
- Key decisions: {2-3 architecture/technology decisions}
- Depth: {depth plan summary}

(Y) `/pa ingest`로 기록 | (n) 건너뛰기
```

### Structured Summary for Ingest

When user confirms, build paste-type input for `/pa ingest`:

```markdown
# {Task Title} — Spiral Decision Record

## Context
{From understand artifact: problem domain, requirements}

## Key Decisions
{From design artifact: architecture choices, trade-offs}

## Implementation Notes
{From implement/optimize: notable patterns, constraints}

## Retrospect
{From tune: lessons learned, next-turn recommendations}

Source: `/swe spiral "{task}"` completed {date}
```

## Route 2: Core → PA (Research Knowledge Note)

### Trigger

After merge completes in `/research` (On Merge — PA Vault Bridge subsection).
Only when `.pa/settings.json` exists.

### Proposal

```
이 연구 결과를 vault에도 기록할까요?

**요약:**
- Topic: {research title}
- Key findings: {2-3 findings}
- Tags: {tags}

(Y) `/pa ingest`로 기록 | (n) 건너뛰기
```

### Structured Summary for Ingest

```markdown
# {Research Title} — Knowledge Summary

## Key Findings
{From research report: findings list}

## Practical Applications
{From research report: applications section}

## Trade-offs
{From research report: trade-offs section}

Source: `/research "{target}"` merged at `docs/specs/knowledge/{filename}.md`
```

## Route 3: PA → SWE (Read-Only Enrichment)

### Trigger

`/pa brief` target matches a project name and `docs/specs/project/` exists.

### Enrichment

1. Check `docs/specs/project/` existence via Glob.
2. Read relevant project model files (domain.md, architecture.md, constraints.md).
3. Assess topic relevance against project model headings/terms.
4. Pass relevant content as `swe_project_context` to librarian delegation.
5. Render under `### Project Model` subsection in brief Connections.

### Constraint

PA reads SWE docs but never writes to them.
One-way enrichment only.

## Invocation Pattern

All SWE→PA and Core→PA proposals invoke:

```
Skill("ouroboros:pa:ingest") with Args: "{structured_summary_text}"
```

This reuses the full ingest pipeline (curator triage, deduplication, rendering, reflection prompt).

## See Also

| Component | Relationship |
|-----------|-------------|
| `commands/swe/spiral.md` | Route 1 trigger — Phase 10.7 |
| `commands/core/research.md` | Route 2 trigger — On Merge, PA Vault Bridge |
| `commands/pa/brief.md` | Route 3 consumer — SWE project context enrichment |
| `commands/pa/ingest.md` | Target — receives bridge proposals as paste-type input |
| `skills/pa/content-pipeline/SKILL.md` | Parent skill |
