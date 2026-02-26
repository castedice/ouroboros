# Constraint Quality Examples — Good, Bad, and Improved Statements

Concrete examples of constraint quality across all 6 categories. Each example demonstrates the quality standard (Specific, Measurable, Time-bounded, Owned, Evidence-backed) and shows the transformation from vague to precise constraint statements.

This reference is self-contained — it can be consulted independently of the parent SKILL.md. For the quality standard definition and statement template, see the parent skill at `skills/swe/constraint/SKILL.md`.

---

## Quality Standard Recap

A constraint is acceptable only if it meets all 5 attributes:

| Attribute | Test | Failure Mode |
|-----------|------|-------------|
| **Specific** | Can you identify exactly what is constrained? | "System must be good" — good at what? |
| **Measurable** | Can you write a test or measurement for it? | "Should be fast" — how fast? |
| **Time-bounded** | When must this constraint be met? | "Eventually consistent" — by when? |
| **Owned** | Who decides if this constraint is met or relaxed? | "The team agrees" — who specifically? |
| **Evidence-backed** | What data supports this threshold? | "We need 10x capacity" — based on what? |

## Transformation Examples by Category

### Performance

| Quality | Statement | Missing Attributes |
|---------|-----------|-------------------|
| Poor | "The system should be fast" | Specific, Measurable, Time-bounded, Owned, Evidence-backed |
| Partial | "API response under 500ms" | Time-bounded, Owned, Evidence-backed |
| Good | "P95 API latency ≤ 200ms at 1000 RPS by Q2 release, owned by Platform Lead, based on load-test-2026-01-15" | None |

**Transformation path**: "fast" → "latency under X" → "P95 latency ≤ Xms at Y RPS" → add timeframe, owner, evidence.

### Scope

| Quality | Statement | Missing Attributes |
|---------|-----------|-------------------|
| Poor | "Ship it ASAP" | Specific, Measurable, Time-bounded (paradoxically), Owned |
| Partial | "Must ship by March 15" | Specific (what exactly ships?), Owned, Evidence-backed |
| Good | "Release candidate with CRUD API by 2026-03-15. Excluded: search, analytics, admin panel. Owned by Product Lead, per roadmap v2.3" | None |

**Transformation path**: "ASAP" → "by date" → "by date with explicit scope and exclusions" → add owner, evidence.

### Team

| Quality | Statement | Missing Attributes |
|---------|-----------|-------------------|
| Poor | "Team is experienced enough" | Specific, Measurable, Evidence-backed |
| Partial | "Team knows Python, not Rust" | Measurable (how well?), Time-bounded, Owned |
| Good | "3 engineers with 2+ years Python production experience; 0 Rust experience; 1-week max learning budget for new tools. Owned by Engineering Manager, per team skill assessment 2026-01" | None |

**Transformation path**: "experienced" → "knows X, not Y" → "N engineers with X years experience in Y" → add learning budget, owner, evidence.

### Technology

| Quality | Statement | Missing Attributes |
|---------|-----------|-------------------|
| Poor | "Use modern tools" | Specific, Measurable |
| Partial | "Python 3.11+, PostgreSQL" | Time-bounded, Owned, Evidence-backed |
| Good | "Python 3.11+, FastAPI, PostgreSQL 15, Redis 7, deployed on AWS ECS. No AGPL dependencies. Owned by Tech Lead, per architecture decision ADR-042" | None |

**Transformation path**: "modern" → "specific versions" → "specific versions + deployment target + license requirements" → add owner, evidence.

### Operations

| Quality | Statement | Missing Attributes |
|---------|-----------|-------------------|
| Poor | "Must be reliable" | Specific, Measurable |
| Partial | "99.9% uptime" | Time-bounded (measurement window?), Owned, Evidence-backed |
| Good | "99.9% monthly uptime for core API, measured by external probe. Rollback within 15 minutes. Owned by SRE Lead, per SLA agreement v1.2" | None |

**Transformation path**: "reliable" → "X% uptime" → "X% monthly uptime with measurement method + rollback target" → add owner, evidence.

### Business

| Quality | Statement | Missing Attributes |
|---------|-----------|-------------------|
| Poor | "Keep costs low" | Specific, Measurable |
| Partial | "Monthly infra cost < $500" | Time-bounded (when does this apply?), Owned, Evidence-backed |
| Good | "Monthly infrastructure cost < $500 starting Q2, with CTO approval required for $500-$1000 range. GDPR compliant for EU user data. Owned by Finance Lead, per budget allocation 2026-Q1" | None |

**Transformation path**: "low cost" → "< $X/month" → "< $X/month with approval path for overages + compliance" → add owner, evidence.

## Common Anti-Patterns

Constraint statements that look specific but fail the quality standard:

| Anti-Pattern | Why It Fails | Fix |
|-------------|-------------|-----|
| "P95 < 200ms" (no load context) | Measurable but not specific — 200ms at what load? | "P95 < 200ms at 1000 RPS" |
| "Must comply with GDPR" (no scope) | Specific regulation but not measurable — which GDPR articles? What data? | "Personal data of EU users must comply with GDPR Articles 5-9, 12-22. Data residency in EU." |
| "Team can learn it" (assumption) | Not evidence-backed — how long? What is the learning budget? | Classify as Assumption: "Team can learn GraphQL in 2 weeks (unverified). Validate by: 2026-02-28. Owner: Tech Lead." |
| "99.99% uptime" (no measurement method) | Measurable but not evidence-backed — how is uptime measured? External probe? Internal health check? | "99.99% uptime measured by external probe from 3 regions, 1-minute intervals" |
| "No breaking changes" (implicit assumption) | Often unstated — needs to be explicit with versioning strategy | "API v1 backward compatible for 6 months after v2 launch. Owned by API Lead." |

## Constraint Statement Template — Worked Example

Template from parent skill:

```text
<category> | <rigidity> | <statement with metric> | <timeframe> | <owner> | <source>
```

Full example for a real project:

```text
Performance | Hard | P95 latency ≤ 200ms at 1000 RPS | Q2 2026 release | Platform Lead | load-test-2026-02-10
Scope | Hard | CRUD API only; search, analytics, admin excluded | Phase 1 by 2026-03-15 | Product Lead | roadmap v2.3
Team | Hard | 3 Python engineers; 0 Rust experience; 1-week learning max | Current sprint | Engineering Manager | skill-assessment-2026-01
Technology | Hard | Python 3.11+, FastAPI, PostgreSQL 15 on AWS ECS | Project lifetime | Tech Lead | ADR-042
Operations | Hard | 99.9% monthly uptime; rollback < 15min | Post-launch | SRE Lead | SLA v1.2
Business | Soft | Monthly infra < $500; up to $1000 with CTO approval | Starting Q2 | Finance Lead | budget-2026-Q1
```

## See Also

- **swe-constraint-methodology** (`skills/swe/constraint/SKILL.md`) — Parent skill; quality standard definition and statement template
- **constraint-categories** (`references/constraint-categories.md`) — Constraint Writing Anti-Examples table for quick weak→improved comparisons
