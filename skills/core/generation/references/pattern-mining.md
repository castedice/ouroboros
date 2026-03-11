# Pattern Mining from Reference Implementations

How to extract reusable patterns from existing components. Applied during Step 1 (Pattern Mining) of the generation workflow.

## Four Extraction Dimensions

Pattern mining examines reference implementations through four lenses. Each dimension captures a different aspect of "what makes this component work" that must be reproduced in generated content.

### 1. Structural Pattern Extraction

**What**: The skeleton of a component — section order, heading hierarchy, frontmatter fields, and content block types.

**Procedure**:

1. Read the reference component's frontmatter — note all fields and their value formats
2. List all heading levels in order (H2 → H3 → H4 nesting pattern)
3. Identify the section types: prose, table, code block, list, template block
4. Note the opening pattern: what comes immediately after frontmatter?
5. Note the closing pattern: what are the final sections?

**Extraction template**:

```markdown
### Structural Pattern: {component type}

Frontmatter: {field1}: {format}, {field2}: {format}, ...
Opening: {what comes first after frontmatter}
Section sequence: {H2: Name} → {H3: Sub} → ...
Closing: {final sections}
Content types: {prose|table|code|list per section}
```

**Example** — Agent structural pattern:

- Frontmatter: `name` (string), `description` (multi-line with triggers + examples), `model` (opus|sonnet), `tools` (array), `color` (string)
- Opening: Persona line ("You are a {role} for the ouroboros meta-plugin.")
- Section sequence: Core Principles (H2) → numbered principles → Analysis Procedures (H2) → Procedure: {Name} (H2) → Step N (H3) → Calibration (H2) → Scope Boundary (H2)
- Closing: Content Safety (if applicable) → Calibration → Scope Boundary
- Content types: Principles are bold+numbered lists; Procedures are numbered steps with sub-steps; Calibration uses code blocks with good/bad examples

### 2. Style Pattern Extraction

**What**: The voice and presentation of content — tone, sentence structure, level of detail, and formatting conventions.

**Procedure**:

1. Read 3-5 representative paragraphs from the reference
2. Identify the voice: imperative ("Do X"), second-person ("You should X"), or declarative ("X is done by")
3. Measure detail level: are procedures step-by-step or high-level summaries?
4. Note formatting conventions: bold for emphasis, `code` for identifiers, > for quotes
5. Check sentence length: short and direct, or longer with qualifications?

**Key style dimensions**:

| Dimension | Options | How to Detect |
|-----------|---------|---------------|
| **Voice** | Imperative / Second-person / Declarative | Read procedure steps — which pronoun/verb form? |
| **Detail** | Step-by-step / Summarized | Count sub-steps per procedure step |
| **Emphasis** | Bold keywords / Inline code / Headers | Scan for formatting patterns in prose |
| **Examples** | Inline / Separate section / Code blocks | Where and how are examples presented? |
| **Tone** | Technical / Instructional / Conversational | Read opening paragraph — formal or direct? |

**Component type norms** (extract from references, don't assume):

- Commands tend toward declarative, step-by-step, with phase-gated structure
- Agents tend toward second-person imperative, with numbered procedures
- Skills tend toward instructional prose, with technique reference tables

### 3. Relationship Pattern Extraction

**What**: How components reference and depend on each other — delegation patterns, skill consumption, cross-references.

**Procedure**:

1. Search for references to other components (file paths, component names)
2. Classify each reference:
   - **Delegation**: "Launch the {agent} agent via Task tool" — command → agent
   - **Consumption**: "Apply techniques from references/{file}" — agent/command → skill
   - **Cross-reference**: "See Also: {component}" — mutual awareness
   - **Dependency**: "Requires {component} to have run first" — ordering constraint
3. Map the relationship direction: who initiates? who provides?
4. Note the reference format: full path, relative path, or name-only?

**Relationship types in ouroboros**:

| Relationship | From → To | Pattern |
|-------------|-----------|---------|
| **Command delegates** | Command → Agent | "Launch the **{agent}** agent via Task tool" in a phase |
| **Agent consumes skill** | Agent → Skill | "Apply {technique} from references/{file}" in a procedure step |
| **Skill references skill** | Skill → Skill | See Also section with path and relationship description |
| **Command chains** | Command → Command | "Suggested Next Actions: `/command {args}`" in report phase |

### 4. Convention Inference

**What**: Implicit rules that are followed consistently but not always documented — naming patterns, required sections, formatting standards.

**Procedure**:

1. Compare 2-3 components of the same type side by side
2. Identify elements that appear in ALL references (these are conventions, not coincidence)
3. Identify elements that appear in SOME references (these may be optional or context-dependent)
4. For each convention, verify it's intentional:
   - Is it documented in AGENTS.md or CLAUDE.md?
   - Is it enforced by evaluation criteria?
   - Is it consistent across all examined references?

**Convention categories**:

| Category | Examples |
|----------|---------|
| **Naming** | Agent descriptions start with "Use this agent when you need to..." |
| **Frontmatter** | Skills use `name: {domain}-methodology` pattern |
| **Sections** | Agents always end with Scope Boundary section |
| **Format** | Tables for structured comparisons, prose for explanations |
| **Content** | Commands include error handling per phase; agents include calibration examples |

## Mining Procedure Summary

For each component to generate:

1. **Select references**: Choose 2-3 existing components of the same type. Prefer components from the same module, then from `core/`
2. **Apply four dimensions**: Extract structural, style, relationship, and convention patterns
3. **Synthesize mining report**: Document the patterns that the new component must follow
4. **Cross-check with criteria**: Verify that following these patterns would satisfy Foundation criteria

## Common Mining Errors

| Error | Symptom | Fix |
|-------|---------|-----|
| Mining from 1 reference only | Generated component copies one component's idiosyncrasies | Always mine from 2+ references; look for shared patterns, not individual quirks |
| Copying content, not patterns | Generated procedures are reworded versions of reference procedures | Extract structure and style, then write domain-specific content |
| Missing convention inference | Generated component breaks unwritten rules | Compare 2+ same-type components side by side to find consistent elements |
| Ignoring relationship patterns | Generated component is isolated, no cross-references | Check how references link to other components; replicate the linking pattern |
| Over-mining (analysis paralysis) | Too much time on mining, not enough on generation | Mining should take ~20% of generation time; extract essentials, not exhaustive catalog |
