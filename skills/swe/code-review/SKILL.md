---
name: swe-code-review
description: This skill codifies security review and four-perspective code review methodology for shipping code, and it should be activated when an agent needs to "perform 4-perspective code review", "run a security review", "audit dependencies for known vulnerabilities", "check for exposed secrets", "check license compliance", "classify review findings as P1/P2/P3", or "write actionable fix guidance for review findings".
summary: Performs evidence-backed security and code reviews with calibrated severity, missing-context disclosure, and concrete remediation guidance.
version: 1
tags: [swe, code-review, security, findings, remediation]
preamble_tier: 3
---

# Code Review

## Core Rule

**"Treat review findings as evidence-backed ship gates, not opinions."**
Security Review and Code Review are distinct procedures that may run independently or together.
Security Review audits dependencies, secrets, and license risk.
Code Review inspects Architecture, Safety, Performance, and Readability with upstream artifacts as review bounds.
Match thoroughness to the requested depth, with Light focusing on critical blockers and deeper passes adding broader coverage and compliance checks.
Every finding must name a concrete location, calibrated severity, observed evidence, impact, and fix guidance.
If the artifacts do not support a strong claim, reduce severity or confidence instead of inventing certainty.
Review is diagnostic and read-only, and the caller or implementer owns the fix.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Inflating too many findings to `P1` | Severity | Reserve `P1` for ship blockers with concrete exploit, correctness, data loss, or hard-contract evidence |
| Reporting architecture violations without an Architecture Spec | Scope | Cap architecture-only findings at `P2` when no authoritative structural expectation exists |
| Treating speculative slow code as a performance defect | Performance | Tie every performance claim to a real control path, data scale, or constraint boundary |
| Scanning only source code and skipping dependency manifests | Security | Always inspect manifests and lock files before concluding the dependency surface is clean |
| Flagging secret risk without checking environment or ignore hygiene | Security | Review `.gitignore`, config files, and environment variable usage alongside secret-like literals |
| Flagging license issues without project-context reasoning | Security | Distinguish unknown, copyleft, and clearly compatible licenses, and explain the compatibility risk |
| Writing findings without concrete remediation | Output | State the exact code, config, or version change that would resolve the issue |
| Letting missing artifacts silently narrow coverage | Scope | List missing inputs explicitly so downstream consumers understand the review ceiling |

### Rationalization Red Flags

Treat these as review-integrity anti-drift checks before publishing findings or changing severity.

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "I would block this in my repo, so it is a `P1`" | Promoting taste, preference, or weak evidence to ship-blocker severity | Tie `P1` to exploitability, correctness, data loss, hard contracts, or reduce severity |
| "The diff looks safe, so manifests do not matter" | Concluding security review without inspecting dependency manifests and lock files | Audit the dependency surface or disclose the missing coverage explicitly |
| "The Architecture Spec is missing, but this pattern is obviously wrong" | Reporting a preference as an authoritative architecture violation | Cite a real boundary violation and cap architecture-only findings by the available artifacts |
| "This might be slow at scale, so it is a performance defect" | Flagging speculative performance risk without a hot path, data scale, or constraint | Connect the claim to evidence or downgrade it to uncertainty or `P3` guidance |
| "The remediation is obvious from the finding" | Omitting exact fix guidance from an otherwise valid finding | State the concrete code, config, dependency, or license action that resolves the issue |

## Workflow

### 1. Bound The Review Before Judging

Identify whether the caller wants Security Review, Code Review, or both.
Collect the source paths, dependency manifests, and upstream artifacts that actually exist.
Use the Architecture Spec to judge structural intent, the Constraint Profile to judge performance boundaries, the Interface Contracts to judge consumer breakage, and the Verification Report to judge known deviations.
When inputs are partial, record the missing artifacts before producing findings.
Load `${CLAUDE_SKILL_DIR}/references/security-checklist.md` for the security pass and `${CLAUDE_SKILL_DIR}/references/perspective-playbook.md` for detailed perspective questions.

### 2. Run The Security Review Procedure

Audit dependency manifests and lock files first.
Use available audit tools when they exist, and fall back to version and manifest inspection when they do not.
Scan for exposed credentials, tokens, private keys, passwords, connection strings, and unsafe secret-handling patterns in source and config.
Check that secrets come from environment variables or secret stores rather than committed literals.
At Standard depth or above, inspect license declarations and flag missing, unknown, or incompatible licenses.
When the caller expects a broader security pass, add targeted code-level checks for injection, path traversal, insecure deserialization, and related OWASP-style risks, but keep dependency audit, secret detection, and license compliance as the required baseline.

### 3. Run The Four-Perspective Code Review Procedure

Review Architecture for boundary violations, dependency direction mistakes, inconsistent pattern application, dead paths, and misplaced responsibilities.
Review Safety for missing validation, swallowed errors, panic or undefined-behavior risk, side-effect leakage, and contract-breaking behavior.
Review Performance for inappropriate algorithmic complexity, unnecessary allocations or copies, unbatched I/O, hot-path pessimization, and blocking work in async flows.
Review Readability for unclear intent, weak naming, unnecessary abstraction, avoidable cognitive load, and navigability issues for future maintainers.
Anchor Architecture judgments to the Architecture Spec, Performance judgments to the Constraint Profile, and contract breakage to the Interface Contracts when available.
Use `${CLAUDE_SKILL_DIR}/references/perspective-playbook.md` when a perspective needs the fuller checklist or evidence standard.

### 4. Calibrate Severity And Handle Ambiguity

Classify findings with the `P1` to `P3` ladder from `${CLAUDE_SKILL_DIR}/references/finding-format.md`.
Use `P1` for must-fix ship blockers such as exploitable security flaws, correctness bugs, data loss risk, hard constraint violations, or consumer-breaking contract failures.
Use `P2` for important but non-blocking issues such as moderate CVEs, reliability gaps, soft constraint breaches, or significant maintainability problems.
Use `P3` for optional improvements such as minor style cleanup, speculative optimizations without evidence, or documentation gaps.
If the Architecture Spec is missing, keep architecture-only findings at `P2` maximum.
If the Constraint Profile is missing, limit performance findings to obvious antipatterns and keep them at `P3`.
If the Verification Report documents an intentional deviation, acknowledge it and downgrade the finding unless there is new evidence of real harm.

### 5. Write Findings That Teach The Fix

Use the exact security and code-review templates from `${CLAUDE_SKILL_DIR}/references/finding-format.md`.
Give every finding a stable category prefix, a precise location, the observed evidence, the real consequence, and a concrete remediation or suggestion.
Fix guidance should say what to change, not just what is wrong.
Summary tables are useful for category and severity rollups, but they never replace individual evidence-backed findings.
If evidence is insufficient for a finding, record the uncertainty or missing input instead of stretching the claim.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Review type | Run Security Review for dependency, secret, and license risk, Code Review for structural and code-quality risk, and both when the caller needs ship readiness |
| Depth | Light should prioritize critical blockers and obvious risks, while Standard and Deep should widen coverage and include license or broader security checks as requested |
| Evidence sufficiency | No evidence means no finding, and weak evidence means lower severity or an explicit uncertainty note |
| Severity bar | `P1` blocks shipment, `P2` should usually be fixed before ship, and `P3` is optional unless the caller is doing a polish pass |
| Security baseline | Dependency audit, secret detection, and license compliance are the minimum security pass, even when code-level security checks are limited |
| Architecture scope | Architecture findings must cite a real boundary or dependency violation and should defer to the Architecture Spec when one exists |
| Performance scope | Performance findings must connect to a real hot path, data scale, or stated constraint rather than intuition |
| Output bar | Every finding must include what was found, why it matters, and how to fix it |
| Missing context | Missing Architecture Spec, Constraint Profile, or Verification Report narrows severity and should be disclosed explicitly |

## Reference Map

| Need | Reference |
|------|-----------|
| Detailed questions and evidence rules for Architecture, Safety, Performance, and Readability | `${CLAUDE_SKILL_DIR}/references/perspective-playbook.md` |
| Dependency audit, secret detection, license compliance, and optional code-level security checks | `${CLAUDE_SKILL_DIR}/references/security-checklist.md` |
| Severity ladder, finding IDs, templates, and fix-guidance standards | `${CLAUDE_SKILL_DIR}/references/finding-format.md` |

## See Also

- `agents/swe/reviewer.md` — Current inline source for the Security Review and Code Review procedures.
- `commands/swe/ship.md` — Current consumer that orchestrates Security Review and Code Review as ship gates.
- `skills/swe/methodology/SKILL.md` — Supplies pipeline depth, artifact-chain expectations, and agent invocation context.
- `skills/swe/methodology/references/swe-relay-prompts.md` — Mirrors the same review procedures for external-model relay prompts.
- `skills/swe/persuasion/SKILL.md` — Helps turn technically correct findings into clear, defensible review language.
