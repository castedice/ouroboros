# Archetype Heuristics — Signature Patterns, Detection Criteria, and False Positives

> Purpose: Detection reference for `vault-modeling` — use it to score archetypes, infer folder roles, and explain why a vault fits or does not fit a known pattern.

This reference is standalone and can be consulted without the parent skill.
For the end-to-end profiling procedure, see `skills/pa/vault-modeling/SKILL.md`.

## Scoring Model

Score archetypes from repeated behavior, not from aspirational naming. Use the normalized score only as an internal aid and always pair it with written evidence.

| Signal Strength | Weight | Definition | Example |
|---|---|---|---|
| **Strong** | `0.30` | repeated structural signal across a large portion of authored notes | most active notes live in root, or most live in project subtrees |
| **Medium** | `0.15` | repeated supporting signal that sharpens a structural reading | dominant daily-note folder, consistent frontmatter family, recurring MOCs |
| **Light** | `0.05` | contextual clue that explains intent but should not decide alone | README note naming a system, one welcome note, one archived top-level folder |

Scoring rules:
- Use at least 3 strong or medium signals before assigning a named archetype.
- Ignore `.obsidian/`, `.pa/`, `.git/`, archives, and imported dumps unless they clearly shape active authored behavior.
- Prefer `hybrid` when two archetypes recur across the vault.
- Prefer `custom` when local logic is stable but does not map cleanly to the named set.
- Fail closed on uncertainty.

## Archetype Cards

### 1. Flat-Kepano

A flat-kepano vault keeps most authored notes at the root or one shallow layer and relies heavily on titles, links, and quick retrieval rather than deep folder nesting.

**Detection Signals (7 total)**:

| # | Signal | How to Check |
|---|--------|-------------|
| 1 | ≥ 60% of markdown files in vault root | File count: root vs. subfolders |
| 2 | ≤ 6 top-level folders | Glob depth-1 directory count |
| 3 | Folders named References/, Clippings/, Attachments/ | Exact or case-insensitive name match |
| 4 | Daily/ or daily/ folder with date-named files | Folder name + content pattern |
| 5 | Templates/ folder with ≤ 10 template files | Small template collection |
| 6 | Average ≥ 5 wikilinks per note (high link density) | Sampled note analysis |
| 7 | Minimal or no nested subfolders (max depth 2) | Directory tree depth analysis |

**Disconfirmers**: deep folder nesting (≥ 4 levels) with meaningful content at each level, project-per-folder organization, PARA folder names.

**False Positives**:
- New vaults often look flat because nothing has been filed yet. Check note count; if < 20, do not classify as flat-kepano.
- A large root plus one imported archive does not make the system flat-kepano unless active authored notes also behave that way.
- PARA vaults can look flat if only the top layer is visible and subfolders are sparse.

### 2. Nested-Project

A nested-project vault organizes notes around project or area trees where folder placement communicates state, scope, or ownership.

**Detection Signals (6 total)**:

| # | Signal | How to Check |
|---|--------|-------------|
| 1 | Folders named projects/, work/, clients/ at top level | Name match |
| 2 | ≥ 3 folders each containing ≥ 5 notes (project clusters) | Per-folder file counts |
| 3 | Average folder depth ≥ 3 | Directory tree analysis |
| 4 | < 30% of notes in vault root | Root vs. subfolder ratio |
| 5 | Project-specific README or index notes inside subfolders | File name detection |
| 6 | Nested subfolders like `notes/`, `meetings/`, `docs/`, `assets/` within project trees | Repeated subtree structure |

**Disconfirmers**: ≥ 60% of notes in root (indicates flat vault), no folder has ≥ 5 notes, deep nesting appears only in archives.

**False Positives**:
- Imported folder dumps (e.g., Notion export) may have deep nesting without intentional project organization. Check for Notion-style `*.csv` exports or UUID-named folders.
- Code repositories or imported documentation sets can mimic nested-project structure without representing the user's note-taking system.
- One large project subtree inside an otherwise flat vault should usually become `hybrid`, not a full nested-project classification.

### 3. Para-Like

A para-like vault groups notes into responsibility buckets such as Projects, Areas, Resources, and Archives, or close synonyms that play the same functional role.

**Detection Signals (6 total)**:

| # | Signal | How to Check |
|---|--------|-------------|
| 1 | Folders named Projects/ or 1-Projects/ (or similar numbered prefix) | Name match with prefix tolerance |
| 2 | Folders named Areas/ or 2-Areas/ | Name match |
| 3 | Folders named Resources/ or 3-Resources/ | Name match |
| 4 | Folders named Archive/ or 4-Archive/ | Name match |
| 5 | ≥ 3 of the 4 PARA folders present | Count of matches |
| 6 | Numbered prefix pattern on folders (0-, 1-, 2-, etc.) | Regex `^\d+-` on folder names |

**Disconfirmers**: no folder matches any PARA category name, root-heavy distribution (≥ 60% of notes in root), top-level bucket names exist but actual notes ignore them.

**False Positives**:
- The mere presence of `Projects` and `Resources` is not enough. Many vaults have a `Projects` folder without adopting a PARA worldview.
- Partial PARA: a vault with Projects/ and Archive/ but no Areas/ or Resources/ might be a simplified project structure. Require ≥ 3 of 4 PARA folders.
- Renamed PARA: some users rename PARA folders (e.g., "Active" instead of "Projects"). Numbered prefixes help detect these cases, but confidence should be lower (0.6-0.7).
- If only half the buckets are used and the rest are aspirational, prefer `custom` or `hybrid`.

### 4. Journal-First

A journal-first vault uses date-based notes as the main coordination layer and often compiles or links outward from daily or timestamped captures.

**Detection Signals (6 total)**:

| # | Signal | How to Check |
|---|--------|-------------|
| 1 | A single folder contains ≥ 100 date-named files | File count + date regex |
| 2 | Date-named files represent ≥ 40% of total vault notes | Proportion calculation |
| 3 | Daily notes contain timestamps or time-based headers | Content sampling |
| 4 | Few or no topical/evergreen notes outside daily folder | File type analysis |
| 5 | Recent daily notes (within last 7 days) exist | Modification date check |
| 6 | Review or compilation notes appear by week, month, or period | Compilation evidence |

**Disconfirmers**: daily notes represent < 15% of vault content, no folder has ≥ 20 date-named files, dated notes exist only for meetings or logs.

**False Positives**:
- Meeting notes named by date are not a journal system unless they cluster into a stable daily workflow. Check content: meeting notes typically have attendee lists and action items.
- Imported logs or exported chat transcripts can inflate date-like filenames.
- A single monthly review habit does not make the vault journal-first if everything else is project- or topic-driven.

### 5. Hybrid

A hybrid vault intentionally combines two or more stable organizational behaviors.

**Detection Criteria**: Hybrid is not detected by its own signals but by the absence of a clear winner:
- Top archetype score < 0.7, OR
- Top two archetype scores are within 0.15 of each other
- At least 2 archetypes score ≥ 0.4

**Characterization**: When classifying as hybrid, identify the contributing archetypes: "hybrid (flat-kepano + journal-first)" is more useful than "hybrid" alone. Record the top 2-3 archetype scores in the profile. Use `hybrid` when the mixture is stable and useful for future automation — do not use it as a vague middle ground when one archetype is obviously dominant.

Typical hybrid pairs: `journal-first` + `nested-project`, `flat-kepano` + `para-like`, `journal-first` + `flat-kepano`.

### 6. Custom

A custom vault uses a stable local logic that does not fit the named archetypes, or the evidence is too sparse or transitional for a confident mapping.

**Detection Criteria**:
- All archetype scores < 0.4, OR
- Vault structure uses an idiosyncratic organization that doesn't map to any known pattern
- Vault has fewer than 30 notes, or migration residue dominates

For custom vaults, folder-role inference becomes the primary modeling tool. Skip archetype-based defaults and infer every profile field from direct observation. `custom` is not a shortcut for "I did not look closely." If evidence is mixed between two named patterns, prefer `hybrid`, not `custom`.

## Quick Reference: Archetype Decision Tree

```
Start
 ├─ ≥3 PARA folders? → para-like (verify with signals 5-6)
 ├─ ≥60% notes in root + ≤6 folders? → flat-kepano (verify link density)
 ├─ ≥100 date files in one folder? → journal-first (verify proportion)
 ├─ ≥3 project clusters + depth ≥3? → nested-project (verify root ratio)
 ├─ Top 2 scores within 0.15? → hybrid (record contributing types)
 └─ All scores < 0.4? → custom (rely on folder-role inference)
```

This decision tree is a quick heuristic for initial classification. Always verify with the full signal set and apply confidence thresholds before finalizing.

## Folder-Role Inference

Infer folder roles from the combination of label, contents, and note behavior.

| Role | Strong Signals | Weak Signals | Common False Positive |
|---|---|---|---|
| `daily_dir` | concentrated date-named notes, repeated daily placement, recent activity | folder named `Daily` but mixed contents | dated meeting notes stored together without a daily-note practice |
| `templates_dir` | mostly skeletal notes with placeholders, repeated template reuse, low outbound links | folder named `Templates` | inactive archive of examples |
| `attachments_dir` | dominated by images, PDFs, media, or binary files | folder named `Assets` | project docs folder containing both notes and files |
| `references_dir` | durable source notes, clippings, reading notes, bibliographic materials | folder named `Resources` | active project material mislabeled as reference |
| `clippings_dir` | imported web captures, excerpts, highlights, inbox scraps | folder named `Inbox` | genuine authored scratch notes that should remain in authored root |
| `categories_dir` | stable taxonomy folders or hub folders that classify topical notes | folder named `Categories` | one-off index experiment or abandoned taxonomy |
| `authored_root` | significant volume of user-authored notes at root, especially evergreen notes | root contains many markdown files | temporary unsorted state in a new vault |

Role rules:
- Require at least 2 supporting signals for high confidence.
- Use content over name when they disagree.
- When two folders plausibly serve the same role, keep both as evidence and choose the one with current active use.

## Daily and Timestamp Pattern Detection

Use filename regex only as the first filter. A vault convention exists when regex, placement, and repetition agree.

| Logical Pattern | Regex | Typical Use | Common Misread |
|---|---|---|---|
| `YYYY-MM-DD` | `^\d{4}-\d{2}-\d{2}$` | daily notes, reviews | standalone meeting note |
| `YYYYMMDD` | `^\d{8}$` | compact daily or import-friendly naming | IDs or log export filenames |
| `YYYY-MM-DD HHmm` | `^\d{4}-\d{2}-\d{2} \d{4}$` | timestamp captures | manually named event notes |
| `YYYYMMDDHHmm` | `^\d{12}$` | machine-like capture flow | imported attachments or scans |
| nested `YYYY/MM/DD` path | path-based rather than basename-based | journal folders | archive by date rather than active daily practice |

Detection rules:
- Dominant daily pattern: at least 80% of date-like note names match one pattern and at least 70% live in one folder family.
- Timestamp notes enabled: at least 5 non-daily notes match a timestamp pattern or captures clearly use minute granularity.
- False positive hint: date-like notes exist but are isolated to one project or import dump.

## False-Positive Checklist

Run this checklist before finalizing the archetype.

| Check | Why It Matters | Safer Move |
|---|---|---|
| Are you classifying from folder names alone? | names are often aspirational or stale | verify with note placement and contents |
| Are archive or import folders inflating the counts? | cold storage can outnumber active notes | separate active authored behavior from storage |
| Is one active project subtree dominating the sample? | local structure can masquerade as vault structure | resample across unrelated folders |
| Is the vault mid-migration? | old and new systems coexist temporarily | prefer `hybrid` or `custom` |
| Is the vault too small for repetition? | patterns need recurrence | emit a low-confidence `custom` profile |
| Are date-like notes actually meetings or logs? | dates alone do not define journaling | require stable placement and repeated cadence |
