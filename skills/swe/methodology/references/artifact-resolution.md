# Artifact Resolution

This reference explains how SWE commands locate, load, validate, and degrade artifact context.
It documents the command-side retrieval pattern that sits on top of `artifact-contracts.md`.
Use this file when you need the resolution algorithm rather than the artifact schema itself.

## Core Principle

Commands separate entry artifacts, supporting artifacts, and project context.
Entry artifacts determine whether a stage can begin at all.
Supporting artifacts enrich the analysis but may degrade to warnings.
Project context is persistent background state loaded from `docs/specs/project/`.

## Resolution Order

An explicit `--artifact` path always wins first.
If no explicit path exists, the command searches canonical `.swe/active/` locations.
If the command supports multiple candidate entry points, it uses a documented priority list.
If multiple valid candidates exist at the same priority, the most recent file by modification time wins.
Optional supporting artifacts are then gathered from `.swe/active/`.
Persistent project context is loaded last from `docs/specs/project/{domain,constraints,architecture,interfaces}.md`.

## Validation Order

Commands resolve the path first.
Commands then confirm the file exists and is readable.
Commands then validate minimum content expectations for the artifact type.
Required artifact failure aborts when the stage cannot proceed safely.
Optional artifact failure becomes a warning with reduced context.
Malformed or empty required artifacts are treated as harder failures than mere absence.

## Load Shapes

Required artifacts are read in full.
Optional artifacts at `Standard` or `Deep` are also read in full.
Optional artifacts at `Light` load only their `## Summary` section through a short read.
Project model files contribute only their `## Summary` sections.
Archived record artifacts are usually consumed by summary during retrospect or project-model merge.

## Primitive Entry Patterns

`/swe understand` has no mandatory upstream artifact.
`/swe understand` may read a provided prior artifact for iteration context.
`/swe constrain` treats the Context Document as its primary upstream artifact.
`/swe design` treats the Constraint Profile as its primary upstream artifact.
`/swe interface` treats the Architecture Spec as its primary upstream artifact.
`/swe test` requires Interface Contracts as its entry artifact.
`/swe implement` requires the Test Suite as its entry artifact.
`/swe verify` requires Interface Contracts and the Implementation artifact in practice because both are always read in full.
`/swe optimize` requires the Constraint Profile, Architecture Spec, and Verification Report.

## Composite Entry Patterns

`/swe spec` starts from the task description and creates its own chain.
`/swe dev` enters through Interface Contracts.
`/swe ship` enters through the newest of `08-optimize.md` or `06-implement.md`.
`/swe tune` enters through the newest of `09-ship.md`, `08-optimize.md`, or `07-verify.md`.
`/swe spiral` uses transition gates instead of a single entry artifact because each composite hands off to the next.

## Stage 1 Pattern

`Understand` surveys the codebase first because it is greenfield-capable.
It may read a supplied artifact, but it does not require one.
It also checks repo guidance files such as `AGENTS.md` and `CLAUDE.md`.
If no code context is found, it logs a greenfield warning and proceeds.
It still injects `docs/specs/project/domain.md` summary when available.

## Stage 2 Pattern

`Constrain` reads the provided Context Document when present.
It validates that Problem Statement and Affected Components exist before relying on it.
A missing or unreadable Context Document downgrades precision but does not force an abort.
If no upstream artifact exists, `Constrain` explicitly warns that `/swe understand` would improve coverage.
It also adds the `docs/specs/project/constraints.md` summary when available.

## Stage 3 Pattern

`Design` reads the provided Constraint Profile when present.
It extracts hard constraints, soft constraints, and conflict resolutions from that artifact.
It also searches `.swe/active/01-understand.md` for task context.
At `Light`, the Context Document is summary-only.
At `Standard` or `Deep`, the Context Document is read in full.
If no Constraint Profile exists, `Design` continues but logs that traceability will be missing.
It also injects the `docs/specs/project/architecture.md` summary when available.

## Stage 4 Pattern

`Interface` reads the provided Architecture Spec when present.
It supplements that with `.swe/active/01-understand.md` and `.swe/active/02-constrain.md`.
At `Light`, those supporting artifacts are summary-only.
At `Standard` or `Deep`, they are full reads.
If the Architecture Spec is missing, the command continues with warnings rather than aborting.
It also injects the `docs/specs/project/interfaces.md` summary when available.

## Stage 5 Pattern

`Test` requires Interface Contracts from `--artifact` or `.swe/active/04-interface.md`.
If the Interface Contracts are absent, the command aborts.
If the Interface Contracts are empty or malformed, the command aborts.
It optionally loads Design, Understand, and Constrain for scenario derivation.
Those optional artifacts use summary-only loading at `Light`.

## Stage 6 Pattern

`Implement` requires the Test Suite from `--artifact` or `.swe/active/05-test.md`.
It always reads `.swe/active/04-interface.md` in full because the contracts are the implementation target.
It reads Design and Constrain as optional enrichers.
Those enrichers degrade to summary-only at `Light`.
Missing Interface Contracts only produces a warning because tests can still anchor the implementation.
Missing Test Suite is fatal because the Red target is the stage contract.

## Stage 7 Pattern

`Verify` gathers the full artifact chain from `.swe/active/`.
It always reads Interface Contracts and the Implementation artifact in full.
It treats Understand, Constrain, Design, and Test as optional at `Light`.
It treats those same artifacts as full reads at `Standard` or `Deep`.
An extra `--artifact` path is additive rather than replacing the chain.
If upstream artifacts are missing, the stage proceeds with an explicit gap note.

## Stage 8 Pattern

`Optimize` is the strictest artifact reader.
It reads Constraint Profile, Architecture Spec, and Verification Report in full.
Those artifacts define the performance target, the architectural guardrails, and the correctness baseline.
A missing Verification Report produces a warning because optimizing unverified code is risky.
A failing test baseline aborts before optimization continues.
An explicit `--artifact` only adds context and does not replace the required trio.

## Project Model Pattern

Specification stages load project summaries that match their domain.
`Understand` reads `docs/specs/project/domain.md` summary.
`Constrain` reads `docs/specs/project/constraints.md` summary.
`Design` reads `docs/specs/project/architecture.md` summary.
`Interface` reads `docs/specs/project/interfaces.md` summary.
These reads are additive context, not stage entry contracts.
They are intentionally summary-scoped to keep the cumulative model cheap to inject.

## Ship Entry Pattern

`/swe ship` first resolves an explicit `--artifact` if the user supplied one.
Without it, ship prefers `.swe/active/08-optimize.md`.
If optimize was skipped, ship falls back to `.swe/active/06-implement.md`.
The command picks the newest file by modification time among valid candidates.
If neither file exists, ship aborts because no implementation review target exists.

## Ship Supporting Pattern

Ship later gathers upstream spec and dev artifacts from `.swe/active/` for review context.
Missing review context narrows review scope but does not abort the composite.
Missing dependency manifests only disables dependency audit work.
Missing tests only downgrades evidence quality and does not block review.

## Tune Entry Pattern

`/swe tune` first resolves an explicit `--artifact` if it exists.
Without it, tune searches `.swe/active/` by priority.
The preferred entry is `09-ship.md`.
The first fallback is `08-optimize.md`.
The second fallback is `07-verify.md`.
The newest file by modification time wins within the candidate set.
If no candidate exists, tune warns and continues on codebase state only.

## Spiral Gate Pattern

`/swe spiral` validates handoffs through transition checkpoints instead of simple path lookup.
The Spec to Dev gate checks that Interface Contracts exist.
The Dev to Ship gate checks implementation artifacts and Green state.
The Ship to Tune gate checks the Ship Report and P1 status.
Each gate uses `.swe/active/` as the working state source.
Each gate updates `spiral-state.json` before and after verification.

## Archive And Record Pattern

`/swe tune` archives `.swe/active/` artifacts into `docs/specs/record/{package}/{NNN}-{slug}/` after retrospect.
Tune skips that archive when `spiral-state.json` is present because spiral owns final archival.
`/swe spiral` later reads archived artifact summaries to update the project model.
The merge step is summary-driven rather than full-content-driven.

## Required Versus Optional Failure

Missing required entry artifacts abort when the downstream stage has no safe substitute.
Missing optional supporting artifacts produce warnings and continue.
Unreadable required artifacts usually abort.
Unreadable optional artifacts usually warn and continue.
Malformed required artifacts abort when the stage depends on specific fields or contract structure.
Malformed optional artifacts are dropped from the context set.

## Summary-Only Loading

Summary-only loading is a deliberate Light-depth optimization.
Commands assume every artifact begins with a `## Summary` section.
A short read is enough to recover the summary and metadata header.
Summary-only loading is never used for required artifacts.
Summary-only loading is most common on earlier-stage supporting documents.

## Logging Pattern

Commands log what artifact path was selected.
Commands log how much context was gathered after loading.
Commands log warnings when fallback or degraded context is used.
Commands log when no upstream artifact exists and explain the consequence.
These logs make degraded reasoning visible instead of implicit.

## Validation Checklist

Confirm whether `--artifact` exists before scanning fallbacks.
Confirm whether a fallback path is canonical for that stage.
Confirm whether the artifact is required or optional.
Confirm whether the stage expects full or summary-only loading at the resolved depth.
Confirm whether minimum structural fields are present before relying on the content.
Confirm whether missing context should abort or degrade.

## Related References

Use `artifact-contracts.md` for the canonical file names and producer-consumer chain.
Use `depth-procedure.md` to understand why some supporting artifacts switch between full and summary loading.
Use `composite-checkpoint-rules.md` to understand why artifacts may be passed forward without an intermediate user approval step.
