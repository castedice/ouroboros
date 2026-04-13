# Evolution Planning and Retry Rules

## Improvement Priority

Select improvement targets in descending score impact.
This keeps the cycle focused on the highest-leverage work first.
It also prevents polish work from crowding out score-critical repair.
It also makes it easier to explain and defend the scope to the user before editing begins.

| Priority | Target | Why It Comes First |
|----------|--------|--------------------|
| 1 | 0-score criteria | They directly block score recovery and often indicate structural gaps |
| 2 | HIGH improvements | They can change the verdict or unlock a blocked criterion |
| 3 | MED improvements | They improve quality after the score-critical work is handled |
| 4 | LOW improvements | They are optional polish once the important work is stable |

### How Much to Do in One Cycle

| Scope | Recommended Batch |
|-------|-------------------|
| Single component | All 0-score criteria plus HIGH improvements |
| Module-wide evolution | The weakest component only |

Single-component work has a bounded blast radius.
Module-wide work should stay narrow because cross-component edits multiply the chance of accidental regression.

### Priority Example

If a skill has three 0-score criteria and one HIGH improvement, handle all four in the same single-component cycle.
If the same situation appears during a module scan, evolve only the weakest component first and re-scan later.

## Evolution Modes

| Mode | Target | Scope | Use When | Output |
|------|--------|-------|----------|--------|
| Mode A | File path | One component | You know exactly what needs work | Evolved file plus decision entry |
| Mode B | Module name | Weakest component in the module | You need quality uplift but not a specific target yet | Scan report plus evolved weakest component |

Mode A is the default.
Mode B should narrow aggressively after the scan rather than trying to improve multiple files at once.
After a successful Mode B cycle, re-run the scan rather than assuming the next target in advance.

## Retry Policy

When a cycle ends in `degraded`, analyze the failure before touching the file again.

1. Explain why the after version scored lower or regressed.
2. Roll back to the preserved before snapshot.
3. Choose a different strategy instead of repeating the same move.
4. Stop after the second consecutive failure and ask the user for direction.
Repeated failure is evidence that the diagnosis or objective needs revision, not just more effort.
Do not keep retrying to prove persistence when the evidence says the approach is wrong.

### What Counts as a Different Strategy

| First Attempt | Different Second Attempt |
|---------------|--------------------------|
| Added more prose and hurt clarity | Restructure the file and move detail into references |
| Reorganized sections and broke links | Make targeted edits without structural movement |
| Optimized for one criterion and hurt another | Re-balance around the regressed criterion first |

### Component-Specific Retry Heuristics

| Component Type | Heuristic |
|----------------|-----------|
| Skill | If the file bloats, move detail into `references/` instead of adding more inline prose |
| Agent | If the prompt loses focus, prefer concrete examples over more abstract instruction |
| Command | If branch logic gets noisy, extract stable rules into references instead of expanding the phase body |

## Cycle Completion Checklist

- [ ] Baseline evaluation exists and includes per-criterion results.
- [ ] Root cause analysis is complete before planning begins.
- [ ] The plan lists both intended changes and preserved scope.
- [ ] User approval exists before any apply step.
- [ ] A before snapshot was preserved before editing.
- [ ] Every edit traces to a specific plan item.
- [ ] Before and after validation ran with criterion-level comparison.
- [ ] The quality gate verdict is explicit.
- [ ] The decision entry records what changed and why.
