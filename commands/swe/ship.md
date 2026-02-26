---
description: "Ship composite — orchestrate Integration Test, Security Review, Code Review, and Deploy Readiness to validate code for production"
argument-hint: "<task-description> [--depth <global|per-stage>] [--artifact <optimization-report-path>]"
allowed-tools: Read, Glob, Grep, Write, Task, Bash
---

# Ship — Ship Composite (Release Pipeline)

Orchestrate the 4 ship stages sequentially — Integration Test, Security Review, Code Review, Deploy Readiness — to validate working code for production release.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | implementer | Integration and e2e test execution |
| 4 | reviewer | Dependency audit, secret detection, license compliance |
| 5 | reviewer | 4-perspective code review (Architecture, Safety, Performance, Readability) |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--depth` | Depth specification | Standard (global) |
| `--artifact` | Path to Optimization Report (Stage 8) or Implementation artifact (Stage 6) | None (auto-discovered) |

`--depth` accepts two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Global | `--depth Deep` | All 4 ship stages at Deep depth |
| Per-stage | `--depth G:Std S:Std R:Deep D:Light` | Individual stage depths (G=inteGration, S=Security, R=Review, D=Deploy) |

Parsing rules:

- If single word (Light/Standard/Deep): apply to all 4 stages
- If colon-separated pairs: parse each. Missing stages default to Standard
- If any stage abbreviation is invalid: error and abort
- If any depth value is invalid: error and abort

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe ship <task-description> [--depth <global|G:level S:level R:level D:level>] [--artifact <path>]`"
- Abort

### Artifact Resolution

If `--artifact` is provided, use that path directly.

If `--artifact` is not provided: check for entry artifact by priority:

1. `.swe/active/08-optimize.md` (Stage 8 output — preferred)
2. `.swe/active/06-implement.md` (Stage 6 output — when optimize was skipped)

Use the most recent file by modification time.

If no entry artifact found:

- Output: "Error: No implementation artifact found. Run `/swe dev` or `/swe implement` first, or provide `--artifact <path>`."
- Abort

## Phase 2: Depth Planning

1. If `--depth` was provided, use parsed values
2. If no `--depth`, apply depth defaults based on task characteristics:
   - Integration Test: Standard when cross-component boundaries exist; Light for single-component
   - Security Review: Standard for all projects with external dependencies; Deep for compliance scope
   - Code Review: Standard for production code; Light for internal tooling; Deep for security-critical paths
   - Deploy Readiness: Light for most tasks; Standard when deploy scripts exist; Deep for compliance-grade release
3. Build Depth Plan:

```text
Depth Plan: G:{level} S:{level} R:{level} D:{level}
Rationale: {key drivers}
```

Log the Depth Plan. Present to user for confirmation:

```markdown
## Depth Plan

| Stage | Depth | Rationale |
|-------|-------|-----------|
| Integration Test | {level} | {reason} |
| Security Review | {level} | {reason} |
| Code Review | {level} | {reason} |
| Deploy Readiness | {level} | {reason} |

Proceed with this plan, or adjust depths?
```

## Phase 3: Integration Test

Execute integration and e2e tests by delegating to the implementer agent:

> Agent: **implementer**

- **Input**: Task description + source code file paths + existing test suites + depth level for Integration Test
- **Instructions**: "Run all integration and e2e test suites using Bash. If no integration tests exist, run the full unit test suite as baseline validation. Report: total tests, pass count, fail count, error details for failures. Do not write new tests — only execute existing ones."
- **Expected output**: Test execution results with pass/fail counts

1. Survey codebase for test directories and test runner configuration
2. Delegate to implementer to execute tests via Bash
3. Record test results: total, passed, failed, error details
4. Log: "Integration Test complete. {pass}/{total} tests passing."

### Phase 3 Recovery

| Failure | Action |
|---------|--------|
| No test suites found | Log warning: "No integration tests found. Proceeding with Security Review." Skip to Phase 4 |
| Test execution error (build failure) | Log error. Present to user: "Build failed — fix build before shipping." Abort composite |
| Some tests failing | Record failures. Proceed — Phase 6 will assess ship readiness |
| Agent timeout | Retry once with instruction: "Run test suite with 60s timeout." If retry fails: log warning, proceed |

## Phase 4: Security Review

Execute security review by delegating to the reviewer agent:

> Agent: **reviewer**

- **Input**: Source code file paths + dependency manifests + depth level for Security Review
- **Instructions**: "Execute Procedure 1 (Security Review) at {depth} depth. Run dependency audit commands if available. Scan for exposed secrets. At Standard+ depth, check license compliance. Return findings classified as P1/P2/P3."
- **Expected output**: Security findings with severity classification

1. Identify dependency manifests and source code directories
2. Delegate to reviewer
3. Collect findings and classify by severity
4. Log: "Security Review complete. {P1_count} P1, {P2_count} P2, {P3_count} P3 findings."

### Phase 4 Recovery

| Failure | Action |
|---------|--------|
| No dependency manifests found | Log: "No dependency files found. Skipping dependency audit." Proceed with secret detection only |
| Audit tool not installed | Log: "Audit tool not available. Manual dependency review in findings." Proceed with available checks |
| Agent timeout/error | Retry once with simplified instruction: "Scan source code for exposed secrets only." If retry fails: log warning, proceed to Phase 5 |

## Phase 5: Code Review

Execute code review by delegating to the reviewer agent:

> Agent: **reviewer**

- **Input**: Source code file paths + Architecture Spec + Constraint Profile + Interface Contracts + Verification Report + depth level for Code Review
- **Instructions**: "Execute Procedure 2 (Code Review) at {depth} depth. Review from all 4 perspectives: Architecture, Safety, Performance, Readability. Classify each finding as P1/P2/P3. Reference the Architecture Spec for structural expectations and Constraint Profile for performance boundaries. Return findings with concrete fix suggestions."
- **Expected output**: Code review findings with severity classification from 4 perspectives

1. Gather upstream artifacts from `.swe/active/` (architecture spec, constraint profile, interface contracts, verification report)
2. Identify source code files modified or created for this task
3. Delegate to reviewer with upstream artifact context
4. Collect findings and classify by severity and perspective
5. Log: "Code Review complete. {P1_count} P1, {P2_count} P2, {P3_count} P3 across {perspective_count} perspectives."

### Phase 5 Recovery

| Failure | Action |
|---------|--------|
| Missing upstream artifacts | Proceed with available artifacts. Instruct reviewer to note limited review scope |
| Agent timeout/error | Retry once with simplified instruction: "Review for P1 issues only — correctness bugs, security vulnerabilities, data loss risk." If retry fails: log warning, proceed |
| No source code files identified | Error: "No source code found for review. Verify the task produced implementation artifacts." Abort |

### Light Depth Behavior

At Light depth, skip Code Review entirely. Log: "Code Review skipped (Light depth). Integration test and security scan only."

## Phase 6: Deploy Readiness

Assess overall ship readiness based on all findings:

### P1 Gate Check

Count all P1 findings from Security Review and Code Review:

- If P1 count > 0: **Ship blocked**
  - List all P1 findings with locations and suggested fixes
  - Output: "Ship BLOCKED: {n} P1 issues must be resolved before deployment."
  - Recommend: "Fix P1 issues and re-run `/swe ship` to validate."
  - Do NOT proceed to deploy

- If P1 count == 0: **Ship clear**
  - Proceed to deploy checklist

### Deploy Checklist

Generate a deploy checklist based on depth:

**Light depth**:

```markdown
- [ ] All tests passing ({pass}/{total})
- [ ] No P1 security or code review findings
- [ ] Ready to deploy
```

**Standard depth**:

```markdown
- [ ] All tests passing ({pass}/{total})
- [ ] No P1 findings
- [ ] P2 findings reviewed and accepted or deferred
- [ ] Dependencies up to date (no critical CVEs)
- [ ] Environment configuration verified
```

**Deep depth**:

```markdown
- [ ] All tests passing ({pass}/{total})
- [ ] No P1 findings
- [ ] P2 findings reviewed and accepted or deferred
- [ ] Dependencies up to date (no critical CVEs)
- [ ] License compliance verified
- [ ] Environment configuration verified
- [ ] Rollback plan documented
- [ ] Monitoring and alerting confirmed
- [ ] Sign-off: {reviewer/approver}
```

### Deploy Execution

If the project has a deploy script or deploy configuration:

- Present the deploy command to the user for confirmation
- Execute only after explicit user approval
- Log the deploy output

If no deploy configuration exists:

- Present the deploy checklist only
- Note: "No deploy script detected. Manual deployment required."

## Phase 7: Review

Present the complete ship results:

```markdown
## Ship Report: {task summary}

### Test Results

| Suite | Total | Passed | Failed | Status |
|-------|-------|--------|--------|--------|
| {suite name} | {total} | {pass} | {fail} | {PASS/FAIL} |

### Security Findings

| Severity | Count | Categories |
|----------|-------|------------|
| P1 | {n} | {categories} |
| P2 | {n} | {categories} |
| P3 | {n} | {categories} |

### Code Review Findings

| Severity | Architecture | Safety | Performance | Readability | Total |
|----------|-------------|--------|-------------|-------------|-------|
| P1 | {n} | {n} | {n} | {n} | {total} |
| P2 | {n} | {n} | {n} | {n} | {total} |
| P3 | {n} | {n} | {n} | {n} | {total} |

### Ship Decision

**Status**: {CLEAR / BLOCKED}
{If BLOCKED: list P1 issues}
{If CLEAR: deploy checklist}
```

Write Ship Report to `.swe/active/09-ship.md` following the template at `templates/swe/ship-report.md`.

## Phase 8: Report

```markdown
## Ship Complete: {task summary}

**Depth Plan**: G:{level} S:{level} R:{level} D:{level}
**Status**: {CLEAR — ready to deploy / BLOCKED — {n} P1 issues}

### Next Steps
{If BLOCKED}:
- Fix P1 issues, then re-run: `/swe ship "{task}"`
- Individual fixes: `/swe implement "{task}"` for code changes

{If CLEAR}:
- Proceed to feedback and retrospect: `/swe tune "{task}" --artifact .swe/active/09-ship.md`

### Full Pipeline Reference
- `/swe dev "{task}"` — return to development (Stages 5-8)
- `/swe spec "{task}"` — return to specification (Stages 1-4)
- `/swe spiral "{task}"` — full engineering cycle (spec + dev + ship + tune)

### Individual Stage Review
- `/swe ship "{task}" --depth G:Std` — re-run integration tests only
- `/swe ship "{task}" --depth S:Std` — re-run security review only
```

## Rules

- Each stage delegates to the appropriate agent — the command orchestrates, not executes
- The reviewer agent is read-only — it produces findings but never modifies code
- P1 gate is non-negotiable: P1 findings block ship. No override, no exception
- Artifact paths follow `.swe/active/09-ship.md` convention
- User checkpoint occurs at Phase 7 (Review) — individual stages do not pause for user review when run as part of ship
- At Light depth, Code Review (Phase 5) is skipped — only Integration Test and Security Review execute
- Deploy execution requires explicit user confirmation — never auto-deploy
- Failure isolation: each stage can fail independently. Prior completed stages remain valid
- The ship composite consumes Optimization Report (Stage 8 output) or Implementation artifact (Stage 6 output) as its entry artifact
- The ship composite produces a Ship Report consumed by the tune composite for retrospect analysis
- Security Review runs before Code Review — security issues take precedence
- Graceful degradation: missing upstream artifacts reduce review scope but do not abort. Missing tests produce a warning but do not block security/code review
