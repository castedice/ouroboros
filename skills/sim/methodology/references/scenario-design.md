# Scenario Design Guide

> Reference for the sim-methodology skill. Covers scenario structure, persona design patterns, event queue construction, and information asymmetry modeling.

## Scenario Structure

A simulation scenario defines the initial conditions, participants, rules, and external stimuli for a bounded multi-agent run.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Human-readable scenario title |
| `description` | yes | One-paragraph purpose statement |
| `ticks` | yes | Number of simulation steps (default max 20) |
| `personas` | yes | Array of 2-8 persona objects |
| `shared_state` | yes | Initial world state visible to all agents |
| `events` | yes | Scheduled external stimuli with tick, type, content, and visibility |
| `rules` | yes | Behavioral constraints and state-delta policies |

## Persona Design

Each persona represents one agent's identity, knowledge, and constraints.

### Required Fields

| Field | Type | Purpose |
|-------|------|---------|
| `id` | string | Unique, filename-safe identifier |
| `name` | string | Human-readable persona label |
| `traits` | object | Behavioral characteristics (risk tolerance, strategy, personality) |
| `private_info` | string | Information only this agent sees — the core of information asymmetry |
| `goals` | array | What the agent is trying to achieve |
| `constraints` | array | Behavioral rules the agent must follow |
| `initial_resources` | object | Starting resources (optional, scenario-dependent) |

### Trait Design Patterns

| Pattern | When to Use | Example |
|---------|-------------|---------|
| Risk profile | Financial or decision-under-uncertainty scenarios | `risk_tolerance: low/medium/high` |
| Big Five traits | Social interaction or group dynamics scenarios | `openness: 0.7, conscientiousness: 0.4` |
| Role-based | Organizational or market structure scenarios | `role: buyer/seller/regulator` |
| Knowledge level | Information asymmetry scenarios | `expertise: novice/intermediate/expert` |

Keep traits minimal — 2-4 key dimensions. Over-specified personas produce rigid, predictable behavior that defeats the simulation purpose.

## Event Queue Design

Events inject external stimuli at specific ticks to create dynamic scenarios.

### Event Fields

| Field | Type | Purpose |
|-------|------|---------|
| `tick` | integer | When the event fires |
| `type` | string | Event category (news, insider, policy, market, social) |
| `content` | string | What happened — written as natural language the agent can interpret |
| `visibility` | `"all"` or `[id, ...]` | Who sees this event — `"all"` for public, array for private |

### Timing Patterns

| Pattern | Example | Effect |
|---------|---------|--------|
| Early shock | Tick 2 of 10 | Forces early adaptation, reveals risk tolerance |
| Mid-game shift | Tick 5 of 10 | Tests strategy flexibility under established positions |
| Late reveal | Tick 8 of 10 | Tests end-game behavior under new information |
| Asymmetric timing | Tick 3 (agent-1 only), Tick 5 (all) | Models information delay and advantage |

### Information Asymmetry Levels

| Level | Implementation | Use When |
|-------|---------------|----------|
| None | All events have `visibility: "all"` | Baseline comparison, equal-information scenarios |
| Partial | Some events visible to subset of agents | Market scenarios, organizational dynamics |
| Full | Most events are agent-specific | Intelligence analysis, negotiation, competitive strategy |

## Shared State Design

`shared_state` represents the world that all agents observe. Design it to be:

1. **Observable** — agents read it but the script owns mutations
2. **Meaningful** — each field should influence at least one agent's decisions
3. **Bounded** — keep to 5-10 top-level fields to prevent observation packet bloat

### State Delta Policy

The `rules.state_delta_policy` field controls whether agent-proposed changes affect shared state:

| Policy | Behavior |
|--------|----------|
| `ignore` (default) | Agent deltas are recorded but never applied to shared state |
| `append-only` | Agent deltas are appended to a history log in `_sim` metadata |
| `merge` | Agent deltas are merged into shared state by the script (use with caution) |

## Anti-Patterns

| Anti-Pattern | Why It Fails | Fix |
|--------------|-------------|-----|
| Too many traits per persona | Agents produce formulaic behavior matching every trait | Use 2-4 key dimensions only |
| Events at every tick | No breathing room for autonomous decisions | Space events with 2-3 tick gaps |
| Symmetric personas | Identical agents produce identical behavior | Differentiate on at least 2 dimensions |
| Missing private_info | No information asymmetry to study | Give each agent at least one private fact |
| Unbounded shared state | Observation packets exceed context limits | Cap shared state fields at 5-10 |
