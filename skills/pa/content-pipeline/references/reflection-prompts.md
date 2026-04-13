# Reflection Prompts — Consumption Journaling

> Purpose: Reference for `content-pipeline` skill — defines reflection question templates that transform passive content ingestion into active knowledge. After every ingest, the user is prompted with a short, source-aware question. Their response becomes a `## My Thoughts` section in the digest note.

## Core Principle

**"Not just what you read, but what you think about it."**

Consumption Journaling turns ingest from a clipping tool into a thinking tool. The reflection prompt is a single question, asked immediately after ingest, that helps the user attach their own meaning to external content. Unanswered prompts are surfaced in the evening daily flow as gentle reminders.

## Prompt Selection

Select the reflection prompt based on `source_shape`. Each shape has 3-4 candidate prompts. Rotate through them to avoid repetition — track the last-used prompt index per shape in `.pa/ingest-tracker.jsonl`.

### URL / Article

| # | Prompt |
|---|--------|
| 1 | 이 글에서 가장 인상 깊었던 부분은 무엇인가요? |
| 2 | 이 내용이 지금 하고 있는 일과 어떻게 연결되나요? |
| 3 | 이 글의 주장에 동의하나요? 왜요? |
| 4 | 이 글에서 나중에 다시 찾아볼 만한 것이 있다면? |

### PDF / Document

| # | Prompt |
|---|--------|
| 1 | 이 문서에서 핵심 메시지를 한 문장으로 요약한다면? |
| 2 | 이 내용 중 내 업무나 관심사에 직접 적용할 수 있는 부분은? |
| 3 | 이 문서를 읽고 새로 알게 된 것이 있나요? |
| 4 | 이 문서에서 더 깊이 파고들고 싶은 주제가 있나요? |

### YouTube / Video

| # | Prompt |
|---|--------|
| 1 | 이 영상의 핵심 메시지를 한 문장으로 정리한다면? |
| 2 | 이 영상에서 가장 기억에 남는 순간은? |
| 3 | 이 영상을 본 후 해보고 싶어진 것이 있나요? |

### Image / Scan

| # | Prompt |
|---|--------|
| 1 | 이 이미지를 저장하려는 이유가 뭔가요? |
| 2 | 이 이미지가 떠올리는 생각이나 아이디어가 있나요? |

### Paste / Excerpt

| # | Prompt |
|---|--------|
| 1 | 이 내용을 저장하려는 이유가 뭔가요? |
| 2 | 이 내용에서 나중에 다시 참고할 부분은? |
| 3 | 이 내용에 대한 당신의 입장은? |

### Bookmark / Saved Article

| # | Prompt |
|---|--------|
| 1 | 이 북마크를 저장한 이유가 뭐였나요? 지금도 같은 생각인가요? |
| 2 | 하이라이트한 부분 중 가장 중요한 것은? 왜 그렇게 생각하나요? |
| 3 | 이 글에서 실제로 적용해볼 수 있는 것이 있나요? |

## Prompt Delivery

1. **Timing**: Immediately after presenting the ingest digest (Phase 6 of `ingest.md`).
2. **Mechanism**: Conversational — present the prompt directly in output, wait for user's next message. Do not use AskUserQuestion (free-text reflection is more natural as a conversation turn).
3. **Format**: `> 💭 {prompt}\n>\n> 생각을 적어주세요. 건너뛰려면 "skip"이라고 답해주세요.`
4. **Response handling**:
   - **Substantive text**: append as `## My Thoughts` section to the digest note via Edit tool. Record `reflected: true` in `ingest-tracker.jsonl`.
   - **Skip keyword** ("skip", "스킵", "나중에", "패스", "pass"): record `reflected: false` in `ingest-tracker.jsonl`. Respond: "나중에 `/pa day --mode evening`에서 다시 물어볼게요."
   - User responds with substantive text → record `reflected: true`, `reflected_at: <ISO timestamp>`, `reflection_summary: <first 100 chars>` in `ingest-tracker.jsonl`.

## Ingest Tracker Schema

`.pa/ingest-tracker.jsonl` — append-only. One entry per ingest event, plus optional follow-up entries when reflection is added later (day evening). For a given `path`, the latest entry takes precedence. Consumers scan for today's entries where the latest entry per path has `reflected: false`.

```jsonl
{"path": "Clippings/understanding-transformers.md", "source_type": "youtube", "source_title": "Understanding Transformer Architecture", "ingested_at": "2026-03-24T14:30:00+09:00", "reflected": true, "reflected_at": "2026-03-24T14:31:00+09:00", "reflection_summary": "attention mechanism이 기존 RNN보다 병렬화에 유리하다는 점이 인상적...", "prompt_index": 1}
{"path": "Clippings/ai-landscape-2026.md", "source_type": "pdf", "source_title": "2026 AI Landscape Report", "ingested_at": "2026-03-24T15:00:00+09:00", "reflected": false, "reflected_at": null, "reflection_summary": null, "prompt_index": 2}
```

## Evening Follow-up

`/pa day --mode evening` reads `.pa/ingest-tracker.jsonl` for today's entries where `reflected: false`. If count > 0, surface:

> 오늘 ingest한 {n}건에 아직 코멘트가 없어요:
> - {title_1}
> - {title_2}
> 지금 짧게 생각을 남길까요?

If user responds per-item, update the digest notes and tracker entries.

## Weekly Compilation

`/pa compile` reads `.pa/ingest-tracker.jsonl` for the compilation period. Entries with `reflected: true` contribute to a `## Consumption Log` section in the period compilation, listing each ingested item with its reflection summary.

## Settings

`.pa/settings.json` optional fields:

```json
{
  "content_pipeline": {
    "reflection_prompts": true,
    "reflection_remind_evening": true
  }
}
```

- `reflection_prompts: false` — disable inline reflection after ingest
- `reflection_remind_evening: false` — disable evening follow-up for unreflected items

Both default to `true` when absent.
