# Review Finding Format

Use this reference when calibrating severity or writing the final finding text.
Every finding should teach the fix as well as report the problem.

## Severity Ladder

- `P1` means must fix before ship because the issue creates an exploit path, correctness failure, data loss risk, hard constraint breach, or consumer-breaking contract failure.
- `P2` means should fix before ship because the issue has meaningful security, reliability, performance, or maintainability impact without clearly blocking release.
- `P3` means optional improvement because the issue is low risk, cleanup-oriented, or not strongly evidenced enough for a higher severity.

## Security Finding Template

```markdown
### {VULN|SECRET|LICENSE}-{n}: {short description}

**Severity**: P1 / P2 / P3
**Location**: {file:line or dependency@version}
**Finding**: {specific evidence that was observed}
**Risk**: {what could go wrong if left unchanged}
**Remediation**: {concrete fix, version upgrade, config change, or follow-up action}
```

## Code Review Finding Template

```markdown
### {ARCH|SAFETY|PERF|READ}-{n}: {short description}

**Severity**: P1 / P2 / P3
**Perspective**: Architecture / Safety / Performance / Readability
**Location**: {file:line}
**Finding**: {specific evidence that was observed}
**Impact**: {technical or delivery consequence if left unchanged}
**Suggestion**: {concrete code, design, or test change to apply}
```

## Fix Guidance Standard

- Name the exact code path, dependency version, config entry, or boundary that should change.
- Prefer specific actions such as "upgrade `foo` to `1.2.3`" or "move validation to the request boundary" over vague verbs such as "improve" or "consider".
- Include the verification step when it is obvious, such as the test to add, the contract to re-check, or the command to rerun.
- Keep the fix proportional to the finding rather than proposing unrelated refactors.
- If the right fix is ambiguous, state the minimum acceptable outcome and the key trade-off.

## Summary And Zero-Finding Rules

- Use category or perspective summary tables when the caller needs rollups by severity.
- Keep individual findings even when a summary table exists because the table is not evidence.
- If no findings exist, say so explicitly rather than leaving the section blank.
