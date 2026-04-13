# Artifact Storage Layout

This reference covers the artifact chain, filesystem layout, and summary convention used by the SWE pipeline.

## Contract Chain

```text
[Understand] → Context Document
                  ↓ input
[Constrain]  → Constraint Profile
                  ↓ input
[Design]     → Architecture Spec
                  ↓ input
[Interface]  → Interface Contracts
                  ↓ input
[Test]       → Test Suite (failing)
                  ↓ input
[Implement]  → Source Code (tests passing)
                  ↓ input
[Verify]     → Verification Report
                  ↓ input
[Optimize]   → Optimization Report
```

Each arrow is a contract.
Downstream stages may assume the upstream artifact is complete and accurate at the chosen depth.
If a downstream stage finds a gap, the producer stage must update the artifact before work continues.

## Path Conventions

Artifacts are stored in different locations based on lifecycle state.

### Active (Current Turn)

| Stage | File |
|-------|------|
| Understand | `.swe/active/01-understand.md` |
| Constrain | `.swe/active/02-constrain.md` |
| Design | `.swe/active/03-design.md` |
| Interface | `.swe/active/04-interface.md` |
| Test | `.swe/active/05-test.md` |
| Implement | `.swe/active/06-implement.md` |
| Verify | `.swe/active/07-verify.md` |
| Optimize | `.swe/active/08-optimize.md` |
| Ship | `.swe/active/09-ship.md` |
| Tune | `.swe/active/10-tune.md` |

### Record (Completed Turns)

`docs/specs/record/{package}/{NNN}-{task-slug}/{NN}-{stage}.md`

- `{package}`: auto-detected from manifest or `default`
- `{NNN}`: zero-padded sequential number within package
- `{task-slug}`: lowercase-hyphenated task description
- `{NN}-{stage}`: same numbering as active artifacts

### Project Model (Living Documents)

`docs/specs/project/{name}.md` stores the cumulative specification that evolves across spiral turns.

| File | Stage | Content |
|------|-------|---------|
| `docs/specs/project/domain.md` | 1 | Cumulative domain model: entities, bounded contexts, ubiquitous language |
| `docs/specs/project/constraints.md` | 2 | Cumulative constraint profile with feature attribution |
| `docs/specs/project/architecture.md` | 3 | Cumulative architecture spec: components, decisions, patterns |
| `docs/specs/project/interfaces.md` | 4 | Cumulative interface contracts: module boundaries, types, invariants |

Project model files are initialized via `scripts/artifact-lifecycle.sh init-project`.
They are updated after each spiral turn or standalone tune.
The merge is additive, so entries are appended or updated rather than deleted.

### Knowledge Base

`docs/specs/knowledge/{entry}.md` stores research entries and accumulated patterns.

| File | Content |
|------|---------|
| `docs/specs/knowledge/INDEX.md` | Auto-generated entry table and tag index |
| `docs/specs/knowledge/{topic}.md` | Individual knowledge entries with YAML frontmatter |

Knowledge entries are created via `/core absorb` and indexed via `scripts/knowledge-catalog.sh index`.

### Monorepo Layout

In monorepo workspaces, artifacts are scoped per subproject.

| Scope | Active | Specs |
|-------|--------|-------|
| Root (repo-wide) | `.swe/active/` | `docs/specs/` |
| Subproject | `packages/{pkg}/.swe/active/` | `packages/{pkg}/docs/specs/` |

Each subproject keeps independent `project/`, `record/`, and `knowledge/` directories.
Root-level docs contain only repo-wide cross-cutting concerns.
Cross-cutting artifacts add an `**Affects**: [pkg1, pkg2]` header field and leave stubs in affected subprojects.

## Artifact Summary Convention

Every artifact starts with a `## Summary` section immediately after the metadata header.
That summary lets downstream stages load only the first section when full content is unnecessary.

```markdown
# {Artifact Title}: {task summary}

**Stage**: {N} — {Name}
**Depth**: {depth}
...

## Summary
> {3-5 sentences: key decisions, primary outputs, critical findings}

## Full Content
...
```

Agent instructions should explicitly require the leading `## Summary` block.
