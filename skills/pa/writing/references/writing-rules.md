# Writing Rules — Markdown Portability and Content Conventions

> Purpose: Reference for `writing` skill — concrete rules for vault-native markdown output, frontmatter handling, link syntax, and portability constraints. This reference is standalone and can be consulted without the parent skill. For the end-to-end writing procedure, see `skills/pa/writing/SKILL.md`.

## Scope

This reference covers the invariant writing rules that apply to all PA-authored markdown regardless of precedent level, fingerprint, or vault archetype.

## Core Writing Rules

1. **Markdown-first**: Notes must be readable in any plain text editor, in 2060. No reliance on a specific rendering engine.
2. **File over app**: No Obsidian-specific features that break portability unless the vault already uses them extensively (5+ notes).
3. **Preserve vault conventions**: Match the vault's existing frontmatter schema, linking syntax, and naming patterns.
4. **Prefer durable structure**: Headings and links over hidden metadata or plugin-dependent semantics.
5. **Never impose a foreign method**: No PARA, no Zettelkasten, no GTD, no system the user did not choose. Follow what exists.
6. **Revision preserves local structure**: When editing an existing note, change only the requested sections. Never normalize formatting, reorder headings, or rewrite untouched paragraphs.

## Frontmatter Rules

| Rule | Detail |
|------|--------|
| Field set | Add only fields that appear in 2+ exemplars or in `vault-profile.frontmatter.common_fields`. Never introduce fields the vault does not use |
| Field order | Match the order observed in exemplars. When no exemplar exists, follow `vault-profile.frontmatter` array order |
| Created/updated | Use the vault's field names (`created`/`updated` vs `date created`/`date modified`). Check vault-profile for the standard |
| Tags | Use the tag format from exemplars (inline `tags: [a, b]` vs nested). Do not add tags the vault does not use |
| Empty fields | Omit fields without a resolved value rather than writing empty strings |

## Link Syntax Rules

| Vault Convention | PA Behavior |
|-----------------|-------------|
| `prefer_wikilinks: true` | Use `[[note name]]` for all internal links |
| `prefer_wikilinks: false` | Use `[text](relative-path.md)` for all internal links |
| Bare wikilinks dominant | Do not add display aliases — write `[[note]]` not `[[note\|alias]]` |
| Aliased wikilinks common | Follow the aliasing pattern — use `[[note\|display text]]` when clarity requires it |
| `unresolved_link_policy: allowed` | May create wikilinks to notes that do not exist yet |
| `unresolved_link_policy: discouraged` | Avoid creating links to non-existent notes; prefer inline text |

## Portability Rules

| Feature | Allowed When | Forbidden When |
|---------|-------------|----------------|
| Dataview queries (`dataview` blocks) | 5+ vault notes use them | Vault does not use dataview |
| Embedded JS (`dataviewjs` blocks) | Vault has an established pattern | Default — never introduce |
| Callout blocks (`> [!type]`) | 2+ exemplars use them | No exemplar uses them |
| Mermaid diagrams | Vault has existing mermaid blocks | Default — never introduce |
| HTML tags | Vault uses them for specific layout | Default — pure markdown only |
| Templater syntax (`<% ... %>`) | Active in templates only | Never in authored notes |

## Content Compression Rules

| Vault Style | PA Behavior |
|-------------|-------------|
| Terse (avg < 12 words/sentence) | Match the compression. Do not expand sentences "for clarity" |
| Standard (12-25 words/sentence) | Write naturally within this range |
| Expanded (avg > 25 words/sentence) | Allow longer sentences. Do not compress "for conciseness" |

The goal is to match, not improve. A terse vault that receives expanded PA notes feels foreign even when the content is correct.
