# Team Specialists — Topology, Prompts, Stage Execution, and Probe

Orchestration protocol for the specialist-facing side of `--policy team`.
Director coordinates 3 Specialists that execute composites concurrently with cross-review.
This reference is self-contained — it can be consulted independently of the parent SKILL.md.
For state machine schema, see `spiral-state.md`.
For artifact dependencies, see `artifact-contracts.md`.
For depth levels, see `depth-system.md`.

## Team Topology

| Role | Agent Type | Owns | Cross-Review Duty | Background Task |
|------|-----------|------|-------------------|----------------|
| **Director** | Main conversation | Gates, state, Tune orchestration | Severity judgment + backtrack decisions | User relay |
| **Shaper** | `general-purpose` | Spec composite | Dev output: domain correctness | Next-turn domain prep |
| **Builder** | `general-purpose` | Dev composite | (receives cross-review) | Codebase pre-analysis during Spec |
| **Critic** | `general-purpose` | Ship composite | Spec output: quality + security | Early security scan during Dev |

Director is the orchestrator — it never executes composites directly.
It manages state, coordinates specialists, evaluates cross-review findings, and relays results to the user.
When `--route` delegates a stage to an external model, Director owns the direct relay loop and artifact validation.
Specialists execute composites via Skill tool and perform cross-reviews of other specialists' output.

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

Specialists are always referenced by their role name (`shaper`, `builder`, `critic`) in SendMessage, TaskUpdate, and team state operations.
Never use agent UUIDs for communication.

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

v0.16.5 default for team policy: Specialists invoke **primitive commands individually** instead of composite Skill calls.
This enables cross-review to start mid-composite and Director to track stage-level progress.

### Primitive Execution Sequence

Instead of `Skill: ouroboros:swe:spec` (black box — 4 stages run internally), Shaper executes:

```text
Skill: ouroboros:swe:understand  → message to Director
Skill: ouroboros:swe:constrain   → message to Director
Skill: ouroboros:swe:design      → message to Director  ← Critic cross-review can start here
Skill: ouroboros:swe:interface   → message to Director
```

Same pattern for Builder (Dev) and Critic (Ship stages where applicable).
Each primitive call produces its artifact in `.swe/active/` as usual.

### Message Checkpoint Protocol

After completing each primitive stage, the specialist sends a progress update:

```text
SendMessage(recipient: "director", content: "Stage complete: {stage_name}. Artifact: .swe/active/{NN}-{stage}.md. Proceeding to {next_stage}.", summary: "{stage_name} complete")
```

Director receives the message and:

1. Updates state: `spiral-state.sh stage-update {specialist} {stage} completed`
2. Checks for pending actions (cross-review trigger, halt instruction, routed direct relay result)
3. Responds only if action is needed — no-op means specialist continues

The specialist checks for Director messages between stage executions.
If Director sends `HALT`, the specialist stops and waits.
If no message, the specialist proceeds to the next stage.

### Cross-Review Trigger Points

Stage-level execution enables **intra-composite cross-review** — reviews start before the full composite finishes:

| After Stage | Trigger | Reviewer Action |
|-------------|---------|-----------------|
| `design` (Spec stage 3) | Critic can begin reviewing Architecture Spec | Director assigns cross-review to Critic; Shaper continues to Interface |
| `implement` (Dev stage 6) | Shaper can begin reviewing implementation code | Director assigns cross-review to Shaper; Builder continues to Verify |

These are **advisory triggers** — Director decides whether to start early cross-review based on team availability.
The mandatory cross-review at auto-gates (Phase 4, 6) still runs as before.

### Known Limitation

Primitives invoked standalone by specialists may display user review checkpoints (e.g., `understand.md` Phase 5).
In team context these are auto-proceeded by the specialist agent — no manual action required.
This adds a minor round-trip but does not block execution.

### Composite-Level Fallback

Stage-level execution is the default for team policy at Standard+ depth.
Fallback to composite-level (v0.16.0 behavior) when:

- `--fast` flag is set (Light depth — stage-level overhead not worth it)
- `--composite-level` explicitly requested
- Specialist failure recovery (Director executes remaining stages as a single composite)

## Probe Composition Protocol

When `--policy team+probe`, each composite runs at Light depth first (probe), then Director relays the result to the user for an escalation decision.
This combines team pipelining with probe's adaptive depth.

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
