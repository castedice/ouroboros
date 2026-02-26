# Conflict Resolution Patterns — Cross-Constraint Tension Analysis

Systematic approaches for resolving tensions between constraint categories. When two constraints pull design in opposite directions, use these patterns to reach a principled resolution rather than ad-hoc compromise.

This reference is self-contained — it can be consulted independently of the parent SKILL.md. For the constraint enumeration procedure that feeds into conflict analysis, see the parent skill at `skills/swe/constraint/SKILL.md`.

---

## When to Use

Conflict resolution applies during Step 3 (Identify Conflicts) of the Constraint Enumeration Procedure. After sweeping all 6 categories and classifying each constraint, compare constraints pairwise for tensions. This reference provides the resolution framework.

## Resolution Decision Framework

When two constraints conflict, apply this decision sequence:

### Step 1: Check Rigidity

| Constraint A | Constraint B | Resolution |
|-------------|-------------|------------|
| Hard | Soft | Hard wins — Soft constraint yields |
| Hard | Hard | Escalate to stakeholder for priority decision |
| Soft | Soft | Choose the one with higher design impact |
| Assumption | Any | Validate the Assumption first — resolve after evidence |

Hard-Hard conflicts are the most dangerous — they indicate either a requirements problem or a scope problem. Never resolve Hard-Hard conflicts by silently downgrading one to Soft.

### Step 2: Apply Resolution Strategy

Five resolution strategies, ordered by preference:

| # | Strategy | When to Use | Example |
|---|----------|-------------|---------|
| 1 | **Decompose** | Constraints apply to different subsystems | "Fast API (Performance) uses caching; Batch jobs (Scope) skip caching" |
| 2 | **Phase** | Constraints apply at different times | "99.9% at launch (Scope); 99.99% in Q2 (Operations)" |
| 3 | **Tier** | Constraints apply at different service levels | "Premium users get <100ms (Performance); Free users get <500ms (Business)" |
| 4 | **Trade** | One constraint explicitly yields with documented rationale | "Accept 200ms instead of 100ms to stay within budget (Performance yields to Business)" |
| 5 | **Escalate** | Team cannot resolve — needs stakeholder decision | "Hard Performance vs Hard Business — CPO must decide priority" |

### Step 3: Document the Resolution

For each resolved conflict, record:

```text
Conflict: {Category A constraint} vs {Category B constraint}
Strategy: {Decompose|Phase|Tier|Trade|Escalate}
Resolution: {specific decision made}
Yields: {which constraint was relaxed and by how much}
Owner: {who approved this resolution}
Risk: {what could go wrong if the resolution is incorrect}
```

## Common Conflict Pairs

Six recurring conflict patterns across the constraint categories:

### 1. Performance vs Business (Speed vs Cost)

**Tension**: Faster infrastructure costs more. Low latency requires caching layers, CDNs, premium database tiers.

**Resolution patterns**:
- **Tier**: Hot path (user-facing) gets premium infrastructure; cold path (batch, analytics) uses commodity resources
- **Phase**: Launch with adequate performance; optimize after profiling identifies actual bottlenecks (avoid premature optimization spending)
- **Trade**: Accept P95 ≤ 500ms instead of ≤ 100ms to stay within $500/month budget

### 2. Technology vs Team (Best Tool vs Capability)

**Tension**: The technically optimal tool requires skills the team doesn't have. Learning time conflicts with delivery timeline.

**Resolution patterns**:
- **Phase**: Use known technology for Phase 1; plan technology migration for Phase 2 with upskilling budget
- **Trade**: Accept a 20% performance penalty from Python over Rust to eliminate 4-week learning curve
- **Decompose**: Use the optimal tool only for the critical subsystem (e.g., Rust for the hot loop, Python for everything else)

### 3. Operations vs Scope (Reliability vs Speed)

**Tension**: High reliability requires monitoring, alerting, runbooks, blue-green deploys — all of which take time to build.

**Resolution patterns**:
- **Phase**: 99.9% at launch with basic monitoring; 99.99% in Q2 with full observability stack
- **Tier**: Core API gets full reliability treatment; internal tools get best-effort
- **Trade**: Skip canary deployment for initial launch, accept higher rollback risk

### 4. Business vs Scope (Compliance vs Deadline)

**Tension**: Compliance requirements (GDPR, SOC2, HIPAA) add scope that conflicts with delivery timeline.

**Resolution patterns**:
- **Hard rule**: Compliance constraints are always Hard and never yield to Scope. If the deadline cannot accommodate compliance, the deadline moves.
- **Decompose**: Deliver non-regulated features first; add compliance features before regulated data enters the system
- **Phase**: Launch with compliance for the minimum required data; extend coverage as more data types are added

### 5. Scope vs Team (Feature Volume vs Capacity)

**Tension**: More features requested than the team can deliver within the timeline.

**Resolution patterns**:
- **Trade**: Reduce feature count — use MoSCoW prioritization (Must/Should/Could/Won't) to cut scope
- **Phase**: Must-have features in Phase 1, Should-have in Phase 2
- **Decompose**: Assign features to different team members or squads based on expertise

### 6. Performance vs Operations (Speed vs Observability)

**Tension**: Monitoring, logging, and tracing add latency overhead. Detailed observability conflicts with performance targets.

**Resolution patterns**:
- **Tier**: Full tracing in staging/debug; sampled tracing (1-10%) in production
- **Trade**: Accept 5-10ms additional latency from structured logging; reject if it exceeds P95 budget
- **Decompose**: Async log shipping — write to local buffer, ship to observability backend asynchronously

## Escalation Protocol

When the team cannot resolve a constraint conflict:

1. **Document** both constraints with their rigidity classifications and the specific tension
2. **Propose** 2-3 resolution options with trade-off analysis for each
3. **Identify** the stakeholder who owns the priority decision (typically the constraint owner with higher organizational authority)
4. **Present** options with clear consequences: "If we choose A, we lose X. If we choose B, we lose Y."
5. **Record** the stakeholder's decision as a new Hard constraint with the stakeholder as owner

Never resolve an escalation by silently choosing one option — the decision must be explicit and recorded.

## Conflict Documentation Template

```text
| Conflict ID | Category A | Category B | Strategy | Resolution | Owner |
|-------------|-----------|-----------|----------|------------|-------|
| C-001 | Performance: P95 < 200ms | Business: < $500/month | Tier | Premium for API, commodity for batch | Platform lead |
| C-002 | Technology: Use Rust | Team: Python-only | Phase | Python now, Rust migration Q3 | Tech lead |
```

## See Also

- **swe-constraint-methodology** (`skills/swe/constraint/SKILL.md`) — Parent skill; conflict analysis is Step 3 of the enumeration procedure
- **constraint-categories** (`references/constraint-categories.md`) — Cross-Category Conflict Patterns table for common tension pairs
