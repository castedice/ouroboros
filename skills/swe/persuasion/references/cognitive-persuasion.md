# Cognitive Persuasion — Psychology-Based Techniques for Technical Communication

> **Purpose**: Psychology-based persuasion techniques (Cialdini, pre-suasion, inoculation, cognitive bias) for SWE contexts.
> **Scope**: Evidence-based techniques for making valid arguments accessible — complements the persuasion SKILL's Steps 2-5.
> **Parent Skill**: `skills/swe/persuasion/SKILL.md` — core methodology and workflow.
> **Standalone**: Yes — can be read independently for technique selection and application.

Psychological principles underlying persuasion, adapted for software engineering contexts. These techniques make valid arguments more accessible — they do not substitute for sound logic.

## Cialdini's Six Principles of Influence

Robert Cialdini's research identified six universal principles that drive human decision-making. Each maps directly to technical communication scenarios.

### 1. Reciprocity

People feel obligated to return what they receive. In technical contexts: provide value before making requests.

| Technique | Example |
|-----------|---------|
| **Give insight first** | "I noticed your service handles retries elegantly in `order-service/retry.ts`. Could we apply the same pattern to the payment flow?" |
| **Share knowledge** | "I found this benchmark data that might be useful for your design decision" (then later: "By the way, I have a suggestion for the caching layer") |
| **Acknowledge contributions** | "Building on your work on the event system, here's how we could extend it for notifications" |

### 2. Commitment/Consistency

Once people take a position, they strive to remain consistent with it. This powers the Yes Ladder structure.

| Technique | Example |
|-----------|---------|
| **Reference prior agreements** | "In last sprint's retro, the team agreed that reliability should take priority over new features" |
| **Written commitment** | "Our ADR-012 established that all external calls should have circuit breakers" |
| **Incremental commitment** | Start with a small agreement, then expand scope consistently |

### 3. Social Proof

People follow what others do, especially in uncertain situations.

| Technique | Example |
|-----------|---------|
| **Industry adoption** | "AWS, Google, and Stripe all use this pattern for exactly this use case" |
| **Internal precedent** | "The payments team adopted this approach 6 months ago and reduced incidents by 40%" |
| **Community consensus** | "The Go community converged on this error handling pattern — it's now in the standard library" |

Social proof is strongest when the reference group is similar to the audience. A startup team resonates more with "Stripe does this" than "Google does this."

### 4. Authority

People defer to credible experts. In technical contexts, authority comes from evidence quality, not job titles.

| Authority Source | Strength | Usage |
|-----------------|----------|-------|
| **Measured data** | Highest | "Our load test shows 340ms p99 at 2x traffic" |
| **RFC/specification** | High | "RFC 7231 Section 6.5.4 specifies 404 semantics as..." |
| **Recognized expert** | Medium | "Martin Fowler's Refactoring (2nd ed.) classifies this as..." (cite specifically) |
| **Peer recognition** | Medium | "The team lead who built the original system recommends..." |

Authority is earned through demonstrated competence — reading the code before commenting, running benchmarks before recommending, understanding constraints before designing.

### 5. Liking

People agree more readily with those they like. In technical contexts: demonstrate respect, share common ground, and communicate constructively.

| Technique | Example |
|-----------|---------|
| **Code appreciation** | "The error handling in this module is really clean — I learned a new pattern from it" |
| **Collaborative framing** | "What if we explored this together?" rather than "You should do X" |
| **Shared experience** | "I hit the same issue in the search service — here's what worked" |

### 6. Scarcity

Limited availability increases perceived value. In technical contexts: opportunity windows and irreversible consequences.

| Technique | Example |
|-----------|---------|
| **Window of opportunity** | "Refactoring is feasible now during the quiet period. After Q3 features land, the code surface doubles and refactoring cost triples" |
| **Irreversibility** | "Once we commit to this API contract, changing it requires a migration for 200+ consumers" |
| **Expertise availability** | "The developer who understands the legacy system is leaving next month. We should extract their knowledge into specs now" |

## Pre-Suasion: Setting the Stage

Robert Cialdini's pre-suasion research shows that what happens before a request shapes the response more than the request itself. Three techniques for technical contexts:

### Attention Channeling

Direct attention to the criteria that favor your recommendation before presenting it.

- Before proposing a reliability improvement: discuss recent incidents and their impact
- Before proposing a simpler architecture: discuss maintenance burden of the current system
- Before proposing a technology migration: discuss the limitations hitting the team daily

The goal is not manipulation — it's ensuring the relevant context is active in the audience's mind when they evaluate the proposal.

### Unity (Shared Identity)

Activate a sense of shared group membership before making the request.

- "As the team responsible for customer-facing reliability..."
- "We've all been dealing with these deployment issues..."
- "Our shared goal for Q3 is..."

Unity is the most ethical pre-suasion technique — it simply reminds people of what they already share.

### Environmental Priming

The context in which a discussion happens affects its outcome.

- Technical proposals during code review: audience is in analytical mode → use Toulmin structure
- Architecture discussions during planning: audience is in strategic mode → use SCQA structure
- Team retrospectives: audience is in reflective mode → use Yes Ladder with historical data

## Steel-Manning: The Four-Step Process

Steel-manning is the opposite of straw-manning. Instead of weakening the opposing argument to defeat it easily, you strengthen it to demonstrate intellectual fairness.

### Step 1: Reconstruct the Strongest Version

State the opposing position in its most compelling form. If the opponent is present, they should nod and say "yes, that's exactly what I mean."

Poor: "Some people think we should just keep using the monolith because they're afraid of change."
Strong: "The strongest argument for the monolithic architecture is that it eliminates distributed system complexity — no network partitions, no eventual consistency, no service discovery. For a team of our size, this reduces operational burden significantly."

### Step 2: Identify Legitimate Strengths

Acknowledge where the opposing position genuinely outperforms yours.

"The monolithic approach genuinely excels at: (1) developer onboarding — one codebase to learn, (2) debugging — full stack traces, no distributed tracing needed, (3) deployment simplicity — one artifact, one rollback path."

### Step 3: Bound the Context

Define the conditions under which the opposing position would be correct.

"If our team stays at 5 developers and traffic remains under 10K RPM, the monolithic approach is not just viable — it's superior. The complexity cost of microservices outweighs the benefits at this scale."

### Step 4: Show Why Your Context Differs

Explain specifically why your situation falls outside those bounds.

"However, our context differs on two critical axes: (1) the team is growing to 15 developers in Q3, which makes independent deployability essential (Constraint T-03), and (2) traffic projections show 50K RPM by year-end, requiring independent scaling of the compute-heavy pricing service."

## Cognitive Biases: Ethical Application

### Loss Aversion (Kahneman & Tversky)

People feel losses approximately 2x as strongly as equivalent gains. Use this to make the cost of inaction visible, not to create false urgency.

**Reframing pattern:**

| Gain Frame (weaker) | Loss Frame (stronger) |
|---------------------|----------------------|
| "Migration gives us 40% faster builds" | "Without migration, we lose 12 developer-hours per week to build wait times" |
| "New monitoring catches errors faster" | "Current monitoring missed 3 production incidents last quarter — 18 hours of user impact" |
| "Refactoring improves readability" | "New developers spend 2 extra weeks onboarding because the code structure is non-obvious" |

### Anchoring

The first information presented disproportionately influences subsequent judgments. Use this to set appropriate reference points.

- Present the cost of doing nothing first, then present the proposal cost — the proposal feels more reasonable
- In trade-off tables, order metrics so the recommended option's strongest dimension appears first
- When estimating effort, present the "full rewrite" option first as the anchor, then present the incremental approach as the realistic option

### Status Quo Bias

People prefer the current state because change feels risky. Counter this by making the status quo feel like an active choice with visible costs.

**Reframing pattern:**

| Status Quo Framing | Active Choice Framing |
|-------------------|----------------------|
| "We can keep using the current approach" | "Choosing to keep the current approach means accepting 3 incidents/month and 20hrs/sprint maintenance" |
| "No change needed right now" | "Every sprint we delay, the migration scope grows by ~500 LOC as new features build on the old pattern" |

### Confirmation Bias

People seek information that confirms their existing beliefs. Counter this in yourself and others:

- Actively search for disconfirming evidence before presenting
- Present the two strongest counter-arguments explicitly
- Use the pre-mortem technique: "Assume this proposal failed. What was the most likely cause?"

### Sunk Cost Reframe

When teams resist abandoning an approach they've invested in:

| Sunk Cost Thinking | Reframed |
|-------------------|----------|
| "We've spent 3 months on this approach, we can't switch now" | "Those 3 months taught us exactly what works and what doesn't. We're applying those learnings, not discarding them" |
| "Throwing away all that code" | "The code served its purpose as a prototype. The production version builds on what we learned" |
| "Starting over from scratch" | "We're not starting over — we're starting from informed. The first version was the research phase" |

## System 1 / System 2 Transition Strategy

Daniel Kahneman's dual-process theory explains why some arguments land instantly while others require deliberation.

### Engaging System 1 (Intuitive)

Use when establishing initial frame, making abstract concepts concrete, or working with time-pressured audiences.

| Technique | Example |
|-----------|---------|
| **Pattern naming** | "This is a classic thundering herd problem" |
| **Visual analogy** | "Think of it like a highway on-ramp — without metering, everyone tries to merge at once" |
| **Concrete numbers** | "340ms latency" is more intuitive than "suboptimal response time" |
| **Before/after comparison** | Side-by-side code or architecture diagrams |

### Shifting to System 2 (Analytical)

Use when the decision is important and the audience needs to evaluate trade-offs systematically.

| Technique | Example |
|-----------|---------|
| **Trade-off matrix** | Structured comparison table with measurable criteria |
| **Constraint traceability** | "This decision satisfies C-02, C-05, and partially addresses C-08" |
| **Probabilistic framing** | "With 80% confidence based on load test data..." |
| **Decision tree** | "If condition A → option X. If condition B → option Y" |

### Transition Pattern

Start with System 1 to establish the frame, then shift to System 2 for the decision:

1. **Hook** (System 1): "We're seeing a 3x increase in checkout timeouts this week" (concrete, alarming)
2. **Frame** (System 1→2): "This maps to a known pattern — cascading failure from a slow dependency"
3. **Analyze** (System 2): "Let me walk through the three options with trade-offs..."
4. **Decide** (System 2): "Given constraints C-02 and C-07, option B gives us the best balance"
5. **Confirm** (System 1): "In concrete terms: 95th percentile drops from 3.2s to 400ms, and we stop the 3am pages"
