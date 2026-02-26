---
type: upgrade
date: ${DATE}
module: ${MODULE}
from-version: ${FROM_VERSION}
to-version: ${TO_VERSION}
upstream-source: "${UPSTREAM_SOURCE}"
intent: "${INTENT}"
---

## Background

${BACKGROUND — why this upgrade was performed, what triggered it}

## Version Info

- **From**: ${FROM_VERSION}
- **To**: ${TO_VERSION}
- **Upstream**: ${UPSTREAM_SOURCE}
- **Method**: ${METHOD — git fetch | --source local path}

## Decisions

${DECISIONS — strategic choices made during the upgrade process}

- {Decision 1}: {rationale}
- {Decision 2}: {rationale}

## Change Summary

| # | File | Classification | Action Taken |
|---|------|----------------|--------------|
| 1 | `${FILE_PATH}` | ${AUTO-MERGE | CONFLICT-A | CONFLICT-B | ADDITION | REMOVAL} | ${action description} |

**Legend:**

- **AUTO-MERGE**: No local customization — upstream change applied directly
- **CONFLICT-A**: Both upstream and local modified — resolved via 3-way merge
- **CONFLICT-B**: Upstream addition overlaps with local component — user choice applied
- **ADDITION**: New file from upstream — no local counterpart
- **REMOVAL**: Upstream removed file — applied or guarded if customized

## Conflict Resolutions

${IF NO CONFLICTS: "No conflicts detected. All changes were auto-merged or additions."}

${FOR EACH CONFLICT:}

### ${CONFLICT_NUMBER}. `${FILE_PATH}` (${CONFLICT-A | CONFLICT-B})

- **Upstream change**: ${description of what upstream modified or added}
- **Local customization**: ${description of user's evolve/generate/absorb decision}
- **Decision entry**: `docs/decisions/${RELATED_DECISION_ENTRY}`
- **Resolution**: ${merged — preserving both | kept local | accepted upstream | user-chosen hybrid}
- **Rationale**: ${why this resolution was chosen}

## User Customizations Preserved

| Component | Decision Entry | Customization | Preserved |
|-----------|---------------|---------------|-----------|
| `${COMPONENT_PATH}` | `${DECISION_ENTRY}` | ${description of customization} | ${yes | partial — detail | no — reason} |

## Verification

- Total changes: ${TOTAL_COUNT}
- Auto-merged: ${AUTO_COUNT}
- Conflicts resolved: ${CONFLICT_COUNT}
- Additions applied: ${ADDITION_COUNT}
- Removals applied: ${REMOVAL_COUNT}
- Validation: ${PASS_COUNT}/${VALIDATED_COUNT} passed evaluation
- User customizations preserved: ${PRESERVED_COUNT}/${TOTAL_CUSTOMIZATIONS}
