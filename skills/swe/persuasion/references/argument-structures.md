# Argument Structures — Technical Delivery Frameworks

> **Purpose**: Detailed frameworks for three argument structures (Toulmin, SCQA, Yes Ladder) with SWE-specific examples.
> **Scope**: Structure selection and assembly — complements the persuasion SKILL's workflow Step 4.
> **Parent Skill**: `skills/swe/persuasion/SKILL.md` — core methodology and audience analysis.
> **Standalone**: Yes — can be read independently for argument structure selection.

Three primary argument structures for technical communication. Each is optimized for a different audience and context. Select based on the Audience Analysis and Claim Classification from the SKILL.

## Aristotle's Three Appeals

The foundation underlying all structures. Every technical argument activates these three dimensions:

| Appeal | Definition | Technical Translation |
|--------|-----------|---------------------|
| **Ethos** (credibility) | The audience trusts the speaker | Demonstrated understanding of the codebase, cited data, acknowledged trade-offs, prior track record |
| **Logos** (logic) | The argument follows valid reasoning | Constraint traceability, benchmark data, systematic comparison, formal logic |
| **Pathos** (values) | The audience cares about the outcome | Team velocity impact, user experience, operational burden, professional growth |

In technical contexts, Logos carries the argument, but Ethos opens the door and Pathos sustains engagement. An argument that is logically perfect but delivered by someone who hasn't read the code (no ethos) or doesn't connect to team goals (no pathos) often fails.

## Structure 1: Toulmin Model

Best for: technical audiences, design reviews, Architecture Decision Records (ADRs), code review justifications.

### Six Elements

| Element | Role | SWE Translation |
|---------|------|-----------------|
| **Claim** | The assertion being argued | "We should use PostgreSQL for the order service" |
| **Ground** | Evidence supporting the claim | "Our Constraint Profile C-04 requires ACID durability for financial data" |
| **Warrant** | The principle connecting ground to claim | "PostgreSQL provides ACID compliance by default, satisfying the durability constraint" |
| **Backing** | Support for the warrant itself | "PostgreSQL ACID compliance is verified by our integration test suite and confirmed by industry adoption (AWS RDS, Google Cloud SQL)" |
| **Qualifier** | Conditions limiting the claim | "For datasets under 10GB, where PostgreSQL query performance is well within our p99 latency constraint" |
| **Rebuttal** | Conditions where the claim doesn't hold | "If dataset grows beyond 100GB, a distributed database should be reconsidered" |

### Delivery Pattern

```
CLAIM: We should [recommendation].
GROUND: Because [evidence from constraints/data/codebase].
WARRANT: This works because [principle connecting evidence to recommendation].
BACKING: This principle is supported by [additional evidence/precedent].
QUALIFIER: This applies when [conditions].
REBUTTAL: If [different conditions], then [alternative] would be better.
```

### SWE Example: ADR

```markdown
## ADR-017: Use Circuit Breaker for Payment Gateway

**Claim**: The payment service should implement a circuit breaker pattern for gateway calls.

**Ground**: Production incident INC-2024-003 showed cascading failures when the payment gateway
went down for 12 minutes. 47% of all requests failed during that window because the service
held connections waiting for timeout.

**Warrant**: Circuit breakers detect downstream failures and fail fast, preventing resource
exhaustion and cascade failures. This directly addresses Constraint P-02 (graceful degradation
under partial failure).

**Backing**: The circuit breaker pattern is proven at scale — Netflix Hystrix (now Resilience4j)
handles 10B+ requests daily. Our existing `UserService` already uses this pattern successfully
(see src/services/user/client.ts:142).

**Qualifier**: Effective for synchronous HTTP calls with configurable timeout. Our payment
gateway calls are synchronous with 5s timeout — well within the pattern's design parameters.

**Rebuttal**: If the payment gateway achieves 99.99% uptime SLA (currently 99.9%), the
circuit breaker adds unnecessary complexity. Monitor gateway SLA and revisit.
```

### When to Use

- Code review comments that require justification
- Architecture Decision Records
- Design review presentations
- Any argument where the audience values systematic reasoning

## Structure 2: SCQA (Minto Pyramid)

Best for: stakeholder presentations, executive summaries, proposals, written documents where the reader may not finish.

### Four Elements

| Element | Role | SWE Translation |
|---------|------|-----------------|
| **Situation** | Shared context everyone agrees on | "Our checkout handles 10K orders/day with 99.5% success rate" |
| **Complication** | What changed or went wrong | "Black Friday projections show 50K orders/day — 5x current capacity" |
| **Question** | The decision that must be made | "How do we handle 5x traffic without degrading checkout reliability?" |
| **Answer** | The recommended action | "Implement async order processing with a queue, reducing checkout latency by 80%" |

### Pyramid Principle (Minto)

The key insight: lead with the answer, then support with details. Busy readers get the recommendation in the first paragraph. Those who want depth continue reading.

```
ANSWER (first paragraph): We recommend [action] because [key reason].
SITUATION: Currently, [shared context].
COMPLICATION: However, [problem/change].
QUESTION: This means we need to decide [decision].
SUPPORTING ARGUMENTS:
  1. [Argument group 1 with evidence]
  2. [Argument group 2 with evidence]
  3. [Argument group 3 with evidence]
```

### SWE Example: Technical Proposal

```markdown
## Proposal: Async Order Processing for Black Friday

**Recommendation**: Migrate checkout to async order processing using SQS queues. This
reduces checkout latency from 2.3s to 450ms and supports 100K+ orders/day.

**Situation**: Our checkout flow currently processes orders synchronously — payment,
inventory, and shipping are called in sequence during the user's request. This handles
our current 10K orders/day at 99.5% success rate.

**Complication**: Black Friday projections (based on marketing spend + historical growth)
indicate 50K-70K orders/day. Load testing shows our synchronous flow degrades to 67%
success rate at 30K orders/day due to payment gateway timeout cascades.

**Question**: How do we handle 5-7x traffic without degrading checkout reliability?

**Supporting Arguments**:
1. **Queue-based decoupling**: Payment processing moves to background workers, reducing
   user-facing latency from 2.3s to 450ms (measured in prototype)
2. **Elastic scaling**: Workers auto-scale with queue depth — handles traffic spikes
   without pre-provisioning (AWS SQS + Lambda, cost: ~$200/month at projected volume)
3. **Failure isolation**: Queue provides natural retry — transient payment failures
   don't affect the user experience (retry within 30s, success rate: 99.9%)
```

### When to Use

- Proposals to management or cross-team stakeholders
- RFC documents
- Quarterly planning presentations
- Any context where the audience has limited time and needs the conclusion first

## Structure 3: Yes Ladder

Best for: team discussions, controversial proposals, building consensus gradually, situations where direct proposals would trigger defensive reactions.

### Mechanism

Build agreement through a sequence of progressively larger propositions. Each "yes" creates psychological momentum (Cialdini's Commitment/Consistency principle) — having agreed to the smaller points, the person is inclined to maintain consistency with their prior agreements.

### Five Rungs

| Rung | Type | Purpose |
|------|------|---------|
| 1 | **Value agreement** | Align on what matters |
| 2 | **Situation agreement** | Align on current reality |
| 3 | **Problem agreement** | Align on what's wrong |
| 4 | **Causal agreement** | Align on why it's wrong |
| 5 | **Solution proposal** | Present the specific recommendation |

### Delivery Pattern

```
1. "We both want [shared goal], right?" → Yes
2. "Currently, [factual description of situation]." → Yes, that's accurate
3. "The challenge is [specific problem]." → Yes, that's a problem
4. "This happens because [root cause]." → Yes, I can see that
5. "So if we [specific action], it addresses the root cause." → That makes sense
```

### SWE Example: Proposing a Refactoring

```
1. VALUE: "We want the auth module to be easy for new team members to understand
   and modify safely, right?" → Yes

2. SITUATION: "Right now, authentication logic is spread across 6 files:
   auth-controller, user-service, token-manager, session-store, middleware/auth,
   and utils/crypto. A new developer needs to trace through all 6 to understand
   the login flow." → Yes, that's how it works

3. PROBLEM: "Last sprint, two bugs came from developers modifying auth logic
   in one file without realizing the side effects in another. Both took 2+ days
   to debug because the flow wasn't obvious." → Yes, those were painful

4. CAUSE: "The root issue is that authentication has no single entry point —
   the logic is scattered by technical layer rather than grouped by domain
   concern." → That makes sense

5. SOLUTION: "If we consolidate into an AuthModule with a clear public interface
   — authenticate(), refreshToken(), revokeSession() — new developers see one
   entry point, and modifications are isolated. I've sketched a migration plan
   that takes 3 days and can be done incrementally." → Let's look at it
```

### When to Use

- Team discussions where you anticipate pushback
- Proposing changes to someone else's code
- Building consensus in design meetings
- Any situation where the direct approach ("we should do X") would trigger defensive reactions

## Combining Structures

Structures can be layered for complex arguments:

| Combination | Use Case |
|-------------|----------|
| Yes Ladder → Toulmin | Build agreement first, then provide rigorous justification for the record |
| SCQA → Toulmin | Executive summary (SCQA) followed by technical appendix (Toulmin) |
| Toulmin with pre-suasion | Set context, then deliver structured argument |

The key is matching the primary structure to the audience, with secondary structures providing depth for those who want it.
