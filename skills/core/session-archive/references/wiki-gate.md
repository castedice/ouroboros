# Session Wiki Gate

Purpose: Define the proposal-only gate for promoting raw archive segments into session-wiki pages.
Scope: Parallel to `skills/pa/trust-and-boundaries/references/write-gate-protocol.md`, but session-wiki has its own gate because it is outside the PA vault.

## Core Rule

Nothing lands in `wiki/` without explicit `/session-wiki apply <id>`.
The raw archive never changes when a wiki proposal is applied or rejected.
Every Stage 3 write is propose-only until the user chooses the apply command.

## Posture Context

DR-075 PA posture does not authorize session-wiki writes because session-wiki is outside the vault.
Session-wiki uses its own gate under `${CLAUDE_PLUGIN_DATA}/session-archive/wiki/`.
DR-105 never-auto applies directly because raw evidence must never cross into promoted knowledge automatically.
DR-106 collaboration posture applies as propose-only, never auto-write.

## Gate Sequence

1. Propose by writing a complete bundle under `${CLAUDE_PLUGIN_DATA}/session-archive/proposals/`.
2. Review by showing `manifest.json`, `review.md`, target paths, source segments, draft pages, and preimage hashes.
3. Apply only when the user runs `/session-wiki apply <id>`.
4. Check each existing target file against its recorded `preimage_hash` before any wiki write.
5. Write draft pages from `pages/` into `wiki/` only after every preimage check passes.
6. Append the apply or reject event to `wiki-ledger.jsonl`.
7. Append the latest proposal status row to `proposals/proposals.jsonl`.

## Proposal-Only Expectations

`/session-wiki propose` writes only to `proposals/`.
`/session-wiki show` reads proposals and wiki preimages but does not mutate `wiki/`.
`/session-wiki apply <id>` is the only promoted-write path.
`/session-wiki reject <id>` records rejection but does not delete raw archive rows or wiki pages.
QMD registration is manual only and must never be performed by `init`, `status`, `propose`, or `apply`.

## Reversal Hints

| Apply Mode | Reversal Hint |
|------------|---------------|
| Create | Delete `wiki/<project_slug>/<page_type>/<slug>.md` and append a ledger reversal event |
| Replace | Restore `proposals/<id>/preimage/<relative-wiki-target>.md` to `wiki/<relative-wiki-target>.md` and append a ledger reversal event |

Never silently edit ledger history.
Never rewrite the raw archive to make a wiki page easier to reverse.

## Fail-Open Rules

| Condition | Rule |
|-----------|------|
| Missing raw archive | Do not create a proposal, report archive unavailable, and keep other archive status checks usable |
| Missing QMD | Keep proposal flows working, report `session-wiki` unregistered, and print the manual registration command in status |
| Apply hash mismatch | Abort before writing wiki files, leave the proposal pending, and report manual drift |
| QMD update failure after apply | Keep wiki files, report the index as stale, and do not roll back the wiki write automatically |
| Lint failure | Report only and never block raw archive search, PA flows, or RnD flows |

## What This Gate Forbids

It forbids writing directly into `${CLAUDE_PLUGIN_DATA}/session-archive/wiki/` from synthesis.
It forbids treating PA posture as permission to mutate session-wiki pages.
It forbids auto-registering the QMD `session-wiki` collection for user convenience.
It forbids applying one page from a multi-page bundle while leaving the bundle partly pending.
It forbids bypassing the preimage hash check for replace proposals.
