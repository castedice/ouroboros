# Team Execution Pattern — Reference Hub

Index for the split team execution references.

| Reference | Contains |
|-----------|----------|
| `team-specialists.md` | Team topology, spawn protocol, specialist prompts, stage-level execution, and probe flow |
| `team-routing-and-direct-relay.md` | Stage routing, routing mode semantics, direct relay protocol, shared team paths, and generator-critic loop |
| `team-flow-and-cross-review.md` | Pipelined phase flow, auto-gates, relay checkpoint, cross-review, backtracking, Tune, shutdown, and recovery |

Use this hub when a caller only knows the legacy `team-execution-pattern.md` path.
Open the child reference that matches the execution concern you need.

## Routing Mode Field

When team routing is active, record a route-plan field `mode` before Phase 2.7.
- `direct` is the default and routes the selected stage through specialist direct relay.
- `bridge` is the legacy mode label retained only for migration history and deprecated comparison notes.
- `dual` is the soak label for side-by-side comparison of direct relay against archived bridge behavior.

Switch modes by changing the route-plan field before team setup begins.
After bridge removal, new runs should use `mode: direct`.
