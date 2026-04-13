---
name: question-patterns
description: This reference provides mode-specific question sets for PA interviews. It should be consulted when an agent needs to "bootstrap profile", "run a catch-up interview", "run a direction check interview", "run a deep interview", "choose follow-up questions", or "map interview prompts to profile fields".
---

# Question Patterns - Mode-Specific Prompt Sets For PA Interviews

> Purpose: Reference for `interviewing` - choose the smallest question set that can raise profile confidence without turning the session into a script recital.
> This reference is standalone and can be consulted without the parent skill.
> For the interview workflow, see `skills/pa/interviewing/SKILL.md`.
> For profile field definitions, see `skills/pa/personal-profiling/references/profile-schema.md`.

## Scope

This reference provides reusable question sets for `bootstrap`, `catch-up`, `direction`, and `deep` interview modes.
It does not choose the mode or mutate the profile.
Use it to pick the next best question after reading the user's last answer.

## Usage Rules

Start with the mode's core questions and adapt wording to the user's language.
Ask one primary question at a time.
In `catch-up`, ask only about fields that may have changed or gone stale.
In `deep`, spend more time on follow-ups than on covering every topic.

## Bootstrap Questions

Use these five questions to seed a new profile.
Keep the tone broad and non-intrusive.

| # | Slot | Prompt | Primary Fields |
|---|------|--------|----------------|
| 1 | Role | "현재 주된 역할이나 하고 있는 일은 뭔가요?" | `identity.current_roles`, `identity.life_stage` |
| 2 | Areas | "삶에서 지속적으로 관리하고 있는 영역은 뭐가 있나요? `work`, `health`, `finance`, `relationships`, `learning`, `hobbies` 같은 것들이요." | `identity.core_areas` |
| 3 | Direction | "2-3년 뒤에 어디에 있고 싶은지 대략적으로 말해줄 수 있나요?" | `direction.long_term_direction`, `direction.directions_by_area` |
| 4 | Values | "의사결정할 때 가장 중요하게 생각하는 것은 뭔가요?" | `identity.values_and_principles` |
| 5 | Focus | "지금 가장 집중하고 있는 것은 뭔가요?" | `focus.current_focus`, `focus.current_commitments` |

## People Bootstrap Questions

Use these five questions to register a new person in the people graph.
Ask via `AskUserQuestion` one at a time.
Convert the real name to mask_id immediately after the first answer.

| # | Slot | Prompt | Target Field |
|---|------|--------|--------------|
| 1 | Name | "등록할 사람의 이름은 뭔가요?" | `mask-map.real_name` (immediately masked) |
| 2 | Relationship | "이 사람과의 관계는 어떻게 되나요? (동료, 가족, 친구, 멘토, 지인 등)" | `profile.relationship_type` |
| 3 | Context | "이 사람을 어떤 맥락에서 알고 있나요? 한 줄로 설명해 주세요." | `profile.context` |
| 4 | Trust | "이 사람의 정보를 어느 수준으로 보호할까요? (inner-circle: 가장 가까운 사람, standard: 일반, restricted: 공개 인물)" | `profile.trust_level` |
| 5 | Notes | "이 사람에 대해 기억해 둘 것이 있나요? (선택사항)" | `profile.notes` |

## Catch-Up Questions

Ask only about fields that may have changed.
Default to two or three questions.

| Situation | Prompt | Primary Fields |
|-----------|--------|----------------|
| Existing focus may be stale | "지난번에 {current_focus}에 집중한다고 하셨는데, 아직 그런가요?" | `focus.current_focus` |
| New or stopped areas possible | "새로 시작하거나 멈춘 영역이 있나요?" | `identity.core_areas`, `direction.paused_areas` |
| Role or workload may have shifted | "요즘 가장 큰 비중을 차지하는 역할이나 책임이 달라졌나요?" | `identity.current_roles`, `focus.current_commitments` |
| Direction confidence is soft | "예전 방향과 비교했을 때, 요즘은 어디로 더 기울고 있나요?" | `direction.long_term_direction`, `direction.directions_by_area` |

## Insight-Triggered Catch-Up Questions

Use these when specialist insight patterns are available during `catch-up` mode. At most one insight-driven question per survey, additive to the 2-3 gap-based questions above.

| Pattern | Prompt | Primary Fields |
|---------|--------|----------------|
| `stable` (3+ on-track) | "{area} 영역이 안정적으로 유지되고 있는데, 이 방향을 계속 유지하면 될까요? 아니면 더 높은 목표를 세워볼까요?" | `direction.directions_by_area[area]`, `focus.current_focus` |
| `declining` (3+ at-risk or needs-attention) | "{area} 영역에서 최근 계속 어려움이 보이는데, 이 영역의 우선순위나 방향을 조정할 필요가 있나요?" | `direction.directions_by_area[area]`, `direction.paused_areas`, `focus.current_focus` |
| `shifted-down` (on-track → at-risk/needs-attention) | "{area} 영역이 이전에는 안정적이었는데 최근 어려워지고 있어요. 뭔가 변화가 있었나요?" | `direction.directions_by_area[area]`, `focus.current_commitments` |
| `shifted-up` (at-risk/needs-attention → on-track) | "{area} 영역이 최근 좋아지고 있어요. 뭔가 변화가 있었나요?" | `direction.directions_by_area[area]`, `focus.current_focus` |

## Direction Questions

Use these during year-plus review or when the user asks whether their current trajectory still fits.
Keep the questions medium-depth and future-facing.

| # | Prompt | Primary Fields |
|---|--------|----------------|
| 1 | "올해 처음에 {long_term}을 향해 가고 있었는데, 지금도 그 방향이 맞나요?" | `direction.long_term_direction`, `direction.directions_by_area`, `direction.last_direction_review` |
| 2 | "이 기간 동안 가장 큰 변화가 있었다면 뭔가요?" | `identity.current_roles`, `identity.life_stage`, `focus.current_commitments` |
| 3 | "다음 1년에서 가장 중요한 것은 뭐가 될까요?" | `focus.current_focus`, `direction.directions_by_area` |
| 4 | "계속 가져가고 싶은 것과 내려놓고 싶은 것은 각각 뭐예요?" | `direction.paused_areas`, `focus.current_commitments` |
| 5 | "지금 속도나 방식이 원하는 삶의 방향과 맞는다고 느끼나요?" | `direction.long_term_direction`, `identity.values_and_principles` |

## Deep Interview Topics

Use these topics only in `deep` mode.
The goal is not to cover every topic mechanically.
The goal is to spend time where the user has real signal.

### Career

- "이 일을 시작한 계기는 뭐였어요?"
- "일할 때 가장 충만한 순간은 언제예요?"
- "5년 전과 지금 달라진 점은 뭐예요?"

Maps primarily to `identity.current_roles`, `direction.long_term_direction`, and `focus.current_commitments`.

### Values

- "절대 양보할 수 없는 것은 뭐예요?"
- "어떤 상황에서 가장 화가 나요?"
- "어떤 사람을 존경해요?"

Maps primarily to `identity.values_and_principles`.

### Energy

- "에너지를 얻는 활동은 뭐예요?"
- "에너지를 빼앗기는 것은 뭐예요?"
- "이상적인 하루의 모습은 어때요?"

Maps primarily to `identity.patterns.energy_sources`, `identity.patterns.energy_drains`, and `identity.patterns.ideal_day_signals`.

### Decisions

- "최근 가장 어려웠던 결정은 뭐였어요?"
- "후회하는 결정이 있다면 뭐예요?"
- "결정할 때 주로 어떤 과정을 거쳐요?"

Maps primarily to `identity.patterns.decision_style` and `identity.patterns.lessons_and_regrets`.

### Relationships

- "가장 중요한 관계는 누구와의 관계예요?"
- "관계에서 가장 중시하는 것은 뭐예요?"
- "갈등이 생기면 어떻게 해결해요?"

Maps primarily to `identity.patterns.relationship_patterns` and `identity.values_and_principles`.

### Life Transitions

- "인생에서 가장 큰 전환점은 언제였어요?"
- "그때 무엇을 배웠어요?"
- "지금 전환기에 있다면 어떤 전환을 지나고 있나요?"

Maps primarily to `identity.life_stage`, `identity.patterns.active_transitions`, and `identity.patterns.lessons_and_regrets`.

### Fears

- "가장 두려운 것은 뭐예요?"
- "실패에 대해 어떻게 생각해요?"
- "무엇이 당신을 멈추게 해요?"

Maps primarily to `direction.constraints_and_fears` and `identity.values_and_principles`.

## Persona Questions (Soul Layer)

Use these 3-5 questions to configure PA's soul layer during `/pa init`.
Questions 1-3 configure the render layer (frontmatter). Questions 4-5 configure the reasoning layer (body). Questions 4-5 are skippable — if skipped, default body sections from `templates/pa/soul.md` are used.

| # | Slot | Prompt | Target |
|---|------|--------|--------|
| 1 | Speech style | "제가 어떤 말투로 도와드리면 편할까요? (해요체/합니다체/반말)" | frontmatter: `formality`, `render_hints.honorific`, `render_hints.sentence_style` |
| 2 | Response style | "답변 스타일은 어떤 게 좋으세요? (부드럽게/균형/직설적으로)" | frontmatter: `directness`, `warmth`, `tone` |
| 3 | Emoji (optional) | "이모지를 사용할까요? (안 쓸래요/조금/적당히)" | frontmatter: `render_hints.emoji` |
| 4 | Relationship | "PA와의 관계를 어떻게 느끼고 싶어요? (전문적인 비서/오래된 동료/친한 친구)" | body: `## Relationship` |
| 5 | Principles | "PA가 어떤 원칙으로 도와드리면 좋을까요? 예: '사실 우선', '도전적으로', '안전하게'" | body: `## Principles` |

Question 3 is skippable: if the user does not express a preference, default to `emoji: "off"`.
Questions 4-5 are skippable: "이 질문은 건너뛰셔도 돼요. 기본 설정을 사용합니다."
Exact persona field mapping lives in `skills/pa/persona-response/references/persona-schema.md`.
Use this reference to choose the smallest question set.
Use the persona schema reference to translate answers into frontmatter or soul-body updates.

## Specialist Persona Questions

Use these 2-3 questions to shape a domain specialist's perspective during `/pa init` or `/pa specialist create`.
Ask one at a time via `AskUserQuestion`. Adapt wording to the specific area.

| # | Slot | Prompt Template | Target |
|---|------|-----------------|--------|
| 1 | Perspective | "{area} 전문가가 어떤 관점을 가졌으면 좋겠어요? 예를 들면 {example_a} 아니면 {example_b} 같은?" | Core Principles, Domain Methodology focus |
| 2 | Style | "조언 스타일은 어떤 게 좋아요? (보수적으로/균형 잡히게/적극적으로)" | Observation tone, risk sensitivity, suggestion aggressiveness |
| 3 | Priority | "이 영역에서 특별히 중요하게 봐줬으면 하는 것은? (선택사항)" | Domain Methodology priority, Calibration focus |

### Area-Specific Example Hints

Prompt 1의 `{example_a}` / `{example_b}`를 area에 맞게 조정:

| Area Pattern | Example A | Example B |
|-------------|-----------|-----------|
| health, fitness, exercise | 꾸준한 가벼운 운동, 지속가능성 | 기록 갱신, 체계적 훈련 프로그램 |
| finance, money, budget | 안정적, 저축/연금 중심 | 수익 극대화, 기회비용 관찰 |
| learning, study, skill | 깊이 우선, 한 분야 마스터리 | 폭 우선, 다양한 분야 탐색 |
| career, work | 승진/성과 중심, 전략적 | 워라밸 중심, 번아웃 방지 |
| (기타) | "어떤 방향으로 접근하면 좋을까요?" | (사용자 자유 응답) |

### Interview-to-Agent Mapping

| Answer | Generated Agent Impact |
|--------|----------------------|
| Perspective answer | Core Principles 1-2에 관점 반영, Domain Methodology의 평가 기준 결정 |
| Style: "보수적" | 리스크 민감도 높음, 변화에 주의 환기, 안정성 강조 |
| Style: "균형" | 증거 기반 중립 판단, 장단점 모두 제시 |
| Style: "적극적" | 기회 관찰 강조, 현 상태에 대한 도전적 질문, 행동 촉구 |
| Priority answer | Domain Methodology에 우선 평가 항목으로 반영, Calibration Good example의 핵심 관찰로 사용 |

## Follow-Up Question Patterns

Use these follow-ups only when the prior answer opened a real thread worth exploring.
Keep them short and specific.

- "왜?"
- "그때 어떤 느낌이었어?"
- "좀 더 구체적으로 말해줄 수 있어?"

## Maps To

Bootstrap questions primarily update `identity`, `direction`, and `focus` fields in `personal-profile.json`.
People bootstrap questions update `mask-map.json` lookup data and the person profile fields defined in `people-schema.md`.
Persona questions map into the soul and persona schema.
Specialist questions shape specialist agent principles, methodology emphasis, and calibration.

## Common Pitfalls

| Pitfall | Why It Fails | Prevention |
|---------|--------------|------------|
| Using the bootstrap list as a rigid script | The interview stops listening and starts surveying | Adapt order and phrasing once the user reveals signal |
| Asking catch-up questions about stable fields | The session becomes repetitive and low-trust | Use gap detection before selecting the question |
| Treating deep topics as a checklist | Depth disappears and fatigue rises | Stay with the strongest live thread |
| Mapping a question to too many fields | The synthesis becomes fuzzy | Map to the narrowest primary field first |
| Storing the real name after Question 1 | Real name leaks into processing context | Convert to mask_id immediately after receiving, use mask_id for all subsequent processing |

## Design Rationale

Why bootstrap stays at five questions: it should create a usable seed without forcing biography.
Why catch-up is gap-based: a mature profile should not require re-interviewing the whole person every refresh.
Why direction questions focus on trajectory: year-plus review is about alignment, not weekly task churn.
Why deep topics use narrative prompts: durable patterns are often revealed through stories, not labels.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/interviewing/SKILL.md` | Parent skill - interview flow, mode selection, and synthesis rules |
| `skills/pa/personal-profiling/SKILL.md` | Downstream consumer - profile lifecycle, gap detection, and confidence rules |
| `skills/pa/personal-profiling/references/profile-schema.md` | Schema target for mapped answers |
| `skills/pa/personal-ontology/references/people-schema.md` | Person schema target for people bootstrap and masking |
| `commands/pa/init.md` | Caller for `bootstrap` interviews |
| `commands/pa/survey.md` | Caller for `catch-up` interviews |
| `commands/pa/review.md` | Caller for `direction` interviews |
