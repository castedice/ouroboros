# Code Review Perspective Playbook

Use this reference when a review needs the detailed question set behind the four-perspective procedure.
These checks assume the reviewer already knows which files and artifacts are in scope.

## Architecture

Goal: verify that the implementation matches the intended structure rather than merely working locally.
- Check whether module and bounded-context boundaries are respected.
- Check whether dependencies flow in the intended direction and avoid circularity.
- Check whether the selected pattern, layer, or adapter boundary is applied consistently.
- Check whether responsibilities sit in the right module rather than leaking across boundaries.
- Check whether dead paths, orphan modules, or accidental duplication suggest architectural drift.
Evidence bar: cite imports, calls, ownership boundaries, or artifact mismatches, not vague discomfort.
Severity anchors: `P1` for systemic boundary breaks or consumer-breaking architectural violations, `P2` for meaningful drift or tight coupling, and `P3` for low-risk cleanup or speculative structure improvements.

## Safety

Goal: verify that the code behaves correctly and fails safely at system boundaries.
- Check whether inputs are validated where untrusted data enters the system.
- Check whether errors are surfaced, propagated, and handled without silent swallowing.
- Check whether panics, unchecked casts, partial writes, or undefined behavior can occur.
- Check whether side effects are isolated enough to reason about rollback and recovery.
- Check whether the changed path introduces injection, XSS, CSRF, insecure deserialization, or comparable application-security issues when relevant.
Evidence bar: connect the claim to a real failure path, not to a generic worry.
Severity anchors: `P1` for correctness or exploit paths with real production impact, `P2` for reliability gaps or weakened defenses, and `P3` for defensive improvements without a demonstrated breakage path.

## Performance

Goal: verify that the changed code respects the performance envelope implied by the workload and constraints.
- Check whether the algorithmic complexity fits the expected data scale.
- Check whether the code introduces repeated expensive work such as N+1 access, redundant parsing, or avoidable allocation.
- Check whether hot paths are accidentally pessimized by new abstractions or copies.
- Check whether I/O is batched and whether expensive network or disk work sits in loops.
- Check whether async flows hide blocking operations or contention hotspots.
Evidence bar: tie the claim to a hot path, scale assumption, benchmark, or stated constraint.
Severity anchors: `P1` for hard constraint violations or catastrophic regressions on normal workloads, `P2` for meaningful latency or throughput harm, and `P3` for cleanup or optimization opportunities without strong evidence.

## Readability

Goal: verify that future maintainers can understand and change the code without paying unnecessary cognitive cost.
- Check whether names express intent and remain consistent across the changed path.
- Check whether control flow is locally understandable without decoding hidden side effects.
- Check whether abstraction layers are justified or whether a simpler design would be clearer.
- Check whether comments explain the truly non-obvious parts rather than compensating for confusing structure.
- Check whether a new developer could find the relevant logic without unnecessary indirection.
Evidence bar: tie the claim to a specific readability obstacle and a concrete simplification path.
Severity anchors: `P1` is rare and should be reserved for readability failures that effectively hide a correctness or operational risk, `P2` for maintainability problems that slow collaboration or safe change, and `P3` for minor clarity polish.
