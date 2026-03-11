# Artifact Wrapper Templates — Stage Output Formatting

Standard metadata wrappers for pipeline stage output artifacts. Each primitive command uses these templates in its Phase 5 (Output) to wrap agent output in a consistent artifact format.

This reference is self-contained. For artifact naming conventions and required fields per depth, see `artifact-contracts.md`. For stage procedures, see `pipeline-stages.md`.

## How to Use

In a command's Phase 5, reference the wrapper by stage number:

```text
Wrap agent output using the Stage 5 (Test) artifact wrapper from `skills/swe/methodology/references/artifact-wrappers.md`.
Bind: task_summary, depth, task_description, upstream_path, date, framework.
```

The wrapper provides: header metadata, agent output placeholder, and exit criteria checklist.

---

## Stage 5: Test Suite

**Path**: `.swe/active/05-test.md`

```markdown
# Test Suite: {task_summary}

**Stage**: 5 — Test (TDD Red Phase)
**Depth**: {depth}
**Task**: {task_description}
**Upstream**: {upstream_path}
**Framework**: {framework}
**Date**: {date}

---

{agent_output}

---

**Exit Criteria Check**:
- [ ] All tests fail for the right reason (missing implementation, not test bugs)
- [ ] {If greenfield} Compilable stubs generated — not-implemented bodies only, no implementation logic
- [ ] Test naming follows `test_<behavior>_when_<condition>_should_<expected>` convention
- [ ] AAA pattern used consistently
- [ ] Test independence — no shared mutable state
- [ ] {At Standard+} Error path tests present
- [ ] {At Standard+} Edge case tests present
- [ ] {At Deep} Integration tests present
- [ ] {At Deep} Property-based tests present
```

## Stage 6: Implementation

**Path**: `.swe/active/06-implement.md`

```markdown
# Implementation: {task_summary}

**Stage**: 6 — Implement (TDD Green Phase)
**Depth**: {depth}
**Task**: {task_description}
**Upstream**: {upstream_path}
**Date**: {date}

---

## Green State

**Status**: {green_status}
**Test Runner**: {test_command}

### Test Output

{test_output}

## Implementation Summary

{implementation_summary}

## Files Modified

| File | Action | Description |
|------|--------|-------------|
| {path} | Created/Modified | {description} |

## Constraint Traceability

| Implementation Decision | Driving Constraint/Contract |
|------------------------|---------------------------|
| {decision} | {reference} |

## Contract Delta Notes

{delta_notes}

---

**Exit Criteria Check**:
- [ ] All tests pass (Green state)
- [ ] Implementation follows Architecture Spec structure
- [ ] Result pattern used for error handling
- [ ] No untested code paths introduced
- [ ] {At Standard+} Inline documentation complete (docstrings, type annotations)
- [ ] {At Standard+} Each implementation decision traces to a contract or constraint
- [ ] {At Deep} Structured logging and observability in place
- [ ] {At Deep} Performance-aware implementation aligned to Constraint Profile SLAs
```

## Stage 7: Verification Report

**Path**: `.swe/active/07-verify.md`

```markdown
# Verification Report: {task_summary}

**Stage**: 7 — Verify (TDD)
**Depth**: {depth}
**Task**: {task_description}
**Upstream**: {upstream_path}
**Date**: {date}

---

{agent_output}

---

**Exit Criteria Check**:
- [ ] Smoke test executed (build + run) or skip documented
- [ ] Acceptance criteria scoped to implementation unit (IN_SCOPE / PARTIAL / OUT_OF_SCOPE)
- [ ] Each IN_SCOPE and PARTIAL criterion checked with evidence
- [ ] {At Standard+} Spec compliance check against Architecture Spec
- [ ] {At Standard+} Cross-type pattern consistency checked (access control, validation, normalization)
- [ ] {At Standard+} Integration test results documented
- [ ] Deviations documented with rationale and impact
- [ ] {At Deep} Performance benchmarks against Constraint Profile targets
- [ ] {At Deep} Security scan results documented
```

## Stage 8: Optimization Report

**Path**: `.swe/active/08-optimize.md`

```markdown
# Optimization Report: {task_summary}

**Stage**: 8 — Optimize (TDD)
**Depth**: {depth}
**Task**: {task_description}
**Upstream**: {upstream_path}
**Date**: {date}

---

{agent_output}

---

**Exit Criteria Check**:
- [ ] All optimizations have before/after measurements
- [ ] No optimization targets constraints outside the Constraint Profile
- [ ] All tests remain Green after every change
- [ ] {At Standard+} Profiling data identifies actual bottlenecks
- [ ] {At Standard+} Each optimization traces to a constraint
- [ ] {At Deep} Algorithmic complexity analysis for hot paths
- [ ] {At Deep} Alternative benchmark comparisons
```
