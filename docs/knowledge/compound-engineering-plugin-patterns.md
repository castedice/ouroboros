---
title: Compound Engineering Plugin — Architecture & Patterns
tags: [compound-engineering, plugin-architecture, agent-organization, workflow-pipeline, review-patterns, naming-conventions, skill-validation, compound-growth]
source: https://github.com/EveryInc/compound-engineering-plugin (v2.31.1, repo clone + WebFetch)
created: 2026-02-18
status: active
related: [oh-my-claudecode-orchestration-patterns.md]
---

# Compound Engineering Plugin — Architecture & Patterns

Analysis of the compound-engineering plugin by Kieran Klaassen (Every Inc.).
The most influential Claude Code plugin (9.1k stars), embodying compound growth philosophy.

## Overview

**Philosophy**: "Each unit of engineering work should make subsequent units easier—not harder."
80/20 rule: planning and review (80%) over execution (20%).
Cyclical workflow: Plan → Work → Review → Compound → Repeat.

## Component Catalog

| Component | Count | Notes |
|-----------|-------|-------|
| Agents | 29 | 52% review (15), research (5), workflow (5), design (3), docs (1) |
| Commands | 22 | 5 workflow + 17 utility |
| Skills | 19 | Flat directory, references/ subdirs in some |
| MCP Servers | 1 | Context7 (framework docs) |

### Agent Organization (by function)

```text
agents/
├── review/ (15)    — architecture-strategist, code-simplicity-reviewer,
│                     data-integrity-guardian, data-migration-expert,
│                     deployment-verification-agent, dhh-rails-reviewer,
│                     julik-frontend-races-reviewer, kieran-python-reviewer,
│                     kieran-rails-reviewer, kieran-typescript-reviewer,
│                     pattern-recognition-specialist, performance-oracle,
│                     schema-drift-detector, security-sentinel, agent-native-reviewer
├── research/ (5)   — repo-research-analyst, learnings-researcher,
│                     best-practices-researcher, framework-docs-researcher,
│                     git-history-analyzer
├── workflow/ (5)   — bug-reproduction-validator, every-style-editor,
│                     lint, pr-comment-resolver, spec-flow-analyzer
├── design/ (3)     — design-implementation-reviewer, design-iterator, figma-design-sync
└── docs/ (1)       — ankane-readme-writer
```

### Workflow Commands

| Command | Description | Agents |
|---------|-------------|--------|
| `/workflows:brainstorm` | Explore WHAT (pre-plan stage) | repo-research-analyst |
| `/workflows:plan` | Generate implementation plan | 5 research agents |
| `/workflows:work` | Execute plan (TDD) | figma-design-sync, reviewers |
| `/workflows:review` | Parallel multi-agent code review | 13+ review agents simultaneously |
| `/workflows:compound` | Document problem resolutions | 5 subagents + reviewers |

### Flagship Pipeline Commands

- `/lfg` (Let's Fucking Go) — Sequential: plan → deepen → work → review → resolve → test → video
- `/slfg` (Swarm LFG) — Parallel variant: review + test run simultaneously

### Skill Structure

```text
skills/skill-name/
├── SKILL.md           # Main document
├── references/        # Detailed reference docs (markdown links required)
├── templates/         # Scaffolding templates
├── workflows/         # Step-by-step procedures
├── assets/            # Supporting assets
└── scripts/           # Validation utilities
```

## Key Patterns

### 1. Namespace Collision Avoidance (CRITICAL for ouroboros)

`workflows:` prefix prevents collision with Claude Code built-in `/plan`, `/review`.
ouroboros `commands/dev/plan.md` and `commands/dev/review.md` have this exact conflict.
**Action needed**: design decision before dev module goes to production.

### 2. Persona-Specialized Reviewers

Each reviewer encodes a specific expert's perspective (dhh-rails-reviewer, kieran-python-reviewer).
Makes reviews multi-dimensional without a monolithic reviewer holding all perspectives.
Naming convention: `{person}-{domain}-{role}`.
**For ouroboros**: when dev module matures, subdivide `reviewer.md` into perspective-based reviewers.
Prefer principle-based over persona-based for portability.

### 3. Agent Functional Subcategories

With 29 agents, flat directory is unmanageable. Categories by function (review/, research/, design/, workflow/, docs/).
**For ouroboros**: current 10 agents in `agents/dev/` approaching threshold. Consider hybrid: `agents/{module}/{function}/`.

### 4. Pipeline Orchestration (lfg/slfg)

Sequential + parallel variants of the same pipeline. Users choose by task confidence.
**For ouroboros**: applicable to composite commands (/absorb, /upgrade). Design sequential + parallel variants.

### 5. Skill Reference Linking Convention

All `references/` files must use markdown links `[file.md](./references/file.md)` — no backtick references.
Validation: ``grep -E '`(references|assets|scripts)/[^`]+`' skills/*/SKILL.md`` returns nothing.
**For ouroboros**: adopt as format rule in CLAUDE.md, add to evaluation criteria.

### 6. Versioning Discipline

Every change updates: plugin.json (semver), CHANGELOG.md, README.md.
MAJOR: breaking changes. MINOR: new agents/commands/skills. PATCH: bug fixes.
**For ouroboros**: adopt before Phase 2 when plugin becomes shareable.

### 7. Self-Healing Commands

`/heal-skill` repairs broken skills, `/create-agent-skill` scaffolds new ones.
**For ouroboros**: lighter complement to `/evolve` for mechanical fixes (broken frontmatter, missing references).

### 8. Compound Knowledge Store (docs/solutions/)

```text
docs/solutions/
├── build-errors/
├── test-failures/
├── runtime-errors/
├── performance-issues/
└── patterns/
    └── critical-patterns.md    # Promoted after 3+ occurrences
```

7-step process: Detect → Gather → Check existing → Filename → Validate YAML → Create → Cross-reference.
YAML frontmatter: module, date, problem_type, component, symptoms, root_cause, severity, tags.
**For ouroboros**: `docs/knowledge/` serves similar role but less structured. Consider YAML frontmatter enrichment.

## Trade-offs

- **Scale vs focus**: 29 agents + 22 commands = broad but high context pressure. ouroboros's 4 fundamental agents (DR-020) prioritizes efficiency. Trade-off is discoverability vs context cost.
- **Review dominance**: 52% agents in review. Non-review tasks (design, docs) structurally underweight.
- **Persona reviewers are team-specific**: dhh/kieran styles are non-transferable. Principle-based > persona-based for portability.
- **No evaluation framework**: No equivalent to /evaluate. Quality maintained through review agents + manual checking. heal-skill addresses symptoms, not root causes.
- **Flat skills directory**: 19 skills without subcategories. Works now, may not scale.
- **Rails/Ruby centrism**: Language-specific agents/skills reduce portability to other stacks.

## Applicability to ouroboros

| Pattern | Priority | Target |
|---------|----------|--------|
| Namespace collision avoidance | **Critical** | `commands/dev/plan.md`, `review.md` |
| Agent subcategory directories | High | When agent count > 15 per module |
| Skill reference linking | High | CLAUDE.md format rules |
| Persona-specialized reviewers | Medium | `agents/dev/reviewer.md` subdivision |
| Pipeline orchestration | Medium | Composite command design |
| Versioning discipline | Medium | Before Phase 2 |
| Self-healing commands | Medium | After `/generate` |
| Skill validation grep | Low-Medium | Automated pre-check |

## References

- <https://github.com/EveryInc/compound-engineering-plugin> — source repository
- `docs/knowledge/plugin-component-quality-patterns.md` — quality patterns extracted from this and other plugins
