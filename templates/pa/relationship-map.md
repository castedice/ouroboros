---
title: Relationship Map
description: Visual relationship map template for a note or entity — rendered from weaver analysis showing connections, clusters, and graph density
---

# Relationship Map Template

PA commands use this template when generating a relationship map for a specific note or entity. The weaver agent provides the graph analysis; the calling command renders this template from the discovered connections.

This template is read-only output — it is presented in the conversation, not written to the vault. Writing a map to the vault requires explicit user request and appropriate automation posture.

## Rendering Rules

1. **Center**: The center entity comes from the caller's target argument. Use its canonical name from the weaver's entity data.
2. **Connections**: List each connected entity grouped by relation type. Show direction, confidence, and evidence summary. Respect `linking_style.prefer_wikilinks` for entity names.
3. **Clusters**: Group entities that share 2+ relations or co-occur in the same notes. Name each cluster by its dominant theme or shared tag.
4. **Unresolved Links**: List wikilinks from the center entity that point to nonexistent notes, with best-match suggestions from the weaver.
5. **Density Summary**: Report graph density metrics — entity count, relation count, and density classification.
6. **Map Visualization**: Render an ASCII or text-based connection diagram showing the center entity and its immediate neighborhood.
7. **Links**: Use `[[wikilinks]]` when `{{linking_style.prefer_wikilinks}}` is `true`, otherwise markdown links.

## Output Format

```markdown
# {{center_entity}} — Relationship Map

> Generated: {{timestamp}} | Connections: {{relation_count}} | Density: {{density}}

## Map

```text
{{ascii_map}}
```

## Connections

### References ({{count}})

| Target | Direction | Confidence | Evidence |
|--------|-----------|------------|----------|
| [[{{entity}}]] | {{center}} → {{entity}} | {{confidence}} | {{evidence_summary}} |

### Extends ({{count}})

| Target | Direction | Confidence | Evidence |
|--------|-----------|------------|----------|
| [[{{entity}}]] | {{center}} → {{entity}} | {{confidence}} | {{evidence_summary}} |

### Related To ({{count}})

| Target | Direction | Confidence | Evidence |
|--------|-----------|------------|----------|
| [[{{entity}}]] | {{center}} ↔ {{entity}} | {{confidence}} | {{evidence_summary}} |

## Clusters

### {{cluster_name}}
- **Members**: [[{{entity_1}}]], [[{{entity_2}}]], [[{{entity_3}}]]
- **Shared signal**: {{what_connects_them}}

## Unresolved Links

| Unresolved | Best Match | Confidence |
|------------|------------|------------|
| `[[{{broken_link}}]]` | [[{{suggested_match}}]] | {{confidence}} |

## Density Summary

- **Entities**: {{entity_count}}
- **Relations**: {{relation_count}}
- **Density**: {{sparse|moderate|dense}}
- **Hub entities**: {{entities_with_5_plus_relations}}
```

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `center_entity` | Weaver's canonical name for the target entity | Caller-provided target argument verbatim |
| `timestamp` | Current date/time at render | ISO 8601 format |
| `relation_count` | Total relations from weaver analysis | `0` if no relations |
| `density` | Weaver's density classification | `sparse` for < 5 relations |
| `ascii_map` | Text diagram of center entity and 1-hop neighborhood | Omit section if < 3 connections |
| `entity` | Canonical entity name from weaver | Wikilink target verbatim |
| `confidence` | Per-relation confidence from weaver | `low` if not provided |
| `evidence_summary` | One-line structural evidence description | "structural co-occurrence" |
| `cluster_name` | Dominant theme or shared tag of the cluster | "Unnamed cluster" |
| `broken_link` | Wikilink target that does not resolve to a note | From target note's wikilinks |
| `suggested_match` | Best matching existing note from weaver search | "No match found" |
| `linking_style.prefer_wikilinks` | `vault-profile.json` → `linking_style.prefer_wikilinks` | `true` |

## ASCII Map Guidelines

Render a simple text-based diagram showing the center entity and its direct connections. Use arrows to show direction.

```text
                    [[parent topic]]
                          ↑
    [[related note]] ← [[CENTER]] → [[referenced note]]
                          ↓
                    [[child topic]]
```

Keep the diagram readable:
- Maximum 8 entities in the diagram (center + 7 neighbors).
- If more than 7 connections exist, show the 7 highest-confidence relations and note "... and N more connections".
- Use `→` for outgoing references, `←` for incoming, `↔` for symmetric relations.
- Group entities by spatial position (parents above, children below, peers on sides).

## Section Omission Rules

| Section | Omit When |
|---------|-----------|
| Map (ASCII) | Fewer than 3 connections |
| Clusters | Fewer than 2 clusters with 2+ members each |
| Unresolved Links | No unresolved wikilinks found |
| Individual relation type tables | No relations of that type exist |

When a section is omitted, do not include its heading. The remaining sections should flow naturally without placeholder text.

## Usage by Commands

Commands reference this template when rendering a relationship map.

The calling command (`/pa link` with `--map` or density threshold) is responsible for:

- Providing the weaver's complete analysis as input
- Selecting which relation types to display (all by default)
- Applying `moc_preference` to decide whether to render a map at all
- Applying `link_density` to cap the number of displayed connections
