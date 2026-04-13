# Scaffold and Quality Gate

## Architecture Design

Architecture design turns mined patterns and requested capability into a bounded component plan.
The question is not "what could exist" but "what is the minimum set that delivers the requested value."

### Design Inputs and Outputs

| Stage | Input | Output |
|-------|-------|--------|
| Architecture design | Extracted patterns, target spec, relevant knowledge entries | Component inventory with roles and relationships |

### Minimum Viable Module Rule

- Map requested capabilities to the smallest set of component types that can deliver them.
- Reuse existing agents or skills when they already fit the job.
- Add new components only when reuse would create a worse fit than creation.
- Treat optional extras as future candidates, not default deliverables.

## Scaffold-then-Flesh Strategy

Scaffolding separates structure from prose.
It makes missing sections obvious while edits are still cheap.

### Why Scaffold First

1. Structure errors are cheapest to fix before the content exists.
2. Completeness is visible at the scaffold level.
3. Parallel fleshing is only safe after the structure is stable.

### Scaffold Completeness Checklist

| Component Type | Scaffold Must Include |
|----------------|-----------------------|
| Command | Frontmatter, phase headers, delegation section, and rules section |
| Agent | Frontmatter, procedure headers, output format, and scope boundary |
| Skill | Frontmatter, Core Rule, Gotchas, Workflow, Decision Rules, Reference Map, and See Also |
| Template | Frontmatter, output sections, and placeholder variables |

If the scaffold cannot satisfy the target type's Foundation criteria, the structure is wrong.
Fix the skeleton before adding any body detail.

## Quality-First Generation

Quality-first generation means checking criteria before and during writing, not only after the draft is complete.

### Pre-Generation Criteria Check

| Type | Criteria File |
|------|---------------|
| Agent | `../../evaluation/references/agent-criteria.md` |
| Command | `../../evaluation/references/command-criteria.md` |
| Skill | `../../evaluation/references/skill-criteria.md` |

For each Foundation criterion, verify that the scaffold already has the needed section or field.
For each Craft criterion, note the content quality that the section must eventually satisfy.

### Common Quality Failures

| Failure | Criterion Risk | Prevention |
|---------|----------------|------------|
| Agent description lacks trigger phrases | Foundation trigger criteria | Write the trigger language before the body |
| Agent prompt lacks examples | Example-related Craft criteria | Add concrete examples while fleshing, not as an afterthought |
| Command omits error handling | Command recovery criteria | Add abort and retry paths during phase drafting |
| Skill omits failure handling or bias control | Skill Craft and Excellence criteria | Include gotchas and explicit decision rules before handoff |
| Component lacks cross-references | Integration criteria | Check See Also and delegation references during the gate |

### First-Draft Gate

Use this quick gate before handing the component forward.

- Foundation must fully pass.
- Craft should reach at least 3 unless the user explicitly asked for a rough scaffold only.
- Any obvious 0-score gap should be revised before submission.
- Record what changed during the gate so downstream reviewers see the adjustment history.

## Validation Checklist

- [ ] Two or more same-type references were studied before drafting.
- [ ] Structural, style, relationship, and convention patterns were extracted.
- [ ] The component inventory follows the minimum viable module rule.
- [ ] The scaffold exists before body content was written.
- [ ] The scaffold was checked against Foundation criteria.
- [ ] Content uses domain-specific actions and examples.
- [ ] Cross-references and integration points were verified.
- [ ] The quick quality gate ran before handoff.
