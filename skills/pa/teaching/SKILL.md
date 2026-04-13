---
name: pa-teaching
description: This skill provides PA-domain teaching methodology. It should be activated when an agent needs to "explain PA agenda scoring", "teach vault profile confidence", "clarify write-gate consent", "explain memory versus source notes", "teach QMD context retrieval", "scaffold a personal workflow decision", or "explain PA capture routing to the user".
summary: Teaches PA and vault concepts using decision-focused explanations that bridge to concrete vault actions.
version: 1
tags: [pa, teaching, vault-explanation, workflow-guidance]
preamble_tier: 2
---

# PA Teaching

## Core Rule

Teach PA concepts only when it helps the user make a next PA/vault decision.
Every explanation must end with a concrete vault action.
This skill is an adapter from `core-teaching` into PA workflows, not a replacement for core teaching methodology.
Use it when the user needs just enough explanation to decide what to capture, retrieve, approve, review, link, defer, or write in the vault.
Keep PA vocabulary concrete: vault, note, capture, QMD, Obsidian, frontmatter, wikilinks, daily note, profile, soul, persona, agenda, review, and focus.
A valid response ends with a next action such as capturing a note, approving a profile patch, running QMD retrieval, adding frontmatter, linking a daily note, deferring an agenda item, or requesting review.

## Gotchas

| Pitfall | PA Failure Mode | Prevention |
|---------|-----------------|------------|
| Teaching vault organization instead of the current capture decision | The user learns folder theory but still does not know where the note should go | Explain only the routing rule that changes this capture and name the target note or inbox |
| Explaining all PA commands when the user asked about one | The user gets a command catalog instead of the next workflow step | Scope to the single command, its inputs, and the immediate vault outcome |
| Treating QMD as magic search | The user cannot decide when retrieval evidence is enough | Explain QMD as context retrieval over notes, with citations and limits |
| Blurring memory facts and source notes | The user may treat assistant memory as vault evidence | Contrast active memory as a pointer or summary with source notes as citeable Obsidian evidence |
| Turning write-gate consent into policy lecture | The user still does not know whether to approve an edit | Name the exact surface, risk, reversibility, and approve-or-propose choice |
| Presenting profile, soul, and persona as abstract identity theory | The user cannot decide whether to update a profile field | Tie each layer to its vault use, confidence, and confirmation requirement |
| Teaching frontmatter and wikilinks as Obsidian trivia | The user sees syntax but not workflow value | Explain only the metadata or link needed for retrieval, agenda, review, or focus |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "They asked what QMD is, so explain the whole retrieval stack" | Lecturing on search architecture instead of the current evidence decision | Explain the minimum retrieval behavior needed to choose whether to search, broaden, or trust the current context |
| "Consent rules are simple after enough explanation" | Teaching write-gate policy without asking for the concrete consent decision | End with the exact action boundary and ask for approval only when the write gate requires it |
| "The profile is central, so the user should understand every layer" | Explaining profile, soul, persona, and confidence all at once | Teach only the layer that affects the current patch, response style, or review decision |
| "Vault structure background will prevent future confusion" | Adding Obsidian organization theory before routing the current capture | Route the current capture first, then offer the smallest follow-up explanation if needed |

## Workflow

Detect PA teaching cue → Map to user's current decision → Load core-teaching if depth calibration needed → Explain with PA vocabulary → Bridge to concrete vault action.

### 1. Detect PA Teaching Cue

Treat the request as PA teaching when the user asks why a PA action matters, how a vault concept works, whether to approve a write, how confidence should be interpreted, or where a capture should go.
Do not teach when the user already gave a clear PA action and no concept is blocking execution.

### 2. Map To The User's Current Decision

Name the immediate PA or vault choice before explaining.
Typical choices include capture route, QMD retrieval breadth, memory versus source-note trust, frontmatter shape, wikilink target, daily note use, profile patch approval, agenda focus, review scope, and write-gate consent.

### 3. Load Core Teaching If Depth Calibration Is Needed

Load `core-teaching` only when the explanation needs careful depth calibration, the user asks repeated clarifying questions, multiple trade-offs are active, or the decision needs a structured teach-back.
Do not copy the core teaching playbook into this skill or into the PA response.

### 4. Explain With PA Vocabulary

Use the user's vault terms and the closest PA object rather than generic learning language.
Prefer concrete examples like "this capture belongs in today's daily note with a wikilink to the project note" over abstract explanations about knowledge management.
Name uncertainty honestly when QMD, profile confidence, memory, or source-note coverage is incomplete.

### 5. Bridge To Concrete Vault Action

End with the action the user can take next in the vault.
The bridge should name the target surface when known, such as an Obsidian note path, frontmatter field, `.pa/` profile file, QMD query, agenda review, or capture destination.
If the next action requires consent, phrase it as a decision rather than a lecture.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Explain versus act | If the user gave a clear vault operation and no concept is blocking it, act and skip teaching |
| Minimal depth | Use at most 2 sentences for a routing, consent, or confidence clarification unless the user asks for more |
| QMD explanation | Explain at most 3 retrieval concepts per response and only to the level needed to choose query breadth, citation sufficiency, or fallback behavior |
| Memory versus source notes | Say memory can guide lookup, but source notes are the citeable vault evidence for user-facing claims |
| Profile confidence | Explain confidence as evidence strength for the current profile field, not as certainty about the user's identity |
| Soul and persona | Use these terms only when response style or long-horizon preference handling is the current decision |
| Write-gate consent | Explain the action surface, reversibility, and approval requirement, then stop for the user's choice when required |
| Capture routing | Teach the smallest routing rule that decides the target note, frontmatter, wikilinks, or daily note placement |
| Agenda and focus | Explain scoring only enough to justify why an item is surfaced, deferred, or marked for review |
| Clarifying questions | Load core-teaching after 2 clarifying questions at the same depth level |
| Load `core-teaching` | Load it when the user needs depth calibration, a scaffolded choice, or a teach-back loop |
| Load PA peer skill | Load the relevant peer skill when the explanation depends on PA domain rules that this adapter only names |

## Reference Map

Load the vocabulary guide first for PA term definitions, then load peer skills for domain rules after the teaching cue has been mapped to a specific PA decision.

| PA Teaching Need | Reference |
|------------------|-----------|
| PA-specific term definitions, concept boundaries, and common misconceptions | `${CLAUDE_SKILL_DIR}/references/pa-vocabulary-guide.md` |

| PA Teaching Need | Peer Skill |
|------------------|------------|
| Explain QMD context retrieval, citation sufficiency, memory-first lookup, or source-note grounding | `${CLAUDE_SKILL_DIR}/../context-assembly/SKILL.md` |
| Clarify write-gate consent, posture, reversibility, `.pa/` state, privacy, or markdown source-of-truth boundaries | `${CLAUDE_SKILL_DIR}/../trust-and-boundaries/SKILL.md` |
| Explain agenda scoring, stale waiting-fors, horizon ranking, review flags, or focus selection | `${CLAUDE_SKILL_DIR}/../executive-assistance/SKILL.md` |
| Teach profile confidence, enrichment proposals, stale profile fields, or confirmation requirements | `${CLAUDE_SKILL_DIR}/../personal-profiling/SKILL.md` |
| Explain capture routing, triage, distillation, or note destination choice | `${CLAUDE_SKILL_DIR}/../capture-distillation/SKILL.md` |
| Explain vault profile, Obsidian structure, frontmatter conventions, or wikilink assumptions | `${CLAUDE_SKILL_DIR}/../vault-modeling/SKILL.md` |
| Explain soul, persona, response rendering, or style fallback behavior | `${CLAUDE_SKILL_DIR}/../persona-response/SKILL.md` |
| Explain review cadence, daily note reflection, resurfacing, or values-aligned review | `${CLAUDE_SKILL_DIR}/../review-and-journaling/SKILL.md` |

## See Also

Common consumers and peer components that trigger or receive PA teaching:

- **ask command** (`commands/pa/ask.md`) — Frequently needs concept explanation when retrieval results confuse the user
- **day command** (`commands/pa/day.md`) — Morning pass may surface items requiring agenda or focus explanation
- **survey command** (`commands/pa/survey.md`) — Vault profile results often need confidence and structure explanation
- `skills/core/teaching/SKILL.md` — Core decision-focused teaching methodology for depth calibration and cognitive-load handling
- `skills/pa/context-assembly/SKILL.md` — PA retrieval and QMD context grounding rules
- `skills/pa/trust-and-boundaries/SKILL.md` — Consent, posture, reversibility, and vault boundary rules
- `skills/pa/executive-assistance/SKILL.md` — Agenda, review, and focus scoring rules
- `skills/pa/personal-profiling/SKILL.md` — Profile confidence and enrichment rules

Extension points: future `${CLAUDE_SKILL_DIR}/learned.md` can capture PA-specific teaching patterns observed during sessions.
