# Verification Report Template (Stage 7 — Verify)

Depth markers: `[Light+]` = Light, Standard, Deep. `[Standard+]` = Standard, Deep. `[Deep]` = Deep only.

---

## Header <!-- [Light+] -->

```markdown
# Verification Report: {title}

**Stage**: 7 — Verify (TDD)
**Depth**: {Light | Standard | Deep}
**Task**: {task description}
**Upstream**: {list of artifact paths read}
**Date**: {YYYY-MM-DD}
```

---

## Acceptance Criteria Check <!-- [Light+] -->

Each criterion comes from the Context Document (Stage 1). At Light depth: top 3 critical criteria only. At Standard+: all criteria with detailed evidence.

```markdown
| # | Criterion | Source | Status | Evidence |
|---|-----------|--------|--------|----------|
| AC1 | {criterion text from Context Document} | Context Document §{section} | PASS / FAIL | {brief evidence — test output, code reference, demonstration} |
| AC2 | {criterion} | ... | PASS / FAIL | {evidence} |
```

For each FAIL:

```markdown
### AC{n} Failure Analysis

**Criterion**: {what was expected}
**Actual**: {what was observed}
**Gap**: {what is missing or incorrect}
**Recommendation**: {return to Stage 6 to address, or accept deviation with rationale}
```

---

## Spec Compliance Check <!-- [Standard+] -->

Compare the implementation against the Architecture Spec (Stage 3) for structural alignment.

```markdown
| Component | Expected (from Architecture Spec) | Actual (in code) | Status |
|-----------|----------------------------------|-------------------|--------|
| {component name} | {architecture spec expectation — module structure, pattern, data model} | {implementation reality — file path, pattern used, actual structure} | Match / Drift / Intentional Deviation |
```

For each Drift or Intentional Deviation:

```markdown
### Deviation: {component}

**Expected**: {what the Architecture Spec specified}
**Actual**: {what was implemented}
**Type**: Drift (accidental) / Intentional Deviation (discovered during implementation)
**Rationale**: {why the deviation occurred — discovered constraint, implementation reality, etc.}
**Impact**: {effect on system correctness, maintainability, performance}
**Action**: {update Architecture Spec / accept as-is / return to Stage 3 for reconciliation}
```

---

## Smoke Test Results <!-- [Light+] -->

Build and execution validation of the implementation.

| Check | Status | Details |
|-------|--------|---------|
| Build | PASS / FAIL / SKIPPED | {build command and output summary} |
| Execution | PASS / FAIL / SKIPPED | {execution command and output summary} |

If skipped: `{reason — no executable artifact, build system not detected, etc.}`

---

## Integration Test Results <!-- [Standard+] -->

Cross-component interaction validation. If no integration tests are applicable, state why.

```markdown
### Test Execution

**Runner**: {test command used}
**Scope**: {which cross-component boundaries were tested}

| # | Test | Components | Status | Details |
|---|------|-----------|--------|---------|
| 1 | {test name} | {component A ↔ component B} | PASS / FAIL | {brief result} |
```

If no integration tests:

```markdown
**Integration tests not applicable**: {reason — e.g., single component, no cross-boundary interactions, mocked dependencies}
```

---

## Contract Compliance <!-- [Standard+] -->

Verify the implementation fulfills the Interface Contracts (Stage 4).

```markdown
| Interface | Method/Type | Contract Requirement | Implementation | Status |
|-----------|-------------|---------------------|----------------|--------|
| {trait/interface name} | {method or type} | {invariant, pre/post condition, or error contract} | {how implementation satisfies it} | Met / Violated |
```

For each Violated contract:

```markdown
### Contract Violation: {interface}.{method}

**Contract**: {what the Interface Contracts specified}
**Implementation**: {what was actually implemented}
**Impact**: {effect on consumers, correctness, or downstream stages}
**Recommendation**: {return to Stage 6 to fix, or return to Stage 4 to update contract}
```

---

## Performance Validation <!-- [Deep] -->

Validate implementation against Constraint Profile (Stage 2) performance targets.

```markdown
### Benchmark Results

| Constraint ID | Target | Measured | Status | Test Conditions |
|--------------|--------|----------|--------|----------------|
| {constraint ID from Constraint Profile} | {threshold — e.g., < 50ms p99} | {measured value} | PASS / FAIL | {test setup — data size, hardware, methodology} |

### Benchmark Methodology

- **Tool**: {profiling tool or benchmark framework used}
- **Environment**: {hardware, OS, compiler flags}
- **Data**: {test data characteristics — size, distribution, edge cases}
- **Runs**: {number of iterations, warm-up period, statistical method}
```

---

## Security Review <!-- [Deep] -->

Security assessment relevant to the implementation scope.

```markdown
| Category | Check | Status | Notes |
|----------|-------|--------|-------|
| Input validation | {specific check — boundary values, malformed input} | PASS / FAIL | {details} |
| Error information | {no sensitive data in error messages} | PASS / FAIL | {details} |
| Resource limits | {no unbounded allocations, timeouts} | PASS / FAIL | {details} |
| Dependency safety | {no known vulnerabilities in dependencies} | PASS / FAIL | {details} |
```

---

## Deviation Summary <!-- [Light+] -->

Consolidate all deviations from upstream artifacts in one reference table.

```markdown
| # | Source Artifact | Deviation | Type | Impact | Resolution |
|---|---------------|-----------|------|--------|------------|
| 1 | {Architecture Spec / Interface Contracts / Constraint Profile} | {what diverged} | Drift / Intentional | {High / Medium / Low} | {accepted / return to Stage N} |
```

If no deviations: `No deviations from upstream artifacts.`

---

## Overall Verdict <!-- [Light+] -->

```markdown
**Verdict**: {PASS / PARTIAL / FAIL}

- **PASS**: All acceptance criteria met and spec compliance confirmed
- **PARTIAL**: {n} criteria failed or {m} spec drifts found — see details above
- **FAIL**: Critical acceptance criteria not met — return to Stage 6 recommended

**Recommendation**: {proceed to Stage 8 (Optimize) / return to Stage 6 (Implement) to address gaps / return to Stage 3 (Design) for spec reconciliation}
```

---

## Exit Criteria Checklist <!-- [Light+] -->

```markdown
- [ ] Smoke test executed (build + run) or skip documented
- [ ] Each acceptance criterion from Context Document checked with evidence
- [ ] Deviations documented with rationale and impact
- [ ] Overall verdict stated with recommendation
- [ ] {At Standard+} Spec compliance check against Architecture Spec
- [ ] {At Standard+} Integration test results documented
- [ ] {At Standard+} Contract compliance against Interface Contracts verified
- [ ] {At Deep} Performance benchmarks against Constraint Profile targets
- [ ] {At Deep} Security review completed
```
