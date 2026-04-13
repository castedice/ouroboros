---
name: qmd-gate
description: This reference defines how PA commands classify QMD as required, optional, degraded, or purely observational, and how each command behaves when QMD is unavailable.
---

# QMD Gate — Requirement Versus Degradation Contract

> Purpose: Reference for `context-assembly` and PA command authorship.
> Scope: The QMD checks used by `ask`, `brief`, `link`, `focus`, `survey`, and `heartbeat`.

## Three Gate Classes

- A hard QMD gate means the command aborts when retrieval is unavailable or the collection is not ready.
- A soft QMD gate means the command continues with structural or state-only evidence when retrieval is unavailable.
- An observational QMD gate means the command still runs and reports QMD as one subsystem among several.

## Distinct QMD States

- `registered` means the command has a collection identity it can ask QMD to use.
- `unregistered` means the collection does not exist yet even though PA state may otherwise be healthy.
- `unavailable` means the status check or backend access failed at runtime.
- `degraded-cli` means MCP is unavailable but the CLI path still works.
- `pending` means onboarding completed without a fully healthy registration or indexing pass.
- `stale` means QMD exists but freshness is poor enough to surface as a health finding.

## Hard Gate Commands

- `ask` is retrieval-native, so QMD registration and `mcp__qmd__status` are hard Phase 2 requirements.
- `ask` aborts when the collection is not registered and tells the user to run `/pa survey`.
- `ask` aborts when `mcp__qmd__status` fails and tells the user QMD is unavailable.
- `ask` does not fall back to filesystem scans or model knowledge for missing vault evidence.
- `brief` uses the same hard gate because its entire product is a QMD-backed dossier.
- `brief` aborts on unregistered or unavailable QMD for the same reason as `ask`.
- `brief` also refuses to replace missing retrieval with generic synthesis.

## Soft Gate Commands

- `link` treats QMD as semantic reinforcement rather than as the core engine.
- `link` warns when QMD is unavailable and continues with structural analysis only.
- `link` can still use note content, wikilinks, frontmatter, entities, relations, and dirty-path context without QMD.
- `link` also falls back to structural-only analysis when the weaver reports a QMD failure mid-run.
- `focus` treats QMD as the content-retrieval side of a mixed librarian-plus-weaver dossier.
- `focus` warns when QMD is unavailable and continues with structural analysis only.
- `focus` can render a dossier from graph analysis alone when the librarian fails.
- `focus` can also do QMD-only retrieval when graph seeding fails, so the gate is asymmetric rather than all-or-nothing.

## Onboarding Gate

- `survey` treats QMD as a capability requirement for PA onboarding rather than as an optional enhancement.
- `survey` aborts in Phase 2 when QMD is not found at all.
- `survey` accepts a degraded path when QMD MCP is missing but the CLI path still works.
- `survey` records that degraded path as `qmd_mode = "cli"` instead of pretending MCP is healthy.
- `survey` still continues when Phase 6 registration or indexing fails after the user confirmed the profile.
- `survey` writes `.pa/` state even when Phase 6 failed, and it records the degraded outcome as `qmd_status = "pending"` or equivalent report text.
- `survey` skips re-registration in refresh mode when state already says QMD is registered.

## Observational Gate

- `heartbeat` does not call `mcp__qmd__status` directly as a startup blocker.
- `heartbeat` passes QMD evaluation to `scripts/pa-heartbeat.sh`.
- `heartbeat` reports QMD as one of the seven backend health checks.
- `heartbeat` still completes when QMD is warning or error severity, unless the backend itself failed before producing output.
- `heartbeat` never repairs QMD inline and only reports follow-up actions such as `qmd update && qmd embed`.

## Shared Decision Pattern

- Commands that depend on citations or semantic recall treat QMD as a hard prerequisite.
- Commands whose core value is graph or structure analysis treat QMD as optional reinforcement.
- Onboarding commands treat QMD as a capability gate up front and a degradable registration step later.
- Health commands treat QMD as something to observe rather than something that must be perfect before the command can run.

## What Counts As Degradation

- Falling back from MCP to CLI is a degraded but valid path in `survey`.
- Skipping semantic retrieval and continuing with structural analysis is a degraded but valid path in `link` and `focus`.
- Reporting a QMD warning or error inside the heartbeat table is degraded visibility rather than command failure.
- Falling back from `retrieval-profiles.json` to `vault-profile.json -> qmd_defaults` is not a QMD degradation and should not be reported as one.

## What Does Not Count As Degradation

- `ask` and `brief` do not have a structural-only fallback mode.
- A missing collection registration in `ask` or `brief` is an abort, not a graceful fallback.
- A failed QMD status check in `ask` or `brief` is an abort, not a low-confidence answer path.
- A stale QMD index in heartbeat is a reported subsystem problem, not a reason to hide the rest of the heartbeat result.

## Command Summary

- `ask` requires registered and reachable QMD before retrieval starts.
- `brief` requires registered and reachable QMD before retrieval starts.
- `link` prefers QMD but continues without it.
- `focus` prefers QMD but can render from graph-only evidence.
- `survey` requires some QMD runtime to exist, but it can finish onboarding with degraded registration or indexing outcomes.
- `heartbeat` always runs the health backend and lets the backend classify QMD freshness.

## Authoring Rules

- Use a hard gate when the command would otherwise fabricate citations or pretend to know vault content.
- Use a soft gate when the command still has a meaningful non-QMD evidence path.
- Use an observational gate when the command's job is to diagnose QMD rather than to depend on it.
- Preserve the exact gate class in the decision matrix instead of mixing aborts and warnings loosely.

## Reporting Rules

- Hard-gate failures should tell the user exactly which setup step to rerun.
- Soft-gate degradations should say what evidence path remains available.
- Onboarding degradations should record the state as pending or degraded instead of claiming full health.
- Heartbeat degradations should preserve backend severity and recommended actions verbatim.

## Practical Checklist

- Abort `ask` and `brief` when QMD is unregistered or unavailable.
- Warn and continue in `link` and `focus` when QMD is unavailable.
- Allow `survey` to continue in CLI mode when MCP is missing but QMD still exists.
- Allow `survey` to finish `.pa/` initialization even when registration or indexing later fails.
- Let `heartbeat` report QMD as one health row instead of turning QMD drift into an upfront startup gate.
