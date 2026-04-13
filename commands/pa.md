---
name: pa
description: "Use when you need to talk to your vault but are not sure which PA command to use"
allowed-tools:
  - Read
  - Agent
  - AskUserQuestion
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__status
argument-hint: "<just say what you need in natural language>"
---

# PA — Natural Language Router

Talk to PA naturally.
This router classifies the request inline, uses a fast path for simple work, and escalates to a full sub-command when the user asks for depth or the task is inherently complex.
Preserve the original request text for any later escalation.

Input: $ARGUMENTS

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/settings.json` | read | Verify setup, read QMD collection name, and read automation posture |
| `.pa/vault-profile.json` | read | Read linking style, frontmatter conventions, timestamp-note rules, and retrieval defaults |
| `.pa/work.jsonl` | read | Fast-path agenda summary input |
| `.pa/timeline.jsonl` | read | Fast-path agenda summary input |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No input | 1 | Ask: "무엇을 도와드릴까요? 질문, 메모, 노트 작성, 일정 확인 등 자유롭게 말씀하세요." |
| Clear survey or onboarding intent | 2 | Allow routing even if `.pa/settings.json` or `.pa/vault-profile.json` is missing |
| Missing setup for non-survey intent | 2 | Abort: "PA is not set up yet. Run `/pa survey <vault-path>` or `/pa init <vault-path>` first." |
| Intent remains ambiguous after classification | 3 | Ask the user to choose between the top `2-3` routes |
| Input is only a depth trigger and the previous `/pa` turn used fast path | 3.5 | Reuse the preserved original request and force deep path |
| Intent is fast-path capable and complexity is `simple` | 4a | Execute inline without agent spawning |
| Explicit depth request or complexity is `complex` | 4b | Delegate to the full sub-command |

## Phase 1: Parse Input

Read the full natural-language request from `$ARGUMENTS`.
Preserve the original text for fast-path escalation and deep-path handoff.
If the input is only `더 자세히`, `더 깊게`, `자세하게`, `deep`, or `full`, treat it as a depth trigger instead of a fresh task.
If the input is empty, resolve per the Decision Matrix.

## Phase 2: Verify Setup

Check whether `.pa/settings.json` and `.pa/vault-profile.json` exist.
If the request is clearly about onboarding, scanning, profiling, or vault setup, do not block on missing setup.
For every other intent, require both files before continuing.
Use `skills/pa/trust-and-boundaries/SKILL.md` for router-level posture and readiness checks only.
The delegated command owns full posture enforcement, escalation, and any write-time boundary decisions.

## Phase 3: Classify Intent

Classify inline from the user's text.
Do not call an agent for routing.
Assign `high` confidence when one route clearly dominates with no close fallback.
Assign `medium` confidence when one route leads but a nearby route still looks plausible.
Treat conflicting or weak signals as `low` confidence and ask the user instead of routing.

### Intent Matrix

| Intent | Signal Words or Patterns | Deep Route |
|--------|--------------------------|------------|
| `question` | `뭐야`, `알려줘`, `찾아줘`, `있어?`, `어떻게`, `why`, `what`, `where`, `?` | `/pa ask` |
| `briefing` | `정리해줘`, `브리핑`, `요약`, `에 대해`, `brief`, `summary`, topic-focused request | `/pa brief` |
| `capture` | `기록`, `메모`, `캡처`, `note this`, `save this`, raw thoughts, meeting notes, bullet dump | `/pa capture` |
| `draft` | `써줘`, `작성`, `노트 만들어`, `초안`, `draft`, explicit note creation | `/pa draft` |
| `revise` | `수정`, `고쳐`, `업데이트`, `revise`, `edit` plus a markdown or vault-relative path | `/pa draft --revise` |
| `agenda` | `오늘`, `할 일`, `뭐 해야`, `우선순위`, `중요한 거`, `priority`, `what matters` | `/pa agenda` |
| `day` | `하루 시작`, `아침`, `저녁`, `데이`, `morning`, `evening`, `daily flow` | `/pa day` |
| `survey` | `스캔`, `온보딩`, `프로필`, `vault setup`, `survey`, `set up my vault` | `/pa survey` |
| `link` | `연결`, `관계`, `링크`, `관련 노트`, `connection`, `related`, `link`, `어떤 노트랑 관련`, `연결된 거` | `/pa link` |
| `focus` | `집중`, `종합 분석`, `프로젝트 분석`, `dossier`, `focus`, `working context`, `전체 분석` | `/pa focus` |
| `ingest` | `가져와`, `import`, `ingest`, `외부`, `URL`, `이 글`, `이 기사`, `넣어줘`, `vault에 저장`, `클리핑` | `/pa ingest` |
| `compile` | `컴파일`, `정리`, `모아서`, `합쳐`, `요약 정리`, `compile`, `aggregate`, `period summary` | `/pa compile` |
| `review` | `리뷰`, `점검`, `방치`, `stale`, `orphan`, `건강`, `health check`, `방치된 노트`, `잊은 거` | `/pa review` |
| `reset` | `이번 주 정리`, `주간 정리`, `월간 정리`, `리셋`, `reset`, `weekly`, `monthly review` | `/pa reset` |
| `steward` | `관리`, `유지보수`, `vault 관리`, `vault 상태`, `maintenance`, `steward`, `정비` | `/pa steward` |

Prefer `question` when the user asks for a specific answer, and prefer `briefing` when they want a broad topic summary.
Prefer `capture` for raw material and `draft` for intentional note creation.
Prefer `revise` whenever edit intent includes a concrete note path.
Prefer `link` when the user asks about connections, relationships, or related notes for a specific note or topic.
Prefer `focus` when the user asks for comprehensive analysis, project dossier, or working context around a goal.
Prefer `ingest` when the user wants to import external content (URL, article, file) into the vault.
Prefer `compile` when the user wants to aggregate or synthesize accumulated captures into a summary.
Prefer `review` when the user asks about vault health, stale items, orphan notes, or forgotten context.
Prefer `reset` when the user wants a periodic reset combining review + compile + agenda + link (e.g., "이번 주 정리해줘").
Prefer `steward` when the user asks about vault maintenance, health check, or overall management (e.g., "vault 관리해줘").
If the top match is weak or two routes remain plausible, ask the user with `2-3` action-oriented options.

## Phase 3.5: Complexity Assessment

| Complexity | Signal | Execution |
|-----------|--------|-----------|
| `simple` | Short question under roughly `30` words, single-topic capture, compact briefing request, or quick status check with one dominant intent | Fast path |
| `complex` | Explicit depth cue, multi-topic synthesis, note creation or revision, temporal composition, or any request for `draft`, `revise`, `survey`, `day`, `focus`, `ingest`, `compile`, `review`, `reset`, or `steward` | Deep path |

Treat `agenda` as `simple` only when the user wants a quick priority summary for `today`, `week`, or `month`.
Treat `agenda` as `complex` when the user asks for a fuller daily flow, deeper prioritization, or explicit judgment beyond a quick summary.
When a depth trigger follows a fast-path answer, force `complex` and reuse the preserved original request.

## Phase 4a: Fast Path Execution

Use fast path only for `question`, `briefing`, `capture`, `agenda`, and `link`.
Read `.pa/settings.json` and `.pa/vault-profile.json` before executing any fast path.
Honor `linking_style.prefer_wikilinks`, `frontmatter.enabled`, `frontmatter.common_fields`, `placement_rules`, and `naming_rules.timestamp_note_pattern` in inline output.
For `question` and `briefing`, require a healthy `mcp__qmd__status` check before querying.

| Intent | Inline Execution |
|--------|------------------|
| `question` | Run paired lexical and vector `mcp__qmd__query` retrieval against the configured collection, read the top `2-3` results with `mcp__qmd__get`, and synthesize a concise answer with inline citations plus a short `Sources` list using `[[wikilinks]]` when preferred |
| `briefing` | Run inline QMD retrieval for the topic, read the top `2-3` results with `mcp__qmd__get`, and present a compact brief with a short summary, `2-4` key points, open gaps, and a short `Sources` list using vault link style |
| `capture` | Classify `input_form` and `capture_kind` inline, default the fast path to a safe `timestamp-note` proposal, and render the exact proposal using `templates/pa/timestamp-note.md` plus vault-profile timestamp, placement, frontmatter, and link rules without calling curator or writing any file |
| `agenda` | Read `.pa/work.jsonl` and `.pa/timeline.jsonl` directly, infer `today`, `week`, or `month` from the request and default to `week`, then present a quick priority summary with top items, deadlines, waiting-fors, and nearest dated anchors using concrete dates and no chief-of-staff |
| `link` | Read `.pa/entities.json` and `.pa/relations.json` if they exist plus the target note, extract wikilinks and check for unresolved links, run a paired QMD query for the topic, and present `1-2` narrow link suggestions with structural evidence. No relationship map, no weaver agent. Respect `link_density` from vault-profile |

Fast path never writes to the vault.
Use `더 자세한 답변이 필요하면 말씀하세요.` after `question`, `briefing`, `agenda`, and `link`.
Use `이 노트를 vault에 저장하려면 말씀하세요.` after `capture`.

## Phase 4b: Deep Path Delegation

Confirm the route with this template before handoff.
`Intent: <intent>`
`Confidence: <high|medium>`
`Complexity: complex`
`Invoke: <command>`

| Intent | Invocation | Command File | Handoff Rule |
|--------|------------|--------------|--------------|
| `question` | `/pa ask {request}` | `commands/pa/ask.md` | Pass the request unchanged |
| `briefing` | `/pa brief {topic}` | `commands/pa/brief.md` | Strip wrapper verbs like `정리해줘` or `brief me on` when obvious |
| `capture` | `/pa capture {request}` | `commands/pa/capture.md` | Pass the raw text unchanged |
| `draft` | `/pa draft {request}` | `commands/pa/draft.md` | Pass the creation request unchanged |
| `revise` | `/pa draft --revise {path}` | `commands/pa/draft.md` | Extract the path into `$ARGUMENTS` and preserve the full request as revision context |
| `agenda` | `/pa agenda --horizon {today\|week\|month}` | `commands/pa/agenda.md` | Map `오늘` or `today` to `today`, `이번 주` or `week` to `week`, `이번 달` or `month` to `month`, and default to `week` |
| `day` | `/pa day --mode {morning\|evening\|status}` | `commands/pa/day.md` | Map `아침` or `morning` to `morning`, `저녁` or `evening` to `evening`, `status` or `오늘 상태` to `status`, and default to `morning` |
| `survey` | `/pa survey {vault-path}` | `commands/pa/survey.md` | If no vault path is present, ask the user for one before routing |
| `link` | `/pa link {target}` | `commands/pa/link.md` | Pass the note path or topic unchanged |
| `focus` | `/pa focus {goal}` | `commands/pa/focus.md` | Pass the goal description unchanged. Focus is always deep path |
| `ingest` | `/pa ingest {source}` | `commands/pa/ingest.md` | Pass the URL, text, or file path unchanged. Always deep path |
| `compile` | `/pa compile [--from DATE] [--to DATE]` | `commands/pa/compile.md` | Extract date range if mentioned, otherwise use cadence default. Always deep path |
| `review` | `/pa review [--horizon HORIZON]` | `commands/pa/review.md` | Map time references to horizon: "이번 주"→week, "이번 달"→month, "올해"→year. Default week. Always deep path |
| `reset` | `/pa reset [--horizon HORIZON]` | `commands/pa/reset.md` | Same horizon mapping as review. Always deep path |
| `steward` | `/pa steward` | `commands/pa/steward.md` | No arguments. Always deep path |

When the user chooses from an ambiguity prompt, route immediately without reclassifying.
When a fast-path answer is escalated, delegate with the preserved original request instead of the depth-trigger phrase.
Do not add next-action suggestions here.
The delegated command handles domain-specific review, recommendations, and follow-up actions.

## Recovery

If the user rejects the proposed route, do not argue for it.
Reclassify from the original request or ask a direct clarifying question.
If the user requests depth after a fast-path answer, route to the deep path for the same intent using the preserved original request.
If no preserved original request is available, ask what they want to deepen before delegating.
If the delegated command fails before meaningful progress, say that the route failed and offer `2-3` choices.
The fallback choices are retry the same route, reclassify, or let the user state the intended action directly.
Preserve the original request so recovery never depends on a lossy rewrite.

## Rules

- **Progressive router**: Execute simple requests inline and delegate only when depth is requested or clearly needed
- **Inline classification only**: Never call an agent to decide the route
- **Fast path is read-only**: `question`, `briefing`, and `agenda` never write, and `capture` only proposes
- **Vault-profile fidelity**: Respect wikilink style, frontmatter conventions, and timestamp naming even in inline output
- **Korean-first signals**: Match Korean and English cues, but bias toward the Korean phrasing listed above
- **Ask instead of guessing**: When intent is unclear, present `2-3` plausible options and let the user choose
- **Minimal transformation**: Preserve the user's wording unless argument normalization is required for the selected deep route
