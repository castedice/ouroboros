# Coordination Patterns

This reference helps choose the simplest multi-agent topology that fits the task.
Use it after deciding that more than one model, agent, or worker is worth the coordination cost.
Use `scripts/parallel.sh` and `skills/core/external-models/references/parallel-fanout.md` only for fan-out transport mechanics.

## Selection Summary

| Pattern | Support | Use When |
|---------|---------|----------|
| Pipeline | [implemented] | Stages depend on the previous stage artifact. |
| Fan-out/Fan-in | [implemented] | Workers can run independently from the same prepared context. |
| Expert Pool | [documented-manual] | One specialist should be selected by capability fit. |
| Supervisor | [future] | A central queue must assign tasks dynamically as workers become available. |
| Hierarchical | [future] | Tasks need recursive decomposition and nested aggregation. |

## Pipeline [implemented]

Definition: Pipeline is a sequential artifact pass where each stage consumes the prior stage output and emits the next artifact.

ASCII topology:
```text
A -> B -> C
```

When to use:
- Use when downstream work depends on an upstream artifact, verdict, or gate.
- Use when each stage has a stable input and output contract.
- Use when correctness depends on preserving artifact lineage.

Avoid when:
- Avoid when branches are independent and waiting only adds latency.
- Avoid when later stages can start from the same prepared context without reading earlier results.
- Avoid when the next stage's contract is still undefined.

Contract shape:
```text
upstream_artifact + acceptance_criteria -> downstream_stage
```

Ouroboros examples:
- SWE `spec -> dev -> ship -> tune` in `commands/swe/spiral.md`.
- SWE primitive stage chains such as Understand -> Constrain -> Design -> Interface and Test -> Implement -> Verify -> Optimize.
- RnD command phases `1-13`, mapped onto the 10 persisted stages in `commands/rnd.md`.

Anti-patterns:
- Do not let a downstream stage infer missing upstream acceptance criteria from chat context.
- Do not skip a gate just because the next stage seems obvious.
- Do not run a strict artifact chain as parallel work and then merge incompatible downstream assumptions.

## Fan-out/Fan-in [implemented]

Definition: Fan-out/Fan-in sends the same prepared context to independent workers, then collects and integrates their results.

ASCII topology:
```text
             /-> W1 -\
Controller --> W2 --> Collector
             \-> W3 -/
```

When to use:
- Use when each worker can act without reading another worker's output.
- Use when parallelism reduces wall-clock time or adds useful independent judgment.
- Use when result collection can tolerate missing or failed branches through an explicit fallback policy.

Avoid when:
- Avoid when workers need to coordinate live or share mutable file ownership.
- Avoid when the relay prompt depends on another branch's eventual answer.
- Avoid when result ordering is ambiguous and no manifest or deterministic ordering exists.

Contract shape:
```text
manifest_init -> worker_calls -> fan_in_collection
```

Ouroboros examples:
- `scripts/parallel.sh` manifest init, collect, and recover for file-based collection.
- `scripts/codex-relay.sh` as an external model branch transport in core and SWE multi-model phases.
- RnD Phase 8 branch probes using `parallel.sh` before branch scoring.
- `/evolve` Phase 6 dual evaluation when Claude and Codex compare before and after artifacts independently.
- `/evaluate` Mode B batch evaluation and `/swe ship` Security Review plus Code Review fan-out.

Anti-patterns:
- Do not launch branches before prompts and expected output files are fixed.
- Do not merge around a missing branch before collection or recovery has run.
- Do not use fan-out to hide disagreement that needs consensus, pruning, or a user decision.

## Expert Pool [documented-manual]

Definition: Expert Pool routes a request to the best-fit specialist from a known set and dispatches only one selected expert.

ASCII topology:
```text
Request -> Router -> [E1 | E2 | E3]
                    |
                    v
              Selected expert
```

When to use:
- Use when the task needs one specialist rather than multiple independent opinions.
- Use when capabilities, tools, model strengths, or domain boundaries determine the right owner.
- Use when dispatching multiple experts would create redundant work or unnecessary consensus overhead.

Avoid when:
- Avoid when the task is too broad for any one expert and needs decomposition.
- Avoid when the route criteria are not explicit enough to defend.
- Avoid when the request needs adversarial review or parallel evidence gathering.

Contract shape:
```text
request_description -> capability_match -> single_specialist_dispatch
```

Ouroboros examples:
- Agent routing with `Agent(subagent_type: "ouroboros:core:{agent}")` or `Agent(subagent_type: "ouroboros:swe:{agent}")`.
- RnD agent dispatch to `collector`, `investigator`, or `critic` based on the current stage.
- Model routing through `skills/core/routing/references/routing-table.md`, where task category and stake select the model profile.
- SWE team `--route` stage routing in `commands/swe/spiral.md`, where selected stages may route to Codex while others stay with Claude.

Anti-patterns:
- Do not call several experts and treat the loudest answer as routing.
- Do not route by model preference when repository evidence or task category points elsewhere.
- Do not hide a routing failure by silently falling back without recording the degraded mode.

## Supervisor [future]

Definition: Supervisor is a central dispatcher that owns a dynamic queue, assigns work to available workers, and collects results as tasks finish.

ASCII topology:
```text
Work Queue -> Supervisor -> Worker A
                         -> Worker B
                         -> Worker C
Workers -> Results -> Supervisor
```

When to use:
- Use when tasks arrive or change dynamically during execution.
- Use when worker availability, rate limits, or failures should affect assignment.
- Use when the work queue is more important than a fixed stage sequence.

Avoid when:
- Avoid when a static pipeline or simple fan-out can express the work.
- Avoid when no durable queue, assignment state, or retry policy exists.
- Avoid when workers would compete for the same mutable files without ownership locks.

Contract shape:
```text
work_queue -> availability_check -> task_dispatch -> result_collect
```

Ouroboros examples:
- No current implementation.
- Future candidate: RnD branch probes if wave scheduling becomes a live queue rather than planned waves.
- Future candidate: SWE team policy if specialist work becomes availability-driven rather than phase-driven.

Anti-patterns:
- Do not call a fixed fan-out batch a supervisor just because one controller collects results.
- Do not assign new work without updating queue state and ownership.
- Do not let workers pull arbitrary tasks without a central acceptance contract.

## Hierarchical [future]

Definition: Hierarchical coordination recursively decomposes a parent task into subtask contracts, delegates them, and aggregates nested results.

ASCII topology:
```text
Parent
  |-- Child A
  |     \-- Grandchild A1
  |-- Child B
  \-- Aggregate
```

When to use:
- Use when a task naturally decomposes into nested scopes with different local contracts.
- Use when each child can further split work without violating the parent invariant.
- Use when aggregation must preserve traceability from child outputs to the parent decision.

Avoid when:
- Avoid when the parent cannot state stable acceptance criteria.
- Avoid when recursive delegation would duplicate context loading and review cost.
- Avoid when child tasks have overlapping write ownership.

Contract shape:
```text
parent_task -> subtask_contracts -> recursive_delegation -> result_aggregation
```

Ouroboros examples:
- No current implementation.
- Future candidate: large SWE programs that split a spiral turn into independently reviewed feature trees.
- Future candidate: RnD studies that split a broad research question into nested sub-studies with their own reports.

Anti-patterns:
- Do not decompose recursively to look thorough when a pipeline stage is enough.
- Do not let child agents invent new parent-level goals.
- Do not aggregate child outputs without checking them against the parent contract.
