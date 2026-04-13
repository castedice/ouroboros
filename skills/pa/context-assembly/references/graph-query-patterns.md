---
name: graph-query-patterns
description: This reference defines graph traversal query types, depth limits, entity caps, and integration patterns for ontology-based retrieval. It should be consulted when an agent needs to "traverse the entity graph", "find entity neighbors", "seed retrieval from graph", or "combine graph context with QMD search".
---

# Graph Query Patterns — Ontology-Based Retrieval

> Purpose: Reference for `context-assembly` — defines how graph traversal complements QMD text search.
> This reference is standalone and can be consulted without the parent skill.
> For text-based retrieval patterns, see `skills/pa/context-assembly/references/query-patterns.md`.
> For entity and relation definitions, see `skills/pa/personal-ontology/SKILL.md`.

## Query Types

| Type | Description | Max Depth | Max Entities | Use Case |
|------|-------------|-----------|-------------|----------|
| `neighbors` | Direct edges from or to the seed entity | 1 | 20 | "What's related to X?" — quick context |
| `path` | Shortest path between two named entities | 5 | 50 | "How are X and Y connected?" |
| `subgraph` | Seed entity plus all entities within 2 hops via strong edges only | 2 | 30 | `/pa focus` deep context |

### Strong Edge Filter (for subgraph)

Only traverse edges with `confidence >= 0.6` and relation type not in `["related-to", "co-occurs-with"]`.

## Seed Resolution

1. Match the query term against `canonical_name` exactly, case-insensitively.
2. If no match exists, check `aliases[]` across all entities.
3. If no match exists, check note titles in `canonical_note` fields.
4. If no match exists, return `seed_resolved: false` and let the caller fall back to pure QMD.

## Graph Context Output

The weaver returns a `graph_context` object to the calling command.

```json
{
  "seed_resolved": true,
  "seed_entity": {"id": "e-001", "label": "Project Alpha", "kind": "project"},
  "query_type": "neighbors",
  "neighbors": [
    {"entity": {"id": "e-002", "label": "Person_A", "kind": "person"}, "relation": "owns", "direction": "incoming", "confidence": 0.85},
    {"entity": {"id": "e-003", "label": "API Design", "kind": "topic"}, "relation": "references", "direction": "outgoing", "confidence": 0.9}
  ],
  "candidate_notes": ["projects/alpha/design.md", "projects/alpha/requirements.md", "daily/2026-03-10.md"],
  "graph_density": "medium"
}
```

`candidate_notes` is the union of `canonical_note` and `source_docs` from the seed and all traversed entities.

## Command Orchestration Pattern

The command layer orchestrates graph and text retrieval.

1. Command detects an entity-centric query from an entity name in the question or `neighborhood`, `dossier`, or `graph` intent.
2. Command calls the weaver with `analysis_type: "graph-query"`, passing the query, `entities.json`, and `relations.json`.
3. Weaver returns `graph_context`.
4. Command passes `graph_context` to the librarian as additional input alongside the question.
5. Librarian uses `candidate_notes` as QMD `multi_get` seeds and also runs normal QMD queries.
6. Librarian fuses graph-seeded results with QMD results.

If `seed_resolved: false`, skip the graph-specific steps and proceed with pure QMD.

## Intent Integration

| Existing Intent | Graph Query | Behavior |
|-----------------|------------|----------|
| `factual` | Optional | Only if the question names a known entity |
| `conceptual` | Optional | If the topic resolves to an entity |
| `dossier` | Always | Central entity plus neighbors |
| `temporal` | No | Time-based, not entity-based |
| `exploratory` | Optional | If the exploration target is an entity |
| `neighborhood` | Always | Graph traversal is the primary strategy |
| `graph` | Always | Explicit graph query |

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/context-assembly/references/query-patterns.md` | Sibling — text-based retrieval patterns |
| `skills/pa/context-assembly/SKILL.md` | Parent — retrieval workflow |
| `agents/pa/weaver.md` | Graph query executor (Workflow G) |
| `agents/pa/librarian.md` | Consumer of `graph_context` for seeded retrieval |
| `skills/pa/personal-ontology/SKILL.md` | Entity and relation definitions |
