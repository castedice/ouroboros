# Constraint Categories — Detection Questions and Examples

Six categories for systematic constraint enumeration. Each category includes: definition, scope, detection questions, example constraints at different specificity levels, and common implicit constraints that are easily missed.

This reference is self-contained — it can be consulted independently of the parent SKILL.md. For the overall constraint enumeration procedure, see the parent skill at `skills/swe/constraint/SKILL.md`.

---

## 1. Performance

**Definition**: Constraints on speed, throughput, resource consumption, and scalability.

**Scope**: Latency, throughput, memory, CPU, disk, network bandwidth, concurrent users, data volume growth.

### Detection Questions

- What is the maximum acceptable response time for this operation?
- How many concurrent requests/users must the system handle?
- What are the memory and CPU budget limits?
- How will data volume grow over time? What is the 1-year projection?
- Are there real-time requirements (sub-second response)?
- What happens if performance degrades — graceful degradation or hard failure?

### Example Constraints

| Specificity | Example | Classification |
|-------------|---------|---------------|
| Vague (avoid) | "Should be fast" | — |
| Acceptable | "API response under 500ms for 95th percentile" | Hard |
| Precise | "P95 latency < 200ms at 1000 RPS with < 512MB RSS" | Hard |
| With degradation | "P95 < 200ms normal, < 2s under 5x load spike" | Hard (normal), Soft (spike) |

### Commonly Missed Implicit Constraints

- Cold start latency (serverless, container startup)
- Database connection pool limits
- Rate limits from upstream services
- Memory leaks under sustained load
- GC pause impact on latency percentiles

---

## 2. Scope

**Definition**: Constraints on timeline, feature boundaries, and explicit exclusions.

**Scope**: Deadlines, MVP boundaries, what is explicitly NOT in scope, phasing strategy.

### Detection Questions

- What is the deadline? Is it a hard date or flexible?
- What is the minimum viable version? What can be deferred?
- What is explicitly excluded from this task?
- Are there phasing requirements (Phase 1 / Phase 2)?
- What is the definition of "done" for this iteration?

### Example Constraints

| Specificity | Example | Classification |
|-------------|---------|---------------|
| Vague (avoid) | "As soon as possible" | — |
| Acceptable | "Must ship by March 15" | Hard |
| Precise | "Phase 1 by March 15: API only, no UI. Phase 2 by April 30: UI integration" | Hard |
| With exclusion | "In scope: CRUD operations. Excluded: search, analytics, admin panel" | Hard (exclusions) |

### Commonly Missed Implicit Constraints

- Implicit "no breaking changes" (backward compatibility assumed)
- Feature flags for gradual rollout (assumed but not stated)
- Documentation as part of delivery (often forgotten until review)
- Deployment coordination with other teams

---

## 3. Team

**Definition**: Constraints from team composition, skills, expertise, and learning capacity.

**Scope**: Programming language proficiency, framework expertise, domain knowledge, team size, timezone distribution.

### Detection Questions

- What languages and frameworks does the team know well?
- What technologies would require learning time?
- Is there domain expertise (e.g., ML, security, distributed systems)?
- How many people will work on this? Are they full-time or shared?
- Are there timezone or communication constraints?

### Example Constraints

| Specificity | Example | Classification |
|-------------|---------|---------------|
| Vague (avoid) | "Team is experienced" | — |
| Acceptable | "Team knows Python, not Rust" | Hard |
| Precise | "3 Python developers, 0 Rust experience, 1-week max learning budget" | Hard |
| With growth | "Currently Python-only; Rust upskilling planned Q3 (not available for this project)" | Hard (now), Soft (future) |

### Commonly Missed Implicit Constraints

- Onboarding time for new team members
- Code review bandwidth (bottleneck if only 1 senior reviewer)
- Operational knowledge for production support
- Cross-team dependency on expertise (e.g., DBA for schema changes)

---

## 4. Technology

**Definition**: Constraints from language, framework, infrastructure, and compatibility requirements.

**Scope**: Programming language version, framework selection, infrastructure platform, third-party service dependencies, backward compatibility.

### Detection Questions

- What programming language and version is required?
- What framework or runtime is mandated?
- What infrastructure platform is used (cloud provider, on-prem, hybrid)?
- What databases, message queues, or services are already in use?
- What backward compatibility requirements exist?
- Are there security requirements for dependencies (CVE scanning, license compliance)?

### Example Constraints

| Specificity | Example | Classification |
|-------------|---------|---------------|
| Vague (avoid) | "Use modern tools" | — |
| Acceptable | "Python 3.11+, PostgreSQL" | Hard |
| Precise | "Python 3.11+, FastAPI, PostgreSQL 15, Redis 7, deployed on AWS ECS" | Hard |
| With flexibility | "PostgreSQL required for transactions; Redis preferred for caching, Memcached acceptable" | Hard (PG), Soft (Redis) |

### Commonly Missed Implicit Constraints

- Minimum supported browser/OS versions
- API versioning strategy (breaking changes in v2?)
- Dependency vulnerability policy (no Critical CVE in dependencies)
- Container image size limits (affects cold start — links to Performance)

---

## 5. Operations

**Definition**: Constraints from deployment, monitoring, maintenance, and incident response requirements.

**Scope**: Deployment strategy, uptime targets, monitoring/alerting, backup/recovery, incident response time.

### Detection Questions

- What is the deployment target (Kubernetes, serverless, bare metal)?
- What uptime target is required (99.9%, 99.99%)?
- What monitoring and alerting is expected?
- What is the backup and recovery strategy?
- What is the maximum acceptable incident response time?
- Who handles on-call? What is the escalation path?

### Example Constraints

| Specificity | Example | Classification |
|-------------|---------|---------------|
| Vague (avoid) | "Should be reliable" | — |
| Acceptable | "99.9% uptime, Kubernetes deployment" | Hard |
| Precise | "99.9% uptime, K8s on AWS EKS, DataDog monitoring, PagerDuty alerting, 30min incident response" | Hard |
| With trade-off | "99.9% uptime for core API; 99% for batch processing" | Hard (core), Soft (batch) |

### Commonly Missed Implicit Constraints

- Log retention requirements (compliance-driven)
- Secret rotation policy
- Blue-green or canary deployment requirements
- Database migration strategy (zero-downtime DDL)
- Disaster recovery RTO/RPO

---

## 6. Business

**Definition**: Constraints from budget, compliance, licensing, and stakeholder expectations.

**Scope**: Infrastructure cost, compliance requirements (GDPR, HIPAA, SOC2), software licensing, stakeholder approval processes, IP protection.

### Detection Questions

- What is the infrastructure budget for this feature?
- What compliance requirements apply (GDPR, HIPAA, PCI-DSS, SOC2)?
- What software licensing constraints exist (no GPL in proprietary code)?
- Who are the stakeholders and what is the approval process?
- Are there IP protection requirements (obfuscation, encryption)?
- What are the success metrics from a business perspective?

### Example Constraints

| Specificity | Example | Classification |
|-------------|---------|---------------|
| Vague (avoid) | "Keep costs low" | — |
| Acceptable | "Monthly infra cost < $500" | Hard |
| Precise | "Monthly infra < $500, GDPR compliant, no AGPL dependencies, CPO sign-off required" | Hard |
| With flexibility | "Prefer < $500/month; acceptable up to $1000 with CTO approval" | Soft ($500), Hard ($1000) |

### Commonly Missed Implicit Constraints

- Data residency requirements (GDPR: EU data stays in EU)
- Audit trail requirements (who changed what, when)
- License compatibility in dependency chains (transitive GPL)
- Accessibility requirements (WCAG 2.1 AA)
- Internationalization requirements (i18n/l10n from day one or retrofit?)

---

## Cross-Category Conflict Patterns

Common tensions between constraint categories:

| Conflict | Category A | Category B | Typical Resolution |
|----------|-----------|-----------|-------------------|
| Speed vs Cost | Performance (fast) | Business (cheap) | Tiered architecture: fast for hot path, cheap for bulk |
| Best Tool vs Team Skill | Technology (Rust) | Team (knows Python) | Evaluate learning time vs project timeline |
| Reliability vs Agility | Operations (99.99%) | Scope (fast delivery) | Phase reliability targets: 99.9% launch, 99.99% Q2 |
| Compliance vs Speed | Business (GDPR) | Scope (deadline) | Non-negotiable — compliance is always Hard |
| Feature Richness vs Maintenance | Scope (many features) | Operations (low maintenance) | Explicit feature budget — each feature has a maintenance cost |

## Constraint Writing Anti-Examples

| Weak Statement | Improved Measurable Version |
|----------------|---------------------------|
| "System must be fast" | "P95 response ≤ 250ms at 1000 RPS" |
| "Keep timeline realistic" | "Release candidate by 2026-03-15 with no more than 3 Must features" |
| "Team should handle it" | "At least 2 engineers with production experience own subsystem" |
| "Deployment should be safe" | "Rollback must complete within 20 minutes" |
