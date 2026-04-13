# Pipeline Reverse Analysis — Code-First Specification Recovery

This reference isolates the reverse block from the main pipeline stage reference.
Use it when you need to infer specification artifacts from an existing codebase before re-entering the forward pipeline.
This reference is self-contained — it can be consulted independently of the parent SKILL.md.
For stage depth rules, see `depth-system.md`.
For artifact paths and contracts, see `artifact-contracts.md`.
For the forward stage sequence, see `pipeline-spec-stages.md` and `pipeline-dev-stages.md`.

## Reverse: Code-First Specification Recovery

**Direction**: Code → Artifacts (opposite of forward pipeline)
**Purpose**: Analyze existing code to produce Stages 1-4 specification artifacts — enabling forward pipeline integration or architectural documentation.
**Key Output**: Context Document + Constraint Profile + Architecture Spec + Interface Contracts (same format as forward)

### Key Questions

- What does this codebase actually do? (vs what was it intended to do)
- What constraints are embedded in the code? (explicit configs, implicit patterns)
- What architectural patterns are actually in use? (vs documented/intended patterns)
- What public interfaces exist? (APIs, module boundaries, event contracts)

### Procedure

1. Build codebase inventory — directory structure, languages, frameworks, dependencies
2. Sample key files — entry points, models, APIs, tests (scale-appropriate sampling)
3. Delegate to analyst (Procedure 5) with inventory and sampled content
4. Analyst produces all 4 artifacts in a single invocation with confidence markers
5. Save artifacts to `.swe/active/01-04.md` — same paths as forward pipeline

### Confidence Levels

Reverse analysis inherently involves inference.
Every conclusion is marked:

| Level | Definition | Typical Source |
|-------|-----------|---------------|
| **Explicit** | Directly visible in code | Type definitions, documented APIs, config values, test assertions |
| **Inferred** | Derived from patterns | Naming conventions, architectural style, implicit constraints |
| **Assumed** | Uncertain, needs validation | Domain knowledge, common practices, absence of evidence |

### Output: 4 Specification Artifacts

| Depth | Content |
|-------|---------|
| Light | Core entities, primary constraints, main architecture pattern, public API surface |
| Standard | Full domain model, 6-category constraints, component breakdown, all interfaces with types |
| Deep | Domain health assessment, missing constraints flagged, architectural debt identified, interface inconsistencies documented |

### Forward Compatibility

Reverse artifacts are format-compatible with the forward pipeline:

- `/swe dev` can consume reverse-generated Interface Contracts
- `/swe ship` can validate code against reverse-generated Architecture Spec
- Forward `/swe spec` can refine or override reverse-generated artifacts

### DO / DON'T

| DO | DON'T |
|----|-------|
| Mark inference confidence on every conclusion | Present inferred patterns as definitive facts |
| Document what the code actually does | Describe what the code was intended to do (unless documented) |
| Flag inconsistencies between code and any existing docs | Silently resolve discrepancies in favor of docs |
| Respect `.gitignore` — skip vendored/generated code | Analyze auto-generated files as if they were authored |
