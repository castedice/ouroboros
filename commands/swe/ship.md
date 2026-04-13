---
name: swe:ship
description: "Use when implementation is complete and you need a production-readiness review across testing, security, and code quality"
argument-hint: "<task-description> [--fast] [--depth <global|per-stage>] [--artifact <path>] [--single]"
allowed-tools: Read, Glob, Grep, Write, Task, Bash
---

# Ship — Ship Composite (Release Pipeline)

Orchestrate the ship stages — Integration Test, Security Review ‖ Code Review, Deploy Readiness — to validate working code for production release. At Standard+ depth, Security Review and Code Review execute as parallel Tasks for faster feedback.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | implementer | Integration and e2e test execution |
| 4 | reviewer × 2 | Security Review ‖ Code Review (parallel Tasks at Standard+ depth) |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass review artifact paths, dependency manifests, and inline source context on every call.
Use named return payloads rather than prose-only summaries.
The command owns test execution, fan-out coordination, consensus, and report persistence.
Internal calls use `Agent(subagent_type: "ouroboros:swe:implementer")` and `Agent(subagent_type: "ouroboros:swe:reviewer")`.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:swe:implementer` | 3 | `task`, `depth_level`, entry artifact summary, source paths, test runner config, and suite inventory | `integration_results`, `suite_statuses[]`, and `coverage_note` |
| `ouroboros:swe:reviewer` | 4 | `source_paths`, `dependency_manifests`, `depth_level`, and upstream artifacts when code review is enabled | `security_findings[]`, `code_findings[]`, `severity_classification`, `accepted_strengths[]`, `required_revisions[]`, and optional `unresolved_questions[]` |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--fast` | Shortcut for `--depth Light` with relaxed skip conditions | Off |
| `--depth` | Depth specification | Standard (global) |
| `--artifact` | Path to Optimization Report (Stage 8) or Implementation artifact (Stage 6) | None (auto-discovered) |
| `--single` | Force single-model mode (skip external CLIs). Multi-model auto-detected by default | — |

**`--fast` mode**: Sets all stages to Light depth and enables relaxed skip conditions. If both `--fast` and `--depth` are present, `--depth` takes precedence.

`--depth` accepts two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Global | `--depth Deep` | All ship stages at Deep depth |
| Per-stage | `--depth G:Std S:Std R:Deep D:Light` | Individual stage depths (G=inteGration, S=Security, R=Review, D=Deploy) |

Parsing rules per `skills/swe/methodology/references/depth-system.md`: single word applies globally, colon-separated pairs apply per-stage (missing stages default to Standard). Invalid abbreviations or values abort with error.

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe ship <task-description> [--depth <global|G:level S:level R:level D:level>] [--artifact <path>] [--multi]`"
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

### Multi-Model Setup (auto-detect)

Skip if `--single` is specified.

1. **CLI availability check**: Check `codex` CLI availability and version via Bash. Store: `codex_available` (bool + version), `failure_count: 0`.
2. **Session temp directory**: If codex available, initialize session temp directory (`.tmp/{SESSION_ID}_*` pattern).

Log availability:

- Codex found: "Multi-model: Claude + Codex v{ver}"
- Codex not found: "Single-model mode (no external CLIs found)"

### Mode Detection

Verify the operating mode from repository state before Phase 2 so the command does not rely on flags alone.

1. Verify the resolved entry artifact exists and is readable before building the review packet.
2. Verify at least one source directory or source file exists for the task scope, or abort because Ship cannot review artifact-only state.
3. Detect integration coverage mode from repository state.
   - If a runnable test command and integration or e2e suites exist, Integration Test runs normally.
   - If only unit tests exist, Integration Test uses the available suite and records reduced coverage.
   - If no runnable tests exist, Integration Test is skipped with warning and Ship continues to reviews.
4. Detect security scope from manifests and source files.
   - If dependency manifests exist, Security Review includes dependency audit plus source scanning.
   - If no manifests exist, Security Review falls back to source-only secret and unsafe-pattern scanning.
5. Detect multi-model mode from executable state, not user intent alone.
   - `--single` forces single-model mode.
   - Otherwise require both `codex` CLI availability and a writable `.tmp/{SESSION_ID}_*` directory before enabling Codex fan-out.
   - If either prerequisite fails, fall back to single-model mode and log the reason.

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| `task` is empty | 1 | Abort with the usage error and do not continue. |
| `--artifact` is provided | 1 | Use that artifact as the entry point after verifying it exists and is readable. |
| No entry artifact can be resolved from `--artifact`, `08-optimize.md`, or `06-implement.md` | 1 | Abort with the missing-artifact error. |
| `--single` is present | 1, 4, 6 | Force single-model mode and skip Codex fan-out. |
| Codex CLI or writable temp directory is unavailable | 1, 4, 6 | Fall back to single-model mode even without `--single`. |
| `--depth` is provided | 2 | Use the parsed global or per-stage depths. |
| `--fast` is provided without `--depth` | 2 | Force Light depth across stages and enable relaxed skip conditions. |
| Neither `--depth` nor `--fast` is provided | 2 | Build the default per-stage depth plan from repository and task characteristics. |
| Integration suites are available | 3 | Run Integration Test normally. |
| No runnable integration or test suites exist | 3 | Skip Integration Test with warning and continue to reviews. |
| Integration build fails | 3 | Abort Ship before the review stages. |
| Standard+ depth is active | 4 | Run Security Review and Code Review in parallel. |
| Light depth is active | 4 | Run Security Review only and skip Code Review. |
| `--multi` effective mode is active at Standard+ depth | 4, 6 | Add Codex Security Review and Codex Code Review to the parallel fan-out. |
| `--multi` effective mode is active at Light depth | 4, 6 | Add Codex Security Review only. |
| No dependency manifests are found | 4 | Reduce Security Review to source-only scanning. |
| No source code files are identified | 4 | Abort because there is nothing to review. |
| Security Review or Code Review fails once | 4 | Retry once with the simplified fallback scope for that review. |
| Both review tasks fail after retries | 4, 5 | Continue to Deploy Readiness with empty findings and a warning. |
| Phase 5 detects one or more P1 findings | 5, 6, 7 | Mark Ship as BLOCKED and do not advance to deployment. |
| Phase 5 detects zero P1 findings | 5, 6, 7 | Mark Ship as CLEAR and produce the deploy checklist. |
| Deploy automation exists | 5 | Present the deploy command and require explicit user confirmation before execution. |
| No deploy automation exists | 5, 6 | Present the checklist only and mark deployment as manual. |

## Phase 2: Depth Planning

1. If `--depth` was provided, use parsed values
2. If `--fast` was provided (and no `--depth`), set all stages to Light and enable `fast_mode=true` — skip depth analysis
3. If neither, apply depth defaults based on task characteristics:
   - Integration Test: Standard when cross-component boundaries exist; Light for single-component
   - Security Review: Standard for all projects with external dependencies; Deep for compliance scope
   - Code Review: Standard for production code; Light for internal tooling; Deep for security-critical paths
   - Deploy Readiness: Light for most tasks; Standard when deploy scripts exist; Deep for compliance-grade release
4. Build Depth Plan:

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
- **Instructions**: Follow the Integration Test instruction template from `skills/swe/methodology/references/agent-instructions.md`.
- **Expected output**: Test execution results with pass/fail counts

1. Survey codebase for test directories and test runner configuration
2. Delegate to implementer to execute tests via Bash
3. Record test results: total, passed, failed, error details
4. Log: "Integration Test complete. {pass}/{total} tests passing."

### Phase 3 Recovery

| Failure | Action |
|---------|--------|
| No test suites found | Log warning: "No integration tests found. Proceeding with reviews." Skip to Phase 4 |
| Test execution error (build failure) | Log error. Present to user: "Build failed — fix build before shipping." Abort composite |
| Some tests failing | Record failures. Proceed — Phase 5 will assess ship readiness |
| Agent timeout | Retry once with instruction: "Run test suite with 60s timeout." If retry fails: log warning, proceed |

## Phase 4: Security Review ‖ Code Review

At Standard+ depth, Security Review and Code Review execute as parallel Tasks — both read implementation artifacts independently and produce separate findings. At Light depth, only Security Review executes (Code Review is skipped).

### Parallel Execution (Standard+ depth)

Fan-out: Launch both reviews simultaneously as independent Tasks.

**Task 1 — Security Review** (reviewer agent):

- **Input**: Source code file paths + dependency manifests + depth level for Security Review
- **Instructions**: Follow the Security Review instruction template from `skills/swe/methodology/references/agent-instructions.md` at {depth} depth.
- **Expected output**: Security findings with severity classification

Steps:
1. Identify dependency manifests and source code directories
2. Delegate to reviewer
3. Collect findings and classify by severity
4. Log: "Security Review complete. {P1_count} P1, {P2_count} P2, {P3_count} P3 findings."

**Task 2 — Code Review** (reviewer agent):

- **Input**: Source code file paths + Architecture Spec + Constraint Profile + Interface Contracts + Verification Report + depth level for Code Review
- **Instructions**: Follow the Code Review instruction template from `skills/swe/methodology/references/agent-instructions.md` at {depth} depth.
- **Expected output**: Code review findings with severity classification from 4 perspectives

Steps:
1. Gather upstream artifacts from `.swe/active/` (architecture spec, constraint profile, interface contracts, verification report)
2. Identify source code files modified or created for this task
3. Delegate to reviewer with upstream artifact context
4. Collect findings and classify by severity and perspective
5. Log: "Code Review complete. {P1_count} P1, {P2_count} P2, {P3_count} P3 across {perspective_count} perspectives."

Fan-in: Merge findings from both Tasks into a unified findings list for Deploy Readiness. Combine all P1/P2/P3 findings — no deduplication needed between security and code review (different finding types).

### Multi-Model Fan-out (--multi only)

When `--multi` is active, launch Codex background reviews alongside Claude Tasks for a 2×2 parallel grid:

1. **Build relay prompts**: Construct Security Review and Code Review relay prompts using templates from `skills/swe/methodology/references/swe-relay-prompts.md`. Save to `.tmp/{SESSION_ID}_security_relay.txt` and `.tmp/{SESSION_ID}_review_relay.txt`.

2. **Fan-out** (4 concurrent evaluations per `skills/core/routing/references/parallel-execution-pattern.md`):
   - Background 1: Codex Security Review via `scripts/codex-relay.sh` (relay → `_codex_security.json`)
   - Background 2: Codex Code Review via `scripts/codex-relay.sh` (relay → `_codex_review.json`)
   - Task 1: Claude Security Review (reviewer agent — same as single-model)
   - Task 2: Claude Code Review (reviewer agent — same as single-model)

3. **Fan-in**: After Claude Tasks complete, collect Codex background results. Handle by exit code per parallel-execution-pattern.md.

### Multi-Model Consensus (--multi only)

Apply finding-level consensus per review type per `skills/core/routing/references/consensus-protocol.md`: union all findings, merge by location+type match, resolve severity disputes to the higher level (P1 disputes → P1 per DR-060). Codex-only findings are advisory. Log agreement rate.

### Light Depth Behavior

At Light depth, skip Code Review entirely. Execute Security Review only (single Task, no parallelism). Log: "Code Review skipped (Light depth). Integration test and security scan only."

When `--multi` + Light: only the Security Review gets multi-model treatment (1 Task + 1 Background).

### Recovery

| Failure | Action |
|---------|--------|
| Security Review Task fails | Retry once with simplified instruction: "Scan source code for exposed secrets only." If retry fails: proceed with Code Review results only |
| Code Review Task fails | Retry once with simplified instruction: "Review for P1 issues only — correctness bugs, security vulnerabilities, data loss risk." If retry fails: proceed with Security Review results only |
| Both Tasks fail | Retry each once. If both retries fail: log error, proceed to Deploy Readiness with empty findings and warning |
| Codex background fails (--multi) | Skip Codex results for that review type. Log warning. Claude results are always sufficient |
| No source code files identified | Error: "No source code found for review. Verify the task produced implementation artifacts." Abort |
| No dependency manifests found | Log: "No dependency files found. Skipping dependency audit." Proceed with secret detection only |

## Phase 5: Deploy Readiness

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

## Phase 6: Review

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

When `--multi` is active, append to the report:

```markdown
### Multi-Model Review Summary

| Review Type | Claude Findings | Codex Findings | Merged | Agreement |
|-------------|----------------|----------------|--------|-----------|
| Security | {n} | {m} | {k} | {rate}% |
| Code Review | {n} | {m} | {k} | {rate}% |

Codex-only findings are marked with † in the findings tables above.
```

Write Ship Report to `.swe/active/09-ship.md` following the template at `templates/swe/ship-report.md`.

## Phase 7: Report

Summary of Phase 6 with actionable next steps:

- **If BLOCKED**: `/swe ship "{task}"` (re-run after P1 fixes), `/swe implement "{task}"` (code changes)
- **If CLEAR**: `/swe tune "{task}" --artifact .swe/active/09-ship.md` (feedback + retrospect)
- **Pipeline**: `/swe dev`, `/swe spec`, `/swe spiral` for upstream stages
- **Stage re-run**: `/swe ship "{task}" --depth G:Std` (integration only), `--depth S:Std` (security only)

### See Also
- **Reviewer agent** (`agents/swe/reviewer.md`) — executes security and code review
- **Implementer agent** (`agents/swe/implementer.md`) — executes integration tests
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
- **SWE Relay Prompts** (`skills/swe/methodology/references/swe-relay-prompts.md`) — external model review templates

## Rules

- Each stage delegates to the appropriate agent — the command orchestrates, not executes
- The reviewer agent is read-only — it produces findings but never modifies code
- P1 gate is non-negotiable: P1 findings block ship. No override, no exception
- Artifact paths follow `.swe/active/09-ship.md` convention
- User checkpoint occurs at Phase 6 (Review) — individual stages do not pause for user review when run as part of ship
- Deploy execution requires explicit user confirmation — never auto-deploy
- Failure isolation: each review can fail independently. The other review's results remain valid
- The ship composite consumes Optimization Report (Stage 8) or Implementation artifact (Stage 6) and produces a Ship Report consumed by the tune composite
- Graceful degradation: missing upstream artifacts reduce review scope but do not abort. Missing tests produce a warning but do not block reviews
