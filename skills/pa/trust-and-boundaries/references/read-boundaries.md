---
name: read-boundaries
description: Shadow-only read rules, authored-path deny generation logic, flat vault handling, and fail-closed principle for the PreToolUse Read guard.
---

# Read Boundaries — Shadow-Only Access Rules

> Purpose: Detection and execution reference for `trust-and-boundaries` — defines when and how the Read guard blocks direct vault note access and redirects to the shadow vault.
> This reference is standalone and can be consulted without the parent skill.

## Scope

This reference governs the PreToolUse Read hook (`scripts/pa-read-guard.sh`) and the `deny-paths.json` configuration that drives it. It covers:

- Which vault paths are denied (authored content)
- Which paths are always allowed (.pa/, shadow, non-vault)
- How deny-paths.json is generated from vault-profile.json
- Fail-closed behavior when shadow copies are missing
- Graceful degradation when deny-paths.json is absent

## deny-paths.json Schema

Location: `{vault}/.pa/deny-paths.json`

```json
{
  "vault_root": "/Users/example/obsidian/my-vault",
  "shadow_root": "/Users/example/.cache/ouroboros/shadow/my-vault-a1b2c3d4",
  "denied_paths": [
    "notes/**",
    "journal/**",
    "Daily/**",
    "References/**",
    "Clippings/**"
  ],
  "allowed_prefixes": [
    ".pa/"
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `vault_root` | yes | Absolute path to the vault directory |
| `shadow_root` | yes | Absolute path to the external shadow vault |
| `denied_paths` | yes | Array of glob patterns for denied vault-relative paths. Use `dir/**` for directory trees |
| `allowed_prefixes` | yes | Array of vault-relative prefixes that are always allowed even if they match a denied pattern |

## Deny Path Generation Rules

Generated during `/pa survey` Phase 7 from `vault-profile.json` `placement_rules`.

### Authored Folders to Deny

Include these folders from vault-profile.json when they exist:

| Profile Field | Example Value | Deny Pattern |
|---------------|---------------|--------------|
| `authored_root` (when not `.`) | `notes` | `notes/**` |
| `daily_dir` | `Daily` | `Daily/**` |
| `references_dir` | `References` | `References/**` |
| `clippings_dir` | `Clippings` | `Clippings/**` |
| `categories_dir` | `Categories` | `Categories/**` |
| Any non-excluded folder with markdown | `journal` | `journal/**` |

### Excluded from Deny

These folders are never denied:

| Folder | Reason |
|--------|--------|
| `.pa/` | Assistant state — always readable |
| `.obsidian/` | App config — not user content |
| `.trash/` | Deleted content |
| `.git/` | Version control |
| `templates_dir` | Templates are structural, not authored PII |
| `attachments_dir` | Binary attachments, not markdown content |

### Flat Vault Handling

When `authored_root` is `.` (vault root), the deny pattern covers all top-level markdown files. Generate deny patterns for each non-excluded folder that contains markdown files, plus a root-level `*.md` pattern if top-level notes exist.

## Read Guard Behavior

### Resolution Order

1. Parse `file_path` from `$TOOL_INPUT`
2. Find `deny-paths.json` by walking up from the file path
3. If no `deny-paths.json` found → pass through (PA not configured)
4. If file is not under `vault_root` → pass through
5. If file matches `allowed_prefixes` → pass through
6. If file is under `shadow_root` → pass through
7. If file matches any `denied_paths` pattern → **deny** (exit 2)
8. Otherwise → pass through

### Fail-Closed Principle

When a read is denied:

| Shadow File Exists? | Behavior |
|---------------------|----------|
| Yes | Deny with message: "Use shadow path instead: {shadow_path}" |
| No | Deny with message: "Shadow copy not found for: {relative_path}" |

**Never fall back to raw vault content when deny is active.** If the shadow copy is missing, the read fails. This prevents accidental PII exposure from stale or incomplete shadow syncs. The user should run `pa-shadow.sh sync` to regenerate.

### Graceful Degradation

| Condition | Behavior |
|-----------|----------|
| `deny-paths.json` absent | Hook passes through silently — PA-unaware users unaffected |
| `deny-paths.json` malformed | Hook passes through (jq parse failure treated as absent) |
| `shadow_root` not set | Hook passes through (no shadow to redirect to) |
| `vault_root` empty | Hook passes through |
| Non-vault path | Hook passes through |

## Operational Thresholds

| Parameter | Threshold | Rationale |
|-----------|-----------|-----------|
| `denied_paths` max entries | 50 patterns | Beyond 50, per-read jq iteration adds measurable latency (>100ms). Consolidate with broader globs |
| `deny-paths.json` max file size | 4 KB | Parsed on every Read call. Larger files indicate pattern bloat |
| Directory walk depth (find_deny_paths) | 10 levels | Hard limit in `pa-read-guard.sh`. Deeper vaults need `PA_VAULT_PATH` env |
| Hook timeout | 3 seconds | Set in `hooks.json`. Exceeding means jq or filesystem is slow — hook passes through on timeout |
| Shadow staleness | Re-sync after any vault edit | `pa-shadow.sh sync --incremental` after note changes. Stale shadow = fail-closed denial |

## Common Pitfalls

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Forgetting to regenerate deny-paths.json after vault restructure (new folders added) | Deny Path Generation | Re-run `/pa survey` after adding new authored folders. Survey Phase 7 regenerates deny-paths.json from current vault-profile.json |
| Using `Read` tool during survey instead of `Bash` for raw vault access | Survey Integration | Always use `cat`/`head` via Bash for one-time raw vault scanning. The Read hook will block denied paths |
| Shadow vault not synced after note edits — fail-closed blocks reads | Shadow Sync | Run `pa-shadow.sh sync {vault} --incremental` after editing vault notes. Autopilot handles this nightly |
| Assuming deny covers all vault files when `authored_root = "."` | Flat Vault Handling | Flat vaults need per-folder patterns plus root `*.md` — verify deny-paths.json covers top-level notes |
| Deleting deny-paths.json without understanding consequences | Disabling | Deletion disables all Read deny. Vault notes become directly readable by AI. Re-run survey to restore |

## Survey Integration

Survey Phase 3 (Vault Scan) is the one-time raw vault exposure. To read raw notes during survey:
- Use `Bash` tool (`cat`, `head`) which bypasses the PreToolUse Read hook
- Or run survey before `deny-paths.json` exists (first survey)

After survey completes, `deny-paths.json` is created and subsequent `Read` calls are guarded.

## Command Integration

Commands that read vault notes must use shadow paths when available:

| Command | Shadow Usage |
|---------|-------------|
| `link.md` | Read target notes from `{shadow_root}/{path}` |
| `focus.md` | Read target notes from `{shadow_root}/{path}` |
| `draft.md` | Read target and exemplar notes from shadow. `--revise` is proposal-only when Read deny is active |
| `day.md` | Read daily notes from shadow |
| `capture.md` | Duplicate checks via shadow |
| `compile.md` | Source note reads via shadow |
| `review.md` | Sentinel uses shadow paths for vault note inspection |

## Disabling Read Deny

Users can disable the Read guard by deleting `.pa/deny-paths.json`. The hook passes through when the file is absent. Re-run `/pa survey` to regenerate.

## See Also

| Component | Relationship |
|-----------|--------------|
| `scripts/pa-read-guard.sh` | Implementation of the PreToolUse Read hook |
| `scripts/pa-shadow.sh` | Shadow vault sync that creates the protected copies |
| `skills/pa/personal-ontology/references/privacy-node-schema.md` | 5-layer protection and shadow vault schema |
| `skills/pa/trust-and-boundaries/references/masking-rules.md` | Masking operations applied during shadow sync |
| `hooks/hooks.json` | Hook registration for the Read matcher |
