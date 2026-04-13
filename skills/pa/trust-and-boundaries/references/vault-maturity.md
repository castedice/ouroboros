---
name: vault-maturity
description: This reference defines vault maturity stages for progressive command onboarding. It should be consulted when a command needs to "check vault maturity", "show onboarding guidance", "determine available commands for the current vault state", "compute vault stage from note count and state completeness", "suppress maturity warnings", or "map command to required maturity stage".
---

# Vault Maturity — Progressive Command Onboarding

> Purpose: Reference for `trust-and-boundaries` — defines maturity stages that guide which PA commands are most useful at each vault growth phase.
> Guidance is advisory, not blocking.
> Users can always run any command explicitly.

## Maturity Stages

| Stage | Criteria | Available Commands | Gated Commands |
|-------|----------|-------------------|----------------|
| `starter` | init/survey complete, <10 notes | ask, brief, capture, draft, link, specialist, heartbeat | agenda, day, focus, compile, ingest, review, reset, steward |
| `intermediate` | 10+ notes AND work.jsonl has 3+ items | + agenda, day, focus, ingest | compile, review, reset, steward |
| `advanced` | 30+ notes AND review-state.json has 2+ checkpoints | + compile, review, reset | steward |
| `expert` | 50+ notes AND 3+ months ledger history | All commands | None |

## Stage Computation

Compute on-the-fly in each command's Phase 2.
Do not pre-store the stage.

1. Count vault markdown files (exclude `.pa/`, `.obsidian/`, `.trash/`, `.git/`, `Templates/`).
2. Count lines in `.pa/work.jsonl` (0 if missing).
3. Count checkpoints in `.pa/review-state.json` (0 if missing).
4. Check oldest `ts` in `.pa/assistant-ledger.jsonl` vs current date (0 months if missing).
5. Resolve stage from highest matching criteria.

## Maturity Check Pattern

Each gated command adds this check at the start of Phase 2:

1. Compute current vault maturity stage.
2. If the command requires a higher stage, present guidance:
   "이 명령은 {required_stage} 단계부터 유용합니다. 현재: {current_stage} ({missing_criterion}). 먼저 {suggested_command}를 사용해보세요."
3. Do NOT abort.
Continue if the user proceeds.
4. If `settings.json` has `show_all_commands: true`, skip the check entirely.

## Suppressibility

Users can disable maturity guidance:
- Set `show_all_commands: true` in `.pa/settings.json`
- Or say "전부 보여줘" to the PA router

## Threshold Rationale

| Threshold | Why |
|-----------|-----|
| 10 notes for intermediate | Below this, work.jsonl extraction has too few sources for meaningful prioritization |
| 3 work items for intermediate | Agenda needs at least a few commitments to produce useful output |
| 30 notes for advanced | Review and compile need sufficient note history to detect patterns and synthesize |
| 2 review checkpoints for advanced | Without prior reviews, review delta comparison is meaningless |
| 50 notes + 3 months for expert | Steward's meta-composite judgment benefits from long-term usage patterns |

## Common Pitfalls

| Pitfall | Why It Fails | Prevention |
|---------|-------------|------------|
| Hard-blocking commands based on stage | Frustrates users who know what they want | Always advisory, never blocking |
| Computing stage from stale file counts | `.pa/` state may not reflect recent vault changes | Compute on-the-fly from live filesystem |
| Showing guidance on every invocation | Becomes noise after the first time | Consider session-level memoization |
| Ignoring `show_all_commands` flag | Power users set it for a reason | Check flag before any guidance |

## Validation Checklist

- [ ] Stage computed from live filesystem, not cached state.
- [ ] Excluded paths (.pa/, .obsidian/, .trash/, .git/, Templates/) filtered from note count.
- [ ] `show_all_commands` flag checked before presenting guidance.
- [ ] Guidance message includes current stage, required stage, and suggested alternative.
- [ ] Command continues execution after guidance — never aborts.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/trust-and-boundaries/SKILL.md` | Parent skill — trust boundaries |
| `commands/pa/README.md` | Command listing with stage annotations |
