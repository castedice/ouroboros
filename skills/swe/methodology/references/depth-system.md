# Depth System — Variable Ceremony for Fixed Stages

The SWE pipeline uses four depth levels to control how much ceremony each stage receives. The pipeline sequence is invariant — what adapts is the effort invested at each stage.

This reference is self-contained — it can be consulted independently of the parent SKILL.md. For stage descriptions, see `pipeline-stages.md`. For input/output contracts, see `artifact-contracts.md`.

## Depth Levels

| Level | Effort | Time | Output Form | Typical Use |
|-------|--------|------|-------------|-------------|
| **Skip** | None | 0 | None | Stage not applicable to this task |
| **Light** | Minimal | Minutes | Inline notes, mental checklist | Familiar domain, small scope, low risk |
| **Standard** | Moderate | Hours | Structured document from template | Default — most production tasks |
| **Deep** | Significant | Hours-Days | Comprehensive with diagrams, alternatives | High risk, unfamiliar domain, broad impact |

**Default**: Standard. Any deviation requires explicit justification.

## Depth Decision Matrix

Five factors determine depth. Score each factor, then apply the decision rule.

| Factor | Low (1) | Medium (2) | High (3) |
|--------|---------|------------|----------|
| **Task Scope** | Single function/file change | Multi-file, single module | Cross-module, architectural |
| **Risk Level** | Easily reversible, low blast radius | Moderate blast radius, some dependencies | Irreversible, wide blast radius, data at risk |
| **Domain Familiarity** | Worked in this domain recently | Domain known but not recent | New domain, unfamiliar codebase |
| **Team Impact** | Solo, no coordination needed | 2-3 people affected | Cross-team, external API consumers |
| **Reversibility** | Full rollback trivial (git revert) | Rollback possible but costly | Rollback impossible or very expensive |

### Decision Rule

Sum the 5 factor scores (range: 5-15):

| Score | Depth | Rationale |
|-------|-------|-----------|
| 5-6 | **Light** | Low ceremony — the task is small, familiar, and reversible |
| 7-10 | **Standard** | Default ceremony — structured artifacts justify the moderate complexity |
| 11-15 | **Deep** | High ceremony — the risk and scope warrant comprehensive documentation |

**Skip** is not determined by scoring — it applies when a stage is categorically inapplicable (see Stage-Specific Skip Conditions below).

## Stage-Specific Rules

### Skip Conditions

| Stage | Skip When |
|-------|-----------|
| Understand | Never (every task requires some understanding) |
| Constrain | Pure refactoring with no new constraints |
| Design | Implementation within existing architecture, no structural decisions |
| Interface | Internal refactoring with no interface changes |
| Test | Configuration-only changes, documentation-only |
| Implement | Specification-only task |
| Verify | Trivial change fully covered by unit tests |
| Optimize | No performance requirements in Constraint Profile |

### Stage-Specific Minimum Depths

Certain stages have minimum depth requirements that override the decision matrix score:

| Stage | Minimum Depth Trigger |
|-------|----------------------|
| Understand | Deep when domain terms are unstable or requirements conflict |
| Constrain | Standard when any external dependency exists |
| Design | Deep when architecture or data model changes across bounded contexts |
| Interface | Standard for any public API or cross-team contract |
| Test | Standard when customer-visible behavior changes |
| Implement | Light allowed only for trivial internal refactor |
| Verify | Deep when rollback > 2 hours or compliance scope exists |
| Optimize | Standard when claiming measurable performance gain |

## Depth Per Stage, Not Per Project

A single task may have different depth levels at different stages. Examples:

| Scenario | Und. | Con. | Des. | Int. | Test | Impl. | Ver. | Opt. |
|----------|------|------|------|------|------|-------|------|------|
| Bug fix in familiar code | Light | Skip | Skip | Skip | Std | Light | Light | Skip |
| New feature, known domain | Std | Std | Std | Std | Std | Std | Std | Light |
| New module, unfamiliar domain | Deep | Deep | Deep | Std | Std | Std | Deep | Std |
| Greenfield app, fixed API | Light | Std | Std | Std | Std | Std | Light | Light |
| Performance optimization | Light | Std | Light | Skip | Std | Std | Std | Deep |
| API migration | Std | Std | Light | Deep | Std | Std | Deep | Light |

The per-stage depth prevents both over-engineering (Deep everywhere) and under-engineering (Light everywhere). Each stage gets exactly the ceremony it needs.

## Escalation Rules

Escalate one level for affected stages when any condition is true:

| Trigger | Affected Stages |
|---------|----------------|
| Security, privacy, or compliance in scope | Constrain, Design, Verify |
| Migration touches ≥ 1,000,000 rows or ≥ 10% of active records | Design, Test, Verify |
| Two or more teams depend on changed interfaces | Interface, Verify |
| P95 target < 200ms at expected load ≥ 1000 rps | Design, Test, Optimize |
| Rollback estimate exceeds 2 hours | Design, Verify |
| Observed flaky-test rate > 2% | Test, Verify |

## De-escalation Guardrails

De-escalate by one level only if ALL conditions hold:

- No externally visible behavior change
- Rollback in one commit or one feature flag
- Full verification under 30 minutes
- No unresolved high-severity risk remains

Record every escalation and de-escalation with rationale.

## Depth vs Coding Style

Depth and coding style are orthogonal concerns:

- **Depth** = how much ceremony/documentation a stage produces (pipeline concern)
- **Coding style** = how code is written — FP vs OOP, naming, formatting, error handling (project concern)

Depth is determined by the task. Coding style is determined by the project's `AGENTS.md` conventions. A Light-depth implementation still follows the project's coding standards; it just produces less documentation around the implementation.

## Fast Mode (`--fast`)

The `--fast` flag is syntactic sugar that sets `--depth Light` globally and enables **relaxed skip conditions** at primitive stages. It targets simple tasks where the 8-stage pipeline's full ceremony is overhead.

### Relaxed Skip Conditions (fast mode only)

| Stage | Fast Mode Skip Condition | Without Fast Mode |
|-------|--------------------------|-------------------|
| Understand | **Never skip** | Never skip |
| Constrain | Single-file change with no external dependencies | Pure refactoring only |
| Design | No structural decisions, existing patterns cover change | Implementation within existing architecture only |
| Interface | Change within single module boundary | Internal refactoring only |
| Test | **Never skip** | Configuration/docs only |
| Implement | **Never skip** | Spec-only workflow |
| Verify | All tests pass and change < 50 lines | Trivial change covered by unit tests |
| Optimize | Default skip unless explicit perf concern | No performance requirements |

**Precedence**: `--depth` always overrides `--fast`. When both are present, `--depth` wins.

## Override Rules

The default from the decision matrix can be overridden in these situations:

| Override | Direction | Condition |
|----------|-----------|-----------|
| User request | Any | User explicitly requests more or less depth |
| Safety-critical domain | ↑ to Deep | Healthcare, finance, infrastructure — minimum Standard for all stages |
| POC / Exploration | ↓ to Light | Explicitly labeled as proof-of-concept — Light for all except Understand |
| Time pressure | ↓ one level | Documented trade-off — the skipped depth becomes tech debt |
| Compliance requirement | ↑ to Deep | Regulatory audit trail needed — Deep for Constrain, Design, Verify |

Time pressure overrides must be documented as tech debt. The reduced depth is a loan that must eventually be repaid (by running the stage at proper depth later).

## Depth Planning Template

Record depth decisions using this compact format:

```text
Depth Plan: U:<level> C:<level> D:<level> I:<level> T:<level> M:<level> V:<level> O:<level>
Rationale: <key drivers — scope, risk, familiarity, team impact, reversibility>
Escalation Triggers: <list if any>
```

Example: `Depth Plan: U:Std C:Std D:Deep I:Std T:Std M:Std V:Deep O:Light` — new service with cross-module architecture (Deep Design) and compliance verification requirement (Deep Verify).

## Calibration from Record

When making depth decisions, consult past calibration data if available:

1. Check `docs/specs/record/` for retrospect reports from previous turns on the same package
2. Read the Depth Accuracy table from each retrospect — look for patterns of Over or Under calibration
3. Adjust the current turn's depth plan based on observed patterns:
   - Repeated "Under" on a stage → raise minimum depth for that stage
   - Repeated "Over" on a stage → lower depth for that stage
   - No clear pattern → use the decision matrix as-is

This is advisory, not automatic. The developer makes the final depth decision.

See `templates/swe/retrospect-report.md` Depth Accuracy section for the calibration data format.
