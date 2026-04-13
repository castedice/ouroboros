---
name: enrichment-rules
description: This reference provides proposal-only conversation enrichment rules for `.pa/personal-profile.json`. It should be consulted when an agent needs to "detect profile update signals in conversation", "draft a profile patch proposal", "apply confidence deltas", "log profile enrichment proposals", or "avoid silently mutating the personal profile".
---

# Enrichment Rules - Proposal-Only Profile Updates During Conversation

> Purpose: Reference for `personal-profiling` - detect when ordinary conversation reveals a meaningful profile change, then convert that signal into one conservative patch proposal instead of a silent mutation.
> This reference is standalone and can be consulted without the parent skill.
> For lifecycle rules, see `skills/pa/personal-profiling/SKILL.md`.
> For the target schema, see `skills/pa/personal-profiling/references/profile-schema.md`.

## Scope

This reference covers four concerns.
It detects enrichment-worthy signals in conversation.
It defines the patch format.
It limits proposal frequency.
It explains how to log approved or declined proposals for auditability.

It does not authorize silent mutation.
It does not replace formal interviews.
It exists to keep the profile current between interviews.

## Enrichment Workflow

### Step 1: Detect A Candidate Signal

Look for explicit role, goal, value, or direction changes during normal conversation.
Prefer statements the user volunteered naturally.
Treat one-off emotional reactions as weak signal until confirmed.

### Step 2: Draft One Minimal Patch

Create the smallest patch that captures the change.
The default patch shape is:

```json
{"field": "...", "old": "...", "new": "...", "reason": "...", "confidence_delta": 0.05}
```

When `old` or `new` is structured data, serialize it as compact JSON text inside the string slot.
Do not draft multiple unrelated patches in one proposal.

### Step 3: Present The Proposal

Show the patch to the user before any write.
Explain the reason in plain language.
Ask for approval or correction.

### Step 4: Apply Only After Approval

If the user approves, apply the patch to `.pa/personal-profile.json`.
Update the relevant confidence value and metadata together.
If the user declines, keep the current profile unchanged.

### Step 5: Log The Outcome

Append the proposal result to `.pa/proposals.jsonl` when audit logging is enabled.
Record both approved and declined outcomes so repeated low-quality proposals can be detected later.

## Detection Signals

Enrichment proposals are allowed only when one of these signal classes is present.

| Signal Class | Example | Default Confidence Delta |
|--------------|---------|--------------------------|
| Explicit role or goal change | "I am moving from engineering management back to IC work." | `+0.05` |
| Explicit value or principle statement | "Autonomy matters more to me than title now." | `+0.05` |
| New or stopped life area | "I started caring seriously about health this year." | `+0.05` |
| Direction regret or excitement | "I feel relieved that I stopped chasing that startup path." | `+0.05` when confirmed |
| Activity-supported inference | Repeated month-long writing activity despite no explicit statement | `+0.02` after confirmation |
| Specialist insight pattern | 3+ consecutive specialist status (stable/declining/shifted) triggers survey catch-up question; user answer drives proposal | `+0.05` after confirmation, `0.00` if declined. See `skills/pa/domain-specialization/references/insight-accumulation.md` |

| Memory-backed observation | Accumulated memory signal from `.pa/memory/observations.jsonl` with matching `kind` and unactioned status | `+0.05` after confirmation, follows one-proposal-per-session rule |

Direct statement beats inference. Memory observations beat cold inference but require confirmation like any other non-anchor signal.
Inference without confirmation should not be written.

## Proposal-Only Rule

Never silently mutate the personal profile.
Always present the patch first.
The sequence is mandatory: present patch, user approves, apply patch.

## Frequency Limit

Propose at most one enrichment per session.
If multiple signals appear, keep the strongest one and defer the rest.
A smaller number of high-quality proposals is better than frequent interruption.

## Confidence Adjustment

Use small, conservative deltas.
Confidence should move only when the patch is approved.

| Signal Source | Confidence Delta |
|---------------|------------------|
| Direct statement | `+0.05` |
| Confirmed inference | `+0.02` |
| Declined proposal | `0.00` |

If the new value contradicts a high-confidence prior value, update the field but keep the resulting confidence bounded until the change is seen again or revisited in interview.

## `proposals.jsonl` Integration

Use `.pa/proposals.jsonl` as the audit trail for enrichment behavior.
Each record should capture enough information to explain what was proposed and what happened.

```jsonl
{"timestamp":"2026-03-17T18:00:00+09:00","kind":"personal-profile-enrichment","field":"focus.current_focus","old":"[\"team operations\"]","new":"[\"writing\", \"health\"]","reason":"User explicitly said their current focus has shifted.","confidence_delta":0.05,"status":"approved"}
{"timestamp":"2026-03-17T18:10:00+09:00","kind":"personal-profile-enrichment","field":"identity.values_and_principles","old":"[\"stability\"]","new":"[\"stability\",\"autonomy\"]","reason":"User said autonomy matters more than title.","confidence_delta":0.05,"status":"declined"}
```

If the caller does not maintain `proposals.jsonl` yet, keep the proposal result in memory for the current session and return it in the command output.

## Anti-Patterns

| Anti-Pattern | Why It Is Unsafe | Correct Behavior |
|--------------|------------------|------------------|
| Inferring values from task preferences | Liking checklists does not prove a life value | Wait for an explicit value statement |
| Updating direction from one-off comments | A rough day or isolated complaint can distort the profile | Require repeated or confirmed direction signal |
| Bundling several field edits into one proposal | The user cannot evaluate what changed cleanly | Propose one coherent patch only |
| Raising confidence on declined proposals | Decline says nothing about truth of the new value | Keep confidence unchanged |
| Treating tone as durable identity | Conversation mood shifts faster than life patterns | Ask or wait for stronger evidence |

## Design Rationale

Why proposal-only: the profile influences future judgment, so silent mutation is a trust failure.
Why one proposal per session: enrichment should feel helpful, not like constant background profiling.
Why direct statements get `+0.05`: the profile should move visibly when the user states something clearly.
Why inference gets only `+0.02`: supporting evidence is useful, but it is easier to overread than to underread.

## Common Pitfalls

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Proposing every interesting observation | Detection | Filter for changes that will materially improve future support |
| Updating profile and log separately | Apply | Move profile, confidence, and audit record together |
| Writing an enrichment patch without `reason` | Drafting | Tie every proposal to the exact signal that triggered it |
| Treating decline as resistance to profiling itself | Review | It may simply mean the draft patch was wrong or badly timed |

## Bias Mitigation

| Bias | Risk | Countermeasure |
|------|------|----------------|
| Over-interpretation bias | The assistant reads too much into casual conversation | Require either an explicit statement or a confirmed inference |
| Recency bias | The last message dominates the profile | Prefer repeated patterns or direct correction over single fresh impressions |
| Helpfulness bias | The assistant proposes updates because it can, not because it should | Enforce the one-proposal-per-session cap |
| Assistant-self-protection bias | The assistant stores preferences that make itself easier to use | Ask whether the change serves the user's direction first |

## Validation Checklist

- [ ] The signal was strong enough to justify an enrichment proposal.
- [ ] The patch is the smallest useful change.
- [ ] The patch includes `field`, `old`, `new`, `reason`, and `confidence_delta`.
- [ ] The proposal was shown before any profile write.
- [ ] No more than one enrichment proposal was made in the session.
- [ ] Confidence moved only after approval.
- [ ] Declined proposals left the profile unchanged.
- [ ] The outcome was logged to `.pa/proposals.jsonl` or returned for audit.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-profiling/SKILL.md` | Parent skill - lifecycle, signal hierarchy, and gap detection |
| `skills/pa/personal-profiling/references/profile-schema.md` | Sibling reference - target fields for enrichment patches |
| `skills/pa/interviewing/SKILL.md` | Alternative path - formal interviews when conversational enrichment is not enough |
| `commands/pa/survey.md` | Likely caller for refresh-time enrichment |
| `commands/pa/review.md` | Likely caller for direction-related enrichment |
