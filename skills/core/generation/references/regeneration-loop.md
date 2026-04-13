# Regeneration Loop

This reference documents how generated components are retried after failing the quality gate.
It covers the shared loop used by `/generate` and `/absorb`.
Use this file when you need the retry algorithm rather than the general generation workflow.

## Scope

The loop runs after generation has already written candidate files to the worktree.
It applies only to generated commands, agents, and skills.
Templates are excluded from evaluation and regeneration.
The loop is quality-driven, not syntax-driven, because structural validation runs first.

## Entry Conditions

Phase 5 or Phase 7 has already produced files in the worktree.
Structural validation has already run on those files.
Auto-fix has already handled obvious mechanical errors where possible.
The remaining question is whether each generated component clears the evaluation bar.

## Inputs

The loop needs the generated file content from the worktree.
It also needs the resolved component type for each file.
It loads the correct criteria reference for that type.
If multi-model mode is active, it also includes Codex evaluation results for consensus.
It may also carry structural-validation warnings forward for the review phase.

## Step 1

Evaluate every non-template generated component.
`/generate` uses Mode A static evaluation for each generated command, agent, and skill.
`/absorb` uses the same Mode A static evaluation for each generated component.
The evaluator reads the component content and the type-specific criteria.
The evaluation result is the gate input for retry decisions.

## Step 2

Determine which components failed the gate.
The command-level rule is `Level >= 2` as the pass threshold.
Level 1 components enter regeneration.
Level 2 or better components do not enter regeneration by default.
Passing components may still receive small inline fixes through a separate optional path.

## Step 3

Build a regeneration packet for each failing component.
The packet includes the original component content.
The packet includes the evaluation report that explains why it failed.
The packet includes the criteria reference for the target type.
The packet does not ask the generator to invent a new architecture from scratch.
The packet asks the generator to revise the same component against explicit failures.

## Step 4

Invoke the Claude generator for retry.
The retry path intentionally stays single-generator even in multi-model mode.
The commands avoid Codex regeneration because that adds complexity with little additional value.
The retry instruction is framed as component regeneration rather than fresh generation.
The generator is expected to diagnose root causes from the evaluation report before revising content.

## Step 5

Strip any trailing completion status block from the generator output before extracting revised content.
This mirrors the extraction rule already used in the shared quality-gate procedure.
The same stripping rule applies before parsing evaluator output for levels or improvement details.
The loop treats parsing hygiene as part of correctness, not cleanup.

## Step 6

Overwrite the failing worktree file with the revised content.
The retry updates the same path instead of creating a parallel variant.
That keeps later validation, review, and commit steps simple.
The worktree remains the single source of truth for the current draft.

## Step 7

Re-evaluate the revised file.
The same type-specific criteria are used again.
This second evaluation determines whether the retry improved the file enough.
The command records the revised score or level even if the result is still weak.
The loop stops after this re-evaluation.

## One-Retry Ceiling

Both `/generate` and `/absorb` cap regeneration at one retry round per failing component.
The limit is explicit rather than heuristic.
The rationale is diminishing returns after the first targeted correction.
The commands prefer surfacing residual weakness to the user instead of spinning on repeated drafts.
Further quality work belongs in a later `/evolve` cycle, not in endless generation retries.

## Multi-Model Evaluation Path

When `--multi` is active, evaluation fans out to Claude and Codex in parallel.
Claude runs in the foreground through the evaluator agent.
Codex runs in the background through the relay flow.
The command fans the results back in after Claude completes.
Consensus then applies per-criterion majority rule.
That consensus score determines whether the component enters regeneration.

## Multi-Model Boundaries

Multi-model support changes evaluation, not regeneration.
Retry generation still uses Claude only.
This keeps the write path deterministic.
It also avoids branching the worktree around competing regenerated drafts.
Codex remains an evaluator and advisory voice during this loop.

## Circuit Breaker

The multi-model path uses a circuit breaker for Codex failures.
Two consecutive Codex failures disable Codex for the remaining components in that run.
Claude evaluation remains sufficient after the breaker trips.
The breaker affects only evaluation fan-out and never cancels the overall quality gate.

## Structural Validation Before Retry

The regeneration loop assumes structural validation has already happened.
Missing frontmatter, bad names, bad paths, and broken references should be fixed before quality scoring.
This keeps the generator from wasting its retry on purely mechanical repairs.
Residual structural issues may still be logged and carried into the final review.
The quality loop is not a substitute for validation.

## Optional Inline Fix Path

Passing components with a tiny obvious issue can skip regeneration and receive an inline fix.
That path is separate from failure retry.
It is reserved for small mechanical improvements that do not require new reasoning.
After the fix, the stricter model re-evaluates the component.
If multi-model evaluation was used, the stricter-model re-check combines with the other model's original scores.

## Post-Retry Decision

A successful retry simply proceeds to the next phase.
A weak retry does not trigger a second retry.
The command logs the result and continues anyway.
This is intentional because generated output is treated as a starting point, not the final quality ceiling.
The user review and later `/evolve` workflow are the next escalation paths.

## Review-Phase Consequence

Residual failures are not hidden.
The decision entry records evaluation summaries, pass counts, and per-component scores.
The review phase shows which component is weakest.
`/generate` even uses the weakest component to seed a recommended `/evolve` command.
The loop therefore preserves visibility instead of pretending the retry solved everything.

## Absorb-Specific Entry

`/absorb` skips the loop entirely when there are no generated components.
That happens in Mode B when the source only contributes a knowledge entry and no actionable gaps.
In that case, absorb goes straight to record creation after the knowledge write.
The absence of a regeneration loop is part of the successful no-gap path.

## Generate-Specific Entry

`/generate` always runs structural validation before the quality loop.
Residual structural warnings do not block entry into quality validation.
The quality gate then evaluates either the single target component or the whole generated module surface.
Each non-template component is processed individually.
The weakest surviving component becomes the recommended next improvement target.

## What Counts As Failure

A Level 1 component fails the gate.
A malformed evaluator output does not automatically count as quality failure if enough score data can be recovered.
A Codex background failure does not fail the component because Claude evaluation still exists.
A template never fails this gate because templates are excluded.
A structural error belongs to the validation phase and should be classified there first.

## What The Generator Receives On Retry

The original content anchors what already exists.
The evaluation report names the failing criteria and the reasoning behind them.
The criteria file restates the quality target in machine-usable form.
This triad makes the retry targeted rather than speculative.
The retry is expected to correct the weakest criteria first.

## Why The Loop Works

The first draft often misses obvious rubric-aligned requirements.
A focused retry is cheap because the evaluation already localized the misses.
Stopping after one retry prevents generation from turning into hidden evolution work.
Proceeding with residual weakness preserves momentum while keeping the quality signal intact.
The loop therefore balances quality, cost, and forward progress.

## Practical Checklist

Exclude templates from the loop.
Run structural validation before quality evaluation.
Evaluate every generated command, agent, and skill.
Enter retry only for failing components.
Pass original content, evaluation report, and criteria into regeneration.
Strip completion status blocks before parsing outputs.
Overwrite the same worktree path with the revised content.
Re-evaluate exactly once.
Log the final score and proceed, even when the result remains weak.

## Related References

Use `scaffold-and-quality-gate.md` for the pre-gate rules that reduce how often regeneration is needed.
Use `quality-gate-procedure.md` for the shared validation-side procedure that this loop operationalizes.
Use `type-detection.md` when retry preparation depends on classifying the generated file correctly before criteria loading.
