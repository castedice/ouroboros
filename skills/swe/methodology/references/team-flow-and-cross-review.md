# Team Flow and Cross-Review — Pipelined Flow, Auto-Gates, Tune, and Recovery

This reference covers the runtime flow once the team is already spawned.
Use it for overlapping composite execution, gate behavior, relay checkpoints, cross-review outcomes, and failure handling.
This reference is self-contained — it can be consulted independently of the parent SKILL.md.
For specialist prompts and probe behavior, see `team-specialists.md`.
For routing and direct relay mechanics, see `team-routing-and-direct-relay.md`.

## Pipelined Phase Flow

The key difference from linear/probe policy: composites overlap.
After each composite completes, the next composite and a cross-review start simultaneously.
Gates (Phase 4, 6) are non-blocking auto-checks, not user approval points.

### Timeline

Stage-level execution (default at Standard+ depth):

```text
Shaper:  [U][C][D]──Critic review starts──[I]    [cross-review Dev]    [prep]
Builder:   [codebase prep]        [T][Imp]──Shaper review starts──[V][O]  [fix]
Critic:            [cross-review Spec]  [early scan]          [═══ Ship ═══]
Director: ─────auto-gate──────────────auto-gate─────────────P1 gate──Tune
```

Composite-level fallback (--fast or --composite-level):

```text
Shaper:  [════ Spec ════]          [cross-review Dev]    [next-turn prep]
Builder:   [codebase prep]  [═══════════ Dev ═══════════]  [fix if needed]
Critic:                  [cross-review Spec] [scan]  [════ Ship ════]
Director: orchestrate──auto-gate──orchestrate──auto-gate──orchestrate──P1 gate──Tune
```

### Phase-by-Phase Detail

| Phase | Director | Shaper | Builder | Critic |
|-------|----------|--------|---------|--------|
| **2.7 Setup** | Spawn team, wait for readiness | — | — | — |
| **3 Spec** | State: spec running | `Skill: swe:spec` | Codebase prep → `.team/builder-prep.md` | Idle |
| **3→4 transition** | Shaper sends Review | — | — | — |
| **4 Auto-gate** | Verify Interface Contracts exist | — | — | — |
| **4+** (simultaneous) | Assign Dev to Builder, cross-review to Critic, relay Review to user | Idle | `Skill: swe:dev` | Cross-review Spec artifacts |
| **4.5 Cross-review** | Evaluate Critic's findings (severity) | — | (running Dev) | Send findings to Director |
| **5 Dev** | — | — | (running Dev) | Early security scan |
| **5→6 transition** | Builder sends Review | — | — | — |
| **6 Auto-gate** | Verify Green state | — | — | — |
| **6+** (simultaneous) | Assign Ship to Critic, cross-review to Shaper, relay Review to user | Cross-review Dev artifacts | Idle | `Skill: swe:ship` |
| **6.5 Cross-review** | Evaluate Shaper's findings (severity) | Send findings to Director | — | (running Ship) |
| **7 Ship** | — | Next-turn prep (if assigned) | Fix if needed | (running Ship) |
| **7→8 transition** | Critic sends Review | — | — | — |
| **8 P1 gate** | **Blocking**: check P1 findings, present to user | — | — | — |
| **9 Tune** | Collect perspectives, invoke Tune | Send domain insights | Send implementation insights | Send quality insights |
| **10 Report** | Present results, archive | — | — | — |
| **11 Shutdown** | Send shutdown_request to all | Approve shutdown | Approve shutdown | Approve shutdown |

## Auto-Gate Protocol

Auto-gates replace the interactive Transition Checkpoint Pattern for Phases 4 and 6.
They verify artifact readiness without requiring user approval.

### Phase 4 Auto-Gate (Spec → Dev)

1. **Verify**: Check Interface Contracts artifact exists via `Glob: .swe/active/*interface*`
2. **State update**: `spiral-state.sh update spec_dev_gate completed`
3. **Simultaneously** (3 actions in parallel):
   - Send Dev assignment to Builder: `SendMessage(recipient: "builder", content: "Start Dev composite: Skill: ouroboros:swe:dev with args: \"{task}\" --depth {dev_depth} --artifact {interface_path}")`
   - Send Spec cross-review to Critic: `SendMessage(recipient: "critic", content: "Cross-review Spec: Read .swe/active/01-understand.md through 04-interface.md. Evaluate architecture soundness, constraint coverage, interface completeness, security posture. Classify findings as P1/P2/P3. Send findings to director.")`
   - Relay Shaper's Review content to user (display in conversation)
4. **State update**: `spiral-state.sh team-update builder active --task "Dev composite"`, `spiral-state.sh cross-review critic spec running`

### Phase 6 Auto-Gate (Dev → Ship)

1. **Verify**: Run test suite via Bash — confirm Green state
2. **State update**: `spiral-state.sh update dev_ship_gate completed`
3. **Simultaneously** (3 actions in parallel):
   - Send Ship assignment to Critic: `SendMessage(recipient: "critic", content: "Start Ship composite: Skill: ouroboros:swe:ship with args: \"{task}\" --depth {ship_depth} --artifact {dev_artifact_path}")`
   - Send Dev cross-review to Shaper: `SendMessage(recipient: "shaper", content: "Cross-review Dev: Read implementation and verification artifacts. Verify domain model compliance, interface contract adherence, business logic correctness. Classify findings as P1/P2/P3. Send findings to director.")`
   - Relay Builder's Review content to user
4. **State update**: `spiral-state.sh team-update critic active --task "Ship composite"`, `spiral-state.sh cross-review shaper dev running`

### Phase 8 Blocking Gate (Ship → Tune)

This gate is NOT auto — it follows the standard Transition Checkpoint Pattern.
Director reads the Ship Report, checks for P1 findings, and presents the Decision Matrix to the user.
This is the only user-facing gate in team policy.

## Director Relay Checkpoint

When a specialist completes a composite, their Review content must be shown to the user.
The relay protocol:

1. Specialist sends Review via `SendMessage(recipient: "director", content: "{review_content}")`
2. Director receives the message (auto-delivered)
3. Director displays the Review content in the conversation for the user to see
4. Director does NOT wait for user response — immediately proceeds to the auto-gate

The user sees each composite's Review as the spiral progresses.
If they spot an issue, they can interrupt (standard Claude Code behavior).
But the pipeline does not pause for acknowledgment — this is what makes it faster than sequential execution.

Exception: Phase 8 (Ship → Tune) is blocking — Director explicitly waits for user decision on P1 findings before proceeding.

## Cross-Review Protocol

### What to Review

| Reviewer | Target | Focus Areas |
|----------|--------|-------------|
| **Critic** reviews Spec | `.swe/active/01-understand.md` through `04-interface.md` | Architecture soundness, constraint coverage, interface completeness, security posture, testability |
| **Shaper** reviews Dev | `.swe/active/05-test.md` through `08-optimize.md` | Domain model compliance, interface contract adherence, business logic correctness, ubiquitous language usage |

### Finding Classification

| Severity | Definition | Examples | Action |
|----------|-----------|----------|--------|
| **P1** | Contract-breaking or security-critical | Missing error handling for critical path, interface contract violated, SQL injection vector, authentication bypass | Director evaluates for backtracking |
| **P2** | Significant but non-blocking | Suboptimal algorithm choice, incomplete edge case handling, minor security hardening needed | Record in `.team/`, address in Tune |
| **P3** | Minor improvement | Naming inconsistency, documentation gap, code style issue | Record in `.team/`, address in Tune |

### Finding Report Format

Reviewer sends findings to Director via SendMessage:

```text
Cross-review complete: {target} artifacts.

P1 findings: {count}
{list each P1 with: location, description, impact}

P2 findings: {count}
{list each P2 briefly}

P3 findings: {count}
{summary}

Recommendation: {proceed / halt for P1 resolution}
```

Director saves the full findings to `.swe/active/.team/{reviewer}-{target}-review.md` and updates state: `spiral-state.sh cross-review {reviewer} {target} completed`.

## Backtracking Decision Tree

When cross-review reports P1 findings, Director evaluates severity against downstream progress:

```text
Cross-review P1 finding received
├── Is the next composite already running?
│   ├── No (not started yet)
│   │   └── ACTION: Halt assignment, request revision from upstream specialist
│   │       State: mark upstream composite as invalidated
│   │       Regression protocol: checkpoint → cascade → restore
│   │
│   └── Yes (in progress)
│       ├── How far along?
│       │   ├── Early stage (Test phase — no implementation yet)
│       │   │   └── ACTION: Halt downstream specialist, revise upstream, restart downstream
│       │   │       Send halt to downstream: SendMessage(recipient: "{specialist}", content: "HALT: P1 finding in upstream. Stop current work and wait for revised artifacts.")
│       │   │       State: mark upstream invalidated, downstream pending
│       │   │
│       │   └── Late stage (Implement or later — significant work done)
│       │       └── ACTION: Continue downstream, flag for urgent fix in Tune
│       │           Record P1 in .team/ with "URGENT" tag
│       │           Tune will prioritize this finding
│       │
└── P2/P3 findings only
    └── ACTION: Record in .team/{reviewer}-{target}-review.md
        Continue pipeline — address in Tune retrospect
```

Backtracking reuses the existing regression protocol from `spiral-state.md`: checkpoint → cascade invalidation → restore.
The trigger differs — cross-review finding instead of gate failure — but the state machine mechanics are identical.

Backtracking from cross-review increments `regression_count` and is subject to the circuit breaker (max 3 regressions per turn).

## Tune Collaboration

Tune in team policy collects perspectives from all 3 specialists before execution:

### Step 1: Collect Perspectives

Director sends perspective requests to all 3 specialists simultaneously:

```text
SendMessage(recipient: "shaper", content: "Spiral Tune: Share your domain insights — what was well-understood vs surprising in the Spec? What would you change in the next turn's specification?")
SendMessage(recipient: "builder", content: "Spiral Tune: Share your implementation insights — what technical challenges did you encounter? What technical debt remains? What would make the next Dev cycle smoother?")
SendMessage(recipient: "critic", content: "Spiral Tune: Share your quality summary — what findings were most significant? What process improvements would reduce defects? Were the cross-reviews valuable?")
```

### Step 2: Aggregate and Invoke

After receiving all 3 responses, Director saves perspectives to `.swe/active/.team/tune-perspectives.md` and invokes Tune:

```text
Skill: ouroboros:swe:tune
Args: "{task}" --depth {tune_depth} --artifact {ship_report_path}
```

The perspectives file is available in `.swe/active/.team/` for the Tune composite to reference during Retrospect.

## Shutdown Protocol

After Phase 10 (Report) completes:

1. Director sends `shutdown_request` to all 3 specialists:

   ```text
   SendMessage(type: "shutdown_request", recipient: "shaper", content: "Spiral complete. Shutting down team.")
   SendMessage(type: "shutdown_request", recipient: "builder", content: "Spiral complete. Shutting down team.")
   SendMessage(type: "shutdown_request", recipient: "critic", content: "Spiral complete. Shutting down team.")
   ```

2. Wait for all 3 `shutdown_response(approve: true)` confirmations
3. Clean up: state file records team shutdown timestamp
4. Team resources are released

If a specialist rejects shutdown (still working): Director waits for completion, then re-sends shutdown request.

## Error Handling

### Specialist Failure

If a specialist becomes unresponsive or encounters an unrecoverable error:

1. **Detect**: No response to SendMessage within a reasonable timeframe, or specialist sends an error report
2. **Fallback**: Director executes the failed specialist's composite directly via Skill tool (single-agent mode for that composite only)
3. **State**: `spiral-state.sh team-update {specialist} idle --task null` — mark specialist as idle
4. **Skip cross-review**: If the failed specialist had a pending cross-review assignment, skip it and proceed without that review
5. **Log**: Record the failure in the transition log with `type: "specialist_failure"`
6. **Continue**: Pipeline continues with remaining active specialists

### Cross-Review Timeout

If a cross-reviewer does not report findings before the downstream composite completes:

1. Cross-review findings are no longer actionable for backtracking (downstream already done)
2. Findings still get recorded in `.team/` for Tune to process
3. Director logs: "Cross-review late — findings deferred to Tune"

### Full Team Failure

If 2+ specialists fail, Director falls back to standard linear/probe policy execution for remaining composites.
The already-completed composites and their artifacts are preserved.
