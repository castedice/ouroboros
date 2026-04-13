# Source Quality Overlay

This reference extends `skills/core/research/references/source-evaluation.md` for RnD studies.
Use the core research rubric for credibility, relevance, and freshness first.
Then apply this overlay to decide whether a source is strong enough to support a hypothesis, a report claim, or a contradiction note.

## RnD Dimensions

| Dimension | Question | High | Medium | Low | Why it matters |
|-----------|----------|------|--------|-----|----------------|
| Credibility | Is the source trustworthy on its own terms? | Primary or well-attributed source with transparent method or provenance | Useful but partly derivative or method-light source | Anonymous, speculative, or unsupported source | Weak credibility corrupts every later claim |
| Relevance | Does the source directly address the active research question or hypothesis? | Speaks directly to the claim under test | Covers an adjacent mechanism or comparison | Only background context | Literature-only mode needs direct evidence, not just interesting reading |
| Freshness | Is the source current enough for the claim type? | Time horizon matches the domain's change rate | Slightly old but still plausible with caveats | Stale for a time-sensitive claim | Old material can still help, but it must not masquerade as current evidence |
| Independence | Does the source add new evidence rather than restating another source? | Independent origin, authorship, and citation chain | Partially independent but shares upstream evidence | Merely echoes or summarizes the same source | Repackaged summaries should not inflate confidence |
| Claim Directness | Can the source support the exact claim being made? | Contains a citable statement, result, or artifact that matches the claim closely | Requires a small inference step | Only supports a loose analogy or intuition | Review should be able to trace claims without generous interpretation |
| Artifact Stability | Can a fresh agent retrieve, snapshot, and cite the source again? | Stable URL or path, hashable content, clear title and date | Recoverable but noisy or partially missing metadata | Ephemeral, unstable, or missing core provenance | Reset-safe research depends on stable source identity |
| Method Transparency | Does the source explain how it reached the claim? | Methods, assumptions, and limits are explicit | Some reasoning is shown but the chain is incomplete | Assertions without method or evidence | Transparent methods make contradictions and limitations analyzable |

## Classification Rules

| Class | Minimum profile | Allowed use |
|-------|-----------------|-------------|
| `core-evidence` | Credibility high, relevance high, independence at least medium, claim directness at least medium, and artifact stability at least medium | May support report claims and recommendation-driving conclusions |
| `supporting-evidence` | Credibility at least medium, relevance at least medium, but one overlay dimension is weak | May support context, mechanism discussion, or limitation notes |
| `context-only` | Credible background but low directness or low independence | May frame the brief or motivate a question, but may not anchor a core claim |
| `reject` | Low credibility, missing provenance, or irrecoverable artifact | Do not cite as evidence |

## Source Family Defaults

| Source family | Default class | Allowed use | Not allowed |
|---|---|---|---|
| `conversation-session` | `context-only` | Framing, vocabulary, prior objections, abandoned branches, dead ends, query seeds | Core evidence, novelty proof, recommendation-driving claims |
| `session-wiki` | `context-only` | Framing, vocabulary, objections, abandoned branches, dead ends, prior synthesis, query seeds; treat as denser form of `conversation-session` | Core evidence, novelty proof, recommendation-driving claims, independent citation |

## Special Cases

Repository code is high-quality evidence for what exists, what an API exposes, and what defaults are implemented.
Repository code is weak evidence for performance, safety, or real-world effectiveness unless paired with stronger external evidence.
Blog posts and conference talks are often good lead sources, but they usually stay `supporting-evidence` until their underlying papers, repos, or official docs are traced.
AI-generated summaries are discovery aids only and never count as `core-evidence`.
Normalized PDFs, decks, images, and transcripts are acceptable inputs when `skills/pa/content-pipeline/SKILL.md` preserved original provenance and the resulting source record carries a stable hash.
Conversation session hits are lower confidence than published, official, repository, or archived study sources.
If a session hit mentions a real source, the collector must retrieve and grade that real source separately before it supports a report claim.
When a session-wiki hit references raw session segments via `[SA<n>]` citations, those raw segments still grade independently.
The wiki page itself never elevates to evidence.
If a wiki page cites a real published source, the collector must retrieve and grade that real source separately before it supports a report claim.

## Contradictions And Novelty

Conflicting high-quality sources are not noise.
They should be recorded as contradictions in `prior-work-map.md`, because novelty often appears as a resolved contradiction, a missing boundary condition, or an archive mismatch.
When two sources disagree, prefer the source with stronger method transparency and stronger claim directness rather than the source with the louder venue alone.

## Review Checklist

Before a source supports a report claim, verify that the claim can be pointed back to a stable source id, that the source passes at least `supporting-evidence`, and that at least one `core-evidence` source anchors any decision-critical claim.
If a claim depends only on `supporting-evidence`, mark the claim provisional in the report and call the weakness out explicitly in review.
