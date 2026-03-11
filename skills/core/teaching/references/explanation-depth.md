# Explanation Depth — Four-Level Selection Matrix and Decision Bridging

> **Purpose**: Detailed depth selection criteria and Decision Bridge patterns for the teaching SKILL's Steps 5-6.
> **Scope**: Four depth levels (Analogy → Principle → Detail → Example) with entry conditions and concrete examples.
> **Parent Skill**: `skills/core/teaching/SKILL.md` — core methodology and workflow.
> **Standalone**: Yes — can be read independently for depth selection and bridging.

Detailed reference for the teaching SKILL's depth selection (Step 5) and decision bridge (Step 6). Includes entry conditions, techniques, and concrete examples for each depth level.

## The Four Depth Levels

Teaching depth follows a progressive ladder. Start at the shallowest level that enables the decision. Only deepen when the learner signals a need or the decision genuinely requires more depth.

### Level a: Analogy (Shallowest)

**Purpose**: Orient the learner by connecting the unknown to the known.

**Techniques**:

- **Schema anchoring** (Schema Theory): "X is like Y but with [key difference]"
- **Feynman simplification**: Explain as if to someone with no domain-specific knowledge — use everyday language
- **Near transfer bridge**: "You've solved this type of problem before — remember when you [similar situation]?"

**Entry conditions** — use Analogy when:

- Learner has never encountered the concept
- The concept has a strong parallel to something the learner knows
- The decision is binary (use/don't use, A/B) and the analogy captures the essential difference
- Cognitive load is high (deadline pressure, context-switching)

**Exit to next level** when:

- Learner asks "why does this work?" or "what's the underlying mechanism?"
- The analogy breaks down at a decision-critical point
- The decision requires comparing multiple dimensions (analogy usually captures only one)

**SWE example — Explaining circuit breakers to someone who knows retry logic**:

> "A circuit breaker is like retry logic, but instead of retrying immediately when a service fails, it says 'that service has been failing a lot — stop trying for 30 seconds and return an error immediately.' It prevents your service from piling up connections to something that's down."
>
> Decision bridge: "For your payment gateway integration, the question is: do you want to keep retrying (which works if failures are brief and rare) or add a circuit breaker (which protects you if the gateway goes down for minutes)? Given that the gateway had a 12-minute outage last month, the circuit breaker prevents the cascading failure we saw."

**Core example — Explaining eventual consistency during onboarding**:

> "Think of it like a group chat. When you send a message, not everyone sees it at the exact same moment — some people's phones update faster. But within a few seconds, everyone has the same messages. That's eventual consistency — different parts of the system might briefly see different data, but they converge."
>
> Decision bridge: "For the notification system, the question is: does it matter if two servers show slightly different notification counts for a second? If not, eventual consistency is fine and much simpler. If users compare screens and discrepancies cause confusion, we need strong consistency."

### Level b: Principle (Moderate)

**Purpose**: Provide the core rule(s) that govern the concept — the "why" behind the behavior.

**Techniques**:

- **Feynman method**: State the principle in one sentence using simple language
- **Dual coding**: Combine verbal principle with a simple diagram or equation
- **Elaborative interrogation**: After stating the principle, ask "why does this matter for your case?"

**Entry conditions** — use Principle when:

- Learner understands what the concept is but not why it works
- The decision requires understanding a trade-off mechanism (not just that it exists)
- The analogy level left a critical "how?" unanswered

**Exit to next level** when:

- Learner asks "how exactly does this work?" or "can you show me?"
- The principle alone doesn't differentiate the options for the specific decision
- Implementation details affect the decision (e.g., performance characteristics)

**SWE example — Explaining CAP theorem for a database decision**:

> "The core principle: in a distributed system, when a network partition happens, you must choose between consistency (every read gets the latest write) and availability (every request gets a response). You can't have both during the partition."
>
> "This matters for your decision because your payment service needs consistency (can't show different balances to different servers), while your product catalog can tolerate brief staleness for higher availability."
>
> Decision bridge: "Payment database: choose consistency (PostgreSQL with synchronous replication). Catalog: choose availability (Redis with async replication). Does this split make sense for your other services?"

**Core example — Explaining idempotency for API design**:

> "The principle: an idempotent operation produces the same result whether you run it once or ten times. PUT is idempotent (setting a value to 5 ten times still gives 5). POST is not (creating an order ten times gives ten orders)."
>
> Decision bridge: "For your retry-safe payment endpoint: make it idempotent by requiring a client-generated request ID. If the client retries, the server recognizes the duplicate and returns the original result. This prevents double-charging during network hiccups."

### Level c: Detail (Deep)

**Purpose**: Explain the mechanism with enough specificity for implementation or precise evaluation.

**Techniques**:

- **Dual coding** (Paivio): Code snippet + verbal explanation side by side
- **Worked example**: Complete solution with reasoning annotations
- **Split attention prevention**: Integrate explanations into the code/diagram rather than presenting separately

**Entry conditions** — use Detail when:

- Learner needs to implement the chosen approach
- The decision depends on specific behavioral characteristics (performance, error handling)
- Principle level left the learner unable to differentiate options for their specific constraints

**Exit to next level** when:

- Learner says "I understand how it works — can you show me what it looks like in practice with real data?"
- The decision requires comparing actual behavior in the learner's specific context

**SWE example — Explaining connection pool sizing for a database decision**:

> "A connection pool pre-creates database connections so requests don't pay the cost of establishing one each time (~50ms for PostgreSQL TCP+SSL handshake). The pool size determines max concurrent database operations."
>
> "Key mechanism: if all connections are busy, new requests wait in a queue. If the queue fills, requests fail. So pool size is a trade-off:"
>
> ```
> Too small: requests queue → latency spikes under load
> Too large: each connection uses ~5MB RAM + one database backend process
>            PostgreSQL default max_connections = 100
>
> Formula (Brian McKenna / HikariCP):
>   pool_size = (core_count * 2) + effective_spindle_count
>   For SSD: pool_size ≈ (core_count * 2) + 1
>   Example: 4 cores → pool_size = 9
> ```
>
> Decision bridge: "Your server has 8 cores. Starting point: 17 connections. With 3 service instances, that's 51 total connections — well within PostgreSQL's default 100. Start here and adjust based on p99 latency under load test."

### Level d: Example (Deepest)

**Purpose**: Show concrete, comparable instances that enable the learner to make their own judgment.

**Techniques**:

- **Desirable difficulty** (Bjork): Present both options in context and let the learner evaluate rather than immediately recommending
- **Interleaving**: Show the two options solving the same problem side-by-side
- **Transfer scaffolding**: After the comparison, extract the general pattern: "whenever you see [conditions], prefer [approach]"

**Entry conditions** — use Example when:

- The decision is between two specific options and the learner needs to see them in action
- Abstract descriptions haven't resolved the learner's uncertainty
- The learner benefits from making their own judgment (builds near transfer capability)

**SWE example — Comparing error handling approaches**:

> "Here's the same API endpoint with both error strategies. Look at how each handles the three failure modes (validation error, not found, internal error):"
>
> **Approach A: Result types**
> ```typescript
> async function getOrder(id: string): Promise<Result<Order, OrderError>> {
>   const validated = validateId(id);
>   if (!validated.ok) return err({ code: 'INVALID_ID', message: validated.error });
>
>   const order = await db.orders.find(id);
>   if (!order) return err({ code: 'NOT_FOUND', message: `Order ${id} not found` });
>
>   return ok(order);
> }
> // Caller: must handle Result — compiler enforces error checking
> ```
>
> **Approach B: Exceptions**
> ```typescript
> async function getOrder(id: string): Promise<Order> {
>   const validated = validateId(id); // throws ValidationError
>   const order = await db.orders.find(id);
>   if (!order) throw new NotFoundError(`Order ${id} not found`);
>   return order;
> }
> // Caller: may forget try/catch — errors bubble up silently
> ```
>
> "Both work. The difference: Result types make error handling explicit at compile time — you can't forget to handle an error. Exceptions are more concise but errors are invisible in the function signature."
>
> Decision bridge: "For your public API boundary serving both Go and TypeScript clients: Result types (or HTTP status codes, which are equivalent) make the contract explicit. For internal module boundaries: exceptions are fine since you control both sides. Does this distinction between public and internal boundaries clarify the choice?"

## Progressive Disclosure Flow

```
START → Analogy + Decision Bridge
            │
            ├── Learner decides → DONE (ideal fast path)
            │
            ├── "Why?" → Add Principle + updated Decision Bridge
            │                 │
            │                 ├── Learner decides → DONE
            │                 │
            │                 └── "How exactly?" → Add Detail
            │                                        │
            │                                        ├── Decides → DONE
            │                                        │
            │                                        └── "Show me" → Add Example
            │                                                          │
            │                                                          └── Decides → DONE
            │
            └── "I already know this" → Skip to deeper level or Decision Bridge directly
```

The goal is to exit as early as possible. Every "DONE" exit is a successful teaching interaction — the learner got exactly what they needed and no more.

## Decision Bridge Patterns

### Pattern 1: Binary Choice

```
"Given [key insight from explanation]:
- Option A gives you [benefit] at the cost of [trade-off]
- Option B gives you [benefit] at the cost of [trade-off]
For your constraint [specific constraint reference], A/B is the better fit."
```

### Pattern 2: Phased Decision

```
"This doesn't have to be all-or-nothing:
- Phase 1 (this sprint): [low-risk first step]
- Phase 2 (after validation): [expand based on Phase 1 results]
The Phase 1 choice is: [specific small decision]."
```

### Pattern 3: Conditional Decision

```
"The answer depends on [key variable]:
- If [condition A]: choose X because [reason]
- If [condition B]: choose Y because [reason]
Can you check [how to determine which condition applies]?"
```

### Pattern 4: Non-Decision (Decision is premature)

```
"Before choosing between A and B, you need to determine [missing information].
Quick check: [specific action to gather the missing data].
Once you know that, the choice becomes clear."
```

## Transfer of Learning: Building Decision Patterns

After each teaching interaction, optionally extract the reusable pattern for near transfer:

"In general, whenever you're choosing between [category of options], the key dimensions to check are: (1) [dimension], (2) [dimension], (3) [dimension]. Today's decision was an instance of this pattern."

This converts a specific decision into a repeatable capability — the compound velocity benefit of teaching well.
