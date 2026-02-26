# Ship Report Template

Depth markers: `[Light+]` = Light, Standard, Deep. `[Standard+]` = Standard, Deep. `[Deep]` = Deep only.

---

## Header <!-- [Light+] -->

```markdown
# Ship Report: {title}

**Composite**: Ship (Release Pipeline)
**Depth**: G:{level} S:{level} R:{level} D:{level}
**Task**: {task description}
**Entry Artifact**: {path to optimization report or implementation artifact}
**Date**: {YYYY-MM-DD}
```

---

## Integration Test Results <!-- [Light+] -->

Test execution summary. At Light depth: pass/fail counts only. At Standard+: detailed failure analysis.

```markdown
### Test Execution

**Runner**: {test command used}
**Scope**: {unit / integration / e2e / all}

| Suite | Total | Passed | Failed | Skipped | Status |
|-------|-------|--------|--------|---------|--------|
| {suite name} | {total} | {pass} | {fail} | {skip} | PASS / FAIL |
```

For each failing test (Standard+ depth):

```markdown
### Test Failure: {test name}

**Suite**: {suite name}
**Error**: {error message}
**Location**: {file:line}
**Impact**: {what functionality is affected}
```

If no tests found:

```markdown
**No test suites detected.** Proceeding with security and code review only.
```

---

## Security Review <!-- [Light+] -->

Findings from dependency audit, secret detection, and license compliance.

```markdown
### Security Summary

| Category | P1 | P2 | P3 | Total |
|----------|----|----|----|----- |
| Vulnerability | {n} | {n} | {n} | {total} |
| Secret Exposure | {n} | {n} | {n} | {total} |
| License | {n} | {n} | {n} | {total} |
```

### Individual Findings

For each finding:

```markdown
### {VULN|SECRET|LICENSE}-{n}: {short description}

**Severity**: P1 / P2 / P3
**Location**: {file:line or dependency@version}
**Finding**: {what was found — specific evidence}
**Risk**: {consequence if not addressed}
**Remediation**: {specific fix}
```

If no security findings: `No security issues found.`

---

## Code Review <!-- [Standard+] -->

Findings from 4-perspective review. Skipped at Light depth.

```markdown
### Code Review Summary

| Perspective | P1 | P2 | P3 | Total |
|-------------|----|----|----|----- |
| Architecture | {n} | {n} | {n} | {total} |
| Safety | {n} | {n} | {n} | {total} |
| Performance | {n} | {n} | {n} | {total} |
| Readability | {n} | {n} | {n} | {total} |
```

### Individual Findings

For each finding:

```markdown
### {ARCH|SAFETY|PERF|READ}-{n}: {short description}

**Severity**: P1 / P2 / P3
**Perspective**: Architecture / Safety / Performance / Readability
**Location**: {file:line}
**Finding**: {what was found — specific evidence}
**Impact**: {consequence if not addressed}
**Suggestion**: {concrete fix}
```

If no code review findings: `No code review issues found.`

---

## Compliance Check <!-- [Deep] -->

Comprehensive compliance assessment for regulated or security-critical deployments.

```markdown
### Compliance Matrix

| Requirement | Source | Status | Evidence |
|------------|--------|--------|----------|
| {compliance requirement} | {regulation, policy, or standard} | PASS / FAIL / N/A | {how compliance was verified} |

### Audit Trail

| Stage | Artifact | Reviewer | Date |
|-------|----------|----------|------|
| {pipeline stage} | {artifact path} | {agent or human} | {date} |
```

---

## Deploy Checklist <!-- [Light+] -->

Ship readiness assessment. Checklist depth varies by depth level.

**Light depth**:

```markdown
- [ ] All tests passing ({pass}/{total})
- [ ] No P1 security findings
- [ ] Ready to deploy
```

**Standard depth**:

```markdown
- [ ] All tests passing ({pass}/{total})
- [ ] No P1 findings (security + code review)
- [ ] P2 findings reviewed: {accepted count} accepted, {deferred count} deferred
- [ ] Dependencies up to date
- [ ] Environment configuration verified
```

**Deep depth**:

```markdown
- [ ] All tests passing ({pass}/{total})
- [ ] No P1 findings
- [ ] P2 findings reviewed and dispositioned
- [ ] Dependencies up to date, no critical CVEs
- [ ] License compliance verified
- [ ] Environment configuration verified
- [ ] Rollback plan documented
- [ ] Monitoring and alerting confirmed
- [ ] Sign-off: {name/role}
```

---

## Ship Decision <!-- [Light+] -->

```markdown
**Status**: {CLEAR / BLOCKED}

{If CLEAR}:
No P1 issues. Code is ready for deployment.
Deploy checklist above should be completed before release.

{If BLOCKED}:
**{n} P1 issues must be resolved before deployment:**

| # | Finding ID | Description | Location |
|---|-----------|-------------|----------|
| 1 | {ID} | {description} | {location} |

**Recommendation**: Fix P1 issues and re-run `/swe ship` to validate.
```

---

## Exit Criteria Checklist <!-- [Light+] -->

```markdown
- [ ] Integration tests executed (or absence documented)
- [ ] Security review completed with findings classified
- [ ] Ship decision stated (CLEAR or BLOCKED with P1 list)
- [ ] Deploy checklist generated at appropriate depth
- [ ] {At Standard+} Code review completed from 4 perspectives
- [ ] {At Standard+} P2 findings dispositioned (accepted or deferred)
- [ ] {At Deep} Compliance check completed
- [ ] {At Deep} Rollback plan documented
- [ ] {At Deep} Sign-off recorded
```
