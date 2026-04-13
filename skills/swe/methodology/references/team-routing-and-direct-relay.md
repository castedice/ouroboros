# Team Routing and Direct Relay — Stage Routing, Relay Modes, and Shared Team Ops

This reference covers external-model routing inside team policy and the shared mechanics that support routed stages.
Use it when Director needs to decide whether a stage stays with a Claude specialist or moves through direct relay.
This reference is self-contained and replaces the legacy team-routing bridge reference.
For specialist ownership and probe flow, see `team-specialists.md`.
For pipelined execution flow and cross-review decisions, see `team-flow-and-cross-review.md`.

## Routing Mode

The team route plan carries a `mode` field alongside the stage-to-model map.
`mode: direct` is the primary and default path.
`mode: bridge` is the legacy label retained only for migration history and deprecated comparison notes.
`mode: dual` is the soak label for side-by-side comparison of direct relay against archived bridge behavior.
Switch modes by changing the route-plan field before Phase 2.7 team setup begins.
After bridge removal, new runs should use `mode: direct`.

## Selective Routing Protocol

When `--route` is specified, Director can delegate individual stages to external models through direct relay instead of Claude specialists.
This keeps specialist ownership intact while letting selected stages use Codex for artifact generation.

### Route Table Format

```text
--route "understand=codex,design=claude,implement=codex"
```

Parsing rules:

- Comma-separated `{stage}={model}` pairs.
- Valid stages are `understand`, `constrain`, `design`, `interface`, `test`, `implement`, `verify`, and `optimize`.
- Valid models are `codex` and `claude`.
- Unspecified stages default to `claude`.
- Invalid stage or model names abort with an error listing valid options.

### Director Routing Logic

At each stage assignment, Director checks the routing table and the route-plan mode.

```text
1. Look up the stage in the routing table.
2. If model == "claude" or the stage is not present:
   → Assign to the owning Claude specialist.
3. If model == "codex" and mode == "direct":
   → Director assembles the relay prompt from `agent-instructions.md`.
   → Director runs `scripts/codex-relay.sh`.
   → Director validates the returned artifact and promotes it into `.swe/active/`.
4. If model == "codex" and mode == "bridge":
   → Treat as a legacy label only.
   → Prefer `direct` unless a migration note explicitly asks for historical comparison.
5. If model == "codex" and mode == "dual":
   → Run the direct relay path.
   → Preserve comparison notes against the legacy bridge expectation for soak analysis.
6. Director updates state regardless of which path produced the routed artifact.
```

When stage-level execution is active at Standard or Deep depth, routing applies per primitive stage.
When composite-level fallback is active through `--fast` or `--composite-level`, routing is ignored and the full composite stays with the Claude specialist.

## Direct Relay Protocol

Direct relay keeps ownership with Director rather than adding an extra relay teammate.
The owning specialist remains responsible for the routed stage in team state and downstream review logic.

### CLI Availability Check

Before the first routed stage, Director verifies Codex CLI availability with `which codex` and `codex --version`.
If Codex CLI is unavailable, Director logs a warning and reassigns affected stages to the Claude specialist.
If all external routes fall back, direct relay is skipped entirely for the turn.

### Stage Assignment Contract

For each routed stage, Director resolves the stage owner, depth, context files, upstream artifacts, and target artifact path.
Director reads the stage template from `skills/swe/methodology/references/agent-instructions.md`.
Director builds a relay prompt that binds the stage requirements, task, depth, and relevant context verbatim.
Director saves the relay prompt to a deterministic `.tmp/` path before execution begins.

### Artifact Handoff

Direct relay writes parsed output to a temporary artifact first.
For markdown stage artifacts, Director uses `scripts/codex-relay.sh ... --text-output <tmp-artifact> --meta`.
For JSON-first consumers, Director uses `--output` instead.
Director validates the temporary result before promoting it to `.swe/active/{NN}-{stage}.md`.
Director preserves the `.raw`, optional saved thread file, and `.meta.json` sidecar for recovery or comparison.

### Spec Stage Pattern

```text
Director → Codex (direct relay): "Analyze this task and produce {artifact type}." + bound stage instructions + context
Codex → Director: artifact content
Director: Evaluate completeness against required sections, domain terms, and stage fields
  If insufficient → follow up on the same thread with targeted gaps
  If sufficient → promote artifact to .swe/active/{NN}-{stage}.md
Director → Team flow: "Stage complete: {stage}. Artifact: {path}."
```

### Dev Stage Pattern

```text
Director → Codex (direct relay): "Given these contracts and tests, propose the next implementation step." + context
Codex → Director: implementation guidance or draft content
Director: Apply file edits and run tests locally
  If tests fail → send failure details back through resume
  Codex → Director: fix guidance
  Director: apply fixes and re-run tests
  Repeat until Green state or circuit breaker
Director → Team flow: "Stage complete: {stage}. Tests: {pass/fail}."
```

### State Tracking

Director tracks routed stages under the owning specialist rather than under a separate relay role.
Use `spiral-state.sh stage-update shaper {stage} {status}` for routed spec stages.
Use `spiral-state.sh stage-update builder {stage} {status}` for routed dev stages.
The team state remains limited to `shaper`, `builder`, and `critic`.

### Error Escalation

When direct relay hits the stage circuit breaker of three failed attempts, Director records the failure reason and reassigns the stage to the owning Claude specialist.
When CLI availability fails, Director falls back to the Claude specialist immediately.
These fallbacks preserve the normal team pipeline and do not introduce a separate relay specialist lifecycle.

## File Locations

| Path | Purpose |
|------|---------|
| `.swe/active/.team/` | Team workspace directory |
| `.swe/active/.team/builder-prep.md` | Builder's codebase pre-analysis |
| `.swe/active/.team/critic-early-scan.md` | Critic's early security scan |
| `.swe/active/.team/{reviewer}-{target}-review.md` | Cross-review findings |
| `.swe/active/.team/tune-perspectives.md` | Collected specialist perspectives for Tune |
| `.swe/active/spiral-state.json` | State file |

## Generator-Critic Loop Protocol

At Standard or Deep depth in team policy, Design and Interface stages can use 2-pass verification where the generator produces output and Critic validates it before proceeding.

### Trigger Conditions

- Depth is Standard or Deep.
- Policy is `team` or `team+probe`.
- Stages are `design` and `interface` only.
- Stage-level execution is active rather than composite-level fallback.

### Loop Sequence

```text
1. Shaper or routed direct relay completes Design and sends it to Director.
2. Director assigns quick review to Critic for P1 issues only.
3. Critic reviews and sends findings to Director.
4. If P1 is found:
   a. Director requests a revision from the current stage owner.
   b. The stage owner revises Design and sends the updated artifact.
   c. Director assigns one re-review to Critic.
   d. If P1 remains, Director logs a warning and proceeds anyway.
5. If no P1 is found, Director proceeds to the next stage.
```

### State Transitions During Revision

When a P1 revision triggers re-entry into a completed stage:

```bash
spiral-state.sh stage-update shaper design completed
spiral-state.sh stage-update shaper design running
spiral-state.sh stage-update shaper design completed
```

The state machine allows `completed → running` re-entry for generator-critic loops only.
This does not reset the transition log and both entries remain visible.

### Constraints

- Maximum 2 iterations per stage are allowed.
- Only P1 findings trigger revision.
- Critic's quick review stays lightweight and focuses on contract-breaking issues.
- This loop does not replace the full cross-review at auto-gates.
- When a routed stage uses direct relay, the same loop applies and Director owns the revision prompt.

## Rules

- Director orchestrates and owns routed direct relay.
- Specialists execute composites via Skill tool and do not manipulate state directly.
- Auto-gates at Phases 4 and 6 are non-blocking.
- Phase 8 is the only blocking gate.
- Cross-review runs in parallel with the next composite.
- Cross-review P1 findings may trigger backtracking through the standard regression protocol.
- The Director relays composite Reviews to the user without pausing for acknowledgment except at Phase 8.
- Specialists communicate through SendMessage and do not message each other directly.
- Team workspace `.team/` is created alongside standard artifacts in `.swe/active/`.
- Direct relay failure degrades gracefully to the owning Claude specialist.
- All SendMessage content uses plain text rather than structured JSON payloads.
