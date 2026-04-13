# PA Vocabulary Guide

> Reference for the pa-teaching skill. Defines PA-specific terms, concept boundaries, and common misconceptions to keep teaching precise and actionable.

## Core Terms

| Term | Definition | Common Misconception |
|------|-----------|---------------------|
| Vault | The user's Obsidian note collection, structured by folders and linked by wikilinks | Not a database — it is a folder of markdown files with conventions, not enforced schema |
| QMD | Local search engine over vault markdown, supporting lexical (BM25) and semantic (vector) queries | Not "AI search" — QMD retrieves and ranks existing notes, it does not generate answers |
| Wikilink | `[[Target Note]]` syntax that creates navigable connections between vault notes | Not a tag or category — wikilinks express relationships, not classification |
| Frontmatter | YAML block at the top of a note (`---` delimited) used for metadata like tags, dates, and properties | Not required for every note — frontmatter matters when retrieval, routing, or automation depends on it |
| Daily note | A date-stamped note (usually `YYYY-MM-DD.md`) used for journaling, capture, and temporal anchoring | Not a diary — daily notes serve as capture inboxes and temporal indexes, not just personal reflection |

## PA State Terms

| Term | Definition | Boundary |
|------|-----------|----------|
| Profile (`.pa/vault-profile.json`) | Observed vault structure: folders, conventions, archetypes, frontmatter patterns | Not user identity — profile describes the vault, not the person |
| Personal profile (`.pa/personal-profile.json`) | User-confirmed life context: name, roles, goals, preferences | Requires explicit user confirmation — never auto-populated from inference |
| Soul (`.pa/soul.md`) | Long-horizon persona layer: values, communication style, life principles | Not a personality test — soul captures what the user explicitly chooses to share about how they want to be assisted |
| Persona (`.pa/persona.json`) | Render settings: warmth, directness, emoji, sentence style | Not soul — persona controls surface output style, not deep values or principles |
| Confidence | Evidence strength for a profile field, scored as `high`, `medium`, or `low` | Not certainty about the user — confidence measures how much vault evidence supports the current field value |
| Memory facts (`.pa/memory-heads.json`) | Active pointer-facts with source note provenance, used for direct answers before QMD | Not persistent knowledge — memory facts are volatile summaries that must trace back to source notes |

## Retrieval Terms

| Term | Definition | Teaching Boundary |
|------|-----------|------------------|
| Context pack | Bundled retrieval results from QMD with citations, coverage assessment, and query analysis | Not "the answer" — a context pack is evidence for the agent to synthesize, not a final response |
| Citation (`[1]`, `[2]`) | Inline marker linking a claim to a specific retrieved vault note | Not a footnote style choice — citations are trust anchors that let the user verify claims |
| Session hit (`[S1]`, `[S2]`) | Reference to a prior conversation segment from the session archive | Not vault evidence — session hits are conversation context, always lower authority than vault notes |
| Coverage assessment | Retrieval confidence indicator: high, medium, low, or none | Not answer confidence — coverage measures how well the vault covers the question, not how correct the answer is |

## Automation Terms

| Term | Definition | Teaching Boundary |
|------|-----------|------------------|
| Write gate | Consent checkpoint before PA writes to the vault | Not a security feature — write gates enforce user control over vault mutations, not access control |
| Posture | Automation level: `observe`, `propose`, `act` | Not a trust level — posture defines the default action boundary, not whether PA is trusted |
| Proposal-only | Default mode where PA suggests changes but never applies them without explicit approval | Not a limitation — proposal-only is a design choice that keeps the user as the vault authority |
| Ledger (`.pa/assistant-ledger.jsonl`) | Append-only audit log of PA actions, decisions, and state changes | Not a conversation log — the ledger records what PA did to the vault, not what was discussed |

## Review Terms

| Term | Definition | Teaching Boundary |
|------|-----------|------------------|
| Agenda | Prioritized list of items for the current day, scored by urgency, importance, and staleness | Not a to-do list — the agenda includes deadlines, waiting-fors, goals, and review items with scoring rationale |
| Horizon | Time scope for review: `day`, `week`, `month` | Not a filter — each horizon has different review behaviors (day=tactical, week=drift, month=structural) |
| Waiting-for | An open dependency tracked until resolved or explicitly closed | Not a reminder — waiting-fors track external blockers, not personal tasks |
| Stale | An item that has not been updated within its expected refresh window | Not forgotten — stale items may still be valid but need re-confirmation |
