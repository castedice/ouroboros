# Adapter Contracts

This reference defines the thin adapter layer for the RnD MVP.
Adapters normalize unstable tools into stable research contracts so stored artifacts stay valid even if the backing tool changes later.

## Shared Rules

Every adapter call should emit enough information to reconstruct what was requested, what was returned, what it cost, and which artifact captured the result.
Adapter outputs should be normalized before they enter `prior-work-map.md`, `experiment-ledger.jsonl`, or `review.md`.
When a fetched source is a PDF, deck, image, or transcript instead of plain HTML, use `skills/pa/content-pipeline/SKILL.md` to normalize the content before minting the final source record.

## MVP Adapters

| Adapter | Backend | Normalized operations | Primary states | Output contract |
|---------|---------|-----------------------|----------------|-----------------|
| Web search | `WebSearch` tool | `search`, `snapshot` | `prior-work`, `perspectives` | Shortlisted result stubs plus stable source records after snapshotting |
| Web fetch | `WebFetch` tool | `fetch`, `snapshot` | `prior-work`, `perspectives`, `probes` | Fetched content, normalized text or extracted packet, and stable source record |
| Model routing | `scripts/codex-relay.sh` with existing routing patterns | `route`, `compare`, `consensus`, `persist` | `hypotheses`, `review`, `meta-learn` | Routed verdicts, disagreement notes, and persisted review-side evidence |

## Operation Contracts

### Web Search

`search` takes a scoped query plus optional domain, recency, and result-count hints.
It returns result stubs that are useful for shortlist generation but are not yet durable evidence.
`snapshot` turns a shortlisted result into a stable source record with query provenance, fetch metadata, and a content hash.

### Web Fetch

`fetch` takes a URL or previously discovered result reference and returns the raw retrievable content plus response metadata.
`snapshot` converts the fetched content into a stable source record and stores normalized text or an extracted packet reference.
Use `fetch` only after a source has passed shortlist judgment, because repeated broad fetching burns budget quickly.

### Model Routing

`route` sends a bounded task to the routed model backend through `scripts/codex-relay.sh`.
`compare` aligns independent routed outputs or scores against the host artifact under review.
`consensus` applies the existing routing and evaluation patterns to boundary disagreements.
`persist` stores the routed verdict, evidence pointers, and confidence note in the review or meta-learning path.

## Source Record Schema

Every durable source becomes a normalized source record before it supports a claim.

```json
{
  "source_id": "src-web-20260408-001",
  "type": "paper",
  "title": "Example Paper Title",
  "authors": [
    "Author One",
    "Author Two"
  ],
  "date": "2026-03-14",
  "url": "https://example.org/paper",
  "hash": "sha256:abcdef1234567890",
  "provenance": {
    "adapter": "web-fetch",
    "discovered_via": "query: low-data adaptation technique x",
    "fetched_at": "2026-04-08T12:34:56Z",
    "snapshot_path": ".rnd/caches/sources/src-web-20260408-001.json"
  }
}
```

The minimum required fields are stable id, type, title, authors, date, URL, hash, and provenance.
Add normalized text paths, archive overlaps, or extraction metadata as optional fields rather than replacing the minimum schema.

## Future Adapter Stubs

| Stub | Planned operations | Future use |
|------|--------------------|------------|
| Semantic Scholar | `search`, `fetch`, `cite`, `related`, `snapshot` | Better paper recall, citation chains, and author graph exploration |
| arXiv | `search`, `fetch`, `snapshot` | Reliable preprint discovery and version tracking |
| Code sandbox | `prepare`, `run`, `capture`, `hash`, `summarize` | `literature+code` reproducibility probes |
| Data sandbox | `mount`, `sample`, `run`, `capture`, `summarize` | `literature+data` empirical probes and dataset lineage |

Future adapters may expand the probe surface, but they should reuse the same source record, probe trace, and handoff contracts so the archive model does not fork.
