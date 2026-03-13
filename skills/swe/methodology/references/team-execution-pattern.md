# Team Execution Pattern — Pipelined Composite Execution

Orchestration protocol for the `--policy team` spiral mode. Director (main conversation) coordinates 3 Specialists that execute composites concurrently with cross-review. Composites overlap via auto-gates — the next composite starts immediately after the previous one completes, while cross-review validates the completed artifacts in parallel.

This reference is self-contained — it can be consulted independently of the parent SKILL.md. For state machine schema, see `spiral-state.md`. For artifact dependencies, see `artifact-contracts.md`. For depth levels, see `depth-system.md`.

## Team Topology

| Role | Agent Type | Owns | Cross-Review Duty | Background Task |
|------|-----------|------|-------------------|----------------|
| **Director** | Main conversation | Gates, state, Tune orchestration | Severity judgment + backtrack decisions | User relay |
| **Shaper** | `general-purpose` | Spec composite | Dev output: domain correctness | Next-turn domain prep |
| **Builder** | `general-purpose` | Dev composite | (receives cross-review) | Codebase pre-analysis during Spec |
| **Critic** | `general-purpose` | Ship composite | Spec output: quality + security | Early security scan during Dev |

Director is the orchestrator — it never executes composites directly. It manages state, coordinates specialists, evaluates cross-review findings, and relays results to the user. Specialists execute composites via Skill tool and perform cross-reviews of other specialists' output.

## Specialist Spawn Protocol

### Team Setup

1. **Create team**: `TeamCreate` with `team_name: "spiral-{timestamp}"` (matches the team_name in state file)
2. **Spawn specialists**: 3 parallel `Agent` calls with `team_name`, `subagent_type: "general-purpose"`, each with role-specific `name` and `prompt`
3. **Readiness handshake**: Each specialist sends an initial `SendMessage` to Director confirming readiness. Director waits for all 3 confirmations before proceeding to Phase 3

```text
Agent(name: "shaper", subagent_type: "general-purpose", team_name: "{team_name}", prompt: "{shaper_system_prompt}")
Agent(name: "builder", subagent_type: "general-purpose", team_name: "{team_name}", prompt: "{builder_system_prompt}")
Agent(name: "critic",  subagent_type: "general-purpose", team_name: "{team_name}", prompt: "{critic_system_prompt}")
```

### Specialist Naming Convention

Specialists are always referenced by their role name (`shaper`, `builder`, `critic`) in SendMessage, TaskUpdate, and team state operations. Never use agent UUIDs for communication.

## Specialist System Prompts

### Shaper

```text
You are Shaper — the Specification Specialist in a spiral team.

Primary responsibility: Execute Spec stages (1-4: Understand, Constrain, Design, Interface).

Stage-Level Execution (default at Standard+ depth):
Execute each stage as an individual primitive command in order:
  1. Skill: ouroboros:swe:understand
  2. Skill: ouroboros:swe:constrain
  3. Skill: ouroboros:swe:design
  4. Skill: ouroboros:swe:interface
After each stage, send a progress message to Director and check for Director messages before proceeding.
If Director sends HALT, stop and wait for further instructions.
If --fast or --composite-level: use `Skill: ouroboros:swe:spec` instead (single composite call).

Cross-review duty: When Director assigns you a Dev cross-review, read the implementation artifacts and verify domain correctness — check that the implementation respects the domain model, ubiquitous language, and bounded context boundaries from the Spec.

Background tasks: After completing cross-review, perform next-turn domain pre-study if Director assigns it.

Communication protocol:
- After each stage: send progress to Director via SendMessage (stage name, artifact path, next stage)
- After completing all stages: send the final Review content to Director via SendMessage
- When assigned cross-review: read artifacts, classify findings as P1/P2/P3, send findings to Director via SendMessage
- Check messages from Director between stages — Director may send halt or adjustment instructions
- If --multi is set: relay it to each primitive Skill call as-is
- Always use `SendMessage(type: "message", recipient: "director")` for all communication

State tracking:
- Director manages all state updates — you do not call spiral-state.sh directly
- Your artifacts go to `.swe/active/` as usual — the Skill tool handles this
```

### Builder

```text
You are Builder — the Development Specialist in a spiral team.

Primary responsibility: Execute Dev stages (5-8: Test, Implement, Verify, Optimize).

Stage-Level Execution (default at Standard+ depth):
Execute each stage as an individual primitive command in order:
  1. Skill: ouroboros:swe:test
  2. Skill: ouroboros:swe:implement
  3. Skill: ouroboros:swe:verify
  4. Skill: ouroboros:swe:optimize
After each stage, send a progress message to Director and check for Director messages before proceeding.
If Director sends HALT, stop and wait for further instructions.
If --fast or --composite-level: use `Skill: ouroboros:swe:dev` instead (single composite call).

Background tasks: During Spec phase, perform codebase pre-analysis — use Read, Grep, Glob to survey the codebase relevant to the task. Save findings to `.swe/active/.team/builder-prep.md`. Focus on: existing test infrastructure, code patterns, dependency structure, and integration points.

Communication protocol:
- After each stage: send progress to Director via SendMessage (stage name, artifact path, next stage)
- After completing all stages: send the final Review content to Director via SendMessage
- Check messages from Director between stages — Director may send halt instructions if cross-review found P1 issues
- If --multi is set: relay it to each primitive Skill call as-is
- Always use `SendMessage(type: "message", recipient: "director")` for all communication

State tracking:
- Director manages all state updates — you do not call spiral-state.sh directly
- Your artifacts go to `.swe/active/` as usual — the Skill tool handles this
```

### Critic

```text
You are Critic — the Quality & Security Specialist in a spiral team.

Primary responsibility: Execute Ship composite via `Skill: ouroboros:swe:ship` (Ship is a unified composite — no stage-level split needed since its internal stages are already parallelized: Security Review ‖ Code Review).

Cross-review duty: When Director assigns you a Spec cross-review, read the specification artifacts (01-understand through 04-interface) and evaluate: architecture soundness, constraint coverage, interface completeness, security posture. Classify findings as P1 (contract-breaking, security critical), P2 (significant but non-blocking), or P3 (minor improvement).

Background tasks: During Dev phase, perform early security scan — read Builder's in-progress code and check for obvious security issues. Save findings to `.swe/active/.team/critic-early-scan.md`.

Communication protocol:
- After completing your composite: send the Review content to Director via SendMessage
- When assigned cross-review: read artifacts, classify findings, send findings to Director via SendMessage
- If --multi is set: relay it to Ship Skill call as-is
- Always use `SendMessage(type: "message", recipient: "director")` for all communication

State tracking:
- Director manages all state updates — you do not call spiral-state.sh directly
- Your artifacts go to `.swe/active/` as usual — the Skill tool handles this
```

## Stage-Level Execution Protocol

v0.16.5 default for team policy: Specialists invoke **primitive commands individually** instead of composite Skill calls. This enables cross-review to start mid-composite and Director to track stage-level progress.

### Primitive Execution Sequence

Instead of `Skill: ouroboros:swe:spec` (black box — 4 stages run internally), Shaper executes:

```text
Skill: ouroboros:swe:understand  → message to Director
Skill: ouroboros:swe:constrain   → message to Director
Skill: ouroboros:swe:design      → message to Director  ← Critic cross-review can start here
Skill: ouroboros:swe:interface   → message to Director
```

Same pattern for Builder (Dev) and Critic (Ship stages where applicable). Each primitive call produces its artifact in `.swe/active/` as usual.

### Message Checkpoint Protocol

After completing each primitive stage, the specialist sends a progress update:

```text
SendMessage(recipient: "director", content: "Stage complete: {stage_name}. Artifact: .swe/active/{NN}-{stage}.md. Proceeding to {next_stage}.", summary: "{stage_name} complete")
```

Director receives the message and:

1. Updates state: `spiral-state.sh stage-update {specialist} {stage} completed`
2. Checks for pending actions (cross-review trigger, halt instruction, Bridge artifact handoff)
3. Responds only if action is needed — no-op means specialist continues

The specialist checks for Director messages between stage executions. If Director sends `HALT`, the specialist stops and waits. If no message, the specialist proceeds to the next stage.

### Cross-Review Trigger Points

Stage-level execution enables **intra-composite cross-review** — reviews start before the full composite finishes:

| After Stage | Trigger | Reviewer Action |
|-------------|---------|-----------------|
| `design` (Spec stage 3) | Critic can begin reviewing Architecture Spec | Director assigns cross-review to Critic; Shaper continues to Interface |
| `implement` (Dev stage 6) | Shaper can begin reviewing implementation code | Director assigns cross-review to Shaper; Builder continues to Verify |

These are **advisory triggers** — Director decides whether to start early cross-review based on team availability. The mandatory cross-review at auto-gates (Phase 4, 6) still runs as before.

### Known Limitation

Primitives invoked standalone by specialists may display user review checkpoints (e.g., `understand.md` Phase 5). In team context these are auto-proceeded by the specialist agent — no manual action required. This adds a minor round-trip but does not block execution.

### Composite-Level Fallback

Stage-level execution is the default for team policy at Standard+ depth. Fallback to composite-level (v0.16.0 behavior) when:

- `--fast` flag is set (Light depth — stage-level overhead not worth it)
- `--composite-level` explicitly requested
- Specialist failure recovery (Director executes remaining stages as a single composite)

## Probe Composition Protocol

When `--policy team+probe`, each composite runs at Light depth first (probe), then Director relays the result to the user for an escalation decision. This combines team pipelining with probe's adaptive depth.

### Execution Flow

```text
1. Director assigns composite to Specialist at --depth Light
2. Specialist executes (stage-level or composite-level, same as team policy)
3. Specialist sends result to Director
4. Director presents probe result to user:
   - Artifacts produced at Light depth
   - Cross-review findings (if available from parallel review)
   - Options: Keep Light / Escalate to {target_depth}
5a. Keep: Director proceeds to auto-gate, pipeline continues
5b. Escalate: Director instructs Specialist to re-run at target depth
    Checkpoint preserves Light artifacts in .versions/
    Escalation does not increment regression_count
```

### Cross-Review as Escalation Context

When Critic's cross-review findings arrive before the escalation decision, Director includes them:

```markdown
## Probe Result: Spec (Shaper)

Executed at Light depth. Target depth: Standard.

Artifacts produced:
- 01-understand.md, 02-constrain.md, 03-design.md, 04-interface.md

Cross-review findings (Critic):
- P2: Interface missing error recovery for timeout scenario
- P3: Constraint naming inconsistency

Options:
(A) Keep Light result — P2/P3 findings deferred to Tune
(B) Escalate to Standard — Shaper re-runs Spec, can address P2 findings
```

This makes the escalation decision more informed: if cross-review found quality gaps, escalation is more likely warranted.

### Skip Conditions

- When target depth is Light (`--fast`): skip probe wrapper, execute directly
- When `--policy team` (without probe): skip probe wrapper, execute at target depth directly

## Selective Routing Protocol

When `--route` is specified, Director can delegate individual stages to external models via the Bridge Agent instead of Claude specialists. This enables model diversity — each stage runs on the model best suited for it.

### Route Table Format

```text
--route "understand=codex,design=claude,implement=codex"
```

Parsing rules:

- Comma-separated `{stage}={model}` pairs
- Valid stages: `understand`, `constrain`, `design`, `interface`, `test`, `implement`, `verify`, `optimize`
- Valid models: `codex`, `claude` (explicit Claude assignment, same as default)
- Unspecified stages default to `claude` (Claude specialist handles them)
- Invalid stage or model names abort with error listing valid options

### Director Routing Logic

At each stage assignment, Director checks the routing table:

```text
1. Look up stage in routing table
2. If model == "claude" (or not in table):
   → Assign to the owning Claude specialist (Shaper for spec stages, Builder for dev stages)
3. If model == "codex":
   → Assign to Bridge Agent via SendMessage with stage details and target model
   → Bridge executes stage via codex exec, saves artifact, reports back
4. Director updates state regardless of which agent executed the stage
```

When stage-level execution is active (Standard+ depth), routing applies per-primitive. When composite-level fallback is active (`--fast`, `--composite-level`), routing is ignored — the full composite runs on the Claude specialist.

### Bridge Agent Lifecycle

Bridge Agent is spawned only when the routing table contains at least one external model assignment:

1. **Spawn**: During Phase 2.7 Team Setup, after Claude specialists. `Agent(name: "bridge", subagent_type: "general-purpose", team_name: "{team_name}")` with Bridge system prompt from `agents/swe/bridge.md`
2. **Reuse**: A single Bridge Agent handles all externally-routed stages. Director sends each assignment sequentially via SendMessage — Bridge maintains its own exec session (thread_id) per stage
3. **Shutdown**: With other specialists in Phase 11

### Codex CLI Availability Check

Before spawning Bridge Agent, Director verifies Codex CLI availability:

1. Check if Codex CLI is installed (`which codex` — Bridge Agent checks on startup and reports)
2. If Codex CLI is unavailable:
   - Log: "Warning: Codex CLI not available. Falling back to Claude specialist for {stage}."
   - Reassign affected stages to Claude specialist
   - If all external routes fall back: skip Bridge Agent spawn entirely

### Interaction with Other Flags

| Flag | Routing Behavior |
|------|-----------------|
| `--route` without `--policy team` | Ignored — routing requires team policy (specialists needed for stage-level execution) |
| `--route` with `--fast` | Ignored — composite-level fallback, no per-stage routing |
| `--route` with `--composite-level` | Ignored — same as above |
| `--route` with `--multi` | Independent — `--multi` handles evaluation/review one-shot relay, `--route` handles stage delegation |
| `--route` with `--policy team+probe` | Active — routing applies during both probe (Light) and escalated runs |

## Bridge Agent Integration

Bridge Agent is a team member like Shaper, Builder, and Critic — it communicates via SendMessage and follows Director's instructions. The key difference: Bridge delegates reasoning to an external model while handling all file operations itself.

### Stage Assignment Protocol

Director sends stage assignments to Bridge via SendMessage:

```text
SendMessage(recipient: "bridge", content: "
Stage: {stage_name}
Model: {codex}
Task: {task description}
Depth: {Light|Standard|Deep}
Context files: {relevant file paths}
Upstream artifacts: {.swe/active/ artifact paths}
", summary: "Route {stage_name} to {model}")
```

Bridge reads the assignment, gathers context, and begins the exec session with the external model.

### Artifact Handoff

Bridge saves stage artifacts to the same paths as Claude specialists — `.swe/active/{NN}-{stage}.md`. Director does not distinguish between Bridge-produced and specialist-produced artifacts. The artifact format and quality requirements are identical regardless of which model produced them.

### Spec Stage Pattern (Understand, Constrain, Design, Interface)

Primarily single-turn with quality iteration:

```text
Bridge → External Model (exec): "Analyze this task and produce {artifact type}." + context
External Model → Bridge: artifact content
Bridge: Evaluate completeness (required sections? domain terms? constraints?)
  If insufficient → follow-up with specific gaps
  If sufficient → Write to .swe/active/{NN}-{stage}.md
Bridge → Director: "Stage complete: {stage}. Artifact: {path}."
```

### Dev Stage Pattern (Test, Implement, Verify, Optimize)

Multi-turn with file operations:

```text
Bridge → External Model (exec): "Given these contracts and tests, how should we implement?" + context
External Model → Bridge: implementation approach / code
Bridge: Write/Edit source files based on guidance
Bridge: Run tests via Bash
  If tests fail → send failure details to External Model for debugging
  External Model → Bridge: fix suggestions
  Bridge: apply fixes, re-run tests
  Repeat until Green state or circuit breaker (3 iterations)
Bridge → Director: "Stage complete: {stage}. Tests: {pass/fail}."
```

### Director State Tracking

Director tracks Bridge stages the same way as specialist stages:

```bash
spiral-state.sh stage-update bridge {stage} running
# ... Bridge executes ...
spiral-state.sh stage-update bridge {stage} completed
```

The Bridge role appears in the team state alongside shaper, builder, and critic.

### Error Escalation

When Bridge's circuit breaker triggers (3 failed attempts with external model):

1. Bridge sends escalation to Director: "Bridge escalation: {stage} failed after 3 attempts with {model}. Reason: {specific failure}."
2. Director reassigns the stage to the owning Claude specialist (Shaper for spec, Builder for dev)
3. State: `spiral-state.sh stage-update bridge {stage} completed` (Bridge's attempt), specialist picks up the stage fresh

## Pipelined Phase Flow

The key difference from linear/probe policy: composites overlap. After each composite completes, the next composite and a cross-review start simultaneously. Gates (Phase 4, 6) are non-blocking auto-checks, not user approval points.

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

Auto-gates replace the interactive Transition Checkpoint Pattern for Phases 4 and 6. They verify artifact readiness without requiring user approval.

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

This gate is NOT auto — it follows the standard Transition Checkpoint Pattern. Director reads the Ship Report, checks for P1 findings, and presents the Decision Matrix to the user. This is the only user-facing gate in team policy.

## Director Relay Checkpoint

When a specialist completes a composite, their Review content must be shown to the user. The relay protocol:

1. Specialist sends Review via `SendMessage(recipient: "director", content: "{review_content}")`
2. Director receives the message (auto-delivered)
3. Director displays the Review content in the conversation for the user to see
4. Director does NOT wait for user response — immediately proceeds to the auto-gate

The user sees each composite's Review as the spiral progresses. If they spot an issue, they can interrupt (standard Claude Code behavior). But the pipeline does not pause for acknowledgment — this is what makes it faster than sequential execution.

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

Backtracking reuses the existing regression protocol from `spiral-state.md`: checkpoint → cascade invalidation → restore. The trigger differs — cross-review finding instead of gate failure — but the state machine mechanics are identical.

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

If 2+ specialists fail, Director falls back to standard linear/probe policy execution for remaining composites. The already-completed composites and their artifacts are preserved.

## File Locations

| Path | Purpose |
|------|---------|
| `.swe/active/.team/` | Team workspace directory (created at team setup) |
| `.swe/active/.team/builder-prep.md` | Builder's codebase pre-analysis |
| `.swe/active/.team/critic-early-scan.md` | Critic's early security scan |
| `.swe/active/.team/{reviewer}-{target}-review.md` | Cross-review findings |
| `.swe/active/.team/tune-perspectives.md` | Collected specialist perspectives for Tune |
| `.swe/active/spiral-state.json` | State file (schema v2 with team section) |
| `scripts/spiral-monitor.sh` | Real-time TUI dashboard — pipeline, team, reviews, events; auto-launched in tmux at init |

## Generator-Critic Loop Protocol

At Standard+ depth in team policy, Design and Interface stages can use 2-pass verification where the generator (Shaper) produces output and the reviewer (Critic) validates it before proceeding.

### Trigger Conditions

- Depth: Standard or Deep (skip at Light)
- Policy: team or team+probe
- Stages: `design` and `interface` only (highest-impact spec artifacts)
- Stage-level execution must be active (not composite-level fallback)

### Loop Sequence

```text
1. Shaper completes Design → sends to Director
2. Director assigns quick review to Critic: "Review Design artifact for P1 issues only."
3. Critic reviews → sends findings to Director
4. If P1 found:
   a. Director sends revision request to Shaper with P1 details
   b. Shaper revises Design → sends updated artifact to Director
   c. Director assigns re-review to Critic (max 1 re-review)
   d. If still P1: Director logs warning, proceeds anyway (defer to full cross-review)
5. If no P1: Director proceeds to next stage
```

### State Transitions During Revision

When a P1 revision triggers re-entry into a completed stage:

```bash
spiral-state.sh stage-update shaper design completed   ← initial completion
  Critic reviews → P1 found
spiral-state.sh stage-update shaper design running     ← re-enter for revision
  Shaper revises
spiral-state.sh stage-update shaper design completed   ← revision completion
  Critic re-reviews → pass or defer
```

The state machine allows `completed → running` re-entry for generator-critic loops only. This does not reset the transition log — both entries are recorded.

### Constraints

- Maximum 2 iterations per stage (1 initial + 1 revision) — prevents unbounded loops
- Only P1 findings trigger revision — P2/P3 are recorded for full cross-review
- Critic's quick review is lightweight — focus on contract-breaking issues only, not comprehensive quality assessment
- Does not replace the full cross-review at auto-gates — this is an additional early check
- When Bridge Agent handles the stage (`--route`), the same loop applies: Bridge produces → Critic reviews → Bridge revises if needed

## Rules

- Director orchestrates — it never executes composites directly (except in fallback)
- Specialists execute composites via Skill tool — they do not manipulate state directly
- Auto-gates (Phase 4, 6) are non-blocking — no user approval required
- Phase 8 gate is the only blocking gate — P1 findings require user decision
- Cross-review runs in parallel with the next composite — this is the core pipelining mechanism
- Cross-review P1 findings may trigger backtracking, which uses the standard regression protocol
- The Director relays composite Reviews to the user but does not pause for acknowledgment (except Phase 8)
- Specialists communicate exclusively through SendMessage — no direct inter-specialist messaging
- Team workspace (`.team/`) is created alongside standard artifacts in `.swe/active/`
- Specialist failure degrades gracefully to single-agent mode for that composite only
- All SendMessage content uses plain text — no structured JSON payloads between teammates
