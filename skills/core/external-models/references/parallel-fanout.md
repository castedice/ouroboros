# Parallel Fan-Out

This reference defines manifest-backed fan-out and fan-in for independent external branches.

## When Fan-Out Is Valid

Fan-out is valid only when the external relay depends on already-gathered context rather than on Claude's eventual answer.
Build every relay prompt before launching any background branch.
Keep external branches independent so their outputs remain unbiased and mergeable later.

## Standard Pattern

Assemble prompt files first and assign deterministic output paths in `.tmp/`.
Declare expected result files with `scripts/parallel.sh init`.
Launch background external branches after the manifest exists.
Run the foreground Claude branch or local phase work in parallel.
After foreground completion, run `scripts/parallel.sh collect` before any merge or consensus step.
Use `scripts/parallel.sh recover` only when gaps remain and salvage still matters.

## Current Consumers

`commands/core/evaluate.md` uses this pattern for external evaluation, including batch waves in Mode B.
`commands/core/evolve.md` uses it for analysis and before or after validation passes.
`commands/core/research.md`, `commands/core/absorb.md`, and `commands/core/generate.md` use it for parallel research or generation support.
`commands/core/brainstorm.md` uses it for parallel idea generation.
`commands/core/upgrade.md` uses it for reconciliation and merge support.
`commands/swe/ship.md` uses it for parallel security review and code review branches.
`commands/swe/tune.md` uses it for external SWE quality evaluation.

## Batch Discipline

Keep result ordering stable even when completion order varies.
Use component discovery order, manifest index, or explicit file naming rather than wall-clock order.
In batch scans, check circuit breakers at batch boundaries rather than cancelling in-flight work.
In the current evaluate module-scan pattern, batches of three components balance concurrency and recoverability.

## Failure Ownership

Helper scripts collect files, but the caller owns failure counters and breaker policy.
A missing background result is not silent once the manifest exists.
Do not merge, cherry-pick, or score around a missing branch until collection or recovery has finished.
When recovery still fails, mark the branch absent and continue only if the caller's fallback policy allows it.
