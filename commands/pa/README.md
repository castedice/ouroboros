# PA Module

Personal Assistant for Obsidian Second Brain — a trusted chief of staff for markdown vaults.

## Philosophy

PA is not a vault optimizer and not a search engine. It is a **trusted chief of staff** that decides what context matters, turns it into useful action, writes durable notes in the vault's native style, and helps notice patterns, commitments, and connections that would otherwise be missed.

Three architectural principles:

| Principle | What It Means |
|-----------|---------------|
| **Methodology-aware, not imposing** | Adapt to the vault's existing conventions. Never convert to a different system |
| **Trust is the product** | Every action governed by automation posture. Reversible, provenance-backed, conservative when unsure |
| **File over app** | User-facing state lives in readable markdown. Hidden state only for semantic overlays and trust controls |

## Three-Plane Architecture

```text
┌─────────────────────────────────────────────────────┐
│                    PA Intelligence                   │
│   (commands, agents, skills — meaning & action)      │
├──────────┬──────────────────┬────────────────────────┤
│  QMD     │  Filesystem      │  ob sync               │
│ retrieve │ read + write     │ cloud sync              │
└──────────┴──────────────────┴────────────────────────┘
         optional: Obsidian CLI (runtime metadata)
```

| Plane | Role |
|-------|------|
| **QMD** | Semantic + fulltext retrieval via MCP/CLI |
| **Filesystem** | All vault read/write. Always available, no app dependency |
| **ob sync** | Cloud synchronization. Headless, no Obsidian app required |
| **Obsidian CLI** | Optional runtime metadata (backlinks, graph stats) |

## Commands

All commands are always available.
Stages indicate when each command has enough vault data to be most useful.

### Natural Language Entry Point

| Command | Type | Stage | Description |
|---------|------|-------|-------------|
| `/pa <자연어>` | router | `all` | Say anything — PA classifies intent and routes. Fast path for simple requests, deep path on demand |

### Phase 1

| Command | Type | Stage | Description |
|---------|------|-------|-------------|
| `/pa survey <vault-path>` | primitive | `setup` | Onboard an existing vault — scan, infer profile, register QMD |
| `/pa init <vault-path>` | primitive | `setup` | Bootstrap a fresh vault — interview, scaffold, configure QMD |

### Phase 2

| Command | Type | Stage | Description |
|---------|------|-------|-------------|
| `/pa ask <question>` | composite | `starter` | Ask your vault a question — RAG Q&A with citations |
| `/pa brief <topic>` | primitive | `starter` | Generate a focus dossier — topic, project, or person briefing |

### Phase 3

| Command | Type | Stage | Description |
|---------|------|-------|-------------|
| `/pa draft <topic\|--revise path>` | primitive | `starter` | Create or revise a note in vault-native voice |
| `/pa capture <raw text>` | primitive | `starter` | Capture raw input — thoughts, transcripts, scraps into structured notes |

### Phase 4

| Command | Type | Stage | Description |
|---------|------|-------|-------------|
| `/pa agenda [--horizon today\|week\|month]` | primitive | `intermediate` | Show what matters now — priorities, deadlines, waiting-fors |
| `/pa day [morning\|evening\|status]` | composite | `intermediate` | Daily flow — morning brief, agenda, Fractal Journaling |

### Phase 5

| Command | Type | Stage | Description |
|---------|------|-------|-------------|
| `/pa link <note-path or topic>` | primitive | `starter` | Discover relationships — link suggestions, unresolved fixes, relationship maps |
| `/pa focus <goal or topic>` | composite | `intermediate` | Build working context — entity dossier, relationship analysis, action plan |

### Phase 6

| Command | Type | Stage | Description |
|---------|------|-------|-------------|
| `/pa ingest <URL, text, or file>` | primitive | `intermediate` | Import external content — URL fetch, article paste, transcript, file import |
| `/pa compile [--from DATE] [--to DATE]` | primitive | `advanced` | Compile captures into period summary — themes, decisions, carry-forward |

### Phase 7 (Current)

| Command | Type | Stage | Description |
|---------|------|-------|-------------|
| `/pa review [--horizon week\|month\|...\|lifetime]` | primitive | `advanced` | Review vault health — stale items, orphans, resurfacing across any horizon |
| `/pa reset [--horizon week\|month\|...\|lifetime]` | composite | `advanced` | Periodic reset — review → compile → agenda → link for any horizon |

### Phase 8

| Command | Type | Stage | Description |
|---------|------|-------|-------------|
| `/pa steward` | meta-composite | `expert` | Bounded vault maintenance — survey refresh, review, link repair, agenda reset |

## Components

| Path | Type | Role |
|------|------|------|
| `commands/pa/survey.md` | command | Existing vault onboarding |
| `commands/pa/init.md` | command | Fresh vault bootstrap |
| `commands/pa/ask.md` | command | RAG Q&A with citations |
| `commands/pa/brief.md` | command | Focus dossier generation |
| `agents/pa/cartographer.md` | agent | Vault structure analyst |
| `agents/pa/librarian.md` | agent | Context broker (QMD retrieval) |
| `agents/pa/scribe.md` | agent | Vault-native writer (opus) |
| `agents/pa/curator.md` | agent | Capture triage specialist (sonnet) |
| `agents/pa/chief-of-staff.md` | agent | Priority judgment engine (opus) |
| `agents/pa/weaver.md` | agent | Graph reasoner — entity/relation discovery (sonnet) |
| `agents/pa/sentinel.md` | agent | Vault health watchdog — stale/orphan detection (sonnet) |
| `skills/pa/vault-modeling/` | skill | Vault inference methodology |
| `skills/pa/trust-and-boundaries/` | skill | Automation posture rules |
| `skills/pa/context-assembly/` | skill | Retrieval orchestration methodology |
| `skills/pa/writing/` | skill | Voice adaptation + vault-native writing |
| `skills/pa/capture-distillation/` | skill | Raw input triage + distillation |
| `skills/pa/executive-assistance/` | skill | Time-aware prioritization + agenda |
| `skills/pa/personal-ontology/` | skill | Entity extraction, relation discovery, graph reasoning |
| `skills/pa/review-and-journaling/` | skill | Review loops, resurfacing, Fractal Journaling hierarchy |
| `templates/pa/vault-profile.md` | template | Profile rendering |
| `templates/pa/profiled-note.md` | template | Profile-aware note |
| `templates/pa/focus-brief.md` | template | Focus dossier rendering |
| `templates/pa/timestamp-note.md` | template | Quick capture note |
| `templates/pa/daily-brief.md` | template | Daily briefing |
| `templates/pa/daily-link-hub.md` | template | Fractal Journaling daily hub |
| `templates/pa/relationship-map.md` | template | Relationship map rendering |
| `templates/pa/project-dossier.md` | template | Project dossier rendering |
| `templates/pa/ingest-digest.md` | template | External source digest |
| `templates/pa/period-compilation.md` | template | Period compilation synthesis |
| `templates/pa/follow-up-report.md` | template | Review follow-up report |
| `templates/pa/weekly-review.md` | template | Horizon-aware reset output |

## Usage

```bash
# Onboard an existing vault
claude "/pa survey ~/obsidian/my-vault"

# Create a new vault from scratch
claude "/pa init ~/obsidian/new-vault"

# Ask a question about vault content
claude "/pa ask 'What meta-prompts are in my vault?'"

# Generate a topic briefing
claude "/pa brief 'meta-prompts'"

# Capture a quick thought
claude "/pa capture '내일 팀 미팅에서 API 설계 논의 필요'"

# Draft a new note with vault context
claude "/pa draft 'meta-prompts design patterns'"

# Discover relationships for a note
claude "/pa link notes/meta-prompts-moc.md"

# Build a working context around a goal
claude "/pa focus 'meta-prompts design patterns'"

# Import an article into the vault
claude "/pa ingest 'https://example.com/article'"

# Compile recent captures into a period summary
claude "/pa compile --from 2026-03-10 --to 2026-03-16"

# Natural language — import and compile
claude "/pa 이 글 정리해서 vault에 넣어줘"

# Review vault health
claude "/pa review --horizon month"

# Weekly reset (review + compile + agenda + link)
claude "/pa reset --horizon week"

# Natural language — review and reset
claude "/pa 방치된 노트 있어?"
claude "/pa 이번 주 정리해줘"

# Vault maintenance
claude "/pa steward"
claude "/pa vault 관리해줘"
```

## Recurring Use

PA commands can run on a recurring schedule in two ways:

### In-Session (`/loop`)

Session-scoped recurring prompts. Expires after 3 days or when the session ends. Use for monitoring during active work.

```bash
# Periodic today snapshot while working
/loop 30m /pa day --mode status

# Watch for stale items during a project sprint
/loop 2h /pa review --horizon week

# Background maintenance during a long session
/loop 6h /pa steward
```

### System-Scope (`pa-scheduler.sh`)

Persistent crontab entries that run unattended. Use for daily routines, nightly gardening, and periodic health checks.

```bash
# Install default schedules (morning brief, weekly review, nightly garden, heartbeat)
bash scripts/pa-scheduler.sh install

# List all scheduled PA tasks
bash scripts/pa-scheduler.sh list

# Run a specific schedule manually
bash scripts/pa-scheduler.sh run morning-brief
```


## Design Spec

