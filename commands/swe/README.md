# SWE Module

Software Engineering methodology for disciplined AI-assisted development, grounded in DDD + SDD + TDD.

## Philosophy

Every software engineering task follows the same cognitive sequence. The SWE module encodes this sequence as an invariant 8-stage pipeline with variable depth — the sequence never changes, only the ceremony at each stage adapts to the task's scope, risk, and complexity.

Three established methodologies anchor the pipeline:

| Methodology | Stages | Contribution |
|-------------|--------|-------------|
| **DDD** | Understand, Design | Domain modeling, ubiquitous language, bounded contexts |
| **SDD** | Constrain, Interface | Constraint-first design, artifacts as contracts |
| **TDD** | Test, Implement, Verify, Optimize | Red-Green-Refactor cycle |

## Pipeline

```text
1. Understand → 2. Constrain → 3. Design → 4. Interface → 5. Test → 6. Implement → 7. Verify → 8. Optimize
```

Each stage produces an artifact that serves as the input contract for the next stage. See `skills/swe/methodology/` for the full methodology.

## Commands

### Primitives (8)

| Command | Stage | Description |
|---------|-------|-------------|
| `/swe understand` | 1 | Analyze requirements, domain modeling, existing code |
| `/swe constrain` | 2 | Enumerate constraints and boundaries |
| `/swe design` | 3 | Architecture, algorithm/data structure selection |
| `/swe interface` | 4 | Define contracts between components |
| `/swe test` | 5 | Write tests against interfaces (TDD Red) |
| `/swe implement` | 6 | Write code to pass tests (TDD Green) |
| `/swe verify` | 7 | Broader validation — integration, acceptance |
| `/swe optimize` | 8 | Profiling-driven tuning, refactoring (TDD Refactor) |

### Composites (4)

| Command | Stages | Description |
|---------|--------|-------------|
| `/swe spec` | 1-4 | Specification — from problem to contracts |
| `/swe dev` | 5-8 | Development — from contracts to working code |
| `/swe ship` | — | Release — integration test, security, review, deploy |
| `/swe tune` | — | Tuning — evaluate, improve, retrospect |

### Meta-composite (1)

| Command | Composes | Description |
|---------|----------|-------------|
| `/swe spiral` | spec → dev → ship → tune | One full engineering cycle with feedback loop |

## Components

| Path | Type | Role |
|------|------|------|
| `skills/swe/methodology/SKILL.md` | skill | Pipeline methodology knowledge |
| `skills/swe/methodology/references/pipeline-stages.md` | reference | Detailed stage descriptions |
| `skills/swe/methodology/references/depth-system.md` | reference | Depth level decision matrix |
| `skills/swe/methodology/references/artifact-contracts.md` | reference | Stage input/output contracts |
| `skills/swe/constraint/SKILL.md` | skill | Constraint-first design methodology |
| `skills/swe/constraint/references/constraint-categories.md` | reference | Six constraint categories with examples |
| `skills/swe/constraint/references/conflict-resolution-patterns.md` | reference | Cross-constraint conflict resolution strategies |
| `skills/swe/constraint/references/constraint-quality-examples.md` | reference | Constraint quality transformation examples |
| `commands/swe/README.md` | readme | This file — module overview |

## Generation Plan

The SWE module is generated in 6 batches via `/generate`:

| Batch | Focus | Components |
|-------|-------|------------|
| **1** | Foundation | Methodology skill + Constraint skill + README (this batch) |
| **2** | Spec | understand + constrain + design + interface + spec commands |
| **3** | Dev | test + implement + verify + optimize + dev commands |
| **4** | Ship | ship composite command |
| **5** | Tune | tune composite command |
| **6** | Spiral | spiral meta-composite command |

Agents and templates are generated alongside commands in each batch as needed.

## Usage

```bash
# Full engineering cycle
/swe spiral "Add caching layer for evaluation results"

# Specification only (Stages 1-4)
/swe spec "Design the new plugin module architecture"

# Development only (Stages 5-8, assumes spec exists)
/swe dev "Implement the caching layer per spec"

# Individual stage
/swe constrain "What constraints apply to the caching design?"

# With depth override
/swe understand --depth deep "Analyze the unfamiliar payment domain"
```
