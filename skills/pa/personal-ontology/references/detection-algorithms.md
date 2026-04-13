---
name: detection-algorithms
description: This reference defines the normalized detection algorithms for PA ontology extraction, including structural signal classes, entity candidate assembly, relation candidate scoring, and evidence thresholds by entity kind.
---
# Detection Algorithms - Signal Classes, Candidate Assembly, and Evidence Gates
> Purpose: Reference for `personal-ontology` - use it to operationalize entity and relation detection from the rules already defined in the discovery, taxonomy, privacy, and people references.
> This reference complements `entity-discovery.md` and `relation-taxonomy.md` by focusing on the execution order and the detection algorithm, not the catalog of kinds or relation labels.
> The procedure below is a normalized execution contract synthesized from those sources plus the weaver workflow.
## Detection Pipeline
Run detection in this order.
1. Normalize privacy-bearing names when a mask registry is available.
2. Extract raw structural observations from notes and approved profile or overlay sources.
3. Assemble entity candidates by normalized identity, ontology family, and kind hints.
4. Apply entity ingress thresholds before canonicalization.
5. Canonicalize surviving entities.
6. Generate relation candidates from entity pairs with shared evidence.
7. Assign the most specific relation type whose minimum evidence rule is satisfied.
8. Treat semantic similarity as reinforcement only after structural or profile-backed grounding exists.
## Signal Classes
Group all observations into one of these signal classes before scoring them.
| Signal Class | Examples | Allowed For Creation | Typical Strength |
|--------------|----------|----------------------|------------------|
| Direct structural | Wikilinks, explicit frontmatter pointers, dedicated note titles | Vault entities and structural relations | Strong |
| Metadata structural | Frontmatter tags, owner fields, project fields, typed properties | Vault entities and structural relations | Strong |
| Note-shape structural | Repeated headings, recurring title patterns, folder or MOC placement | Vault entities and some relation hints | Medium |
| Profile-backed | `personal-profile.json`, approved interview output, approved life overlays | Life entities and life or person relations | Strong |
| Contextual | Repeated co-occurrence, shared entity neighborhood, scope overlap, temporal replacement cues | Relation typing only after grounding exists | Medium |
| Semantic | QMD similarity, lexical cluster overlap | Never by itself | Weak reinforcement |
## Entity Candidate Assembly
Build candidates as grouped observation buckets.
1. Normalize the observed name or mask identifier.
2. Keep `vault` and `life` buckets separate even when the normalized labels match.
3. Track per bucket the set of source notes, signal classes, kind hints, and authoritative sources.
4. Preserve note-level provenance so later invalidation can subtract one note without destroying the whole bucket.
## Vault Entity Ingress Gate
A vault candidate survives only when structural evidence reaches the minimum threshold.
| Gate | Pass Condition |
|------|----------------|
| Structural count gate | The candidate appears in at least `2` structural sources |
| Distinct note gate | The candidate appears across at least `2` distinct notes |
| Signal diversity gate | The candidate appears through at least `2` signal types |
Operational rule: a vault candidate may proceed when any one of these gates is satisfied.
Semantic similarity never satisfies a vault ingress gate.
## Life Entity Ingress Gate
A life candidate uses authority, not repetition.
| Life Kind Group | Minimum Authority |
|-----------------|-------------------|
| `area`, `goal`, `direction`, `value` | One confirmed profile field |
| `habit`, `milestone` | One approved overlay pointer |
| `decision` | One approved capture or review-backed decision record |
Vault reinforcement may raise confidence for a life entity, but it does not create the identity in the first place.
## Registry-Seeded Exception
Registered people are an explicit exception to the generic vault two-signal rule.
Interview bootstrap or direct registration may create a minimal person shell before vault reinforcement exists.
That shell is still treated as a `vault` family person entity for later graph work.
## Kind Resolution Priority
Resolve entity kind by taking the strongest available hint, not the most frequent vague one.
| Priority | Kind Signal |
|----------|-------------|
| 1 | Privacy or people registry hit that already declares the entity kind |
| 2 | Explicit profile or overlay source that declares a life kind |
| 3 | Direct frontmatter typing such as people, owner, project, or tag-like fields |
| 4 | Dedicated note role implied by note title or canonical note placement |
| 5 | Repeated heading or contextual hints when stronger evidence is absent |
When two kind hints conflict, keep the lower-confidence result and send the candidate to canonicalization or review instead of forcing a merge.
## Practical Kind Heuristics
Use these dominant-context heuristics when the sources provide more than one plausible kind.
| Kind Or Group | Dominant Hints |
|---------------|----------------|
| `person` | People registry hit, people frontmatter, repeated person-like wikilinks, or person profile shell |
| `project` | Dedicated project note, project frontmatter, recurring operational references, or project privacy registration |
| `topic` or `concept` | Tag-like metadata, repeated headings, hub-note inclusion, or MOC clustering without concrete ownership fields |
| `organization`, `place`, `education` | Privacy registry hit first, then repeated named structural references with matching contextual fields |
| `event` or `artifact` | Time-anchored note titles, date-heavy source notes, or artifact-like file references |
If the signal remains ambiguous after these heuristics, keep the more general kind and avoid speculative specialization.
## Confidence Bands For Entity Detection
Use evidence pattern, not prose confidence language, to pick the confidence band.
| Pattern | Confidence Band |
|---------|-----------------|
| Dedicated note plus several reinforcing structural signals | High |
| Multiple strong structural signals without a dedicated note | Medium |
| Bare minimum qualifying evidence from weak structural sources | Low |
| Confirmed profile or overlay-backed life identity before vault reinforcement | Medium to high depending on authority depth |
| Registry-seeded person with no vault reinforcement yet | Low to medium |
## Privacy-Bearing Detection Pass
Run privacy normalization before final entity labeling when `mask_map` exists.
Replace matched real names and aliases with `mask_id` for assistant-facing extraction.
Store masked `canonical_name` in the overlay.
Keep real names in the protected detail layer only.
## Relation Candidate Generation
Generate relation candidates from canonicalized entity pairs, not from raw mentions.
1. Build same-note pairs from entities observed in the same note.
2. Add direct structural pairs when a note explicitly links, tags, owns, or contains another entity.
3. Add profile-backed pairs when a life or person authority explicitly names the connection.
4. Remove self-pairs before typing.
5. Attach note-level `evidence_slices` to every surviving pair candidate.
## Co-Occurrence Scoring Ladder
Use the following ladder to decide whether a pair stays weak, upgrades, or remains a suggestion.
| Ladder Stage | Minimum Evidence | Default Outcome |
|--------------|------------------|-----------------|
| 0 | Semantic similarity only | Suggestion only, not a stored relation |
| 1 | Same-note presence with no stronger signal | `co-occurs-with` candidate |
| 2 | Co-occurrence across `2+` notes or repeated structural co-presence | `related-to` candidate |
| 3 | Explicit structural pointer such as wikilink, containment, or frontmatter field | Structural typed relation candidate |
| 4 | Structural or profile-backed grounding plus contextual analysis | Semantic typed relation candidate |
| 5 | Profile or interview authority with entity metadata alignment | Life-specific or person-specific typed relation candidate |
This ladder is not a second taxonomy.
It is the promotion order that determines which candidate class should be evaluated next.
## Relation Selection Order
When more than one relation type could fit the same pair, evaluate in this order.
1. Explicit structural relation types such as `references`, `parent-of`, `tagged-with`, and `owned-by`.
2. Profile-backed life relation types such as `belongs-to-area`, `advances-direction`, `guided-by-value`, `informed-by-decision`, and `embodies`.
3. Profile-backed person relation types such as `colleague-of`, `family-of`, `friend-of`, `mentored-by`, and `reports-to`.
4. Structural plus contextual semantic relation types such as `extends`, `supports`, `contradicts`, and `supersedes`.
5. Weak fallbacks `related-to` and then `co-occurs-with`.
Choose the most specific satisfied type and do not keep a weaker duplicate of the same pair.
## Contextual Evidence Rules
Contextual evidence never stands alone.
It upgrades a grounded pair.
Use it only after a structural or profile-backed signal already exists.
| Contextual Pattern | What It Can Upgrade |
|--------------------|---------------------|
| Elaborative discussion after a direct reference | `references` to `extends` |
| Example or evidence language after a direct reference | `references` to `supports` |
| Later note with overlapping scope and replacement cues | `references` to `supersedes` |
| Explicit opposing claims on the same grounded topic | Grounded pair to `contradicts` |
| Profile or metadata tie between goal and value, direction, or decision | Grounded pair to the corresponding life relation |
## Evidence Thresholds By Relation Family
Apply these minimum gates before assigning a stored relation type.
| Relation Family | Minimum Gate |
|-----------------|--------------|
| Structural vault relations | One direct structural signal |
| Semantic vault relations | One structural signal plus one contextual signal |
| Weak fallback relations | Repeated co-occurrence for `related-to`, or one same-note pair for `co-occurs-with` |
| Life-specific relations | One profile-backed or overlay-backed signal, optionally reinforced by vault notes |
| Person-specific relations | One profile-backed or interview-backed signal, with vault co-occurrence as reinforcement only |
Vault co-occurrence alone is insufficient for person-specific relation typing.
## Evidence Thresholds By Entity Kind
Use the strongest threshold that applies to the entity you are about to create.
| Entity Kind Group | Minimum Threshold |
|-------------------|-------------------|
| Generic vault kinds | Pass one vault ingress gate from the structural threshold table |
| Registered or masked person | Registration or interview may seed the shell, then vault evidence reinforces it |
| Other privacy-bearing vault kinds | Structural detection still creates the entity, but mask normalization must run before persistence when a registry hit exists |
| Core life kinds | One confirmed profile field |
| Overlay-backed life kinds | One approved overlay pointer or approved decision record |
## Upgrade Rules
Relations may upgrade as stronger evidence appears later.
`co-occurs-with` may become `related-to`.
`related-to` may become a structural or profile-backed typed relation.
`references` may become `extends`, `supports`, or `supersedes` when contextual evidence appears.
Do not auto-downgrade a stored relation when evidence weakens.
Flag the stale edge for review or remove it only when its supporting slices disappear entirely.
## Sparse Vault Adjustment
Detection should scale down when the vault is small.
Sparse vaults still allow entity extraction, but relation typing should stay conservative.
If the vault has fewer than `5` authored notes, skip aggressive relation discovery.
If the vault has fewer than `10` notes, expect mostly isolated entities and weak edges.
## Pseudocode
```text
for each authority in [vault notes, profile, approved overlays]:
  collect observations by normalized identity and family
  normalize privacy-bearing mentions through mask_map when present
for each candidate bucket:
  if family == life and authority exists:
    accept
  else if family == vault and any structural ingress gate passes:
    accept
  else:
    keep as suggestion only
canonicalize accepted entities
for each canonical entity pair with shared evidence:
  if no structural or profile-backed grounding:
    keep as semantic suggestion only
  else:
    evaluate relation families in specificity order
    assign the first relation type whose minimum gate passes
```
## Validation Checklist
- [ ] Semantic similarity did not create any entity or stored relation by itself.
- [ ] Vault entities passed at least one structural ingress gate before canonicalization.
- [ ] Life entities were created only from confirmed profile or approved overlay authorities.
- [ ] Person-specific relations required profile or interview grounding.
- [ ] Relation typing evaluated stronger, more specific classes before weak fallbacks.
- [ ] Privacy-bearing detections were normalized through `mask_id` before persistence when a registry hit existed.
- [ ] Weak co-occurrence stayed weak until a stronger gate was actually satisfied.
## See Also
| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/references/entity-discovery.md` | Defines the source priorities and ingress rules this algorithm executes |
| `skills/pa/personal-ontology/references/relation-taxonomy.md` | Defines the relation catalog and per-type evidence requirements used at typing time |
| `skills/pa/personal-ontology/references/people-schema.md` | Adds the person-specific shell, registry, and confidence rules |
| `skills/pa/personal-ontology/references/privacy-node-schema.md` | Defines mask normalization and privacy-bearing entity handling |
| `agents/pa/weaver.md` | Primary consumer that applies the detection pipeline during extraction and refresh |
