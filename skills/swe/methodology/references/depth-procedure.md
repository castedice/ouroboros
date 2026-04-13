# Depth Procedure

This reference explains how SWE commands parse, resolve, validate, and apply depth.
It complements `depth-system.md`, which defines the rules, by documenting the runtime procedure used in commands.
Use this file when you need the command-side algorithm instead of the policy definitions.

## Scope

The same procedure appears in primitive SWE stages, composite SWE commands, and `/swe reverse`.
Primitive stages resolve one stage depth.
Composite commands resolve multiple internal stage depths from one flag set.
`/swe spiral` resolves composite depths and then passes them to lower composites.
`/swe reverse` uses the same parsing shapes but a different auto-detection heuristic.

## Inputs

Commands accept explicit depth overrides through `--depth`.
Most SWE commands also accept `--fast` as a shortcut to Light depth.
`/swe spiral` additionally accepts `--deep` as a shortcut to Deep depth.
Primitive stages accept `Skip`, `Light`, `Standard`, or `Deep`.
Composites accept either one global value or per-stage abbreviations.
Per-stage abbreviations depend on the command boundary that is being controlled.

## Parse First

The command always parses arguments before it decides any depth.
An empty required task or path aborts before any depth work begins.
Invalid depth values abort immediately.
Invalid stage abbreviations abort immediately.
Missing per-stage entries default to `Standard`.
A single depth word expands to every controlled stage in that command.

## Supported Shapes

Primitive stages use `--depth Skip|Light|Standard|Deep`.
`/swe spec` accepts global depth or `U: C: D: I:` pairs.
`/swe dev` accepts global depth or `T: I: V: O:` pairs.
`/swe ship` accepts global depth or `G: S: R: D:` pairs.
`/swe tune` accepts global depth or `E: I: R:` pairs.
`/swe spiral` accepts global depth or `S: D: H: N:` pairs.
`/swe reverse` accepts global depth or `U: C: D: I:` pairs for recovered artifacts.

## Precedence

Explicit `--depth` always wins over shortcuts.
`--fast` only applies when `--depth` is absent.
`/swe spiral --deep` only applies when `--depth` is absent.
`/swe spiral` rejects `--fast` and `--deep` together.
Composite commands treat parsed explicit values as final unless later skip validation overrides them.

## Primitive Resolution

Primitive stages follow a three-branch resolution order.
Branch one uses the explicit `--depth` value directly.
Branch two converts `--fast` into `Light` and enables fast-mode skip relaxation.
Branch three computes a default through the depth matrix in `depth-system.md`.
The matrix scores task scope, risk, familiarity, team impact, and reversibility once for the task.
The summed score maps to `Light`, `Standard`, or `Deep`.
`Skip` is never produced by the score table.
Commands then apply stage-specific minimum depth triggers from `depth-system.md`.
Commands then apply escalation rules from `depth-system.md`.
Commands log the factor scores and the chosen depth for traceability.

## Primitive Skip Validation

Primitive commands do not trust `Skip` blindly.
Each stage checks whether its categorical skip condition actually holds.
If the skip condition is valid, the command writes a minimal skip artifact and jumps to output.
If the skip condition is invalid, the command overrides `Skip` to `Light`.
The override reason is logged explicitly.
`/swe understand` is the hard exception because it can never be skipped.
When `Understand` receives `Skip`, it always downgrades that request into `Light`.

## Fast Mode

Fast mode is two changes, not one.
It sets the resolved depth to `Light`.
It also activates relaxed skip conditions in primitive stages.
Those relaxed rules are stage-specific and are stricter than a blanket "skip if small" policy.
Commands that enter fast mode must still validate whether the relaxed skip condition actually applies.
If the relaxed skip does not apply, the stage continues at `Light`.

## Composite Resolution

Composite commands resolve multiple depths before any internal stage runs.
`/swe spec`, `/swe dev`, `/swe ship`, and `/swe tune` all parse global or per-stage depth input.
Their explicit path mirrors the primitive rules because parsed `--depth` values are used directly.
Their fast path sets every internal stage to `Light`.
Their auto path builds a Depth Plan instead of jumping straight into execution.
The composite Depth Plan names every internal stage and its rationale.
The composite then shows that plan to the user for confirmation before execution.

## Composite Auto Planning

`/swe spec` scores the task once and then distributes that result across Understand, Constrain, Design, and Interface.
`/swe dev` scores the task once and then applies extra minimum-depth triggers for Test, Implement, Verify, and Optimize.
`/swe ship` does not reuse the five-factor matrix directly and instead applies stage defaults from task characteristics.
`/swe tune` also uses stage defaults rather than the five-factor matrix.
The common pattern is still the same because all four commands produce a per-stage plan before they run.
Composite planning always names the stages explicitly.
Composite planning always records rationale, not just the final depth labels.

## Spiral Resolution

`/swe spiral` resolves depths at the composite boundary instead of the primitive boundary.
Its explicit path uses parsed per-composite values directly.
Its fast path sets every composite to `Light` and enables downstream fast-mode behavior.
Its deep path sets every composite to `Deep`.
If no shortcut or explicit depth is provided, `spiral` asks the user for a depth plan instead of inferring one silently.
`spiral` optionally loads the previous turn's learning delta before finalizing the plan.
Learning deltas suggest depth changes but never apply them automatically.
The final output is a composite Depth Plan that later composites further distribute internally.

## Reverse Resolution

`/swe reverse` is the intentional variation.
It uses explicit `--depth` first and `--fast` second like the other commands.
Its auto path is based on codebase scale rather than task complexity.
File count, language count, and module boundary count determine the default depth.
That scale then maps to `Light`, `Standard`, or `Deep`.
The reverse command still presents a Depth Plan to the user before proceeding.

## Confirmation Pattern

Primitive commands do not stop for a separate depth confirmation step.
Composite commands do stop for depth confirmation before stage execution.
`/swe reverse` also confirms its artifact depth plan before running.
`/swe spiral` confirms the composite plan before state initialization.
The confirmation output always shows stage or composite names, chosen depths, and rationale.

## Application Pattern

Resolved depth is passed into the delegated agent instruction template.
Resolved depth is written into the artifact header or report.
Resolved depth controls whether optional upstream artifacts load in full or by summary.
Resolved depth controls whether Light-only skip branches stay active.
Resolved depth controls which template sections are expected from the agent.
Resolved depth also shapes the next-step recommendation handed to downstream stages.

## Logging Requirements

Commands log explicit overrides when `--depth` is provided.
Commands log fast-mode activation when `--fast` is used without `--depth`.
Matrix-based primitives log the factor breakdown and total score.
Composite commands log a compact Depth Plan string.
Depth logging is part of auditability rather than optional debugging.

## Failure Handling

Malformed `--depth` input aborts instead of degrading silently.
Unknown stage abbreviations abort instead of being ignored.
Invalid depth words abort instead of defaulting.
Skip misuse is corrected only after the input itself has parsed successfully.
Commands only auto-correct semantic misuse such as an inapplicable `Skip`.

## Invariants

`--depth` is authoritative whenever it exists.
`Skip` is validated by stage semantics, not by user intent alone.
`Skip` is categorical and never comes from the numeric score map.
Fast mode means `Light` plus relaxed skip handling, not `Skip`.
Per-stage or per-composite plans default omitted entries to `Standard`.
Depth is resolved before agent delegation.
Depth decisions are visible in logs and user-facing plans when the command is composite.

## When To Reach For Another Reference

Use `depth-system.md` when you need the policy tables and escalation triggers.
Use `artifact-resolution.md` when you need to see how depth changes summary versus full artifact loading.
Use `composite-checkpoint-rules.md` when you need to see how composite commands suppress intermediate review pauses after depth planning.
