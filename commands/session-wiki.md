---
name: session-wiki
description: "Use when you need to synthesize raw session archive segments into proposal-only wiki pages, review a pending proposal, apply or reject a proposal, lint the promoted wiki tier, or query the session-wiki QMD collection"
argument-hint: [propose|list|show|apply|reject|lint|query|status] [options]
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Bash(scripts/session-archive.sh *)
  - Bash(sha256sum *)
  - Bash(shasum *)
  - Agent
  - mcp__qmd__query
---

# Session Wiki - Proposal-Only Promotion

Promote raw session archive segments into reviewed session wiki pages.
This command writes drafts only under `proposals/` during synthesis and writes to `wiki/` only through explicit `apply`.
It never writes to `.pa/`, the vault, `docs/`, or RnD artifacts.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|------------|------|
| 1 | Read, Grep, Glob | Parse action arguments and inspect proposal or template files when needed |
| 2 propose | Bash (`scripts/session-archive.sh propose`) | Build mechanical proposal bundles from raw archive segments |
| 2 propose | Agent (`ouroboros:core:session-synthesizer`) | Draft wiki page markdown from bundle segments and return a write_plan |
| 2 propose | Bash (`sha256sum` or `shasum`) | Compute draft hashes for manifest `after_hash` fields |
| 2 list | Bash (`scripts/session-archive.sh proposal-list`) | Return latest proposal status rows |
| 2 show | Bash (`scripts/session-archive.sh proposal-show`) | Return manifest, draft pages, review markdown, and preimage diffs |
| 2 apply | Bash (`scripts/session-archive.sh proposal-apply`) | Promote draft pages into `wiki/` after preimage hash checks |
| 2 reject | Bash (`scripts/session-archive.sh proposal-reject`) | Record a rejection reason without deleting proposal audit data |
| 2 lint | Bash (`scripts/session-archive.sh wiki-lint *`) | Scan promoted wiki pages for stale pages, orphan pages, and dangling source citations |
| 2 query | `mcp__qmd__query` when registered | Query the manually registered `session-wiki` QMD collection |
| 2 status | Bash (`scripts/session-archive.sh wiki-status`) | Report wiki health and manual QMD registration hint |

## References

| Reference | Path | Usage |
|-----------|------|-------|
| Wiki schema | `skills/core/session-archive/references/wiki-schema.md` | Page frontmatter, body shape, path layout, grouping rules, and citation marker rules |
| Wiki gate | `skills/core/session-archive/references/wiki-gate.md` | Proposal-only gate, apply sequence, drift defense, and fail-open rules |
| Page template | `templates/core/session-wiki-page.md` | Markdown structure rendered by the synthesizer |
| Proposal template | `templates/core/session-wiki-proposal.md` | Review summary written to `proposals/<id>/review.md` |
| Archive script | `scripts/session-archive.sh` | Mechanical bundle creation, proposal list, show, apply, reject, and status actions |
| Synthesizer agent | `agents/core/session-synthesizer.md` | LLM synthesis contract for raw segment bundles |

## System Boundaries

| Boundary | Rule |
|----------|------|
| Propose-only guarantee | `propose` writes only under `proposals/`; only `apply <id>` writes into `wiki/` |
| No vault writes | Never write `.pa/`, engram, Obsidian vault files, or PA memory files |
| No PA posture | PA write posture does not authorize session wiki mutation |
| No auto registration | Never run `qmd collection add` automatically |
| Raw archive immutability | Never edit `index.sqlite` segments while proposing, applying, or rejecting |
| QMD isolation | Proposals are outside the `wiki/**/*.md` QMD pattern and invisible until applied |
| Drift defense | `apply` must abort on preimage hash mismatch unless the user re-proposes after manual edits |
| Audit retention | Rejected proposal directories remain for audit until a later prune flow exists |

## Phase 1 - Parse Input

Parse `$ARGUMENTS` into one action plus that action's remaining options.
Default to `status` when no action is provided.

| Action | Arguments | Route |
|--------|-----------|-------|
| `propose` | Selectors such as `--task-key`, `--component`, `--session`, `--query`, `--since`, `--project`, and threshold flags | Run the proposal synthesis flow |
| `list` | Optional `--status pending|applied|rejected|all` | Run proposal list |
| `show` | Required `<proposal-id>` | Run proposal show |
| `apply` | Required `<proposal-id>`, optional `--force` | Run proposal apply |
| `reject` | Required `<proposal-id>` and `--reason "..."` | Run proposal reject |
| `lint` | Optional `--stale-days N` | Run wiki lint |
| `query` | Required `<question>` | Run QMD query if `session-wiki` is registered |
| `status` | Optional `--format json|text` | Run wiki status |

Unknown actions abort with the accepted action list.
Missing ids abort before any script call.
Missing rejection reasons abort before any script call.

## Phase 2 - Action Execution

### `propose`

Run the mechanical bundle builder first.

```text
bash scripts/session-archive.sh propose {selectors} --format json
```

Use non-dry-run mode for `/session-wiki propose`.
Do not pass `--dry-run` unless the user explicitly asked for a shell-level dry run.
If the script returns zero proposals, report the message and stop.

For each returned proposal:

1. Read `proposals/<id>/manifest.json`.
2. Read `proposals/<id>/bundle.json`.
3. For each `target_pages[]` entry, select the matching segment subset from the bundle.
4. Read `templates/core/session-wiki-page.md`.
5. If the target wiki page already exists, read that page as `existing_page_content`; otherwise pass `null`.
6. Delegate to `ouroboros:core:session-synthesizer` with the Agent input from the Delegation Contract.
7. Require a `write_plan.mode` of `proposal-only`.
8. Write `write_plan.rendered_content` to `proposals/<id>/pages/<relative-wiki-target>.md`.
9. Compute `after_hash` from the draft page using `sha256sum` or `shasum -a 256`.
10. Update `manifest.json` with `draft_path`, `after_hash`, `synthesis_confidence`, `claim_citations`, and `reversal_hint`.
11. Render `proposals/<id>/review.md` from `templates/core/session-wiki-proposal.md`.
12. Report the proposal id, target pages, confidence, and next review command.

Never write the synthesized page directly to `wiki/`.
If one page fails synthesis, mark that page as `synthesis-failed` in the manifest and do not apply the bundle.
If the synthesizer returns prose without a parseable write_plan, leave the proposal pending and report the parse failure.

### `list`

Run:

```text
bash scripts/session-archive.sh proposal-list {--status status?} --format json
```

Format the result as a compact table with proposal id, status, updated time, target page count, segment count, and session count.
If no proposals match, say so and stop.

### `show <id>`

Run:

```text
bash scripts/session-archive.sh proposal-show <id> --format json
```

Display `review_md` first when present.
Then display a manifest summary with status, target pages, source segment count, confidence, and reversal hint.
For each draft page, show the relative path, size, first lines, and any preimage diff summary.
If the script reports a missing manifest, stop and surface the error.

### `apply <id>`

Run:

```text
bash scripts/session-archive.sh proposal-apply <id> {--force?} --format json
```

Report applied target wiki paths, final content hashes, catalog regeneration paths, and the reversal hint.
If the script reports a preimage hash mismatch, tell the user the proposal stayed pending and should be rejected or re-proposed.
`--force` only bypasses the pending-status check.
It does not bypass drift checks or unexpected target-existence checks.

### `reject <id> --reason "..."`

Run:

```text
bash scripts/session-archive.sh proposal-reject <id> --reason "{reason}" --format json
```

Report the rejected proposal id, decided timestamp, and reason.
Do not delete `proposals/<id>/`.
Do not mutate `wiki/`.

### `lint`

Run:

```text
bash scripts/session-archive.sh wiki-lint {--stale-days N?} --format json
```

Format the result as a compact findings table with `wiki_key`, `flags`, `missing_count`, `age_days`, and `reason`.
If `flagged` is `0`, report `Session wiki is clean`.
For each finding, include the remediation suggestion "run `/session-wiki propose --task-key <k>` to refresh".
Lint is diagnostic only and never edits wiki pages or raw archive rows.

### `query <question>`

First run:

```text
bash scripts/session-archive.sh wiki-status --format json
```

If `qmd_registered` is `false`, report that `session-wiki` is not registered and print this manual registration hint.

```bash
qmd collection add session-wiki "$CLAUDE_PLUGIN_DATA/session-archive/wiki" --pattern '**/*.md'
qmd update && qmd embed
```

If `qmd_registered` is `true`, call `mcp__qmd__query` with collection `session-wiki` and the user's question.
Return wiki page hits with title, path, excerpt, confidence if present, and cited `[SA<n>]` markers when the hit text includes them.
If QMD returns zero results, say that the wiki has no registered match and suggest using `status` to check page count.

### `status`

Run:

```text
bash scripts/session-archive.sh wiki-status --format json
```

Report archive root, wiki dir, page count, pending proposal count, QMD registration state, and last lint timestamp if present.
When QMD is unregistered, print the manual registration hint exactly.

### Bounded Recovery

Recovery is bounded and must detect non-convergence.

- For `propose`, allow max 1 retry per proposal page only for transient synthesis or parse failures.
- After 1 retry fails, mark the page `synthesis-failed` in `manifest.json`, leave the proposal pending, and stop synthesis for that proposal.
- Do not run unbounded retry loops or fallback loops.
- Treat repeated synthesizer output without a parseable `write_plan` as non-convergence and stop after the bounded retry.
- For `apply` and `reject`, abort immediately on preimage hash mismatch; do not retry and do not use a fallback promotion path.

## Delegation Contract

Use this Agent call only for the `propose` action.

```text
Agent(subagent_type: "ouroboros:core:session-synthesizer")
```

Pass the input as an explicit payload.
Do not tell the synthesizer to use prior chat context.

```json
{
  "bundle_json": {
    "proposal_id": "PROMO-YYYYMMDD-HHMMSS-slug",
    "segments": [
      {
        "segment_id": "main:session:12:0",
        "content": "short segment text",
        "session_id": "session",
        "agent_kind": "main",
        "speaker": "assistant",
        "segment_kind": "text",
        "ts": "2026-04-11T00:00:00Z",
        "component_hint": "scripts/session-archive.sh",
        "source_ref": "~/.claude/projects/project/session.jsonl:12"
      }
    ],
    "agent_kind_mix": {
      "main": 5,
      "subagent": 3
    }
  },
  "wiki_key": "components/scripts-session-archive",
  "page_type": "component",
  "project_slug": "-Users-kibum-park-workspace-ouroboros",
  "grouping_rule": "task_key",
  "page_template": "templates/core/session-wiki-page.md",
  "min_supporting_segments": 2,
  "existing_page_content": null
}
```

Expect this output shape.

```json
{
  "write_plan": {
    "mode": "proposal-only",
    "rendered_content": "<complete markdown>",
    "supporting_segment_ids": ["main:session:12:0"],
    "claim_citations": [
      {
        "claim_text": "Claim text.",
        "segment_ids": ["main:session:12:0"]
      }
    ],
    "confidence": "high",
    "reversal_hint": "delete wiki/<target>.md or restore proposals/<id>/preimage/<target>.md",
    "decisions_found": [],
    "open_questions": [],
    "dropped_claims": []
  }
}
```

The command writes only `write_plan.rendered_content`.
The command stores `supporting_segment_ids`, `claim_citations`, `confidence`, and `reversal_hint` in `manifest.json`.

## Manifest And Review Writes

The `propose` action must leave a proposal directory self-contained enough for a later shell-only `show`, `apply`, or `reject` action.
Update the manifest only after the draft file is written and hashable.

| Manifest Field | Source | Rule |
|----------------|--------|------|
| `target_pages[].draft_path` | Written draft page | Store the proposal-relative draft path under `pages/` |
| `target_pages[].after_hash` | Draft hash | Store `sha256:<hash>` for the draft content, not the live wiki file |
| `synthesis_confidence` | Synthesizer write_plan | Use the lowest page confidence when a proposal contains multiple pages |
| `claim_citations` | Synthesizer write_plan | Preserve the full claim-to-segment map for review |
| `supporting_segment_ids` | Synthesizer write_plan | Preserve the cited segment ids and keep them within `source_segments` |
| `reversal_hint` | Synthesizer write_plan | Prefer create or replace wording based on `preimage_hash` |
| `status` | Script state | Leave as `pending` during propose |
| `decided_at` | Script state | Do not set during propose |

Render `review.md` from `templates/core/session-wiki-proposal.md` after manifest update succeeds.
The review file is a human aid, not the source of truth.
If review rendering fails, keep the manifest and draft and report that `show` will fall back to raw manifest output.

| Review Placeholder | Value |
|--------------------|-------|
| `{{PROPOSAL_ID}}` | Manifest `proposal_id` |
| `{{TARGET_PAGES}}` | Count and relative paths from `target_pages[]` |
| `{{SOURCE_SEGMENT_COUNT}}` | Manifest `segment_count` |
| `{{CONFIDENCE}}` | Manifest `synthesis_confidence` |
| `{{TRIGGER}}` | Compact JSON or text summary of `trigger.selectors` |
| `{{APPLY_COMMAND}}` | `/session-wiki apply <proposal-id>` |
| `{{REJECT_COMMAND}}` | `/session-wiki reject <proposal-id> --reason "<reason>"` |
| `{{REVERSAL_HINT}}` | Manifest `reversal_hint` or `not recorded` |

## Decision Matrix

| Condition | Action | Outcome |
|-----------|--------|---------|
| No action | 1 | Route to `status` |
| Unknown action | 1 | Abort with accepted action list |
| `propose` returns no proposals | propose | Report the script message and stop without synthesis |
| `propose` returns a bundle with no target pages | propose | Mark synthesis failed and stop |
| `propose` bundle is missing `bundle.json` | propose | Abort and keep proposal pending |
| Synthesizer omits `write_plan` | propose | Abort the page draft and keep proposal pending |
| Synthesizer returns non-`proposal-only` mode | propose | Reject the returned draft and keep proposal pending |
| Draft page cannot be hashed | propose | Abort manifest update and keep proposal pending |
| Review template missing | propose | Still keep draft and manifest; report review rendering failed |
| No proposals match `list` filter | list | Print an empty result |
| `show` missing id | show | Abort before script call |
| `show` manifest absent | show | Surface `proposal not found` from the script |
| `apply` missing id | apply | Abort before script call |
| `apply` proposal not pending | apply | Surface `proposal not pending`; user may pass `--force` for status only |
| `apply` draft page missing | apply | Abort before any wiki write |
| `apply` preimage hash mismatch | apply | Abort before any wiki write and leave proposal pending |
| `apply` target exists but preimage hash is null | apply | Abort unless the user re-proposes or the script explicitly supports a force flow |
| `apply` catalog regeneration fails | apply | Keep applied wiki files and report stale catalogs |
| `reject` missing id | reject | Abort before script call |
| `reject` missing reason | reject | Abort before script call |
| `reject` proposal absent | reject | Surface `proposal not found` from the script |
| `lint` returns zero findings | lint | Report `Session wiki is clean` |
| `lint` returns findings | lint | Render compact findings table and remediation suggestion |
| `lint` reports unavailable | lint | Report unavailable state and keep proposal/query/status flows unaffected |
| `query` missing question | query | Ask for a question |
| `query` QMD unregistered | query | Print manual registration hint and stop |
| `query` QMD unavailable | query | Report unavailable and keep proposal flows unaffected |
| `status` script fails | status | Surface the script error unchanged |

## Fail-Open Rules

| Failure | Rule |
|---------|------|
| Missing raw archive | Do not create proposals; report archive unavailable and keep `status` usable |
| Missing QMD | Keep `propose`, `list`, `show`, `apply`, `reject`, and `status` usable |
| Synthesis failure | Keep the mechanical proposal pending and do not write to `wiki/` |
| Partial multi-page synthesis | Keep the whole proposal pending until every target page has a draft |
| Apply drift | Abort before wiki writes and leave proposal pending |
| Reject failure | Do not delete proposal directories as a cleanup shortcut |
| Lint unavailable | Report diagnostic unavailability and do not block proposal, query, or status flows |
| QMD update failure after apply | Keep wiki files and report index staleness |

Fail-open means local proposal state remains inspectable.
It never means promoting a draft without the apply gate.

## Phase 3 - Output Assembly

Assemble each action's result for the user using the relevant format below.
When an action encounters a failure, apply the Fail-Open Rules before rendering the final response.

### Propose

```text
proposal_id: PROMO-20260411-142209-session-archive-phase3
status: pending
target_pages: 1
source_segments: 8
synthesis_confidence: medium
review: /session-wiki show PROMO-20260411-142209-session-archive-phase3
apply: /session-wiki apply PROMO-20260411-142209-session-archive-phase3
```

### List

```text
Proposal ID                                      Status    Updated                Pages
PROMO-20260411-142209-session-archive-phase3    pending   2026-04-11T14:22:09Z   1
```

### Show

```text
# Session Wiki Proposal PROMO-20260411-142209-session-archive-phase3

status: pending
target: wiki/-Users-kibum-park-workspace-ouroboros/components/scripts-session-archive.md
draft: proposals/PROMO-20260411-142209-session-archive-phase3/pages/wiki/-Users-kibum-park-workspace-ouroboros/components/scripts-session-archive.md
preimage_hash: null
after_hash: sha256:...
```

### Apply

```text
applied: PROMO-20260411-142209-session-archive-phase3
targets:
- wiki/-Users-kibum-park-workspace-ouroboros/components/scripts-session-archive.md sha256:...
reversal_hint: delete the created wiki target and append a ledger reversal event
```

### Reject

```text
rejected: PROMO-20260411-142209-session-archive-phase3
reason: too broad
proposal_dir: kept for audit
```

### Lint

```text
wiki_key    flags                    missing_count    age_days    reason
components/scripts-session-archive    stale,orphan    0                120         age_days=120 exceeds stale_days=90
```

### Query

```text
session-wiki is not registered.
Run:
qmd collection add session-wiki "$CLAUDE_PLUGIN_DATA/session-archive/wiki" --pattern '**/*.md'
qmd update && qmd embed
```

### Status

```text
archive_root: ~/.claude/plugins/data/ouroboros-inline/session-archive
wiki_dir: ~/.claude/plugins/data/ouroboros-inline/session-archive/wiki
wiki_page_count: 0
pending_proposals: 0
qmd_registered: false
```

### Completion

End with the applied, rejected, or pending proposal id when an action changes proposal state.
For read-only actions, end with the next useful command only when it follows directly from the result.
