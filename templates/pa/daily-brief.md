---
title: Daily Brief
description: Structured daily briefing template for today's commitments, risks, focus, and follow-ups
---

# Daily Brief Template

PA commands use this template when generating a daily briefing for the current day.
The chief-of-staff agent provides prioritization and the calling command renders this template from the active temporal overlay.

This template targets the user's daily note location.
When the active automation posture does not permit a write, the caller presents the same structure in the conversation or as a proposal.

## Rendering Rules

1. **Placement**: Save to `{{placement_rules.daily_dir}}/{{today_title}}.md`.
   If `{{placement_rules.daily_dir}}` does not exist or resolving this path would create a new directory, treat that as a structure change and follow `{{assistant_preferences.suggest_before_structure_changes}}`.
2. **Title**: Format the note title from today's date using `{{naming_rules.daily_note_pattern}}` in the active vault timezone.
   Do not prepend or append labels such as "Daily Brief" unless the vault pattern already does so.
3. **Temporal frame**: Resolve all sections against `{{timestamp}}` in `{{vault_timezone}}`.
   When using labels such as `today`, `tomorrow`, `overdue`, or `this week`, include the concrete date in parentheses.
4. **Today's Commitments**: Pull open or active items from `.pa/work.jsonl` that are due today, scheduled for today, overdue, or explicitly marked as current commitments.
   Order them by urgency, commitment strength, and proximity when that metadata is available.
5. **Risks & Deadlines**: Highlight overdue items first, then upcoming deadlines and time-sensitive risks inside `{{briefing_horizon_days}}`.
   Include dated anchors from `.pa/timeline.jsonl` when available.
   Include blockers, dependency risk, and calendar collisions when the assembled context supports them.
6. **Recent Activity**: Summarize relevant vault changes since `{{recent_activity_since}}`.
   Prefer changes tied to active projects, captured notes, daily notes, or newly surfaced evidence that materially changes today's priorities.
7. **Focus Suggestions**: Render 2-5 priority recommendations from the chief-of-staff.
   Each suggestion must trace to commitments, risks, recent activity, or waiting-fors included in the briefing inputs.
8. **Waiting-Fors**: List blocked items, delegated work, and follow-ups awaiting an external response or prerequisite.
   If no waiting-fors are active, state "No active waiting-fors."
9. **Sources**: Reproduce the caller's source index exactly.
   Do not add notes or records that were not part of the assembled daily context.
10. **Links**: Use `[[wikilinks]]` when `{{linking_style.prefer_wikilinks}}` is `true`, otherwise markdown links.

## Output Format

    # {{today_title}}
    
    > Generated: {{timestamp}} | Timezone: {{vault_timezone}} | Horizon: {{briefing_horizon_days}}d | Sources: {{source_count}}
    
    ## Today's Commitments
    
    {{today_commitments}}
    
    ## Risks & Deadlines
    
    {{risks_and_deadlines}}
    
    ## Recent Activity
    
    {{recent_activity}}
    
    ## Focus Suggestions
    
    {{focus_suggestions}}
    
    ## Waiting-Fors
    
    {{waiting_fors}}
    
    ## Sources
    
    | # | Type | Title | Path |
    |---|------|-------|------|
    | 1 | {{source_type}} | {{title}} | {{path}} |
    | 2 | {{source_type}} | {{title}} | {{path}} |

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `today_title` | Current date formatted with `{{naming_rules.daily_note_pattern}}` in `{{vault_timezone}}` | Required - do not render without a resolved daily title |
| `timestamp` | Current date/time at render | ISO 8601 format |
| `vault_timezone` | Active vault timezone from caller context | System timezone |
| `briefing_horizon_days` | Caller-provided deadline horizon for near-term risk scanning | `7` |
| `source_count` | Number of rows in the assembled source index | `0` if no results |
| `today_commitments` | Caller synthesizes from open and active items in `.pa/work.jsonl` | "No commitments identified for today." |
| `risks_and_deadlines` | Caller derives from approaching or overdue items in `.pa/work.jsonl` plus dated anchors from `.pa/timeline.jsonl` when available | "No immediate risks or deadlines identified." |
| `recent_activity_since` | Caller-provided lower bound for vault change scanning | Start of the current day in `{{vault_timezone}}` |
| `recent_activity` | Caller summarizes relevant vault changes from note updates, capture activity, or assistant ledger events | "No material recent activity detected." |
| `focus_suggestions` | Chief-of-staff priorities derived from the assembled daily context | "No focus suggestions available." |
| `waiting_fors` | Caller filters blocked or externally dependent items from `.pa/work.jsonl` and related context | "No active waiting-fors." |
| `placement_rules.daily_dir` | `vault-profile.json` -> `placement_rules.daily_dir` | Required for direct write - otherwise render as proposal only |
| `naming_rules.daily_note_pattern` | `vault-profile.json` -> `naming_rules.daily_note_pattern` | `"YYYY-MM-DD"` |
| `linking_style.prefer_wikilinks` | `vault-profile.json` -> `linking_style.prefer_wikilinks` | `true` |
| `assistant_preferences.suggest_before_structure_changes` | `vault-profile.json` -> `assistant_preferences.suggest_before_structure_changes` | `true` |

## Usage by Commands

Commands reference this template when rendering a daily briefing.

The calling commands (`/pa day` and `/pa agenda`) are responsible for:

- Loading open commitments, deadlines, and waiting-fors from `.pa/work.jsonl`
- Merging near-term dated context from `.pa/timeline.jsonl` when available so deadline and risk sections are temporally grounded
- Assembling a recent activity digest from relevant vault changes
- Obtaining priority recommendations from `chief-of-staff`
- Resolving the daily note path from the active vault profile
- Reproducing the source index without modification
- Deciding whether to write to today's daily note or present the briefing as read-only output based on posture and user intent
